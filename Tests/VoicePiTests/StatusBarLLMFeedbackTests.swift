import Foundation
import Testing
@testable import VoicePi

struct StatusBarLLMFeedbackTests {
    @Test
    func displayProviderUsesLLMWhileRefinementIsSelected() {
        #expect(
            TranslationProvider.displayProvider(
                mode: .refinement,
                storedProvider: .appleTranslate,
                appleTranslateSupported: true
            ) == .llm
        )
    }

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

    @Test
    func refinementWithExternalProcessorMentionsSelectedProcessor() {
        let processor = ExternalProcessorEntry(
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "alma"
        )

        let message = LLMSectionFeedback.message(
            mode: .refinement,
            provider: .llm,
            refinementProvider: .externalProcessor,
            externalProcessor: processor,
            configuration: .init(),
            selectedLanguage: .english,
            targetLanguage: .japanese,
            appleTranslateSupported: true
        )

        #expect(
            message
                == "Refinement is active and will use Alma CLI."
        )
    }

    @Test
    func refinementWithExternalProcessorWithoutSelectionPointsToProcessorsTab() {
        let message = LLMSectionFeedback.message(
            mode: .refinement,
            provider: .llm,
            refinementProvider: .externalProcessor,
            externalProcessor: nil,
            configuration: .init(),
            selectedLanguage: .english,
            targetLanguage: .japanese,
            appleTranslateSupported: true
        )

        #expect(
            message
                == "Refinement is selected, but no processor is configured yet. Click Processors to add one."
        )
    }
}
