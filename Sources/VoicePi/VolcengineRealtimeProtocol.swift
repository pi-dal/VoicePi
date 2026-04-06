import Foundation

enum VolcengineRealtimeProtocolError: Error, LocalizedError {
    case invalidEndpoint
    case invalidCredential
    case invalidMessage
    case unsupportedCompression
    case unsupportedMessageType
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid Volcengine realtime websocket endpoint."
        case .invalidCredential:
            return "Missing Volcengine realtime credentials."
        case .invalidMessage:
            return "Invalid Volcengine realtime websocket message."
        case .unsupportedCompression:
            return "Unsupported Volcengine realtime compression type."
        case .unsupportedMessageType:
            return "Unsupported Volcengine realtime message type."
        case .serializationFailed:
            return "Failed to serialize Volcengine realtime message payload."
        }
    }
}

enum VolcengineRealtimeServerEvent: Equatable {
    case acknowledged
    case partial(text: String)
    case final(text: String)
    case completed
    case failed(code: String, message: String)
    case ignored
}

enum VolcengineRealtimeProtocol {
    static let defaultWebSocketPath = "/api/v3/sauc/bigmodel"
    static let defaultResourceID = "bigmodel"
    static let pcmChunkSize = 3_200
    static let sampleRate = 16_000
    static let bitsPerSample = 16
    static let channels = 1

    private static let protocolVersion: UInt8 = 0x1
    private static let headerWords: UInt8 = 0x1
    private static let positiveSequenceFlag: UInt8 = 0x1
    private static let negativeSequenceFlag: UInt8 = 0x2

    private enum MessageType: UInt8 {
        case fullClientRequest = 0x1
        case audioOnlyRequest = 0x2
        case fullServerResponse = 0x9
        case serverACK = 0xB
        case serverErrorResponse = 0xF
    }

    private enum SerializationMethod: UInt8 {
        case none = 0x0
        case json = 0x1
    }

    private enum CompressionType: UInt8 {
        case none = 0x0
        case gzip = 0x1
    }

    private struct ParsedFrame {
        let messageType: MessageType
        let flags: UInt8
        let sequence: Int32?
        let serialization: SerializationMethod
        let compression: CompressionType
        let payload: Data

        var isFinalSequence: Bool {
            if let sequence, sequence < 0 {
                return true
            }
            return flags == VolcengineRealtimeProtocol.negativeSequenceFlag
        }
    }

    static func normalizeWebSocketEndpoint(from raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VolcengineRealtimeProtocolError.invalidEndpoint
        }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate),
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty
        else {
            throw VolcengineRealtimeProtocolError.invalidEndpoint
        }
        components.host = host

        guard let scheme = components.scheme?.lowercased() else {
            throw VolcengineRealtimeProtocolError.invalidEndpoint
        }

        switch scheme {
        case "https":
            components.scheme = "wss"
        case "http":
            components.scheme = "ws"
        case "wss", "ws":
            break
        default:
            throw VolcengineRealtimeProtocolError.invalidEndpoint
        }

        components.path = normalizedRealtimePath(from: components.path)

        guard let url = components.url else {
            throw VolcengineRealtimeProtocolError.invalidEndpoint
        }
        return url
    }

    static func makeHandshakeHeaders(
        configuration: RemoteASRConfiguration,
        requestID: String
    ) throws -> [String: String] {
        let apiKey = configuration.trimmedAPIKey
        let appID = configuration.trimmedVolcengineAppID
        guard !apiKey.isEmpty, !appID.isEmpty else {
            throw VolcengineRealtimeProtocolError.invalidCredential
        }

        let resourceID = configuration.trimmedModel.isEmpty ? defaultResourceID : configuration.trimmedModel
        return [
            "X-Api-App-Key": appID,
            "X-Api-Access-Key": apiKey,
            "X-Api-Resource-Id": resourceID,
            "X-Api-Request-Id": requestID,
            "X-Api-Connect-Id": requestID
        ]
    }

    static func makeStartFrame(
        configuration: RemoteASRConfiguration,
        requestID: String
    ) throws -> Data {
        var requestPayload: [String: Any] = [
            "model_name": configuration.trimmedModel.isEmpty ? defaultResourceID : configuration.trimmedModel,
            "enable_itn": true,
            "enable_punc": true
        ]
        if !configuration.trimmedPrompt.isEmpty {
            requestPayload["context"] = configuration.trimmedPrompt
        }

        let payload: [String: Any] = [
            "app": ["appid": configuration.trimmedVolcengineAppID],
            "user": ["uid": requestID],
            "audio": [
                "format": "pcm",
                "sample_rate": sampleRate,
                "bits": bitsPerSample,
                "channel": channels,
                "codec": "raw"
            ],
            "request": requestPayload
        ]

        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw VolcengineRealtimeProtocolError.serializationFailed
        }

        let header = makeHeader(
            messageType: .fullClientRequest,
            flags: 0,
            serialization: .json,
            compression: .none
        )
        return header + uint32Data(UInt32(payloadData.count)) + payloadData
    }

    static func makeAudioFrame(
        sequence: Int32,
        audioChunk: Data,
        isFinal: Bool
    ) -> Data {
        let absSequence = max(Int32(1), abs(sequence))
        let sequenceValue = isFinal ? -absSequence : absSequence
        let flags = isFinal ? negativeSequenceFlag : positiveSequenceFlag
        let header = makeHeader(
            messageType: .audioOnlyRequest,
            flags: flags,
            serialization: .none,
            compression: .none
        )
        return header
            + int32Data(sequenceValue)
            + uint32Data(UInt32(audioChunk.count))
            + audioChunk
    }

    static func appendAndChunkPCM(
        pending: inout Data,
        incoming: Data,
        flushTail: Bool
    ) -> [Data] {
        RealtimePCMChunker.appendAndChunk(
            pending: &pending,
            incoming: incoming,
            chunkSize: pcmChunkSize,
            flushTail: flushTail
        )
    }

    static func parseServerMessage(_ data: Data) throws -> VolcengineRealtimeServerEvent {
        let frame = try parseFrame(data)
        switch frame.messageType {
        case .serverACK:
            if let payload = try decodePayload(from: frame),
               let failure = extractFailure(from: payload)
            {
                return .failed(code: failure.code, message: failure.message)
            }
            return .acknowledged
        case .serverErrorResponse:
            if let payload = try decodePayload(from: frame),
               let failure = extractFailure(from: payload)
            {
                return .failed(code: failure.code, message: failure.message)
            }
            let fallbackCode = frame.sequence.map(String.init) ?? "unknown"
            return .failed(code: fallbackCode, message: "Volcengine realtime server returned an error.")
        case .fullServerResponse:
            guard let payload = try decodePayload(from: frame) else {
                return frame.isFinalSequence ? .completed : .ignored
            }

            if let failure = extractFailure(from: payload) {
                return .failed(code: failure.code, message: failure.message)
            }

            let text = extractTranscript(from: payload).trimmingCharacters(in: .whitespacesAndNewlines)
            let isFinal = frame.isFinalSequence || payloadIndicatesFinal(payload)
            if !text.isEmpty {
                return isFinal ? .final(text: text) : .partial(text: text)
            }
            return isFinal ? .completed : .ignored
        default:
            return .ignored
        }
    }

    private static func parseFrame(_ data: Data) throws -> ParsedFrame {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else {
            throw VolcengineRealtimeProtocolError.invalidMessage
        }

        let version = bytes[0] >> 4
        guard version == protocolVersion else {
            throw VolcengineRealtimeProtocolError.invalidMessage
        }

        let headerWordCount = Int(bytes[0] & 0x0F)
        let headerLength = headerWordCount * 4
        guard headerWordCount >= 1, bytes.count >= headerLength else {
            throw VolcengineRealtimeProtocolError.invalidMessage
        }

        let messageTypeRaw = bytes[1] >> 4
        guard let messageType = MessageType(rawValue: messageTypeRaw) else {
            throw VolcengineRealtimeProtocolError.unsupportedMessageType
        }
        let flags = bytes[1] & 0x0F

        let serializationRaw = bytes[2] >> 4
        guard let serialization = SerializationMethod(rawValue: serializationRaw) else {
            throw VolcengineRealtimeProtocolError.invalidMessage
        }

        let compressionRaw = bytes[2] & 0x0F
        guard let compression = CompressionType(rawValue: compressionRaw) else {
            throw VolcengineRealtimeProtocolError.invalidMessage
        }

        var cursor = headerLength
        var sequence: Int32?
        if messageType == .serverACK || messageType == .fullServerResponse || messageType == .serverErrorResponse {
            if let parsedSequence = int32Value(in: bytes, offset: cursor) {
                sequence = parsedSequence
                cursor += 4
            }
        }

        let payload: Data
        if let declaredLength = uint32Value(in: bytes, offset: cursor) {
            cursor += 4
            let length = Int(declaredLength)
            if length > 0, bytes.count >= cursor + length {
                payload = Data(bytes[cursor..<(cursor + length)])
            } else if bytes.count > cursor {
                payload = Data(bytes[cursor..<bytes.count])
            } else {
                payload = Data()
            }
        } else if bytes.count > cursor {
            payload = Data(bytes[cursor..<bytes.count])
        } else {
            payload = Data()
        }

        return ParsedFrame(
            messageType: messageType,
            flags: flags,
            sequence: sequence,
            serialization: serialization,
            compression: compression,
            payload: payload
        )
    }

    private static func decodePayload(from frame: ParsedFrame) throws -> [String: Any]? {
        guard !frame.payload.isEmpty else {
            return nil
        }

        switch frame.compression {
        case .none:
            break
        case .gzip:
            throw VolcengineRealtimeProtocolError.unsupportedCompression
        }

        switch frame.serialization {
        case .none:
            guard let json = parseJSONDictionary(from: frame.payload) else {
                return nil
            }
            return json
        case .json:
            guard let json = parseJSONDictionary(from: frame.payload) else {
                throw VolcengineRealtimeProtocolError.invalidMessage
            }
            return json
        }
    }

    private static func parseJSONDictionary(from data: Data) -> [String: Any]? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }
        if let dictionary = jsonObject as? [String: Any] {
            return dictionary
        }
        if let array = jsonObject as? [Any] {
            return ["results": array]
        }
        return nil
    }

    private static func payloadIndicatesFinal(_ payload: [String: Any]) -> Bool {
        if boolValue(payload["is_final"]) == true
            || boolValue(payload["final"]) == true
            || boolValue(payload["is_end"]) == true
            || boolValue(payload["end"]) == true
        {
            return true
        }

        if let statusCode = intValue(payload["status"]),
           statusCode >= 3
        {
            return true
        }

        if let status = stringValue(payload["status"])?.lowercased() {
            return ["final", "finished", "done", "completed", "complete", "end"].contains(status)
        }

        return false
    }

    private static func extractTranscript(from payload: [String: Any]) -> String {
        if let direct = firstNonEmptyString(
            in: payload,
            keys: ["text", "transcript", "recognized_text", "sentence"]
        ) {
            return direct
        }

        if let utterances = payload["utterances"] as? [[String: Any]] {
            let text = utterances
                .compactMap { firstNonEmptyString(in: $0, keys: ["text", "transcript", "sentence"]) }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
        }

        for key in ["result", "results", "payload_msg", "payload", "data", "response"] {
            guard let value = payload[key] else { continue }
            let text = extractTranscript(fromAny: value)
            if !text.isEmpty {
                return text
            }
        }

        return ""
    }

    private static func extractTranscript(fromAny value: Any) -> String {
        if let dictionary = value as? [String: Any] {
            return extractTranscript(from: dictionary)
        }

        if let array = value as? [Any] {
            return array
                .map(extractTranscript(fromAny:))
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "" }

            if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")),
               let nestedData = trimmed.data(using: .utf8),
               let nested = parseJSONDictionary(from: nestedData)
            {
                let nestedText = extractTranscript(from: nested)
                if !nestedText.isEmpty {
                    return nestedText
                }
            }

            return trimmed
        }

        return ""
    }

    private static func extractFailure(from payload: [String: Any]) -> (code: String, message: String)? {
        let code = firstNonEmptyString(
            in: payload,
            keys: ["code", "error_code", "status_code", "status"]
        )
        let message = firstNonEmptyString(
            in: payload,
            keys: ["error_message", "error_msg", "message", "msg", "error", "detail"]
        )

        if let code, !isSuccessCode(code) {
            return (code, message ?? "Volcengine realtime request failed.")
        }

        if let message,
           payload.keys.contains(where: { ["error", "error_message", "error_msg"].contains($0) })
        {
            return (code ?? "error", message)
        }

        return nil
    }

    private static func isSuccessCode(_ code: String) -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "0"
            || normalized == "200"
            || normalized == "ok"
            || normalized == "success"
    }

    private static func normalized(path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "/" {
            return ""
        }
        if trimmed.hasSuffix("/") {
            return String(trimmed.dropLast())
        }
        return trimmed
    }

    private static func normalizedRealtimePath(from path: String) -> String {
        let normalizedPath = normalized(path: path)
        if normalizedPath.isEmpty {
            return defaultWebSocketPath
        }

        switch normalizedPath {
        case "/api/v3", "/api/v3/audio/transcriptions", "/audio/transcriptions":
            return defaultWebSocketPath
        default:
            return normalizedPath
        }
    }

    private static func makeHeader(
        messageType: MessageType,
        flags: UInt8,
        serialization: SerializationMethod,
        compression: CompressionType
    ) -> Data {
        let b0 = (protocolVersion << 4) | headerWords
        let b1 = (messageType.rawValue << 4) | (flags & 0x0F)
        let b2 = (serialization.rawValue << 4) | (compression.rawValue & 0x0F)
        return Data([b0, b1, b2, 0x00])
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let int32 as Int32:
            return Int(int32)
        case let int64 as Int64:
            return Int(int64)
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            return ["1", "true", "yes"].contains(string.lowercased())
        default:
            return nil
        }
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func firstNonEmptyString(in payload: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = stringValue(payload[key]) {
                return value
            }
        }
        return nil
    }

    private static func int32Value(in bytes: [UInt8], offset: Int) -> Int32? {
        guard bytes.count >= offset + 4 else { return nil }
        let value = UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
        return Int32(bitPattern: value)
    }

    private static func uint32Value(in bytes: [UInt8], offset: Int) -> UInt32? {
        guard bytes.count >= offset + 4 else { return nil }
        return UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
    }

    private static func uint32Data(_ value: UInt32) -> Data {
        var bigEndian = value.bigEndian
        return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
    }

    private static func int32Data(_ value: Int32) -> Data {
        var bigEndian = value.bigEndian
        return Data(bytes: &bigEndian, count: MemoryLayout<Int32>.size)
    }
}
