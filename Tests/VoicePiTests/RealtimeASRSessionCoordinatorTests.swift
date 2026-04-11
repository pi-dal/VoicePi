import Foundation
import Testing
@testable import VoicePi

@MainActor
@Suite(.serialized)
struct RealtimeASRSessionCoordinatorTests {
    @Test
    func preconnectFramesBufferUntilConnectSucceedsThenFlushInOrder() async throws {
        let client = StreamingClientStub()
        client.suspendConnect = true
        let coordinator = RealtimeASRSessionCoordinator(clientFactory: { _ in client })

        let sink = CallbackSink()
        try await coordinator.start(
            configuration: .fixtureAliyunRealtime(),
            backend: .remoteAliyunASR,
            language: .english,
            callbacks: sink.callbacks
        )

        await coordinator.handleCapturedFrame(Data([1, 2, 3]))
        await coordinator.handleCapturedFrame(Data([4, 5, 6]))
        #expect(client.sentFrames.isEmpty)

        await waitUntilConnectSuspended(client)
        client.resumeConnectSuccess()
        try? await Task.sleep(nanoseconds: 20_000_000)
        client.emit(.partial(text: "hello"))
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(sink.partialTexts == ["hello"])
        #expect(client.sentFrames == [Data([1, 2, 3]), Data([4, 5, 6])])
    }

    @Test
    func stopDuringConnectingCancelsWithoutTerminalError() async throws {
        let client = StreamingClientStub()
        client.suspendConnect = true
        let coordinator = RealtimeASRSessionCoordinator(clientFactory: { _ in client })
        let sink = CallbackSink()

        try await coordinator.start(
            configuration: .fixtureAliyunRealtime(),
            backend: .remoteAliyunASR,
            language: .english,
            callbacks: sink.callbacks
        )

        try? await Task.sleep(nanoseconds: 20_000_000)
        await coordinator.cancelConnecting()

        #expect(sink.errors.isEmpty)
        #expect(client.closeCalls == 1)
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
        await waitUntilStreamingReady(coordinator)

        let final = try await coordinator.stopAndResolveFinal()

        #expect(final == "final text")
        #expect(client.finishCalls == 1)
    }

    @Test
    func connectFailureAfterCaptureBeginsDegradesToBatchFallbackWithoutTerminalError() async throws {
        let client = StreamingClientStub()
        client.suspendConnect = true
        let coordinator = RealtimeASRSessionCoordinator(clientFactory: { _ in client })
        let sink = CallbackSink()

        try await coordinator.start(
            configuration: .fixtureAliyunRealtime(),
            backend: .remoteAliyunASR,
            language: .english,
            callbacks: sink.callbacks
        )
        await coordinator.handleCapturedFrame(Data([1, 2, 3]))
        await waitUntilConnectSuspended(client)
        client.resumeConnectFailure(RemoteASRStreamingError.connectFailed("timeout"))
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(coordinator.degradedToBatchFallback)
        #expect(sink.errors.isEmpty)
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
        await waitUntilStreamingReady(coordinator)

        await #expect(throws: RemoteASRStreamingError.finalTimeout) {
            _ = try await coordinator.stopAndResolveFinal()
        }

        #expect(sink.errors.contains("Realtime ASR final timeout."))
    }

    @Test
    func sendFailureDegradesToBatchFallback() async throws {
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
        await waitUntilStreamingReady(coordinator)

        await coordinator.handleCapturedFrame(Data([1, 2, 3]))
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(coordinator.degradedToBatchFallback)
        #expect(sink.errors.isEmpty)
        #expect(client.closeCalls == 1)
    }

    private func waitUntilStreamingReady(_ coordinator: RealtimeASRSessionCoordinator) async {
        for _ in 0..<50 {
            if coordinator.isRealtimeStreamingReady {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func waitUntilConnectSuspended(_ client: StreamingClientStub) async {
        for _ in 0..<50 {
            if client.isConnectSuspended {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
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

    var isConnectSuspended: Bool {
        connectContinuation != nil
    }

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

    func resumeConnectSuccess() {
        connectContinuation?.resume()
        connectContinuation = nil
    }

    func resumeConnectFailure(_ error: Error) {
        connectContinuation?.resume(throwing: error)
        connectContinuation = nil
    }

    func emit(_ event: RemoteASRStreamEvent) {
        streamContinuation.yield(event)
    }
}
