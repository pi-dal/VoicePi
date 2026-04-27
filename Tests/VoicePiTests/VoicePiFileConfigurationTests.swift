import Foundation
import Testing
import TOMLKit
@testable import VoicePi

struct VoicePiFileConfigurationTests {
    @Test
    func tomlRoundTripPreservesAllConfigSections() throws {
        let original = VoicePiFileConfiguration(
            app: .init(
                language: .english,
                interfaceTheme: .dark
            ),
            asr: .init(
                backend: .remoteVolcengineASR,
                remote: .init(
                    baseURL: "https://asr.example.com",
                    apiKey: "asr-key",
                    model: "bigmodel",
                    prompt: "Prefer punctuation",
                    volcengineAppID: "volc-app-id"
                )
            ),
            text: .init(
                postProcessingMode: .translation,
                translationProvider: .llm,
                refinementProvider: .externalProcessor,
                targetLanguage: .japanese
            ),
            llm: .init(
                baseURL: "https://llm.example.com",
                apiKey: "llm-key",
                model: "gpt-5-mini",
                refinementPrompt: "Keep concise bullets.",
                enableThinking: true
            ),
            hotkeys: .init(
                activation: .init(keyCodes: [35], modifierFlags: 262_144),
                cancel: .init(keyCodes: [47], modifierFlags: 262_144),
                modeCycle: .init(keyCodes: [49], modifierFlags: 1_310_720),
                processor: .init(keyCodes: [31], modifierFlags: 786_432),
                promptCycle: .init(keyCodes: [32], modifierFlags: 786_432)
            ),
            history: .init(
                enabled: false,
                storeText: false,
                directory: "history-data"
            ),
            paths: .init(
                userPrompt: "user.txt",
                userPromptsDirectory: "prompt-library",
                dictionary: "dict.json",
                dictionarySuggestions: "dict-suggestions.json",
                processors: "processors-data.json",
                promptWorkspace: "workspace.json"
            )
        )

        let encoder = TOMLEncoder()
        let decoder = TOMLDecoder()
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(VoicePiFileConfiguration.self, from: encoded)

        #expect(decoded == original)
    }
}
