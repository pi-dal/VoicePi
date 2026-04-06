import Foundation
import Testing
@testable import VoicePi

@Suite(.serialized)
struct AliyunRealtimeASRStreamingClientTests {
    @Test
    func connectRequiresTaskStartedAckBeforeReturning() async throws {
        let transport = MockWebSocketTransport(
            incoming: [.success(.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#))]
        )
        let capturedRequest = AliyunRequestCapture()
        let client = AliyunRealtimeASRStreamingClient(
            transportFactory: { request in
                capturedRequest.set(request)
                return transport
            }
        )

        try await client.connect(
            configuration: .fixtureAliyun(),
            backend: .remoteAliyunASR,
            language: .english
        )

        #expect(capturedRequest.value?.value(forHTTPHeaderField: "Authorization") == "bearer sk-test")
        let startText = try #require(transport.sentTexts.first)
        #expect(startText.contains("\"action\":\"run-task\""))
        #expect(startText.contains("\"streaming\":\"duplex\""))
        #expect(startText.contains("\"language_hints\"") == false)
    }

    @Test
    func connectTwiceThrowsInvalidState() async throws {
        let transport = MockWebSocketTransport(
            incoming: [.success(.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#))]
        )
        let client = AliyunRealtimeASRStreamingClient(
            transportFactory: { _ in transport }
        )

        try await client.connect(
            configuration: .fixtureAliyun(),
            backend: .remoteAliyunASR,
            language: .english
        )

        await #expect(throws: RemoteASRStreamingError.protocolError("invalidState")) {
            try await client.connect(
                configuration: .fixtureAliyun(),
                backend: .remoteAliyunASR,
                language: .english
            )
        }
    }

    @Test
    func finishAndAwaitFinalReturnsJoinedSentenceEndText() async throws {
        let transport = MockWebSocketTransport(
            incoming: [
                .success(.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#)),
                .success(.string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"你好","end_time":100}}}}"#)),
                .success(.string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"世界","end_time":220}}}}"#)),
                .success(.string(#"{"header":{"event":"task-finished","task_id":"t1"}}"#))
            ]
        )
        let client = AliyunRealtimeASRStreamingClient(transportFactory: { _ in transport })

        try await client.connect(
            configuration: .fixtureAliyun(),
            backend: .remoteAliyunASR,
            language: .english
        )
        try await client.finishInput()
        let final = try await client.awaitFinalResult(timeoutSeconds: 1.2)

        #expect(final == "你好 世界")
    }

    @Test
    func partialEventsEmitCumulativeTranscriptAcrossSentenceChunks() async throws {
        let transport = MockWebSocketTransport(
            incoming: [
                .success(.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#)),
                .success(.string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"你好","end_time":100}}}}"#)),
                .success(.string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"世界","end_time":220}}}}"#))
            ]
        )
        let client = AliyunRealtimeASRStreamingClient(transportFactory: { _ in transport })
        let collector = EventCollector()
        let consumeTask = Task {
            for await event in client.events {
                collector.append(event)
            }
        }

        try await client.connect(
            configuration: .fixtureAliyun(),
            backend: .remoteAliyunASR,
            language: .english
        )

        try? await Task.sleep(nanoseconds: 20_000_000)
        await client.close()
        consumeTask.cancel()

        let partials = collector.values.compactMap { event -> String? in
            guard case .partial(let text) = event else { return nil }
            return text
        }

        #expect(partials.contains("你好"))
        #expect(partials.contains("你好 世界"))
    }

    @Test
    func finalFallsBackToLatestPartialWhenNoSentenceEnd() async throws {
        let transport = MockWebSocketTransport(
            incoming: [
                .success(.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#)),
                .success(.string(#"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"latest partial","end_time":null}}}}"#)),
                .success(.string(#"{"header":{"event":"task-finished","task_id":"t1"}}"#))
            ]
        )
        let client = AliyunRealtimeASRStreamingClient(transportFactory: { _ in transport })

        try await client.connect(
            configuration: .fixtureAliyun(),
            backend: .remoteAliyunASR,
            language: .english
        )
        try await client.finishInput()
        let final = try await client.awaitFinalResult(timeoutSeconds: 1.2)

        #expect(final == "latest partial")
    }

    @Test
    func awaitFinalTimeoutEmitsTimeoutEvent() async throws {
        let transport = MockWebSocketTransport(
            incoming: [
                .success(.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#))
            ]
        )
        let client = AliyunRealtimeASRStreamingClient(transportFactory: { _ in transport })
        let collector = EventCollector()
        let consumeTask = Task {
            for await event in client.events {
                collector.append(event)
            }
        }

        try await client.connect(
            configuration: .fixtureAliyun(),
            backend: .remoteAliyunASR,
            language: .english
        )
        try await client.finishInput()

        await #expect(throws: RemoteASRStreamingError.finalTimeout) {
            _ = try await client.awaitFinalResult(timeoutSeconds: 0.05)
        }

        try? await Task.sleep(nanoseconds: 30_000_000)
        let events = collector.values
        #expect(events.contains(.timeout(kind: "final")))
        consumeTask.cancel()
    }

    @Test
    func sendBeforeConnectThrowsInvalidState() async {
        let client = AliyunRealtimeASRStreamingClient(
            transportFactory: { _ in MockWebSocketTransport(incoming: []) }
        )

        await #expect(throws: RemoteASRStreamingError.protocolError("invalidState")) {
            try await client.sendPCM16LEFrame(Data([1, 2, 3]))
        }
    }

    @Test
    func sendAfterFinishThrowsInvalidState() async throws {
        let transport = MockWebSocketTransport(
            incoming: [.success(.string(#"{"header":{"event":"task-started","task_id":"t1"}}"#))]
        )
        let client = AliyunRealtimeASRStreamingClient(transportFactory: { _ in transport })

        try await client.connect(
            configuration: .fixtureAliyun(),
            backend: .remoteAliyunASR,
            language: .english
        )
        try await client.finishInput()

        await #expect(throws: RemoteASRStreamingError.protocolError("invalidState")) {
            try await client.sendPCM16LEFrame(Data([1]))
        }
    }

    @Test
    func connectFactoryAuthenticationErrorMapsThrough() async {
        let client = AliyunRealtimeASRStreamingClient(
            transportFactory: { _ in throw RemoteASRStreamingError.authenticationFailed }
        )

        await #expect(throws: RemoteASRStreamingError.authenticationFailed) {
            try await client.connect(
                configuration: .fixtureAliyun(),
                backend: .remoteAliyunASR,
                language: .english
            )
        }
    }
}

private extension RemoteASRConfiguration {
    static func fixtureAliyun() -> RemoteASRConfiguration {
        .init(
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            apiKey: "sk-test",
            model: "fun-asr-realtime",
            prompt: ""
        )
    }
}

private final class EventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [RemoteASRStreamEvent] = []

    func append(_ event: RemoteASRStreamEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }

    var values: [RemoteASRStreamEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class MockWebSocketTransport: WebSocketTransport, @unchecked Sendable {
    private let queue = DispatchQueue(label: "MockWebSocketTransport.queue")
    private var incoming: [Result<URLSessionWebSocketTask.Message, Error>]

    private(set) var sentTexts: [String] = []
    private(set) var sentBinaries: [Data] = []
    private(set) var cancelCount = 0

    init(incoming: [Result<URLSessionWebSocketTask.Message, Error>]) {
        self.incoming = incoming
    }

    func sendText(_ text: String) async throws {
        queue.sync {
            sentTexts.append(text)
        }
    }

    func sendBinary(_ data: Data) async throws {
        queue.sync {
            sentBinaries.append(data)
        }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        let next: Result<URLSessionWebSocketTask.Message, Error>? = queue.sync {
            guard !incoming.isEmpty else { return nil }
            return incoming.removeFirst()
        }
        if let next {
            return try next.get()
        }

        try await Task.sleep(nanoseconds: 5_000_000_000)
        throw URLError(.timedOut)
    }

    func cancel(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        queue.sync {
            cancelCount += 1
        }
    }
}

private final class AliyunRequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?

    func set(_ request: URLRequest) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    var value: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return request
    }
}
