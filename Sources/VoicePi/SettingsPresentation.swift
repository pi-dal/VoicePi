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
    let promptShortcutSummary: String
    let cancelShortcutSummary: String
    let languageSummary: String
    let permissionSummary: String
    let asrSummary: String
    let llmSummary: String
    let shortcutHint: String
    let modeShortcutHint: String
    let promptShortcutHint: String
    let cancelShortcutHint: String
    let statusSummary: String
    let statusTone: SettingsPresentationStatusTone
}

struct DictionarySectionPresentation: Equatable {
    let termCount: Int
    let suggestionCount: Int
    let summaryText: String
    let pendingReviewText: String
}

struct DictionaryTermRowPresentation: Equatable {
    let canonical: String
    let bindingSummary: String
    let tagLabel: String
    let enabledStateText: String
}

struct AboutSectionPresentation: Equatable {
    let version: String
    let build: String
    let author: String
    let websiteDisplay: String
    let githubDisplay: String
    let xDisplay: String
    let repositoryLinkDisplay: String
}

enum PermissionsCopy {
    static let permissionsSectionSubtitle =
        "Review the current macOS permissions VoicePi depends on for recording, recognition, automation, and shortcut capture."

    static let permissionsFooterNote =
        "Some permissions require a restart to take effect."

    static let permissionsHint =
        "Click a permission card to jump to the matching macOS settings pane. Use the footer action to open the broader Privacy & Security overview."

    static let accessibilityDescription =
        "Required to control system UI."

    static let inputMonitoringDescription =
        "Required to capture keystrokes."

    static let strategyDescription =
        "VoicePi uses guided permission handoffs: Microphone and Speech Recognition lead into macOS permission sheets, while Accessibility and Input Monitoring are only needed for advanced shortcut handling and paste injection."

    static let standardShortcutHint =
        "Current shortcut: %@. Click above to change it. Standard shortcuts work without Input Monitoring. Accessibility is still required for paste injection."

    static let advancedShortcutHint =
        "Current shortcut: %@. Click above to change it. Advanced shortcuts require Input Monitoring. Accessibility covers suppression and paste injection."

    static let standardModeShortcutHint =
        "Current mode-switch shortcut: %@. Click above to change it. Standard shortcuts work without Input Monitoring."

    static let advancedModeShortcutHint =
        "Current mode-switch shortcut: %@. Click above to change it. Advanced shortcuts require Input Monitoring. Accessibility lets VoicePi suppress it before it reaches the frontmost app."

    static let standardCancelShortcutHint =
        "Current cancel shortcut: %@. Click above to change it. Standard shortcuts work without Input Monitoring."

    static let advancedCancelShortcutHint =
        "Current cancel shortcut: %@. Click above to change it. Advanced shortcuts require Input Monitoring. Accessibility lets VoicePi suppress it before it reaches the frontmost app."

    static let escapeCancelShortcutHint =
        "Current cancel shortcut: %@. Click above to change it. Escape is an advanced global key. It requires Input Monitoring for listening, and Accessibility lets VoicePi suppress it before the frontmost app also handles Escape."

    static let unsetModeShortcutHint =
        "Mode-switch shortcut is not set. Click the field above and press a combination to enable quick cycling between Disabled, Refinement, and Translate."

    static let standardPromptCycleShortcutHint =
        "Current prompt-cycle shortcut: %@. Click above to change it. Standard shortcuts work without Input Monitoring."

    static let advancedPromptCycleShortcutHint =
        "Current prompt-cycle shortcut: %@. Click above to change it. Advanced shortcuts require Input Monitoring. Accessibility lets VoicePi suppress it before it reaches the frontmost app."

    static let unsetPromptCycleShortcutHint =
        "Prompt-cycle shortcut is not set. Click the field above and press a combination to enable quick prompt switching."
}

enum SettingsPresentation {
    private static let maxDisplayedBuildLength = 12

    static func selectedThemeIndex(for theme: InterfaceTheme) -> Int {
        InterfaceTheme.allCases.firstIndex(of: theme) ?? 0
    }

    static func aboutPresentation(infoDictionary: [String: Any]?) -> AboutSectionPresentation {
        AboutSectionPresentation(
            version: infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            build: displayedBuildString(from: infoDictionary?["CFBundleVersion"] as? String),
            author: AboutProfile.author,
            websiteDisplay: AboutProfile.websiteDisplay,
            githubDisplay: AboutProfile.githubDisplay,
            xDisplay: AboutProfile.xDisplay,
            repositoryLinkDisplay: AboutProfile.repositoryLinkDisplay
        )
    }

    private static func displayedBuildString(from build: String?) -> String {
        guard let build, build.isEmpty == false else {
            return "Unknown"
        }

        return String(build.prefix(maxDisplayedBuildLength))
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
        switch model.postProcessingMode {
        case .disabled:
            llmSummary = "Text processing: Disabled"
        case .refinement:
            let target = model.targetLanguage.recognitionDisplayName
            let promptTitle = model.resolvedPromptPreset().title
            switch model.refinementProvider {
            case .llm:
                let suffix = model.llmConfiguration.isConfigured ? "LLM configured" : "LLM not configured"
                llmSummary = "Text processing: Refinement via LLM • Target \(target) • Prompt \(promptTitle) • \(suffix)"
            case .externalProcessor:
                let backendTitle = model.selectedExternalProcessorEntry()?.kind.title ?? "No processor configured"
                let status = model.selectedExternalProcessorEntry()?.isEnabled == true ? "Enabled" : "Disabled"
                llmSummary = "Text processing: Processors • \(backendTitle) • Target \(target) • Prompt \(promptTitle) • \(status)"
            }
        case .translation:
            let effectiveTranslationProvider = model.effectiveTranslationProvider(
                appleTranslateSupported: appleTranslateSupported
            )
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
            modeShortcutHint = SettingsWindowSupport.formattedShortcutHint(
                format: modeShortcutHintFormat,
                shortcutDisplay: model.modeCycleShortcut.displayString
            )
        }

        let promptShortcutHint: String
        if model.promptCycleShortcut.isEmpty {
            promptShortcutHint = PermissionsCopy.unsetPromptCycleShortcutHint
        } else {
            let promptShortcutHintFormat = model.promptCycleShortcut.isRegisteredHotkeyCompatible
                ? PermissionsCopy.standardPromptCycleShortcutHint
                : PermissionsCopy.advancedPromptCycleShortcutHint
            promptShortcutHint = SettingsWindowSupport.formattedShortcutHint(
                format: promptShortcutHintFormat,
                shortcutDisplay: model.promptCycleShortcut.displayString
            )
        }
        let cancelShortcutHint = SettingsWindowSupport.cancelShortcutHintText(for: model.cancelShortcut)

        return HomeSectionPresentation(
            shortcutSummary: "Current shortcut: \(model.activationShortcut.menuTitle)",
            modeShortcutSummary: "Mode-switch shortcut: \(model.modeCycleShortcut.menuTitle)",
            promptShortcutSummary: "Prompt-cycle shortcut: \(model.promptCycleShortcut.menuTitle)",
            cancelShortcutSummary: "Cancel shortcut: \(model.cancelShortcut.menuTitle)",
            languageSummary: "Recognition language: \(model.selectedLanguage.menuTitle)",
            permissionSummary: "Permissions: Mic \(permissionPresentation(for: model.microphoneAuthorization).title), Speech \(permissionPresentation(for: model.speechAuthorization).title), Accessibility \(permissionPresentation(for: model.accessibilityAuthorization).title), Input Monitoring \(permissionPresentation(for: model.inputMonitoringAuthorization).title)",
            asrSummary: "ASR backend: \(model.asrBackend.title) • \(model.remoteASRConfiguration.isConfigured ? "Remote configured" : "Remote not configured")",
            llmSummary: llmSummary,
            shortcutHint: SettingsWindowSupport.formattedShortcutHint(
                format: shortcutHintFormat,
                shortcutDisplay: model.activationShortcut.displayString
            ),
            modeShortcutHint: modeShortcutHint,
            promptShortcutHint: promptShortcutHint,
            cancelShortcutHint: cancelShortcutHint,
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

    static func dictionarySectionPresentation(
        entries: [DictionaryEntry],
        suggestions: [DictionarySuggestion]
    ) -> DictionarySectionPresentation {
        let termCount = entries.count
        let suggestionCount = suggestions.count
        return DictionarySectionPresentation(
            termCount: termCount,
            suggestionCount: suggestionCount,
            summaryText: "Dictionary terms: \(termCount) • Suggestions: \(suggestionCount)",
            pendingReviewText: suggestionCount == 1
                ? "1 suggestion pending review."
                : "\(suggestionCount) suggestions pending review."
        )
    }

    static func dictionaryRowPresentation(entry: DictionaryEntry) -> DictionaryTermRowPresentation {
        let bindingSummary: String
        if entry.aliases.isEmpty {
            bindingSummary = "No bindings"
        } else {
            bindingSummary = entry.aliases.joined(separator: ", ")
        }

        return DictionaryTermRowPresentation(
            canonical: entry.canonical,
            bindingSummary: bindingSummary,
            tagLabel: entry.tag ?? "No tag",
            enabledStateText: entry.isEnabled ? "Enabled" : "Disabled"
        )
    }
}
