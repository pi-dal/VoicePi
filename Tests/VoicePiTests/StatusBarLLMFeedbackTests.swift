import Foundation
import Testing
@testable import VoicePi

struct StatusBarLLMFeedbackTests {
    @Test
    func translationWithIncompleteLLMConfigFallsBackToAppleTranslateWhenAvailable() {
        let message = LLMSectionFeedback.message(
            mode: .translation,
            provider: .llm,
            configuration: .init(),
            selectedLanguage: .english,
            targetLanguage: .japanese,
            appleTranslateSupported: true
        )

        #expect(
            message
                == "LLM translation is selected, but the LLM configuration is incomplete. VoicePi will fall back to Apple Translate."
        )
    }

    @Test
    func translationWithIncompleteLLMConfigMentionsBlockedStateWhenAppleTranslateIsUnavailable() {
        let message = LLMSectionFeedback.message(
            mode: .translation,
            provider: .llm,
            configuration: .init(),
            selectedLanguage: .english,
            targetLanguage: .japanese,
            appleTranslateSupported: false
        )

        #expect(
            message
                == "LLM translation is selected because Apple Translate is unavailable on this macOS version, but the LLM configuration is incomplete. Translation will not work until API Base URL, API Key, and Model are provided."
        )
    }
}
