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
    let languageSummary: String
    let permissionSummary: String
    let asrSummary: String
    let llmSummary: String
    let shortcutHint: String
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
            let suffix = model.llmConfiguration.isConfigured ? "LLM configured" : "LLM not configured"
            llmSummary = "Text processing: Refinement via LLM • Target \(target) • \(suffix)"
        case .translation:
            llmSummary = "Text processing: Translate via \(effectiveTranslationProvider.title) • Target \(model.targetLanguage.recognitionDisplayName)"
        }

        return HomeSectionPresentation(
            shortcutSummary: "Current shortcut: \(model.activationShortcut.menuTitle)",
            languageSummary: "Recognition language: \(model.selectedLanguage.menuTitle)",
            permissionSummary: "Permissions: Mic \(permissionPresentation(for: model.microphoneAuthorization).title), Speech \(permissionPresentation(for: model.speechAuthorization).title), Accessibility \(permissionPresentation(for: model.accessibilityAuthorization).title)",
            asrSummary: "ASR backend: \(model.asrBackend.title) • \(model.remoteASRConfiguration.isConfigured ? "Remote configured" : "Remote not configured")",
            llmSummary: llmSummary,
            shortcutHint: "Current shortcut: \(model.activationShortcut.displayString). Click the field above and press a new combination to replace it.",
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
