import Foundation

@MainActor
final class RealtimeASRSessionCoordinator {
    enum State: Equatable {
        case idle
        case connectingRealtimeASR
        case recordingAndStreaming
        case stoppingAndAwaitingFinal
        case completed
        case failed
        case cancelled
    }

    struct Callbacks {
        let onPartial: @MainActor (String) -> Void
        let onFinal: @MainActor (String) -> Void
        let onTerminalError: @MainActor (String) -> Void
    }

    nonisolated static let connectTimeoutSeconds: Double = 2.0
    nonisolated static let finalTimeoutSeconds: Double = 1.2

    private let clientFactory: (ASRBackend) throws -> RemoteASRStreamingClient
    private let finalTimeoutSecondsValue: Double

    private var client: RemoteASRStreamingClient?
    private var eventsTask: Task<Void, Never>?
    private var callbacks: Callbacks?
    private var hasReportedTerminalError = false
    private var latestFinalText = ""

    private(set) var state: State = .idle

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

        let client: RemoteASRStreamingClient
        do {
            client = try clientFactory(backend)
            self.client = client
            state = .connectingRealtimeASR
        } catch {
            state = .failed
            reportTerminalError(error.localizedDescription)
            await cleanupAfterSession()
            state = .idle
            throw error
        }

        eventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in client.events {
                await self.handleEvent(event)
            }
        }

        do {
            try await client.connect(
                configuration: configuration,
                backend: backend,
                language: language
            )
            guard state == .connectingRealtimeASR else {
                throw RemoteASRStreamingError.cancelled
            }
            state = .recordingAndStreaming
        } catch {
            if case let asrError as RemoteASRStreamingError = error, asrError == .cancelled {
                state = .cancelled
                await cleanupAfterSession()
                state = .idle
                throw asrError
            }

            state = .failed
            reportTerminalError(error.localizedDescription)
            await cleanupAfterSession()
            state = .idle
            throw error
        }
    }

    func handleCapturedFrame(_ data: Data) async {
        guard state == .recordingAndStreaming else { return }
        guard let client else { return }

        do {
            try await client.sendPCM16LEFrame(data)
        } catch {
            await failSession(message: error.localizedDescription)
        }
    }

    func stopAndResolveFinal() async throws -> String {
        guard let client else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        guard state == .recordingAndStreaming || state == .stoppingAndAwaitingFinal else {
            throw RemoteASRStreamingError.protocolError("invalidState")
        }

        if state == .stoppingAndAwaitingFinal {
            return latestFinalText
        }

        state = .stoppingAndAwaitingFinal

        do {
            try await client.finishInput()
            let finalText = try await client.awaitFinalResult(timeoutSeconds: finalTimeoutSecondsValue)
            latestFinalText = finalText
            state = .completed
            await cleanupAfterSession()
            state = .idle
            return finalText
        } catch {
            if case let asrError as RemoteASRStreamingError = error, asrError == .cancelled {
                state = .cancelled
            } else {
                state = .failed
                reportTerminalError(error.localizedDescription)
            }
            await cleanupAfterSession()
            state = .idle
            throw error
        }
    }

    func cancelConnecting() async {
        guard state == .connectingRealtimeASR else { return }
        state = .cancelled
        await client?.close()
        await cleanupAfterSession()
        state = .idle
    }

    func close() async {
        if state != .idle {
            state = .cancelled
        }
        await client?.close()
        await cleanupAfterSession()
        state = .idle
    }

    private func handleEvent(_ event: RemoteASRStreamEvent) async {
        guard let callbacks else { return }

        switch event {
        case .partial(let text):
            callbacks.onPartial(text)
        case .final(let text):
            latestFinalText = text
            callbacks.onFinal(text)
        case .timeout(let kind):
            await failSession(message: "Realtime ASR \(kind) timeout.")
        case .closedByServer(_, let reason):
            if let reason, !reason.isEmpty {
                await failSession(message: "Realtime ASR server closed connection: \(reason)")
            } else {
                await failSession(message: "Realtime ASR server closed connection.")
            }
        case .protocolError(let message):
            await failSession(message: message)
        }
    }

    private func reportTerminalError(_ message: String) {
        guard !hasReportedTerminalError else { return }
        hasReportedTerminalError = true
        callbacks?.onTerminalError(message)
    }

    private func cleanupAfterSession() async {
        if let client {
            await client.close()
        }
        eventsTask?.cancel()
        eventsTask = nil
        client = nil
        callbacks = nil
        hasReportedTerminalError = false
    }

    private func failSession(message: String) async {
        state = .failed
        reportTerminalError(message)
        await cleanupAfterSession()
        state = .idle
    }
}
