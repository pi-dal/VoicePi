import Testing
@testable import VoicePi

struct RemoteASRSupportTests {
    @Test
    func remoteConfigurationAcceptsHostWithoutScheme() throws {
        let configuration = RemoteASRConfiguration(
            baseURL: "api.example.com/v1",
            apiKey: "sk-test",
            model: "whisper-large"
        )

        #expect(configuration.normalizedBaseURL?.absoluteString == "https://api.example.com/v1")
        #expect(throws: Never.self) {
            try configuration.validate()
        }
    }

    @Test
    func remoteConfigurationRequiresBaseURLKeyAndModel() {
        #expect(RemoteASRConfiguration().isConfigured == false)
        #expect(throws: Error.self) {
            try RemoteASRConfiguration().validate()
        }
    }
}
