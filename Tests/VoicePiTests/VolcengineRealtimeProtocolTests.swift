import Foundation
import Testing
@testable import VoicePi

struct VolcengineRealtimeProtocolTests {
    @Test
    func normalizeEndpointSupportsHttpsAndWsForms() throws {
        #expect(
            try VolcengineRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "https://openspeech.bytedance.com"
            ).absoluteString == "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"
        )
        #expect(
            try VolcengineRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"
            ).absoluteString == "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"
        )
        #expect(
            try VolcengineRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "wss://openspeech.bytedance.com/api/v3/audio/transcriptions"
            ).absoluteString == "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"
        )
        #expect(
            try VolcengineRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "https://openspeech.bytedance.com/api/v3"
            ).absoluteString == "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"
        )
        #expect(
            try VolcengineRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "openspeech.bytedance.com/custom"
            ).absoluteString == "wss://openspeech.bytedance.com/custom"
        )
    }

    @Test
    func normalizeEndpointRejectsUnsupportedScheme() {
        #expect(throws: VolcengineRealtimeProtocolError.invalidEndpoint) {
            _ = try VolcengineRealtimeProtocol.normalizeWebSocketEndpoint(
                from: "ftp://openspeech.bytedance.com"
            )
        }
    }

    @Test
    func handshakeHeadersRequireAppIDAndKey() throws {
        let configuration = RemoteASRConfiguration(
            baseURL: "https://openspeech.bytedance.com",
            apiKey: "ak-test",
            model: "bigmodel",
            prompt: "",
            volcengineAppID: "app-test"
        )
        let headers = try VolcengineRealtimeProtocol.makeHandshakeHeaders(
            configuration: configuration,
            requestID: "request-1"
        )
        #expect(headers["X-Api-App-Key"] == "app-test")
        #expect(headers["X-Api-Access-Key"] == "ak-test")
        #expect(headers["X-Api-Resource-Id"] == "bigmodel")
        #expect(headers["X-Api-Request-Id"] == "request-1")
        #expect(headers["X-Api-Connect-Id"] == "request-1")
    }

    @Test
    func startAndAudioFramesEncodeRequiredFields() throws {
        let configuration = RemoteASRConfiguration(
            baseURL: "https://openspeech.bytedance.com",
            apiKey: "ak-test",
            model: "bigmodel",
            prompt: "prefer technical terms",
            volcengineAppID: "app-test"
        )
        let startFrame = try VolcengineRealtimeProtocol.makeStartFrame(
            configuration: configuration,
            requestID: "request-1"
        )
        #expect(startFrame.count > 12)
        #expect(startFrame[0] == 0x11)
        #expect(startFrame[1] == 0x10)
        #expect(startFrame[2] == 0x10)
        let payloadLength = Int(try #require(uint32(at: 4, in: startFrame)))
        let payload = Data(startFrame[8..<(8 + payloadLength)])
        let payloadObject = try #require(
            try JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any]
        )
        let request = try #require(payloadObject["request"] as? [String: Any])
        let context = try #require(request["context"] as? String)
        #expect(context.contains("Built-in ASR bias rules:"))
        #expect(context.contains("prefer technical terms"))

        let audioFrame = VolcengineRealtimeProtocol.makeAudioFrame(
            sequence: 3,
            audioChunk: Data([0x01, 0x02]),
            isFinal: true
        )
        #expect(audioFrame[0] == 0x11)
        #expect(audioFrame[1] == 0x22)
        #expect(audioFrame[2] == 0x00)
        #expect(int32(at: 4, in: audioFrame) == -3)
        #expect(uint32(at: 8, in: audioFrame) == 2)
    }

    @Test
    func parseServerMessageHandlesPartialFinalAndFailure() throws {
        let partialPayload = try JSONSerialization.data(
            withJSONObject: ["result": ["text": "hello"]],
            options: []
        )
        let partialFrame = makeServerFrame(
            messageType: 0x9,
            flags: 0x1,
            serialization: 0x1,
            sequence: 1,
            payload: partialPayload
        )
        #expect(try VolcengineRealtimeProtocol.parseServerMessage(partialFrame) == .partial(text: "hello"))

        let finalPayload = try JSONSerialization.data(
            withJSONObject: ["result": ["text": "hello world"], "is_final": true],
            options: []
        )
        let finalFrame = makeServerFrame(
            messageType: 0x9,
            flags: 0x2,
            serialization: 0x1,
            sequence: -2,
            payload: finalPayload
        )
        #expect(try VolcengineRealtimeProtocol.parseServerMessage(finalFrame) == .final(text: "hello world"))

        let failurePayload = try JSONSerialization.data(
            withJSONObject: ["error_code": "401", "error_message": "bad token"],
            options: []
        )
        let failureFrame = makeServerFrame(
            messageType: 0xF,
            flags: 0x0,
            serialization: 0x1,
            sequence: 401,
            payload: failurePayload
        )
        #expect(try VolcengineRealtimeProtocol.parseServerMessage(failureFrame) == .failed(code: "401", message: "bad token"))
    }

    @Test
    func chunkPCMUsesFixed3200BytesAndFlushesTail() {
        var pending = Data()
        let chunks = VolcengineRealtimeProtocol.appendAndChunkPCM(
            pending: &pending,
            incoming: Data(repeating: 1, count: 6_500),
            flushTail: true
        )
        #expect(chunks.map(\.count) == [3_200, 3_200, 100])
        #expect(pending.isEmpty)
    }
}

private func makeServerFrame(
    messageType: UInt8,
    flags: UInt8,
    serialization: UInt8,
    sequence: Int32?,
    payload: Data
) -> Data {
    let header = Data([0x11, (messageType << 4) | (flags & 0x0F), (serialization << 4), 0x00])

    var frame = header
    if [0x9, 0xB, 0xF].contains(messageType), let sequence {
        frame.append(int32Data(sequence))
    }
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

private func int32(at offset: Int, in data: Data) -> Int32? {
    guard data.count >= offset + 4 else { return nil }
    let bytes = [UInt8](data[offset..<(offset + 4)])
    let raw = UInt32(bytes[0]) << 24
        | UInt32(bytes[1]) << 16
        | UInt32(bytes[2]) << 8
        | UInt32(bytes[3])
    return Int32(bitPattern: raw)
}

private func uint32(at offset: Int, in data: Data) -> UInt32? {
    guard data.count >= offset + 4 else { return nil }
    let bytes = [UInt8](data[offset..<(offset + 4)])
    return UInt32(bytes[0]) << 24
        | UInt32(bytes[1]) << 16
        | UInt32(bytes[2]) << 8
        | UInt32(bytes[3])
}
