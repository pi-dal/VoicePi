import Foundation

actor RealtimeASRSessionCoordinator {
    enum State: Equatable {
        case idle
        case recordingAndConnecting
        case drainingBufferedAudio
        case recordingAndStreaming
        case recordingWithBatchFallback
        case stoppingAndAwaitingRealtimeFinal
        case completed
        case failed
        case cancelled
    }

    struct Callbacks {
        let onPartial: @MainActor (String) -> Void
        let onFinal: @MainActor (String) -> Void
        let onTerminalError: @MainActor (String) -> Void
    }

    struct StatusSnapshot: Equatable {
        let state: State
        let isRealtimeStreamingReady: Bool
        let degradedToBatchFallback: Bool
        let hasCapturedAudio: Bool
    }

    nonisolated static let connectTimeoutSeconds: Double = 2.0
    nonisolated static let finalTimeoutSeconds: Double = 1.2
    nonisolated static let preconnectBufferByteLimit = 160_000

    private let clientFactory: (ASRBackend) throws -> RemoteASRStreamingClient
    private let finalTimeoutSecondsValue: Double

    private var client: RemoteASRStreamingClient?
    private var eventsTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?
    private var callbacks: Callbacks?
    private var hasReportedTerminalError = false
    private var latestFinalText = ""
    private var preconnectBuffer = RealtimeASRPreconnectBuffer(byteLimit: preconnectBufferByteLimit)

    private(set) var state: State = .idle

    var isRealtimeStreamingReady: Bool {
        switch state {
        case .drainingBufferedAudio, .recordingAndStreaming, .stoppingAndAwaitingRealtimeFinal:
            return true
        case .idle, .recordingAndConnecting, .recordingWithBatchFallback, .completed, .failed, .cancelled:
            return false
        }
    }

    var degradedToBatchFallback: Bool {
        state == .recordingWithBatchFallback
    }

    var hasCapturedAudio: Bool {
        preconnectBuffer.hasCapturedAudio
    }

    init(
        clientFactory: @escaping (ASRBackend) throws -> RemoteASRStreamingClient = { backend in
            try RealtimeASRStreamingClientFactory.make(
                backend: backend,
                connectTimeoutSeconds: RealtimeASRSessionCoordinator.connectTimeoutSeconds
            )
        },
        finalTimeoutSeconds: Double = RealtimeASRSessionCoordinator.finalTimeoutSeconds
    ) {
        self.clientFactory = clientFactory
        self.finalTimeoutSecondsValue = finalTimeoutSeconds
    }

    func statusSnapshot() -> StatusSnapshot {
        StatusSnapshot(
            state: state,
            isRealtimeStreamingReady: isRealtimeStreamingReady,
            degradedToBatchFallback: degradedToBatchFallback,
            hasCapturedAudio: hasCapturedAudio
        )
    }

    func start(
        configuration: RemoteASRConfiguration,
        backend: ASRBackend,
        language: SupportedLanguage,
        callbacks: Callbacks
    ) async throws {
        guard state == .idle else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        self.callbacks = callbacks
        self.hasReportedTerminalError = false
        self.latestFinalText = ""
        self.preconnectBuffer.reset()

        let client: RemoteASRStreamingClient
        do {
            client = try clientFactory(backend)
            self.client = client
            state = .recordingAndConnecting
        } catch {
            state = .failed
            await reportTerminalError(error.localizedDescription)
            await cleanupAfterSession(clearCallbacks: true)
            state = .idle
            throw error
        }

        eventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in client.events {
                await self.handleEvent(event)
            }
        }

        connectTask = Task { [weak self] in
            guard let self else { return }
            await self.runConnect(configuration: configuration, backend: backend, language: language, client: client)
        }
    }

    func handleCapturedFrame(_ data: Data) async {
        switch state {
        case .recordingAndConnecting, .drainingBufferedAudio:
            preconnectBuffer.append(data)
        case .recordingAndStreaming, .stoppingAndAwaitingRealtimeFinal:
            guard let client else { return }
            do {
                try await client.sendPCM16LEFrame(data)
            } catch {
                await degradeToBatchFallback()
            }
        case .recordingWithBatchFallback:
            preconnectBuffer.append(data)
        case .idle, .completed, .failed, .cancelled:
            return
        }
    }

    func stopAndResolveFinal() async throws -> String {
        guard let client else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        guard state == .recordingAndStreaming || state == .stoppingAndAwaitingRealtimeFinal else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        if state == .stoppingAndAwaitingRealtimeFinal {
            return latestFinalText
        }

        state = .stoppingAndAwaitingRealtimeFinal

        do {
            try await client.finishInput()
            let finalText = try await client.awaitFinalResult(timeoutSeconds: finalTimeoutSecondsValue)
            latestFinalText = finalText
            state = .completed
            await cleanupAfterSession(clearCallbacks: true)
            state = .idle
            return finalText
        } catch {
            if case let asrError as RemoteASRStreamingError = error, asrError == .cancelled {
                state = .cancelled
            } else {
                state = .failed
                await reportTerminalError(error.localizedDescription)
            }
            await cleanupAfterSession(clearCallbacks: true)
            state = .idle
            throw error
        }
    }

    func cancelConnecting() async {
        guard state == .recordingAndConnecting || state == .drainingBufferedAudio else { return }
        state = .cancelled
        await cleanupAfterSession(clearCallbacks: true)
        state = .idle
    }

    func close() async {
        if state != .idle {
            state = .cancelled
        }
        await cleanupAfterSession(clearCallbacks: true)
        state = .idle
    }

    func handleCaptureBackpressureLimitExceeded() async {
        switch state {
        case .recordingAndConnecting, .drainingBufferedAudio, .recordingAndStreaming, .stoppingAndAwaitingRealtimeFinal:
            await degradeToBatchFallback()
        case .idle, .recordingWithBatchFallback, .completed, .failed, .cancelled:
            break
        }
    }

    private func runConnect(
        configuration: RemoteASRConfiguration,
        backend: ASRBackend,
        language: SupportedLanguage,
        client: RemoteASRStreamingClient
    ) async {
        do {
            try await client.connect(
                configuration: configuration,
                backend: backend,
                language: language
            )
        } catch {
            if case let asrError as RemoteASRStreamingError = error, asrError == .cancelled {
                if state != .idle {
                    state = .cancelled
                }
                await cleanupAfterSession(clearCallbacks: true)
                if state != .idle {
                    state = .idle
                }
                return
            }

            await degradeToBatchFallback()
            return
        }

        guard state == .recordingAndConnecting || state == .drainingBufferedAudio else {
            await client.close()
            return
        }

        state = .drainingBufferedAudio

        do {
            try await flushBufferedFrames(to: client)
            if state == .drainingBufferedAudio {
                state = .recordingAndStreaming
            }
        } catch {
            await degradeToBatchFallback()
        }
    }

    private func flushBufferedFrames(to client: RemoteASRStreamingClient) async throws {
        while state == .drainingBufferedAudio {
            guard let frame = preconnectBuffer.popFirst() else { return }
            try await client.sendPCM16LEFrame(frame)
        }
    }

    private func handleEvent(_ event: RemoteASRStreamEvent) async {
        guard let callbacks else { return }

        switch event {
        case .partial(let text):
            guard isRealtimeStreamingReady else { return }
            await callbacks.onPartial(text)
        case .final(let text):
            latestFinalText = text
            await callbacks.onFinal(text)
        case .timeout, .closedByServer, .protocolError:
            switch state {
            case .recordingAndConnecting, .drainingBufferedAudio, .recordingAndStreaming:
                await degradeToBatchFallback()
            case .stoppingAndAwaitingRealtimeFinal:
                await failSession(message: eventMessage(for: event))
            case .idle, .recordingWithBatchFallback, .completed, .failed, .cancelled:
                break
            }
        }
    }

    private func eventMessage(for event: RemoteASRStreamEvent) -> String {
        switch event {
        case .partial, .final:
            return ""
        case .timeout(let kind):
            return "Realtime ASR \(kind) timeout."
        case .closedByServer(_, let reason):
            if let reason, !reason.isEmpty {
                return "Realtime ASR server closed connection: \(reason)"
            }
            return "Realtime ASR server closed connection."
        case .protocolError(let message):
            return message
        }
    }

    private func reportTerminalError(_ message: String) async {
        guard !hasReportedTerminalError else { return }
        hasReportedTerminalError = true
        if let callbacks {
            await callbacks.onTerminalError(message)
        }
    }

    private func cleanupAfterSession(clearCallbacks: Bool) async {
        connectTask?.cancel()
        connectTask = nil
        await client?.close()
        eventsTask?.cancel()
        eventsTask = nil
        client = nil
        hasReportedTerminalError = false
        if clearCallbacks {
            callbacks = nil
        }
    }

    private func degradeToBatchFallback() async {
        guard state != .recordingWithBatchFallback else { return }
        state = .recordingWithBatchFallback
        connectTask?.cancel()
        connectTask = nil
        await client?.close()
        client = nil
        eventsTask?.cancel()
        eventsTask = nil
    }

    private func failSession(message: String) async {
        state = .failed
        await reportTerminalError(message)
        await cleanupAfterSession(clearCallbacks: true)
        state = .idle
    }
}
