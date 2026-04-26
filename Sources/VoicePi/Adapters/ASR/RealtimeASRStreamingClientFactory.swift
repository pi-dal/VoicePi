import Foundation

enum RealtimeASRStreamingClientFactory {
    static func make(
        backend: ASRBackend,
        connectTimeoutSeconds: Double
    ) throws -> RemoteASRStreamingClient {
        switch backend {
        case .remoteAliyunASR:
            return AliyunRealtimeASRStreamingClient(connectTimeoutSeconds: connectTimeoutSeconds)
        case .remoteVolcengineASR:
            return VolcengineRealtimeASRStreamingClient(connectTimeoutSeconds: connectTimeoutSeconds)
        case .appleSpeech, .remoteOpenAICompatible:
            throw RemoteASRStreamingError.protocolError("unsupportedBackend")
        }
    }
}
