import Testing
@testable import VoicePi

struct RealtimeASRStreamingClientFactoryTests {
    @Test
    func factoryBuildsAliyunAndVolcengineRealtimeClients() throws {
        let aliyun = try RealtimeASRStreamingClientFactory.make(
            backend: .remoteAliyunASR,
            connectTimeoutSeconds: 1
        )
        let volcengine = try RealtimeASRStreamingClientFactory.make(
            backend: .remoteVolcengineASR,
            connectTimeoutSeconds: 1
        )

        #expect(type(of: aliyun) == AliyunRealtimeASRStreamingClient.self)
        #expect(type(of: volcengine) == VolcengineRealtimeASRStreamingClient.self)
    }

    @Test
    func factoryRejectsNonRealtimeBackends() {
        #expect(throws: RemoteASRStreamingError.protocolError("unsupportedBackend")) {
            _ = try RealtimeASRStreamingClientFactory.make(
                backend: .remoteOpenAICompatible,
                connectTimeoutSeconds: 1
            )
        }
        #expect(throws: RemoteASRStreamingError.protocolError("unsupportedBackend")) {
            _ = try RealtimeASRStreamingClientFactory.make(
                backend: .appleSpeech,
                connectTimeoutSeconds: 1
            )
        }
    }
}
