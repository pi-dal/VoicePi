import Foundation

actor VolcengineRealtimeASRStreamingClient: RemoteASRStreamingClient {
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
    private var requestID: String = UUID().uuidString
    private var nextSequence: Int32 = 1
    private var pendingPCMBuffer = Data()
    private var latestPartialText = ""
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
        _ = language // Volcengine realtime language routing is model-side.

        guard backend == .remoteVolcengineASR else {
            throw RemoteASRStreamingError.connectFailed("Volcengine realtime requires Volcengine backend.")
        }

        guard state == .idle, !eventsFinished else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        guard configuration.isConfigured(for: backend) else {
            throw RemoteASRStreamingError.connectFailed(RemoteASRClientError.notConfigured.localizedDescription)
        }

        guard let baseURL = configuration.normalizedEndpoint else {
            throw RemoteASRStreamingError.connectFailed(RemoteASRClientError.invalidBaseURL.localizedDescription)
        }

        resetSessionStateForConnect()
        state = .connecting

        let endpoint: URL
        do {
            endpoint = try VolcengineRealtimeProtocol.normalizeWebSocketEndpoint(from: baseURL.absoluteString)
        } catch {
            state = .failed
            throw RemoteASRStreamingError.connectFailed(error.localizedDescription)
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20

        requestID = UUID().uuidString
        let headers: [String: String]
        do {
            headers = try VolcengineRealtimeProtocol.makeHandshakeHeaders(
                configuration: configuration,
                requestID: requestID
            )
        } catch {
            state = .failed
            throw RemoteASRStreamingError.connectFailed(error.localizedDescription)
        }
        for (header, value) in headers {
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
            let startFrame = try VolcengineRealtimeProtocol.makeStartFrame(
                configuration: configuration,
                requestID: requestID
            )
            try await transport.sendBinary(startFrame)
            try await waitForConnectionAck(timeoutSeconds: connectTimeoutSeconds)
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

        let chunks = VolcengineRealtimeProtocol.appendAndChunkPCM(
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
                let binaryFrame = VolcengineRealtimeProtocol.makeAudioFrame(
                    sequence: nextSequence,
                    audioChunk: chunk,
                    isFinal: false
                )
                nextSequence += 1
                try await transport.sendBinary(binaryFrame)
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

            let tailChunks = VolcengineRealtimeProtocol.appendAndChunkPCM(
                pending: &pendingPCMBuffer,
                incoming: Data(),
                flushTail: true
            )
            for chunk in tailChunks {
                let binaryFrame = VolcengineRealtimeProtocol.makeAudioFrame(
                    sequence: nextSequence,
                    audioChunk: chunk,
                    isFinal: false
                )
                nextSequence += 1
                try await transport.sendBinary(binaryFrame)
            }

            let finishFrame = VolcengineRealtimeProtocol.makeAudioFrame(
                sequence: nextSequence,
                audioChunk: Data(),
                isFinal: true
            )
            nextSequence += 1
            try await transport.sendBinary(finishFrame)
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
        if state == .connecting || state == .connected || state == .finishing {
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

        nextSequence = 1
        pendingPCMBuffer.removeAll(keepingCapacity: true)
        latestPartialText = ""
        finalText = nil
        terminalError = nil
        finishSent = false
    }

    private func cleanupTransport(code: URLSessionWebSocketTask.CloseCode) {
        transport?.cancel(code: code, reason: nil)
        transport = nil
    }

    private func waitForConnectionAck(timeoutSeconds: Double) async throws {
        guard let transport else {
            throw RemoteASRStreamingError.connectFailed("Realtime transport unavailable.")
        }

        do {
            let message = try await receiveOneMessage(transport: transport, timeoutSeconds: timeoutSeconds)
            switch message {
            case .data(let data):
                let event = try VolcengineRealtimeProtocol.parseServerMessage(data)
                switch event {
                case .acknowledged, .ignored, .completed:
                    return
                case .partial(let text):
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let merged = RealtimeTranscriptComposer.merge(
                            cumulative: latestPartialText,
                            incoming: trimmed
                        )
                        if merged != latestPartialText {
                            latestPartialText = merged
                            emit(event: .partial(text: merged))
                        }
                    }
                    return
                case .final(let text):
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        latestPartialText = RealtimeTranscriptComposer.merge(
                            cumulative: latestPartialText,
                            incoming: trimmed
                        )
                    }
                    return
                case .failed(let code, let message):
                    throw RemoteASRStreamingError.protocolError("\(code): \(message)")
                }
            case .string(let text):
                let lowered = text.lowercased()
                if lowered.contains("error") || lowered.contains("failed") {
                    throw RemoteASRStreamingError.protocolError(text)
                }
                return
            @unknown default:
                throw RemoteASRStreamingError.protocolError("Unexpected websocket message from realtime ASR server.")
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
        let event: VolcengineRealtimeServerEvent
        switch message {
        case .data(let data):
            event = try VolcengineRealtimeProtocol.parseServerMessage(data)
        case .string(let text):
            let lowered = text.lowercased()
            if lowered.contains("error") || lowered.contains("failed") {
                throw RemoteASRStreamingError.protocolError(text)
            }
            return
        @unknown default:
            throw RemoteASRStreamingError.protocolError("Unexpected websocket message from realtime ASR server.")
        }

        switch event {
        case .acknowledged, .ignored:
            return
        case .partial(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let merged = RealtimeTranscriptComposer.merge(
                cumulative: latestPartialText,
                incoming: trimmed
            )
            guard merged != latestPartialText else { return }
            latestPartialText = merged
            emit(event: .partial(text: merged))
        case .final(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                latestPartialText = RealtimeTranscriptComposer.merge(
                    cumulative: latestPartialText,
                    incoming: trimmed
                )
            }
            let resolved = try resolveFinalText()
            finalText = resolved
            state = .finished
            emit(event: .final(text: resolved))
            finishEventsIfNeeded()
            cleanupTransport(code: .normalClosure)
        case .completed:
            let resolved = try resolveFinalText()
            finalText = resolved
            state = .finished
            emit(event: .final(text: resolved))
            finishEventsIfNeeded()
            cleanupTransport(code: .normalClosure)
        case .failed(let code, let message):
            throw RemoteASRStreamingError.protocolError("\(code): \(message)")
        }
    }

    private func resolveFinalText() throws -> String {
        let final = latestPartialText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !final.isEmpty {
            return final
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
