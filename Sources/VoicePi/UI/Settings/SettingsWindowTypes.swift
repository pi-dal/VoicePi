import AppKit
import Foundation

@MainActor
enum SettingsSection: Int, CaseIterable {
    case home = 0
    case permissions = 1
    case dictionary = 2
    case history = 3
    case asr = 4
    case llm = 5
    case externalProcessors = 6
    case about = 7

    static var navigationCases: [SettingsSection] {
        allCases.filter { $0 != .history }
    }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .permissions:
            return "Permissions"
        case .dictionary:
            return "Library"
        case .history:
            return "History"
        case .asr:
            return "ASR"
        case .llm:
            return "Text"
        case .externalProcessors:
            return "Processors"
        case .about:
            return "About"
        }
    }
}

enum SettingsLayoutMetrics {
    static let pageSpacing: CGFloat = 12
    static let cardPaddingHorizontal: CGFloat = 16
    static let cardPaddingVertical: CGFloat = 14
    static let compactCardPaddingVertical: CGFloat = 12
    static let sectionHeaderSpacing: CGFloat = 3
    static let formRowVerticalInset: CGFloat = 8
    static let twoColumnSpacing: CGFloat = 12
    static let compactShortcutCardSpacing: CGFloat = 6
    static let actionButtonHeight: CGFloat = 32
    static let headerHeight: CGFloat = 64
    static let navigationButtonHeight: CGFloat = 64
    static let navigationButtonMinWidth: CGFloat = 88
    static let contentMinWidth: CGFloat = 660
    static let contentMaxWidth: CGFloat = 792
    static let contentMinHeight: CGFloat = 300
    static let dictionarySidebarWidth: CGFloat = 360
    static let dictionarySearchMinWidth: CGFloat = 220
    static let updatePanelWidth: CGFloat = 436
    static let updatePanelMinHeight: CGFloat = 408
    static let updatePanelNotesHeight: CGFloat = 120
    static let updatePanelOuterInset: CGFloat = 18
    static let promptEditorOuterInset: CGFloat = 18
    static let promptEditorSectionSpacing: CGFloat = 12
    static let promptEditorFieldSpacing: CGFloat = 8
    static let promptEditorBodyMinHeight: CGFloat = 240
    static let promptEditorSidebarWidth: CGFloat = 272
}

enum AboutProfile {
    static let author = "pi-dal"
    static let websiteDisplay = "pi-dal.com"
    static let websiteURL = "https://pi-dal.com"
    static let githubDisplay = "@pi-dal"
    static let githubURL = "https://github.com/pi-dal"
    static let repositoryLinkDisplay = "VoicePi"
    static let repositoryDisplay = "VoicePi"
    static let repositoryURL = "https://github.com/pi-dal/VoicePi"
    static let footerRepositoryDisplay = "Repository"
    static let licenseDisplay = "License (MIT)"
    static let licenseURL = "https://github.com/pi-dal/VoicePi/blob/main/LICENSE"
    static let legacyCreditsNote =
        "VoicePi is a lightweight macOS dictation utility that lives in the menu bar, captures speech with a shortcut, optionally refines or translates transcripts, and pastes the final text into the active app."
    static let inspirationAuthorDisplay = "yetone"
    static let inspirationAuthorURL = "https://x.com/yetone"
    static let inspirationPostURL = "https://x.com/yetone/status/2038183163579810024"
    static let xDisplay = "@pidal20"
    static let xURL = "https://x.com/pidal20"
}

@MainActor
protocol SettingsWindowControllerDelegate: AnyObject {
    func settingsWindowControllerDidRequestStartRecording(_ controller: SettingsWindowController)
    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSave configuration: LLMConfiguration
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSelectASRBackend backend: ASRBackend
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSelect language: SupportedLanguage
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateActivationShortcut shortcut: ActivationShortcut
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateCancelShortcut shortcut: ActivationShortcut
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateModeCycleShortcut shortcut: ActivationShortcut
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdatePromptCycleShortcut shortcut: ActivationShortcut
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateProcessorShortcut shortcut: ActivationShortcut
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestTest configuration: LLMConfiguration
    ) async -> Result<String, Error>

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestRemoteASRTest configuration: RemoteASRConfiguration
    ) async -> Result<String, Error>

    func settingsWindowControllerDidRequestOpenMicrophoneSettings(_ controller: SettingsWindowController)
    func settingsWindowControllerDidRequestOpenSpeechSettings(_ controller: SettingsWindowController)
    func settingsWindowControllerDidRequestOpenAccessibilitySettings(_ controller: SettingsWindowController)
    func settingsWindowControllerDidRequestOpenInputMonitoringSettings(_ controller: SettingsWindowController)
    func settingsWindowControllerDidRequestPromptAccessibilityPermission(_ controller: SettingsWindowController)
    func settingsWindowControllerDidRequestRefreshPermissions(_ controller: SettingsWindowController) async
    func settingsWindowControllerDidRequestCheckForUpdates(_ controller: SettingsWindowController) async -> String
}
