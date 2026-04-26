import Foundation

enum AliyunRealtimeProtocolError: LocalizedError, Equatable {
    case invalidEndpoint
    case invalidMessage
    case unsupportedEvent(String)
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid Aliyun realtime websocket endpoint."
        case .invalidMessage:
            return "Invalid Aliyun realtime websocket message."
        case .unsupportedEvent(let event):
            return "Unsupported Aliyun realtime event: \(event)"
        case .serializationFailed:
            return "Failed to serialize Aliyun realtime message."
        }
    }
}

enum AliyunRealtimeServerEvent: Equatable {
    case taskStarted(taskID: String)
    case resultGenerated(text: String, endTime: Int?, isHeartbeat: Bool)
    case taskFinished(taskID: String)
    case taskFailed(taskID: String, code: String, message: String)
}

enum AliyunRealtimeProtocol {
    static let websocketPath = "/api-ws/v1/inference"
    static let pcmChunkSize = 3_200
    static let sampleRate = 16_000

    static func normalizeWebSocketEndpoint(from raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AliyunRealtimeProtocolError.invalidEndpoint
        }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate) else {
            throw AliyunRealtimeProtocolError.invalidEndpoint
        }

        guard
            let scheme = components.scheme?.lowercased(),
            let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
            !host.isEmpty
        else {
            throw AliyunRealtimeProtocolError.invalidEndpoint
        }

        guard ["http", "https", "ws", "wss"].contains(scheme) else {
            throw AliyunRealtimeProtocolError.invalidEndpoint
        }

        var wsComponents = URLComponents()
        wsComponents.scheme = "wss"
        wsComponents.host = host
        wsComponents.port = components.port
        wsComponents.path = websocketPath
        wsComponents.queryItems = components.queryItems

        guard let normalized = wsComponents.url else {
            throw AliyunRealtimeProtocolError.invalidEndpoint
        }
        return normalized
    }

    static func makeHandshakeHeaders(apiKey: String, workspace: String?) -> [String: String] {
        var headers: [String: String] = ["Authorization": "bearer \(apiKey)"]
        let trimmedWorkspace = workspace?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedWorkspace.isEmpty {
            headers["X-DashScope-WorkSpace"] = trimmedWorkspace
        }
        return headers
    }

    static func makeStartMessage(taskID: String, model: String) throws -> String {
        let object: [String: Any] = [
            "header": [
                "streaming": "duplex",
                "task_id": taskID,
                "action": "run-task"
            ],
            "payload": [
                "model": model,
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "input": [:],
                "parameters": [
                    "format": "pcm",
                    "sample_rate": sampleRate
                ]
            ]
        ]

        return try serializeJSON(object)
    }

    static func makeFinishMessage(taskID: String) throws -> String {
        let object: [String: Any] = [
            "header": [
                "task_id": taskID,
                "action": "finish-task"
            ],
            "payload": [
                "input": [:]
            ]
        ]
        return try serializeJSON(object)
    }

    static func parseServerMessage(_ text: String) throws -> AliyunRealtimeServerEvent {
        guard
            let data = text.data(using: .utf8),
            let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let header = jsonObject["header"] as? [String: Any],
            let event = header["event"] as? String
        else {
            throw AliyunRealtimeProtocolError.invalidMessage
        }

        let taskID = (header["task_id"] as? String) ?? ""

        switch event {
        case "task-started":
            return .taskStarted(taskID: taskID)
        case "task-finished":
            return .taskFinished(taskID: taskID)
        case "task-failed":
            let code = (header["error_code"] as? String) ?? "Unknown"
            let message = (header["error_message"] as? String) ?? "Unknown error"
            return .taskFailed(taskID: taskID, code: code, message: message)
        case "result-generated":
            let sentence = extractSentence(from: jsonObject)
            let text = (sentence["text"] as? String) ?? ""
            let isHeartbeat = (sentence["heartbeat"] as? Bool) ?? false
            let endTime = intValue(sentence["end_time"])
            return .resultGenerated(text: text, endTime: endTime, isHeartbeat: isHeartbeat)
        default:
            throw AliyunRealtimeProtocolError.unsupportedEvent(event)
        }
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

    private static func serializeJSON(_ object: [String: Any]) throws -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []),
              let string = String(data: data, encoding: .utf8) else {
            throw AliyunRealtimeProtocolError.serializationFailed
        }
        return string
    }

    private static func extractSentence(from object: [String: Any]) -> [String: Any] {
        if
            let payload = object["payload"] as? [String: Any],
            let output = payload["output"] as? [String: Any],
            let sentence = output["sentence"] as? [String: Any]
        {
            return sentence
        }

        if
            let payload = object["payload"] as? [String: Any],
            let sentence = payload["sentence"] as? [String: Any]
        {
            return sentence
        }

        return [:]
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }
}
