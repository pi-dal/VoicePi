import Foundation

enum RemoteASRStreamEvent: Equatable {
    case partial(text: String)
    case final(text: String)
    case timeout(kind: String)
    case closedByServer(code: URLSessionWebSocketTask.CloseCode, reason: String?)
    case protocolError(message: String)
}

enum RemoteASRStreamingError: LocalizedError, Equatable {
    case connectFailed(String)
    case authenticationFailed
    case protocolError(String)
    case streamSendFailed(String)
    case finalTimeout
    case serverClosed(String?)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .connectFailed(let message):
            return message.isEmpty ? "Failed to connect realtime ASR." : message
        case .authenticationFailed:
            return "Realtime ASR authentication failed."
        case .protocolError(let message):
            return message.isEmpty ? "Realtime ASR protocol error." : message
        case .streamSendFailed(let message):
            return message.isEmpty ? "Failed to stream audio to realtime ASR." : message
        case .finalTimeout:
            return "Realtime ASR final timeout."
        case .serverClosed(let reason):
            if let reason, !reason.isEmpty {
                return "Realtime ASR server closed connection: \(reason)"
            }
            return "Realtime ASR server closed the connection."
        case .cancelled:
            return "Realtime ASR session cancelled."
        }
    }
}

protocol RemoteASRStreamingClient: AnyObject {
    var events: AsyncStream<RemoteASRStreamEvent> { get }

    func connect(
        configuration: RemoteASRConfiguration,
        backend: ASRBackend,
        language: SupportedLanguage
    ) async throws

    func sendPCM16LEFrame(_ frame: Data) async throws
    func finishInput() async throws
    func awaitFinalResult(timeoutSeconds: Double) async throws -> String
    func close() async
}
