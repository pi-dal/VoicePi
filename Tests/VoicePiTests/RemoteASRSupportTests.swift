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

    @Test
    func volcengineConfigurationRequiresAppID() {
        let withoutAppID = RemoteASRConfiguration(
            baseURL: "https://openspeech.bytedance.com/api/v3/sauc/bigmodel",
            apiKey: "ak-test",
            model: "bigmodel",
            prompt: "",
            volcengineAppID: ""
        )
        #expect(withoutAppID.isConfigured(for: .remoteVolcengineASR) == false)
        #expect(throws: Error.self) {
            try withoutAppID.validate(for: .remoteVolcengineASR)
        }

        let withAppID = RemoteASRConfiguration(
            baseURL: "https://openspeech.bytedance.com/api/v3/sauc/bigmodel",
            apiKey: "ak-test",
            model: "bigmodel",
            prompt: "",
            volcengineAppID: "app-test"
        )
        #expect(withAppID.isConfigured(for: .remoteVolcengineASR))
        #expect(throws: Never.self) {
            try withAppID.validate(for: .remoteVolcengineASR)
        }
    }
}
