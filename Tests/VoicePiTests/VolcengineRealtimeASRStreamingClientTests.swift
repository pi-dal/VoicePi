import Foundation
import Testing
@testable import VoicePi

@Suite(.serialized)
struct VolcengineRealtimeASRStreamingClientTests {
    @Test
    func connectSendsStartFrameAndUsesVolcengineHeaders() async throws {
        let transport = VolcMockWebSocketTransport(
            incoming: [.success(.data(makeACKFrame(sequence: 1)))]
        )
        let capturedRequest = VolcRequestCapture()
        let client = VolcengineRealtimeASRStreamingClient(
            transportFactory: { request in
                capturedRequest.set(request)
                return transport
            }
        )

        try await client.connect(
            configuration: .fixtureVolcengine(),
            backend: .remoteVolcengineASR,
            language: .english
        )

        #expect(capturedRequest.value?.value(forHTTPHeaderField: "X-Api-App-Key") == "app-test")
        #expect(capturedRequest.value?.value(forHTTPHeaderField: "X-Api-Access-Key") == "ak-test")
        #expect(capturedRequest.value?.value(forHTTPHeaderField: "X-Api-Resource-Id") == "bigmodel")
        #expect((transport.sentBinaries.first?.count ?? 0) > 12)
    }

    @Test
    func connectRejectsOtherBackends() async {
        let client = VolcengineRealtimeASRStreamingClient(
            transportFactory: { _ in VolcMockWebSocketTransport(incoming: []) }
        )

        await #expect(throws: RemoteASRStreamingError.connectFailed("Volcengine realtime requires Volcengine backend.")) {
            try await client.connect(
                configuration: .fixtureVolcengine(),
                backend: .remoteAliyunASR,
                language: .english
            )
        }
    }

    @Test
    func finishAndAwaitFinalReturnsServerFinalText() async throws {
        let partialPayload = try JSONSerialization.data(
            withJSONObject: ["result": ["text": "hello"]],
            options: []
        )
        let finalPayload = try JSONSerialization.data(
            withJSONObject: ["result": ["text": "hello world"], "is_final": true],
            options: []
        )
        let transport = VolcMockWebSocketTransport(
            incoming: [
                .success(.data(makeACKFrame(sequence: 1))),
                .success(.data(makeServerResponseFrame(sequence: 2, flags: 0x1, payload: partialPayload))),
                .success(.data(makeServerResponseFrame(sequence: -3, flags: 0x2, payload: finalPayload)))
            ]
        )
        let client = VolcengineRealtimeASRStreamingClient(transportFactory: { _ in transport })

        try await client.connect(
            configuration: .fixtureVolcengine(),
            backend: .remoteVolcengineASR,
            language: .english
        )
        try await client.finishInput()
        let final = try await client.awaitFinalResult(timeoutSeconds: 1.2)

        #expect(final == "hello world")
    }

    @Test
    func partialEventsEmitCumulativeTranscriptAcrossChunks() async throws {
        let firstPartialPayload = try JSONSerialization.data(
            withJSONObject: ["result": ["text": "你好"]],
            options: []
        )
        let secondPartialPayload = try JSONSerialization.data(
            withJSONObject: ["result": ["text": "世界"]],
            options: []
        )
        let transport = VolcMockWebSocketTransport(
            incoming: [
                .success(.data(makeACKFrame(sequence: 1))),
                .success(.data(makeServerResponseFrame(sequence: 2, flags: 0x1, payload: firstPartialPayload))),
                .success(.data(makeServerResponseFrame(sequence: 3, flags: 0x1, payload: secondPartialPayload)))
            ]
        )
        let client = VolcengineRealtimeASRStreamingClient(transportFactory: { _ in transport })
        let collector = VolcEventCollector()
        let consumeTask = Task {
            for await event in client.events {
                collector.append(event)
            }
        }

        try await client.connect(
            configuration: .fixtureVolcengine(),
            backend: .remoteVolcengineASR,
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
        #expect(partials.contains("你好世界"))
    }

    @Test
    func sendAfterFinishThrowsInvalidState() async throws {
        let transport = VolcMockWebSocketTransport(
            incoming: [.success(.data(makeACKFrame(sequence: 1)))]
        )
        let client = VolcengineRealtimeASRStreamingClient(transportFactory: { _ in transport })

        try await client.connect(
            configuration: .fixtureVolcengine(),
            backend: .remoteVolcengineASR,
            language: .english
        )
        try await client.finishInput()

        await #expect(throws: RemoteASRStreamingError.protocolError("invalidState")) {
            try await client.sendPCM16LEFrame(Data([1]))
        }
    }

    @Test
    func awaitFinalTimeoutEmitsTimeoutEvent() async throws {
        let transport = VolcMockWebSocketTransport(
            incoming: [.success(.data(makeACKFrame(sequence: 1)))]
        )
        let client = VolcengineRealtimeASRStreamingClient(transportFactory: { _ in transport })
        let collector = VolcEventCollector()
        let consumeTask = Task {
            for await event in client.events {
                collector.append(event)
            }
        }

        try await client.connect(
            configuration: .fixtureVolcengine(),
            backend: .remoteVolcengineASR,
            language: .english
        )
        try await client.finishInput()

        await #expect(throws: RemoteASRStreamingError.finalTimeout) {
            _ = try await client.awaitFinalResult(timeoutSeconds: 0.05)
        }

        #expect(collector.values.contains(.timeout(kind: "final")))
        consumeTask.cancel()
    }
}

private extension RemoteASRConfiguration {
    static func fixtureVolcengine() -> RemoteASRConfiguration {
        .init(
            baseURL: "https://openspeech.bytedance.com/api/v3/sauc/bigmodel",
            apiKey: "ak-test",
            model: "bigmodel",
            prompt: "",
            volcengineAppID: "app-test"
        )
    }
}

private final class VolcEventCollector: @unchecked Sendable {
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

private final class VolcMockWebSocketTransport: WebSocketTransport, @unchecked Sendable {
    private let queue = DispatchQueue(label: "VolcMockWebSocketTransport.queue")
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

private final class VolcRequestCapture: @unchecked Sendable {
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

private func makeACKFrame(sequence: Int32) -> Data {
    makeServerFrame(messageType: 0xB, flags: 0x0, serialization: 0x0, sequence: sequence, payload: Data())
}

private func makeServerResponseFrame(sequence: Int32, flags: UInt8, payload: Data) -> Data {
    makeServerFrame(messageType: 0x9, flags: flags, serialization: 0x1, sequence: sequence, payload: payload)
}

private func makeServerFrame(
    messageType: UInt8,
    flags: UInt8,
    serialization: UInt8,
    sequence: Int32,
    payload: Data
) -> Data {
    let header = Data([0x11, (messageType << 4) | (flags & 0x0F), (serialization << 4), 0x00])
    var frame = header
    frame.append(int32Data(sequence))
    frame.append(uint32Data(UInt32(payload.count)))
    frame.append(payload)
    return frame
}

private func uint32Data(_ value: UInt32) -> Data {
    var bigEndian = value.bigEndian
    return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
}

private func int32Data(_ value: Int32) -> Data {
    var bigEndian = value.bigEndian
    return Data(bytes: &bigEndian, count: MemoryLayout<Int32>.size)
}
