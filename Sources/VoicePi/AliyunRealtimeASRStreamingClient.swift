import Foundation

actor AliyunRealtimeASRStreamingClient: RemoteASRStreamingClient {
    typealias TransportFactory = @Sendable (URLRequest) async throws -> WebSocketTransport

    private enum State: Equatable {
        case idle
        case connecting
        case connected
        case finishing
        case finished
        case failed
        case cancelled
    }

    nonisolated let events: AsyncStream<RemoteASRStreamEvent>

    private let eventsContinuation: AsyncStream<RemoteASRStreamEvent>.Continuation
    private let transportFactory: TransportFactory
    private let clock: RealtimeClock
    private let connectTimeoutSeconds: Double

    private var state: State = .idle
    private var transport: WebSocketTransport?
    private var receiveTask: Task<Void, Never>?
    private var taskID: String = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    private var pendingPCMBuffer = Data()
    private var latestPartialText = ""
    private var sentenceEndResults: [(endTime: Int, text: String)] = []
    private var seenSentenceEndTimes: Set<Int> = []
    private var finalText: String?
    private var terminalError: RemoteASRStreamingError?
    private var finishSent = false
    private var eventsFinished = false

    init(
        transportFactory: @escaping TransportFactory = { request in
            URLSessionWebSocketTransportFactory().makeTransport(request: request)
        },
        clock: RealtimeClock = SystemRealtimeClock(),
        connectTimeoutSeconds: Double = 2.0
    ) {
        var continuation: AsyncStream<RemoteASRStreamEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventsContinuation = continuation
        self.transportFactory = transportFactory
        self.clock = clock
        self.connectTimeoutSeconds = connectTimeoutSeconds
    }

    func connect(
        configuration: RemoteASRConfiguration,
        backend: ASRBackend,
        language: SupportedLanguage
    ) async throws {
        _ = language // Intentionally ignored for Aliyun realtime in this iteration.

        guard backend == .remoteAliyunASR else {
            throw RemoteASRStreamingError.connectFailed("Aliyun realtime requires Aliyun backend.")
        }

        guard state == .idle, !eventsFinished else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        guard configuration.isConfigured else {
            throw RemoteASRStreamingError.connectFailed(RemoteASRClientError.notConfigured.localizedDescription)
        }

        guard let baseURL = configuration.normalizedEndpoint else {
            throw RemoteASRStreamingError.connectFailed(RemoteASRClientError.invalidBaseURL.localizedDescription)
        }

        resetSessionStateForConnect()
        state = .connecting

        let endpoint: URL
        do {
            endpoint = try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(from: baseURL.absoluteString)
        } catch {
            state = .failed
            throw RemoteASRStreamingError.connectFailed(error.localizedDescription)
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20
        for (header, value) in AliyunRealtimeProtocol.makeHandshakeHeaders(
            apiKey: configuration.trimmedAPIKey,
            workspace: nil
        ) {
            request.setValue(value, forHTTPHeaderField: header)
        }

        do {
            transport = try await transportFactory(request)
        } catch {
            let mapped = RealtimeASRStreamingErrorMapper.mapConnectError(error)
            state = mapped == .cancelled ? .cancelled : .failed
            terminalError = mapped
            throw mapped
        }

        do {
            guard let transport else {
                throw RemoteASRStreamingError.connectFailed("Realtime transport unavailable.")
            }
            let startMessage = try AliyunRealtimeProtocol.makeStartMessage(
                taskID: taskID,
                model: configuration.trimmedModel
            )
            try await transport.sendText(startMessage)
            try await waitForTaskStartedAck(timeoutSeconds: connectTimeoutSeconds)
        } catch {
            let mapped = RealtimeASRStreamingErrorMapper.mapConnectError(error)
            state = mapped == .cancelled ? .cancelled : .failed
            terminalError = mapped
            cleanupTransport(code: .goingAway)
            throw mapped
        }

        state = .connected
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func sendPCM16LEFrame(_ frame: Data) async throws {
        guard state == .connected else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        guard !finishSent else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        let chunks = AliyunRealtimeProtocol.appendAndChunkPCM(
            pending: &pendingPCMBuffer,
            incoming: frame,
            flushTail: false
        )
        guard !chunks.isEmpty else { return }
        guard let transport else {
            let mapped = RemoteASRStreamingError.streamSendFailed("Realtime transport unavailable.")
            terminalError = mapped
            state = .failed
            emit(event: .protocolError(message: mapped.localizedDescription))
            finishEventsIfNeeded()
            throw mapped
        }

        do {
            for chunk in chunks {
                try await transport.sendBinary(chunk)
            }
        } catch {
            let mapped = RemoteASRStreamingError.streamSendFailed(error.localizedDescription)
            terminalError = mapped
            state = .failed
            emit(event: .protocolError(message: mapped.localizedDescription))
            finishEventsIfNeeded()
            cleanupTransport(code: .goingAway)
            throw mapped
        }
    }

    func finishInput() async throws {
        guard state == .connected || state == .finishing || state == .finished else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        if finishSent {
            return
        }

        do {
            guard let transport else {
                throw RemoteASRStreamingError.streamSendFailed("Realtime transport unavailable.")
            }
            let tailChunks = AliyunRealtimeProtocol.appendAndChunkPCM(
                pending: &pendingPCMBuffer,
                incoming: Data(),
                flushTail: true
            )
            for chunk in tailChunks {
                try await transport.sendBinary(chunk)
            }

            let finishMessage = try AliyunRealtimeProtocol.makeFinishMessage(taskID: taskID)
            try await transport.sendText(finishMessage)
        } catch {
            let mapped = RemoteASRStreamingError.streamSendFailed(error.localizedDescription)
            terminalError = mapped
            state = .failed
            emit(event: .protocolError(message: mapped.localizedDescription))
            finishEventsIfNeeded()
            cleanupTransport(code: .goingAway)
            throw mapped
        }

        finishSent = true
        state = .finishing
    }

    func awaitFinalResult(timeoutSeconds: Double) async throws -> String {
        guard finishSent else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        if let finalText, !finalText.isEmpty {
            return finalText
        }

        if let terminalError {
            throw terminalError
        }

        var elapsed: Double = 0
        while elapsed < timeoutSeconds {
            if let finalText, !finalText.isEmpty {
                return finalText
            }

            if let terminalError {
                throw terminalError
            }

            let remaining = timeoutSeconds - elapsed
            let step = min(0.02, max(remaining, 0))
            if step == 0 { break }

            do {
                try await clock.sleep(seconds: step)
            } catch {
                throw RemoteASRStreamingError.finalTimeout
            }
            elapsed += step
        }

        let timeoutError = RemoteASRStreamingError.finalTimeout
        terminalError = timeoutError
        state = .failed
        emit(event: .timeout(kind: "final"))
        finishEventsIfNeeded()
        cleanupTransport(code: .goingAway)
        throw timeoutError
    }

    func close() async {
        if state == .connecting {
            state = .cancelled
            terminalError = .cancelled
        } else if state == .connected || state == .finishing {
            state = .cancelled
            terminalError = .cancelled
        }

        receiveTask?.cancel()
        receiveTask = nil
        cleanupTransport(code: .normalClosure)
        finishEventsIfNeeded()
    }

    private func resetSessionStateForConnect() {
        receiveTask?.cancel()
        receiveTask = nil
        cleanupTransport(code: .normalClosure)

        taskID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        pendingPCMBuffer.removeAll(keepingCapacity: true)
        latestPartialText = ""
        sentenceEndResults.removeAll(keepingCapacity: false)
        seenSentenceEndTimes.removeAll(keepingCapacity: false)
        finalText = nil
        terminalError = nil
        finishSent = false
    }

    private func cleanupTransport(code: URLSessionWebSocketTask.CloseCode) {
        transport?.cancel(code: code, reason: nil)
        transport = nil
    }

    private func waitForTaskStartedAck(timeoutSeconds: Double) async throws {
        guard let transport else {
            throw RemoteASRStreamingError.connectFailed("Realtime transport unavailable.")
        }

        do {
            let message = try await receiveOneMessage(transport: transport, timeoutSeconds: timeoutSeconds)
            guard case .string(let text) = message else {
                throw RemoteASRStreamingError.protocolError("Expected task-started ack before streaming.")
            }

            let event = try AliyunRealtimeProtocol.parseServerMessage(text)
            switch event {
            case .taskStarted:
                return
            case .taskFailed(_, let code, let message):
                throw RemoteASRStreamingError.protocolError("\(code): \(message)")
            default:
                throw RemoteASRStreamingError.protocolError("Expected task-started ack before streaming.")
            }
        } catch let error as RemoteASRStreamingError {
            throw error
        } catch {
            throw RealtimeASRStreamingErrorMapper.mapConnectError(error)
        }
    }

    private func receiveOneMessage(
        transport: WebSocketTransport,
        timeoutSeconds: Double
    ) async throws -> URLSessionWebSocketTask.Message {
        let realtimeClock = clock
        return try await withThrowingTaskGroup(of: URLSessionWebSocketTask.Message.self) { group in
            group.addTask {
                try await transport.receive()
            }
            group.addTask {
                try await realtimeClock.sleep(seconds: timeoutSeconds)
                throw RemoteASRStreamingError.connectFailed("timeout")
            }

            guard let first = try await group.next() else {
                throw RemoteASRStreamingError.connectFailed("timeout")
            }
            group.cancelAll()
            return first
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let transport else { return }

            do {
                let message = try await transport.receive()
                try await handleIncomingMessage(message)
            } catch is CancellationError {
                return
            } catch let error as RemoteASRStreamingError {
                handleTerminalError(error)
                return
            } catch {
                if case .cancelled = terminalError {
                    return
                }
                let mapped = RemoteASRStreamingError.serverClosed(error.localizedDescription)
                handleTerminalError(mapped)
                return
            }
        }
    }

    private func handleIncomingMessage(_ message: URLSessionWebSocketTask.Message) async throws {
        switch message {
        case .string(let text):
            let event = try AliyunRealtimeProtocol.parseServerMessage(text)
            switch event {
            case .taskStarted:
                return
            case .resultGenerated(let text, let endTime, let isHeartbeat):
                guard !isHeartbeat else { return }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    latestPartialText = trimmed
                    emit(event: .partial(text: trimmed))
                }
                if let endTime, !trimmed.isEmpty, !seenSentenceEndTimes.contains(endTime) {
                    seenSentenceEndTimes.insert(endTime)
                    sentenceEndResults.append((endTime: endTime, text: trimmed))
                    sentenceEndResults.sort { $0.endTime < $1.endTime }
                }
            case .taskFinished:
                let resolved = try resolveFinalText()
                finalText = resolved
                state = .finished
                emit(event: .final(text: resolved))
                finishEventsIfNeeded()
                cleanupTransport(code: .normalClosure)
            case .taskFailed(_, let code, let message):
                throw RemoteASRStreamingError.protocolError("\(code): \(message)")
            }
        case .data:
            throw RemoteASRStreamingError.protocolError("Unexpected binary message from realtime ASR server.")
        @unknown default:
            throw RemoteASRStreamingError.protocolError("Unexpected websocket message from realtime ASR server.")
        }
    }

    private func resolveFinalText() throws -> String {
        if !sentenceEndResults.isEmpty {
            let final = sentenceEndResults
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !final.isEmpty {
                return final
            }
        }

        let fallback = latestPartialText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty {
            return fallback
        }

        throw RemoteASRStreamingError.protocolError("emptyFinal")
    }

    private func handleTerminalError(_ error: RemoteASRStreamingError) {
        guard finalText == nil else { return }
        guard terminalError == nil else { return }
        terminalError = error

        switch error {
        case .cancelled:
            state = .cancelled
        case .serverClosed(let reason):
            state = .failed
            emit(event: .closedByServer(code: .goingAway, reason: reason))
        case .finalTimeout:
            state = .failed
            emit(event: .timeout(kind: "final"))
        default:
            state = .failed
            emit(event: .protocolError(message: error.localizedDescription))
        }

        finishEventsIfNeeded()
        cleanupTransport(code: .goingAway)
    }

    private func emit(event: RemoteASRStreamEvent) {
        guard !eventsFinished else { return }
        eventsContinuation.yield(event)
    }

    private func finishEventsIfNeeded() {
        guard !eventsFinished else { return }
        eventsFinished = true
        eventsContinuation.finish()
    }

}
