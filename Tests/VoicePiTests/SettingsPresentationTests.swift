import AppKit
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
                == "Current shortcut: A + S. Click the field above and press a new combination to replace it. Advanced shortcuts require Input Monitoring, while Accessibility covers suppression and paste injection."
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
    func homePresentationExplainsThatStandardShortcutsAvoidInputMonitoring() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.homePresentationExplainsThatStandardShortcutsAvoidInputMonitoring.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.setActivationShortcut(
            ActivationShortcut(
                keyCodes: [49],
                modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
            )
        )

        let presentation = SettingsPresentation.homeSectionPresentation(
            model: model,
            appleTranslateSupported: true
        )

        #expect(
            presentation.shortcutHint
                == "Current shortcut: ⌘⌥ + Space. Click the field above and press a new combination to replace it. Standard shortcuts work without Input Monitoring. Accessibility is still required for paste injection."
        )
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
    @MainActor
    func settingsWindowUsesWarmOuterBackgroundInLightTheme() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.settingsWindowUsesTintedOuterBackgroundInLightTheme.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.interfaceTheme = .light

        let controller = SettingsWindowController(model: model, delegate: nil)
        let expectedBackground = NSColor(
            calibratedRed: 0xF5 / 255.0,
            green: 0xF3 / 255.0,
            blue: 0xED / 255.0,
            alpha: 1
        )

        #expect(controller.window?.titlebarAppearsTransparent == true)
        #expect(controller.window?.backgroundColor.isApproximatelyEqual(to: expectedBackground) == true)
        #expect(color(from: controller.window?.contentView?.layer?.backgroundColor)?.isApproximatelyEqual(to: expectedBackground) == true)
    }

    @Test
    func permissionCopyReflectsCurrentInputMonitoringRequirement() {
        #expect(
            PermissionsCopy.permissionsSectionSubtitle
                == "Manage the macOS permissions VoicePi uses for shortcut listening, advanced shortcut suppression, recording, and paste injection."
        )
        #expect(
            PermissionsCopy.permissionsHint
                == "VoicePi shows a guided permission flow first, then hands off to macOS only when you choose to continue. After changing anything in System Settings, refresh here."
        )
        #expect(
            PermissionsCopy.accessibilityDescription
                == "Required for advanced shortcut suppression and paste injection."
        )
        #expect(
            PermissionsCopy.inputMonitoringDescription
                == "Required for listening to advanced global shortcuts."
        )
        #expect(
            PermissionsCopy.strategyDescription
                == "VoicePi uses guided permission handoffs: Microphone and Speech Recognition lead into macOS permission sheets, while Accessibility and Input Monitoring are only needed for advanced shortcut handling and paste injection."
        )
        #expect(
            PermissionsCopy.standardShortcutHint
                == "Current shortcut: %@. Click the field above and press a new combination to replace it. Standard shortcuts work without Input Monitoring. Accessibility is still required for paste injection."
        )
        #expect(
            PermissionsCopy.advancedShortcutHint
                == "Current shortcut: %@. Click the field above and press a new combination to replace it. Advanced shortcuts require Input Monitoring, while Accessibility covers suppression and paste injection."
        )
    }
}

private func color(from cgColor: CGColor?) -> NSColor? {
    guard let cgColor else { return nil }
    return NSColor(cgColor: cgColor)
}

private extension NSColor {
    func isApproximatelyEqual(to other: NSColor, tolerance: CGFloat = 0.002) -> Bool {
        guard let lhs = usingColorSpace(.deviceRGB),
              let rhs = other.usingColorSpace(.deviceRGB) else {
            return false
        }

        return abs(lhs.redComponent - rhs.redComponent) <= tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) <= tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) <= tolerance
            && abs(lhs.alphaComponent - rhs.alphaComponent) <= tolerance
    }
}
