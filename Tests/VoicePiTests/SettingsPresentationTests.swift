import Foundation
import Testing
@testable import VoicePi

struct SettingsPresentationTests {
    @Test
    @MainActor
    func homePresentationReflectsModelStateWhenAppleTranslateIsAvailable() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.homePresentationReflectsModelStateWhenAppleTranslateIsAvailable.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.setActivationShortcut(ActivationShortcut(keyCodes: [0, 1], modifierFlagsRawValue: 0))
        model.selectedLanguage = .english
        model.setMicrophoneAuthorization(.granted)
        model.setSpeechAuthorization(.denied)
        model.setAccessibilityAuthorization(.unknown)
        model.setASRBackend(.remoteOpenAICompatible)
        model.saveRemoteASRConfiguration(baseURL: "https://api.example.com", apiKey: "sk", model: "whisper", prompt: "")
        model.setPostProcessingMode(.translation)
        model.setTranslationProvider(.appleTranslate)
        model.setTargetLanguage(.japanese)
        model.saveLLMConfiguration(baseURL: "https://llm.example.com", apiKey: "sk", model: "gpt")

        let presentation = SettingsPresentation.homeSectionPresentation(
            model: model,
            appleTranslateSupported: true
        )

        #expect(presentation.shortcutSummary == "Current shortcut: A + S")
        #expect(presentation.languageSummary == "Recognition language: English")
        #expect(presentation.permissionSummary == "Permissions: Mic Granted, Speech Denied, Accessibility Unknown")
        #expect(presentation.asrSummary == "ASR backend: Remote OpenAI-Compatible ASR • Remote configured")
        #expect(presentation.llmSummary == "Text processing: Translate via Apple Translate • Target Japanese")
        #expect(presentation.statusTone == .secondary)
    }

    @Test
    @MainActor
    func homePresentationFallsBackToLLMWhenAppleTranslateIsUnavailable() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.homePresentationFallsBackToLLMWhenAppleTranslateIsUnavailable.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.setActivationShortcut(ActivationShortcut(keyCodes: [0, 1], modifierFlagsRawValue: 0))
        model.selectedLanguage = .english
        model.setMicrophoneAuthorization(.granted)
        model.setSpeechAuthorization(.denied)
        model.setAccessibilityAuthorization(.unknown)
        model.setASRBackend(.remoteOpenAICompatible)
        model.saveRemoteASRConfiguration(baseURL: "https://api.example.com", apiKey: "sk", model: "whisper", prompt: "")
        model.setPostProcessingMode(.translation)
        model.setTranslationProvider(.appleTranslate)
        model.setTargetLanguage(.japanese)
        model.saveLLMConfiguration(baseURL: "https://llm.example.com", apiKey: "sk", model: "gpt")

        let presentation = SettingsPresentation.homeSectionPresentation(
            model: model,
            appleTranslateSupported: false
        )

        #expect(presentation.llmSummary == "Text processing: Translate via LLM • Target Japanese")
    }

    @Test
    @MainActor
    func homePresentationUsesErrorSummaryWhenPresent() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.homePresentationUsesErrorSummaryWhenPresent.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.presentError("Permission missing")

        let presentation = SettingsPresentation.homeSectionPresentation(model: model)

        #expect(presentation.statusSummary == "Latest status: Permission missing")
        #expect(presentation.statusTone == .error)
    }

    @Test
    func aboutPresentationUsesBundleValuesAndStaticProfile() {
        let presentation = SettingsPresentation.aboutPresentation(
            infoDictionary: [
                "CFBundleShortVersionString": "1.2.3",
                "CFBundleVersion": "123"
            ]
        )

        #expect(presentation.version == "1.2.3")
        #expect(presentation.build == "123")
        #expect(presentation.author == "pi-dal")
        #expect(presentation.websiteDisplay == "pi-dal.com")
        #expect(presentation.githubDisplay == "@pi-dal")
        #expect(presentation.xDisplay == "@pidal20")
    }

    @Test
    func permissionPresentationMapsTitlesAndTones() {
        #expect(SettingsPresentation.permissionPresentation(for: .granted) == .init(title: "Granted", tone: .granted))
        #expect(SettingsPresentation.permissionPresentation(for: .denied) == .init(title: "Denied", tone: .denied))
        #expect(SettingsPresentation.permissionPresentation(for: .restricted) == .init(title: "Restricted", tone: .restricted))
        #expect(SettingsPresentation.permissionPresentation(for: .unknown) == .init(title: "Unknown", tone: .unknown))
    }

    @Test
    func selectedThemeIndexMatchesEnumOrdering() {
        #expect(SettingsPresentation.selectedThemeIndex(for: .system) == 0)
        #expect(SettingsPresentation.selectedThemeIndex(for: .light) == 1)
        #expect(SettingsPresentation.selectedThemeIndex(for: .dark) == 2)
    }

    @Test
    func permissionCopyReflectsCurrentInputMonitoringRequirement() {
        #expect(
            PermissionsCopy.inputMonitoringDescription
                == "Input Monitoring is required for the current global shortcut implementation on some macOS setups. If the shortcut does not trigger, grant it here and refresh."
        )
        #expect(
            PermissionsCopy.strategyDescription
                == "VoicePi needs microphone, speech recognition, and accessibility. For the current global shortcut implementation, Input Monitoring may also be required on your macOS setup. If a status changes in System Settings, come back here and refresh to confirm everything is ready."
        )
    }
}
