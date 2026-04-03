import Foundation

enum SettingsPresentationStatusTone: Equatable {
    case secondary
    case error
}

enum PermissionPresentationTone: Equatable {
    case granted
    case denied
    case restricted
    case unknown
}

struct PermissionPresentation: Equatable {
    let title: String
    let tone: PermissionPresentationTone
}

struct HomeSectionPresentation: Equatable {
    let shortcutSummary: String
    let modeShortcutSummary: String
    let languageSummary: String
    let permissionSummary: String
    let asrSummary: String
    let llmSummary: String
    let shortcutHint: String
    let modeShortcutHint: String
    let statusSummary: String
    let statusTone: SettingsPresentationStatusTone
}

struct AboutSectionPresentation: Equatable {
    let version: String
    let build: String
    let author: String
    let websiteDisplay: String
    let githubDisplay: String
    let xDisplay: String
}

enum PermissionsCopy {
    static let permissionsSectionSubtitle =
        "Manage the macOS permissions VoicePi uses for shortcut listening, advanced shortcut suppression, recording, and paste injection."

    static let permissionsHint =
        "VoicePi shows a guided permission flow first, then hands off to macOS only when you choose to continue. After changing anything in System Settings, refresh here."

    static let accessibilityDescription =
        "Required for advanced shortcut suppression and paste injection."

    static let inputMonitoringDescription =
        "Required for listening to advanced global shortcuts."

    static let strategyDescription =
        "VoicePi uses guided permission handoffs: Microphone and Speech Recognition lead into macOS permission sheets, while Accessibility and Input Monitoring are only needed for advanced shortcut handling and paste injection."

    static let standardShortcutHint =
        "Current shortcut: %@. Click the field above and press a new combination to replace it. Standard shortcuts work without Input Monitoring. Accessibility is still required for paste injection."

    static let advancedShortcutHint =
        "Current shortcut: %@. Click the field above and press a new combination to replace it. Advanced shortcuts require Input Monitoring, while Accessibility covers suppression and paste injection."

    static let standardModeShortcutHint =
        "Current mode-switch shortcut: %@. Click the field above and press a new combination to replace it. Standard shortcuts work without Input Monitoring."

    static let advancedModeShortcutHint =
        "Current mode-switch shortcut: %@. Click the field above and press a new combination to replace it. Advanced shortcuts require Input Monitoring. Accessibility lets VoicePi suppress the shortcut before it reaches the frontmost app."

    static let unsetModeShortcutHint =
        "Mode-switch shortcut is not set. Click the field above and press a combination to enable quick cycling between Disabled, Refinement, and Translate."
}

enum SettingsPresentation {
    static func selectedThemeIndex(for theme: InterfaceTheme) -> Int {
        InterfaceTheme.allCases.firstIndex(of: theme) ?? 0
    }

    static func aboutPresentation(infoDictionary: [String: Any]?) -> AboutSectionPresentation {
        AboutSectionPresentation(
            version: infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            build: infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            author: AboutProfile.author,
            websiteDisplay: AboutProfile.websiteDisplay,
            githubDisplay: AboutProfile.githubDisplay,
            xDisplay: AboutProfile.xDisplay
        )
    }

    @MainActor
    static func homeSectionPresentation(model: AppModel) -> HomeSectionPresentation {
        homeSectionPresentation(
            model: model,
            appleTranslateSupported: AppleTranslateService.isSupported
        )
    }

    @MainActor
    static func homeSectionPresentation(
        model: AppModel,
        appleTranslateSupported: Bool
    ) -> HomeSectionPresentation {
        let statusSummary: String
        let statusTone: SettingsPresentationStatusTone

        if let errorState = model.errorState {
            statusSummary = "Latest status: \(errorState.text)"
            statusTone = .error
        } else {
            statusSummary = "VoicePi is ready to transcribe with the floating overlay, clipboard restoration, and input-method-safe paste flow."
            statusTone = .secondary
        }

        let llmSummary: String
        let effectiveTranslationProvider = model.effectiveTranslationProvider(
            appleTranslateSupported: appleTranslateSupported
        )
        switch model.postProcessingMode {
        case .disabled:
            llmSummary = "Text processing: Disabled"
        case .refinement:
            let target = model.targetLanguage.recognitionDisplayName
            let templateTitle = model.resolvedPromptSelection(for: .voicePi)?.title ?? "None"
            let suffix = model.llmConfiguration.isConfigured ? "LLM configured" : "LLM not configured"
            llmSummary = "Text processing: Refinement via LLM • Target \(target) • Template \(templateTitle) • \(suffix)"
        case .translation:
            llmSummary = "Text processing: Translate via \(effectiveTranslationProvider.title) • Target \(model.targetLanguage.recognitionDisplayName)"
        }

        let shortcutHintFormat = model.activationShortcut.isRegisteredHotkeyCompatible
            ? PermissionsCopy.standardShortcutHint
            : PermissionsCopy.advancedShortcutHint
        let modeShortcutHint: String

        if model.modeCycleShortcut.isEmpty {
            modeShortcutHint = PermissionsCopy.unsetModeShortcutHint
        } else {
            let modeShortcutHintFormat = model.modeCycleShortcut.isRegisteredHotkeyCompatible
                ? PermissionsCopy.standardModeShortcutHint
                : PermissionsCopy.advancedModeShortcutHint
            modeShortcutHint = String(format: modeShortcutHintFormat, model.modeCycleShortcut.displayString)
        }

        return HomeSectionPresentation(
            shortcutSummary: "Current shortcut: \(model.activationShortcut.menuTitle)",
            modeShortcutSummary: "Mode-switch shortcut: \(model.modeCycleShortcut.menuTitle)",
            languageSummary: "Recognition language: \(model.selectedLanguage.menuTitle)",
            permissionSummary: "Permissions: Mic \(permissionPresentation(for: model.microphoneAuthorization).title), Speech \(permissionPresentation(for: model.speechAuthorization).title), Accessibility \(permissionPresentation(for: model.accessibilityAuthorization).title), Input Monitoring \(permissionPresentation(for: model.inputMonitoringAuthorization).title)",
            asrSummary: "ASR backend: \(model.asrBackend.title) • \(model.remoteASRConfiguration.isConfigured ? "Remote configured" : "Remote not configured")",
            llmSummary: llmSummary,
            shortcutHint: String(format: shortcutHintFormat, model.activationShortcut.displayString),
            modeShortcutHint: modeShortcutHint,
            statusSummary: statusSummary,
            statusTone: statusTone
        )
    }

    static func permissionPresentation(for state: AuthorizationState) -> PermissionPresentation {
        switch state {
        case .granted:
            return .init(title: "Granted", tone: .granted)
        case .denied:
            return .init(title: "Denied", tone: .denied)
        case .restricted:
            return .init(title: "Restricted", tone: .restricted)
        case .unknown:
            return .init(title: "Unknown", tone: .unknown)
        }
    }
}
