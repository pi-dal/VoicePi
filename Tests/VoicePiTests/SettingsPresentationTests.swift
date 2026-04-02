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
        model.setInputMonitoringAuthorization(.granted)
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
        #expect(presentation.permissionSummary == "Permissions: Mic Granted, Speech Denied, Accessibility Unknown, Input Monitoring Granted")
        #expect(presentation.asrSummary == "ASR backend: Remote OpenAI-Compatible ASR • Remote configured")
        #expect(presentation.llmSummary == "Text processing: Translate via Apple Translate • Target Japanese")
        #expect(
            presentation.shortcutHint
                == "Current shortcut: A + S. Click the field above and press a new combination to replace it. Input Monitoring covers shortcut listening, while Accessibility covers suppression and paste injection."
        )
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
        model.setInputMonitoringAuthorization(.unknown)
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
            PermissionsCopy.permissionsSectionSubtitle
                == "Manage the macOS permissions VoicePi uses for shortcut listening, event suppression, recording, and paste injection."
        )
        #expect(
            PermissionsCopy.permissionsHint
                == "VoicePi asks for these at launch while macOS still treats them as undecided. After changing anything in System Settings, refresh here."
        )
        #expect(
            PermissionsCopy.accessibilityDescription
                == "Required for shortcut suppression and paste injection."
        )
        #expect(
            PermissionsCopy.inputMonitoringDescription
                == "Required for listening to the global shortcut. VoicePi asks for it at launch while macOS still treats it as undecided."
        )
        #expect(
            PermissionsCopy.strategyDescription
                == "VoicePi currently splits shortcut handling across two macOS privacy gates: Input Monitoring for listening, Accessibility for suppressing and injecting events. Microphone and Speech Recognition cover recording and local transcription."
        )
        #expect(
            PermissionsCopy.shortcutHint
                == "Current shortcut: %@. Click the field above and press a new combination to replace it. Input Monitoring covers shortcut listening, while Accessibility covers suppression and paste injection."
        )
    }
}
