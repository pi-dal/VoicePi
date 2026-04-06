import Foundation
import Testing
@testable import VoicePi

struct AliyunRealtimeProtocolTests {
    @Test
    func normalizeEndpointSupportsCompatibleAndWsForms() throws {
        #expect(
            try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "https://dashscope.aliyuncs.com/compatible-mode/v1"
            ).absoluteString == "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
        )
        #expect(
            try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
            ).absoluteString == "wss://dashscope-intl.aliyuncs.com/api-ws/v1/inference"
        )
        #expect(
            try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
            ).absoluteString == "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
        )
        #expect(
            try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "wss://dashscope.aliyuncs.com/compatible-mode/v1"
            ).absoluteString == "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
        )
        #expect(
            try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "ws://dashscope.aliyuncs.com/api-ws/v1/inference"
            ).absoluteString == "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
        )
        #expect(
            try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "https://example.internal/custom/path"
            ).absoluteString == "wss://example.internal/api-ws/v1/inference"
        )
    }

    @Test
    func normalizeEndpointRejectsInvalidSchemeOrHost() {
        #expect(throws: AliyunRealtimeProtocolError.invalidEndpoint) {
            _ = try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(from: "ftp://dashscope.aliyuncs.com")
        }

        #expect(throws: AliyunRealtimeProtocolError.invalidEndpoint) {
            _ = try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(from: "https://")
        }
    }

    @Test
    func handshakeHeadersUseBearerAndOptionalWorkspace() {
        let base = AliyunRealtimeProtocol.makeHandshakeHeaders(apiKey: "sk-test", workspace: nil)
        #expect(base["Authorization"] == "bearer sk-test")
        #expect(base["X-DashScope-WorkSpace"] == nil)

        let withWorkspace = AliyunRealtimeProtocol.makeHandshakeHeaders(
            apiKey: "sk-test",
            workspace: "workspace-id"
        )
        #expect(withWorkspace["Authorization"] == "bearer sk-test")
        #expect(withWorkspace["X-DashScope-WorkSpace"] == "workspace-id")
    }

    @Test
    func startAndFinishMessagesContainRequiredSchema() throws {
        let startMessage = try AliyunRealtimeProtocol.makeStartMessage(
            taskID: "task-1",
            model: "fun-asr-realtime"
        )
        let startObject = try #require(
            try JSONSerialization.jsonObject(with: Data(startMessage.utf8)) as? [String: Any]
        )
        let startHeader = try #require(startObject["header"] as? [String: Any])
        #expect(startHeader["action"] as? String == "run-task")
        #expect(startHeader["streaming"] as? String == "duplex")
        #expect(startHeader["task_id"] as? String == "task-1")

        let startPayload = try #require(startObject["payload"] as? [String: Any])
        #expect(startPayload["task_group"] as? String == "audio")
        #expect(startPayload["task"] as? String == "asr")
        #expect(startPayload["function"] as? String == "recognition")
        let params = try #require(startPayload["parameters"] as? [String: Any])
        #expect(params["format"] as? String == "pcm")
        #expect(params["sample_rate"] as? Int == 16_000)

        let finishMessage = try AliyunRealtimeProtocol.makeFinishMessage(taskID: "task-1")
        let finishObject = try #require(
            try JSONSerialization.jsonObject(with: Data(finishMessage.utf8)) as? [String: Any]
        )
        let finishHeader = try #require(finishObject["header"] as? [String: Any])
        #expect(finishHeader["action"] as? String == "finish-task")
        #expect(finishHeader["task_id"] as? String == "task-1")
        let finishPayload = try #require(finishObject["payload"] as? [String: Any])
        let input = try #require(finishPayload["input"] as? [String: Any])
        #expect(input.isEmpty)
    }

    @Test
    func parseServerEventsCoversExpectedEventTypes() throws {
        #expect(
            try AliyunRealtimeProtocol.parseServerMessage(
                #"{"header":{"event":"task-started","task_id":"t1"}}"#
            ) == .taskStarted(taskID: "t1")
        )

        #expect(
            try AliyunRealtimeProtocol.parseServerMessage(
                #"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"text":"hello","end_time":null}}}}"#
            ) == .resultGenerated(text: "hello", endTime: nil, isHeartbeat: false)
        )

        #expect(
            try AliyunRealtimeProtocol.parseServerMessage(
                #"{"header":{"event":"result-generated"},"payload":{"output":{"sentence":{"heartbeat":true}}}}"#
            ) == .resultGenerated(text: "", endTime: nil, isHeartbeat: true)
        )

        #expect(
            try AliyunRealtimeProtocol.parseServerMessage(
                #"{"header":{"event":"task-finished","task_id":"t1"}}"#
            ) == .taskFinished(taskID: "t1")
        )

        #expect(
            try AliyunRealtimeProtocol.parseServerMessage(
                #"{"header":{"event":"task-failed","task_id":"t1","error_code":"Invalid","error_message":"bad audio"}}"#
            ) == .taskFailed(taskID: "t1", code: "Invalid", message: "bad audio")
        )
    }

    @Test
    func chunkPCMUsesFixed3200BytesAndFlushesTail() {
        var pending = Data()

        let chunks = AliyunRealtimeProtocol.appendAndChunkPCM(
            pending: &pending,
            incoming: Data(repeating: 1, count: 6500),
            flushTail: true
        )
        #expect(chunks.map(\.count) == [3200, 3200, 100])
        #expect(pending.isEmpty)
    }
}
