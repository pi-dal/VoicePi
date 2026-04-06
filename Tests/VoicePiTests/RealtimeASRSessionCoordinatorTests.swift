import Foundation
import Testing
@testable import VoicePi

@MainActor
@Suite(.serialized)
struct RealtimeASRSessionCoordinatorTests {
    @Test
    func partialEventsUpdateCallbackAndFramesForwardToClient() async throws {
        let client = StreamingClientStub()
        let coordinator = RealtimeASRSessionCoordinator(clientFactory: { _ in client })

        let sink = CallbackSink()
        try await coordinator.start(
            configuration: .fixtureAliyunRealtime(),
            backend: .remoteAliyunASR,
            language: .english,
            callbacks: sink.callbacks
        )

        client.emit(.partial(text: "hello"))
        await coordinator.handleCapturedFrame(Data([1, 2, 3]))
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(sink.partialTexts == ["hello"])
        #expect(client.sentFrames == [Data([1, 2, 3])])
    }

    @Test
    func stopDuringConnectingCancelsWithoutTerminalError() async throws {
        let client = StreamingClientStub()
        client.suspendConnect = true
        let coordinator = RealtimeASRSessionCoordinator(clientFactory: { _ in client })
        let sink = CallbackSink()

        let startTask = Task {
            try await coordinator.start(
                configuration: .fixtureAliyunRealtime(),
                backend: .remoteAliyunASR,
                language: .english,
                callbacks: sink.callbacks
            )
        }

        try? await Task.sleep(nanoseconds: 20_000_000)
        await coordinator.cancelConnecting()

        await #expect(throws: RemoteASRStreamingError.cancelled) {
            _ = try await startTask.value
        }
        #expect(sink.errors.isEmpty)
    }

    @Test
    func stopAndResolveFinalReturnsFinalTextAndResets() async throws {
        let client = StreamingClientStub()
        client.awaitFinalResultValue = .success("final text")
        let coordinator = RealtimeASRSessionCoordinator(clientFactory: { _ in client })
        let sink = CallbackSink()

        try await coordinator.start(
            configuration: .fixtureAliyunRealtime(),
            backend: .remoteAliyunASR,
            language: .english,
            callbacks: sink.callbacks
        )

        let final = try await coordinator.stopAndResolveFinal()

        #expect(final == "final text")
        #expect(client.finishCalls == 1)
    }

    @Test
    func connectFailureReportsTerminalError() async {
        let client = StreamingClientStub()
        client.connectResult = .failure(RemoteASRStreamingError.connectFailed("timeout"))
        let coordinator = RealtimeASRSessionCoordinator(clientFactory: { _ in client })
        let sink = CallbackSink()

        await #expect(throws: RemoteASRStreamingError.connectFailed("timeout")) {
            try await coordinator.start(
                configuration: .fixtureAliyunRealtime(),
                backend: .remoteAliyunASR,
                language: .english,
                callbacks: sink.callbacks
            )
        }

        #expect(sink.errors == ["timeout"])
    }

    @Test
    func stopAndResolveFinalFailureReportsTerminalError() async throws {
        let client = StreamingClientStub()
        client.awaitFinalResultValue = .failure(RemoteASRStreamingError.finalTimeout)
        let coordinator = RealtimeASRSessionCoordinator(clientFactory: { _ in client })
        let sink = CallbackSink()

        try await coordinator.start(
            configuration: .fixtureAliyunRealtime(),
            backend: .remoteAliyunASR,
            language: .english,
            callbacks: sink.callbacks
        )

        await #expect(throws: RemoteASRStreamingError.finalTimeout) {
            _ = try await coordinator.stopAndResolveFinal()
        }

        #expect(sink.errors.contains("Realtime ASR final timeout."))
    }

    @Test
    func sendFailureReportsTerminalErrorAndClosesSession() async throws {
        let client = StreamingClientStub()
        client.sendError = RemoteASRStreamingError.streamSendFailed("send failed")
        let coordinator = RealtimeASRSessionCoordinator(clientFactory: { _ in client })
        let sink = CallbackSink()

        try await coordinator.start(
            configuration: .fixtureAliyunRealtime(),
            backend: .remoteAliyunASR,
            language: .english,
            callbacks: sink.callbacks
        )

        await coordinator.handleCapturedFrame(Data([1, 2, 3]))
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(sink.errors.contains { $0.contains("send failed") })
        #expect(client.closeCalls == 1)
    }
}

private extension RemoteASRConfiguration {
    static func fixtureAliyunRealtime() -> RemoteASRConfiguration {
        .init(
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            apiKey: "sk-test",
            model: "fun-asr-realtime"
        )
    }
}

private final class CallbackSink: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var partialTexts: [String] = []
    private(set) var finals: [String] = []
    private(set) var errors: [String] = []

    var callbacks: RealtimeASRSessionCoordinator.Callbacks {
        RealtimeASRSessionCoordinator.Callbacks(
            onPartial: { [weak self] text in
                self?.appendPartial(text)
            },
            onFinal: { [weak self] text in
                self?.appendFinal(text)
            },
            onTerminalError: { [weak self] message in
                self?.appendError(message)
            }
        )
    }

    private func appendPartial(_ value: String) {
        lock.lock()
        partialTexts.append(value)
        lock.unlock()
    }

    private func appendFinal(_ value: String) {
        lock.lock()
        finals.append(value)
        lock.unlock()
    }

    private func appendError(_ value: String) {
        lock.lock()
        errors.append(value)
        lock.unlock()
    }
}

private final class StreamingClientStub: RemoteASRStreamingClient, @unchecked Sendable {
    var connectResult: Result<Void, Error> = .success(())
    var awaitFinalResultValue: Result<String, Error> = .success("final")
    var sendError: Error?
    var finishError: Error?
    var suspendConnect = false

    private var connectContinuation: CheckedContinuation<Void, Error>?

    private let streamContinuation: AsyncStream<RemoteASRStreamEvent>.Continuation
    let events: AsyncStream<RemoteASRStreamEvent>

    private(set) var sentFrames: [Data] = []
    private(set) var finishCalls = 0
    private(set) var closeCalls = 0

    init() {
        var continuation: AsyncStream<RemoteASRStreamEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.streamContinuation = continuation
    }

    func connect(
        configuration: RemoteASRConfiguration,
        backend: ASRBackend,
        language: SupportedLanguage
    ) async throws {
        switch connectResult {
        case .success:
            break
        case .failure(let error):
            throw error
        }

        if suspendConnect {
            try await withCheckedThrowingContinuation { continuation in
                connectContinuation = continuation
            }
        }
    }

    func sendPCM16LEFrame(_ frame: Data) async throws {
        if let sendError {
            throw sendError
        }
        sentFrames.append(frame)
    }

    func finishInput() async throws {
        finishCalls += 1
        if let finishError {
            throw finishError
        }
    }

    func awaitFinalResult(timeoutSeconds: Double) async throws -> String {
        switch awaitFinalResultValue {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    func close() async {
        closeCalls += 1
        connectContinuation?.resume(throwing: RemoteASRStreamingError.cancelled)
        connectContinuation = nil
    }

    func emit(_ event: RemoteASRStreamEvent) {
        streamContinuation.yield(event)
    }
}
