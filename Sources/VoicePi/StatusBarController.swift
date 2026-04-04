import AppKit
import Foundation

@MainActor
protocol StatusBarControllerDelegate: AnyObject {
    func statusBarControllerDidRequestStartRecording(_ controller: StatusBarController)
    func statusBarControllerDidRequestStopRecording(_ controller: StatusBarController)
    func statusBarController(_ controller: StatusBarController, didSelect language: SupportedLanguage)
    func statusBarController(_ controller: StatusBarController, didSelectASRBackend backend: ASRBackend)
    func statusBarController(_ controller: StatusBarController, didSave configuration: LLMConfiguration)
    func statusBarController(_ controller: StatusBarController, didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration)
    func statusBarController(_ controller: StatusBarController, didUpdateActivationShortcut shortcut: ActivationShortcut)
    func statusBarController(_ controller: StatusBarController, didUpdateModeCycleShortcut shortcut: ActivationShortcut)
    func statusBarController(_ controller: StatusBarController, didRequestTest configuration: LLMConfiguration) async -> Result<String, Error>
    func statusBarController(_ controller: StatusBarController, didRequestRemoteASRTest configuration: RemoteASRConfiguration) async -> Result<String, Error>
    func statusBarControllerDidRequestOpenAccessibilitySettings(_ controller: StatusBarController)
    func statusBarControllerDidRequestQuit(_ controller: StatusBarController)

    func statusBarControllerDidRequestOpenMicrophoneSettings(_ controller: StatusBarController)
    func statusBarControllerDidRequestOpenSpeechSettings(_ controller: StatusBarController)
    func statusBarControllerDidRequestOpenInputMonitoringSettings(_ controller: StatusBarController)
    func statusBarControllerDidRequestPromptAccessibilityPermission(_ controller: StatusBarController)
    func statusBarControllerDidRequestRefreshPermissions(_ controller: StatusBarController) async
    func statusBarControllerDidRequestCheckForUpdates(_ controller: StatusBarController) async -> String
}

struct LanguageMenuItemPresentation: Equatable {
    let language: SupportedLanguage
    let isSelected: Bool
    let isEnabled: Bool
}

struct LanguageMenuPresentation: Equatable {
    let inputItems: [LanguageMenuItemPresentation]
    let outputItems: [LanguageMenuItemPresentation]
    let outputSummary: String
    let outputSelectionEnabled: Bool
    let effectiveOutputLanguage: SupportedLanguage

    @MainActor
    static func make(model: AppModel) -> LanguageMenuPresentation {
        let outputSelectionEnabled = model.postProcessingMode != .disabled
        let effectiveOutputLanguage = outputSelectionEnabled ? model.targetLanguage : model.selectedLanguage
        let outputItems: [LanguageMenuItemPresentation]
        let outputSummary: String

        if outputSelectionEnabled {
            outputItems = SupportedLanguage.allCases.map { language in
                LanguageMenuItemPresentation(
                    language: language,
                    isSelected: language == effectiveOutputLanguage,
                    isEnabled: true
                )
            }
            outputSummary = "Current Output: \(effectiveOutputLanguage.menuTitle)"
        } else {
            outputItems = []
            outputSummary = "Output unavailable while text processing is disabled"
        }

        return LanguageMenuPresentation(
            inputItems: SupportedLanguage.allCases.map { language in
                LanguageMenuItemPresentation(
                    language: language,
                    isSelected: language == model.selectedLanguage,
                    isEnabled: true
                )
            },
            outputItems: outputItems,
            outputSummary: outputSummary,
            outputSelectionEnabled: outputSelectionEnabled,
            effectiveOutputLanguage: effectiveOutputLanguage
        )
    }
}

struct StatusMenuPresentation: Equatable {
    let statusLine: String
    let languageLine: String
    let permissionsLine: String

    @MainActor
    static func make(
        model: AppModel,
        transientStatus: String?,
        isRecording: Bool
    ) -> StatusMenuPresentation {
        let languagePresentation = LanguageMenuPresentation.make(model: model)

        let statusText: String
        if let transientStatus, !transientStatus.isEmpty {
            statusText = compactStatusLine(transientStatus)
        } else if isRecording {
            statusText = "Recording…"
        } else if model.recordingState == .refining {
            statusText = "Refining…"
        } else {
            statusText = "Ready"
        }

        return StatusMenuPresentation(
            statusLine: statusText,
            languageLine: "Language: \(model.selectedLanguage.menuTitle) → \(languagePresentation.effectiveOutputLanguage.menuTitle)",
            permissionsLine: "Permissions: Mic \(symbol(for: model.microphoneAuthorization)) / Speech \(symbol(for: model.speechAuthorization)) / AX \(symbol(for: model.accessibilityAuthorization)) / IM \(symbol(for: model.inputMonitoringAuthorization))"
        )
    }

    private static func compactStatusLine(_ status: String) -> String {
        let normalized = status
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized {
        case AppController.shortcutMonitoringFailureMessage:
            return "Shortcut unavailable"
        case AppController.shortcutSuppressionWarningMessage:
            return "Listening only"
        default:
            break
        }

        if normalized.hasPrefix("Translation via "), normalized.contains(" failed") {
            return "Translation failed"
        }

        if normalized.contains("permission was not granted") {
            return "Permission denied"
        }

        if normalized.count > 44 {
            return String(normalized.prefix(43)) + "…"
        }

        return normalized
    }

    private static func symbol(for state: AuthorizationState) -> String {
        switch state {
        case .granted:
            return "✓"
        case .denied, .restricted:
            return "✗"
        case .unknown:
            return "…"
        }
    }
}

struct LLMSectionFeedback {
    static func message(
        mode: PostProcessingMode,
        provider: TranslationProvider,
        configuration: LLMConfiguration,
        selectedLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        appleTranslateSupported: Bool
    ) -> String {
        switch mode {
        case .disabled:
            return "Text processing is disabled. VoicePi will inject the transcript without additional refinement or translation."
        case .refinement:
            guard configuration.isConfigured else {
                return "Refinement is selected, but API Base URL, API Key, and Model are still required."
            }

            if targetLanguage == selectedLanguage {
                return "Refinement is active and will use the configured LLM provider."
            }

            return "Refinement is active. VoicePi will fold translation into the LLM prompt and target \(targetLanguage.recognitionDisplayName)."
        case .translation:
            if provider == .appleTranslate {
                return "Translation is active and defaults to Apple Translate."
            }

            guard configuration.isConfigured else {
                if appleTranslateSupported {
                    return "LLM translation is selected, but the LLM configuration is incomplete. VoicePi will fall back to Apple Translate."
                }

                return "LLM translation is selected because Apple Translate is unavailable on this macOS version, but the LLM configuration is incomplete. Translation will not work until API Base URL, API Key, and Model are provided."
            }

            return "Translation is active and will use the configured LLM provider."
        }
    }
}

@MainActor
final class StatusBarController: NSObject {
    enum AboutOverviewRow: Equatable {
        case repository
        case builtBy
        case inspiredBy
        case checkForUpdates
    }

    weak var delegate: StatusBarControllerDelegate?

    private let model: AppModel
    private let statusItem: NSStatusItem

    private var menu: NSMenu?
    private weak var languageMenu: NSMenu?
    private weak var llmMenu: NSMenu?
    private weak var statusMenuItem: NSMenuItem?
    private weak var languageStatusMenuItem: NSMenuItem?
    private weak var permissionsStatusMenuItem: NSMenuItem?
    private weak var shortcutMenuItem: NSMenuItem?
    private var inputLanguageItems: [SupportedLanguage: NSMenuItem] = [:]
    private var outputLanguageItems: [SupportedLanguage: NSMenuItem] = [:]

    private var settingsWindowController: SettingsWindowController?

    private var isRecording = false
    private var transientStatus: String?

    static let aboutOverviewRowOrder: [AboutOverviewRow] = [
        .repository,
        .builtBy,
        .inspiredBy,
        .checkForUpdates
    ]

    static let primaryMenuActionTitles = [
        "Language",
        "Text Processing",
        "Check for Updates…",
        "Settings…",
        "Quit VoicePi"
    ]

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        rebuildMenu()
    }

    func start() {
        refreshAll()
    }

    func setRecording(_ recording: Bool) {
        isRecording = recording
        refreshStatusItemAppearance()
        refreshStatusSummary()
    }

    func setTransientStatus(_ text: String?) {
        transientStatus = text
        refreshStatusSummary()
    }

    func refreshAll() {
        refreshStatusItemAppearance()
        refreshLanguageMenuState()
        refreshLLMMenuState()
        refreshStatusSummary()
        settingsWindowController?.reloadFromModel()
    }

    func showSettingsWindow(section: SettingsSection = .home) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                model: model,
                delegate: self
            )
        }

        settingsWindowController?.show(section: section)
        settingsWindowController?.window?.center()
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.toolTip = "VoicePi"
        refreshStatusItemAppearance()
    }

    private func refreshStatusItemAppearance() {
        guard let button = statusItem.button else { return }

        button.image = statusBarIconImage(isRecording: isRecording)
    }

    static func statusBarIconResourceName(isRecording: Bool) -> String {
        "AppIcon"
    }

    private func statusBarIconImage(isRecording: Bool) -> NSImage? {
        let resourceName = Self.statusBarIconResourceName(isRecording: isRecording)

        if let url = Bundle.main.url(forResource: resourceName, withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false
            return image
        }

        let fallbackSymbolName = isRecording ? "mic.circle.fill" : "waveform.circle"
        return NSImage(
            systemSymbolName: fallbackSymbolName,
            accessibilityDescription: "VoicePi"
        )
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let headerItem = NSMenuItem(title: "VoicePi", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let statusSummaryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusSummaryItem.isEnabled = false
        menu.addItem(statusSummaryItem)
        self.statusMenuItem = statusSummaryItem

        let languageSummaryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        languageSummaryItem.isEnabled = false
        menu.addItem(languageSummaryItem)
        self.languageStatusMenuItem = languageSummaryItem

        let permissionsSummaryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        permissionsSummaryItem.isEnabled = false
        menu.addItem(permissionsSummaryItem)
        self.permissionsStatusMenuItem = permissionsSummaryItem

        menu.addItem(.separator())

        let holdToTalkItem = NSMenuItem(
            title: shortcutMenuTitle(),
            action: nil,
            keyEquivalent: ""
        )
        holdToTalkItem.isEnabled = false
        menu.addItem(holdToTalkItem)
        self.shortcutMenuItem = holdToTalkItem

        menu.addItem(.separator())

        let languageRoot = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu(title: "Language")
        languageRoot.submenu = languageMenu
        menu.addItem(languageRoot)
        self.languageMenu = languageMenu
        rebuildLanguageMenu()

        let llmRoot = NSMenuItem(title: "Text Processing", action: nil, keyEquivalent: "")
        let llmMenu = NSMenu(title: "Text Processing")
        llmRoot.submenu = llmMenu
        menu.addItem(llmRoot)
        self.llmMenu = llmMenu
        rebuildLLMMenu()

        menu.addItem(.separator())

        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdatesFromMenu),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self
        menu.addItem(checkForUpdatesItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit VoicePi",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        self.menu = menu
        self.statusItem.button?.menu = menu
        self.statusItem.menu = menu

        refreshAll()
    }

    private func rebuildLanguageMenu() {
        guard let languageMenu else { return }
        let presentation = LanguageMenuPresentation.make(model: model)

        languageMenu.removeAllItems()
        inputLanguageItems.removeAll()
        outputLanguageItems.removeAll()

        let inputRoot = NSMenuItem(title: "Input", action: nil, keyEquivalent: "")
        let inputSubmenu = NSMenu(title: "Input")
        inputRoot.submenu = inputSubmenu
        languageMenu.addItem(inputRoot)

        for itemPresentation in presentation.inputItems {
            let item = NSMenuItem(
                title: itemPresentation.language.menuTitle,
                action: #selector(selectInputLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = itemPresentation.language.rawValue
            item.state = itemPresentation.isSelected ? .on : .off
            item.isEnabled = itemPresentation.isEnabled
            inputSubmenu.addItem(item)
            inputLanguageItems[itemPresentation.language] = item
        }

        languageMenu.addItem(.separator())

        let outputRoot = NSMenuItem(title: "Output", action: nil, keyEquivalent: "")
        let outputSubmenu = NSMenu(title: "Output")
        outputRoot.submenu = outputSubmenu
        languageMenu.addItem(outputRoot)

        let outputSummaryItem = NSMenuItem(title: presentation.outputSummary, action: nil, keyEquivalent: "")
        outputSummaryItem.isEnabled = false
        outputSubmenu.addItem(outputSummaryItem)

        if !presentation.outputItems.isEmpty {
            outputSubmenu.addItem(.separator())

            for itemPresentation in presentation.outputItems {
                let item = NSMenuItem(
                    title: itemPresentation.language.menuTitle,
                    action: #selector(selectOutputLanguage(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = itemPresentation.language.rawValue
                item.state = itemPresentation.isSelected ? .on : .off
                item.isEnabled = itemPresentation.isEnabled
                outputSubmenu.addItem(item)
                outputLanguageItems[itemPresentation.language] = item
            }
        }
    }

    private func rebuildLLMMenu() {
        guard let llmMenu else { return }

        llmMenu.removeAllItems()

        for mode in PostProcessingMode.allCases {
            let item = NSMenuItem(
                title: mode.title,
                action: #selector(selectPostProcessingModeFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == model.postProcessingMode ? .on : .off
            llmMenu.addItem(item)
        }

        llmMenu.addItem(.separator())

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openLLMSettings),
            keyEquivalent: ""
        )
        settings.target = self
        llmMenu.addItem(settings)

        let providerSummary = NSMenuItem(
            title: llmProviderSummaryText(),
            action: nil,
            keyEquivalent: ""
        )
        providerSummary.isEnabled = false
        llmMenu.addItem(providerSummary)

        let targetSummary = NSMenuItem(
            title: llmTargetSummaryText(),
            action: nil,
            keyEquivalent: ""
        )
        targetSummary.isEnabled = false
        llmMenu.addItem(targetSummary)

        let endpointSummary = NSMenuItem(
            title: llmEndpointSummaryText(),
            action: nil,
            keyEquivalent: ""
        )
        endpointSummary.isEnabled = false
        llmMenu.addItem(endpointSummary)

        let modelSummary = NSMenuItem(
            title: llmModelSummaryText(),
            action: nil,
            keyEquivalent: ""
        )
        modelSummary.isEnabled = false
        llmMenu.addItem(modelSummary)
    }

    private func refreshLanguageMenuState() {
        if languageMenu == nil {
            rebuildLanguageMenu()
            return
        }
        rebuildLanguageMenu()
    }

    private func refreshLLMMenuState() {
        rebuildLLMMenu()
    }

    private func shortcutMenuTitle() -> String {
        "Press \(model.activationShortcut.menuTitle) to Start / Press Again to Paste"
    }

    private func refreshStatusSummary() {
        let presentation = StatusMenuPresentation.make(
            model: model,
            transientStatus: transientStatus,
            isRecording: isRecording
        )

        statusMenuItem?.title = presentation.statusLine
        languageStatusMenuItem?.title = presentation.languageLine
        permissionsStatusMenuItem?.title = presentation.permissionsLine
    }

    private func llmEndpointSummaryText() -> String {
        let text = model.llmConfiguration.trimmedBaseURL
        return text.isEmpty ? "API Base URL: Not configured" : "API Base URL: \(text)"
    }

    private func llmModelSummaryText() -> String {
        let text = model.llmConfiguration.trimmedModel
        return text.isEmpty ? "Model: Not configured" : "Model: \(text)"
    }

    private func llmProviderSummaryText() -> String {
        switch model.postProcessingMode {
        case .disabled:
            return "Provider: Not in use"
        case .refinement:
            return "Provider: LLM"
        case .translation:
            return "Provider: \(model.effectiveTranslationProvider(appleTranslateSupported: AppleTranslateService.isSupported).title)"
        }
    }

    private func llmTargetSummaryText() -> String {
        "Target Language: \(model.targetLanguage.menuTitle)"
    }

    private func symbol(for state: AuthorizationState) -> String {
        switch state {
        case .granted:
            return "✓"
        case .denied, .restricted:
            return "✗"
        case .unknown:
            return "…"
        }
    }

    @objc
    private func selectInputLanguage(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let language = SupportedLanguage(rawValue: rawValue)
        else {
            return
        }

        model.selectedLanguage = language
        refreshLanguageMenuState()
        refreshStatusSummary()
        settingsWindowController?.reloadFromModel()
        delegate?.statusBarController(self, didSelect: language)
    }

    @objc
    private func selectOutputLanguage(_ sender: NSMenuItem) {
        guard model.postProcessingMode != .disabled else { return }
        guard
            let rawValue = sender.representedObject as? String,
            let language = SupportedLanguage(rawValue: rawValue)
        else {
            return
        }

        model.setTargetLanguage(language)
        refreshLanguageMenuState()
        refreshLLMMenuState()
        refreshStatusSummary()
        settingsWindowController?.reloadFromModel()
    }

    @objc
    private func selectPostProcessingModeFromMenu(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let mode = PostProcessingMode(rawValue: rawValue)
        else {
            return
        }

        model.setPostProcessingMode(mode)
        refreshLanguageMenuState()
        refreshLLMMenuState()
        refreshStatusSummary()
        settingsWindowController?.reloadFromModel()
    }

    @objc
    private func openSettings() {
        showSettingsWindow(section: .home)
    }

    @objc
    private func openLLMSettings() {
        showSettingsWindow(section: .llm)
    }

    @objc
    private func checkForUpdatesFromMenu() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let status = await delegate?.statusBarControllerDidRequestCheckForUpdates(self)
                ?? "No update handler is available."
            self.settingsWindowController?.setAboutUpdateStatus(status)
            self.settingsWindowController?.reloadFromModel()
            self.setTransientStatus(status)
        }
    }

    @objc
    private func quitApp() {
        delegate?.statusBarControllerDidRequestQuit(self)
    }
}

@MainActor
enum SettingsSection: Int, CaseIterable {
    case home = 0
    case permissions = 1
    case asr = 2
    case llm = 3
    case about = 4

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .permissions:
            return "Permissions"
        case .asr:
            return "ASR"
        case .llm:
            return "Text"
        case .about:
            return "About"
        }
    }
}

enum SettingsLayoutMetrics {
    static let pageSpacing: CGFloat = 12
    static let cardPaddingHorizontal: CGFloat = 18
    static let cardPaddingVertical: CGFloat = 16
    static let sectionHeaderSpacing: CGFloat = 4
    static let formRowVerticalInset: CGFloat = 9
    static let twoColumnSpacing: CGFloat = 12
    static let actionButtonHeight: CGFloat = 32
    static let navigationButtonHeight: CGFloat = 34
    static let navigationButtonMinWidth: CGFloat = 88
    static let contentMinWidth: CGFloat = 660
    static let contentMaxWidth: CGFloat = 792
    static let contentMinHeight: CGFloat = 360
}

enum AboutProfile {
    static let author = "pi-dal"
    static let websiteDisplay = "pi-dal.com"
    static let websiteURL = "https://pi-dal.com"
    static let githubDisplay = "@pi-dal"
    static let githubURL = "https://github.com/pi-dal"
    static let repositoryDisplay = "VoicePi"
    static let repositoryURL = "https://github.com/pi-dal/VoicePi"
    static let inspirationAuthorDisplay = "yetone"
    static let inspirationAuthorURL = "https://x.com/yetone"
    static let inspirationPostURL = "https://x.com/yetone/status/2038183163579810024"
    static let xDisplay = "@pidal20"
    static let xURL = "https://x.com/pidal20"
}

@MainActor
protocol SettingsWindowControllerDelegate: AnyObject {
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
        didUpdateActivationShortcut shortcut: ActivationShortcut
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateModeCycleShortcut shortcut: ActivationShortcut
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

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    weak var delegate: SettingsWindowControllerDelegate?

    private let model: AppModel

    private let contentContainer = NSView()

    private let homeView = NSView()
    private let permissionsView = NSView()
    private let asrView = NSView()
    private let llmView = NSView()
    private let aboutView = NSView()

    private let homeSummaryLabel = NSTextField(labelWithString: "")
    private let homePermissionSummaryLabel = NSTextField(labelWithString: "")
    private let homeLanguageLabel = NSTextField(labelWithString: "")
    private let homeShortcutLabel = NSTextField(labelWithString: "")
    private let homeModeShortcutLabel = NSTextField(labelWithString: "")
    private let homeASRLabel = NSTextField(labelWithString: "")
    private let homeLLMLabel = NSTextField(labelWithString: "")

    private let shortcutRecorderField = ShortcutRecorderField()
    private let shortcutHintLabel = NSTextField(labelWithString: "")
    private let modeShortcutRecorderField = ShortcutRecorderField()
    private let modeShortcutHintLabel = NSTextField(labelWithString: "")

    private let microphoneStatusLabel = NSTextField(labelWithString: "")
    private let speechStatusLabel = NSTextField(labelWithString: "")
    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let inputMonitoringStatusLabel = NSTextField(labelWithString: "")
    private let permissionsHintLabel = NSTextField(labelWithString: "")
    private let aboutVersionLabel = NSTextField(labelWithString: "")
    private let aboutBuildLabel = NSTextField(labelWithString: "")
    private let aboutAuthorLabel = NSTextField(labelWithString: "")
    private let aboutWebsiteLabel = NSTextField(labelWithString: "")
    private let aboutGitHubLabel = NSTextField(labelWithString: "")
    private let aboutXLabel = NSTextField(labelWithString: "")
    private lazy var aboutCheckForUpdatesButton = StyledSettingsButton(
        title: "Check for Updates",
        role: .primary,
        target: self,
        action: #selector(checkForUpdates)
    )
    private let aboutUpdateStatusLabel = NSTextField(labelWithString: "")
    private let interfaceThemeControl = NSSegmentedControl()

    private let baseURLField = NSTextField(string: "")
    private let apiKeyField = NSSecureTextField(string: "")
    private let modelField = NSTextField(string: "")
    private let defaultPromptTemplatePopup = ThemedPopUpButton()
    private let appPromptOverridePopup = ThemedPopUpButton()
    private let promptOptionRowsStack = NSStackView()
    private let resolvedPromptSummaryLabel = NSTextField(labelWithString: "")
    private lazy var resolvedPromptPreviewButton = StyledSettingsButton(
        title: "Preview Resolved Prompt",
        role: .secondary,
        target: self,
        action: #selector(previewResolvedPrompt)
    )
    private let asrBackendPopup = ThemedPopUpButton()
    private let asrBaseURLField = NSTextField(string: "")
    private let asrAPIKeyField = NSSecureTextField(string: "")
    private let asrModelField = NSTextField(string: "")
    private let asrPromptField = NSTextField(string: "")
    private let postProcessingModePopup = ThemedPopUpButton()
    private let translationProviderPopup = ThemedPopUpButton()
    private let targetLanguagePopup = ThemedPopUpButton()
    private let asrStatusView = ConnectionFeedbackView()
    private let llmStatusView = ConnectionFeedbackView()

    private let asrTestButton = NSButton(title: "Test Connection", target: nil, action: nil)
    private let asrSaveButton = NSButton(title: "Save", target: nil, action: nil)
    private let testButton = NSButton(title: "Test Connection", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)

    private var sectionButtons: [SettingsSection: NSButton] = [:]
    private var currentSection: SettingsSection = .home
    private var aboutUpdateStatusText = "Use Homebrew for install and upgrades."
    private var promptLibrary: PromptLibrary?
    private var promptPolicy: PromptAppPolicy?
    private var promptLibraryLoadError: String?
    private var optionPopupsByGroupID: [String: NSPopUpButton] = [:]
    private var promptTemplateFormState = PromptTemplateFormState(
        globalSelection: .none,
        appSelection: .inherit
    )
    private var promptSelectionDrafts: [PromptTemplateScope: PromptSelection] = [:]

    init(model: AppModel, delegate: SettingsWindowControllerDelegate?) {
        self.model = model
        self.delegate = delegate

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 872, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "VoicePi Settings"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 780, height: 520)
        window.titlebarAppearsTransparent = true
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .preference
        }
        window.center()

        super.init(window: window)
        window.delegate = self

        buildUI()
        applyThemeAppearance()
        reloadFromModel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        reloadFromModel()
    }

    func show(section: SettingsSection) {
        showWindow(nil)
        selectSection(section)
    }

    func setAboutUpdateStatus(_ text: String) {
        aboutUpdateStatusText = text
        aboutUpdateStatusLabel.stringValue = text
    }

    func reloadFromModel() {
        applyThemeAppearance()
        loadCurrentValues()
        refreshPermissionLabels()
        refreshHomeSection()
        refreshASRSection()
        refreshLLMSection()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        model.closeSettings()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = pageBackgroundColor.cgColor

        let titleLabel = NSTextField(labelWithString: "VoicePi Settings")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        let subtitleLabel = NSTextField(labelWithString: "A cleaner control center for permissions, dictation, translation, and LLM processing.")
        subtitleLabel.font = .systemFont(ofSize: 12.5)
        subtitleLabel.textColor = .secondaryLabelColor

        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.orientation = .vertical
        titleStack.spacing = 4
        titleStack.alignment = .leading

        let navigation = makeSectionNavigation()
        navigation.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = NSStackView(views: [titleStack, NSView(), navigation])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 14
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(headerRow)
        contentView.addSubview(separator)
        contentView.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headerRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            headerRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 14),

            contentContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            contentContainer.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            contentContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            contentContainer.widthAnchor.constraint(lessThanOrEqualToConstant: SettingsLayoutMetrics.contentMaxWidth),
            contentContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: SettingsLayoutMetrics.contentMinWidth),
            contentContainer.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 18),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -22),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsLayoutMetrics.contentMinHeight)
        ])

        buildHomeView()
        buildPermissionsView()
        buildASRView()
        buildLLMView()
        buildAboutView()

        contentContainer.addSubview(homeView)
        contentContainer.addSubview(permissionsView)
        contentContainer.addSubview(asrView)
        contentContainer.addSubview(llmView)
        contentContainer.addSubview(aboutView)

        [homeView, permissionsView, asrView, llmView, aboutView].forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
            ])
        }

        selectSection(.home)
    }

    private func buildHomeView() {
        let contentStack = makePageStack()

        homeLanguageLabel.font = .systemFont(ofSize: 13)
        homeLanguageLabel.alignment = .left
        homePermissionSummaryLabel.font = .systemFont(ofSize: 13)
        homePermissionSummaryLabel.alignment = .left
        homePermissionSummaryLabel.lineBreakMode = .byWordWrapping
        homePermissionSummaryLabel.maximumNumberOfLines = 0
        homeShortcutLabel.font = .systemFont(ofSize: 13)
        homeShortcutLabel.alignment = .left
        homeModeShortcutLabel.font = .systemFont(ofSize: 13)
        homeModeShortcutLabel.alignment = .left
        homeASRLabel.font = .systemFont(ofSize: 13)
        homeASRLabel.alignment = .left
        homeLLMLabel.font = .systemFont(ofSize: 13)
        homeLLMLabel.alignment = .left
        homeSummaryLabel.font = .systemFont(ofSize: 12.5)
        homeSummaryLabel.textColor = .secondaryLabelColor
        homeSummaryLabel.alignment = .left
        homeSummaryLabel.lineBreakMode = .byWordWrapping
        homeSummaryLabel.maximumNumberOfLines = 0

        shortcutRecorderField.target = self
        shortcutRecorderField.action = #selector(shortcutRecorderChanged(_:))
        shortcutHintLabel.font = .systemFont(ofSize: 12)
        shortcutHintLabel.textColor = .secondaryLabelColor
        shortcutHintLabel.alignment = .left
        shortcutHintLabel.lineBreakMode = .byWordWrapping
        shortcutHintLabel.maximumNumberOfLines = 0
        shortcutHintLabel.stringValue = "Click the shortcut field, then press the combination you want to use. Standard shortcuts work without Input Monitoring. Advanced shortcuts use Input Monitoring. Accessibility is still required for paste injection and advanced shortcut suppression."

        modeShortcutRecorderField.target = self
        modeShortcutRecorderField.action = #selector(modeShortcutRecorderChanged(_:))
        modeShortcutHintLabel.font = .systemFont(ofSize: 12)
        modeShortcutHintLabel.textColor = .secondaryLabelColor
        modeShortcutHintLabel.alignment = .left
        modeShortcutHintLabel.lineBreakMode = .byWordWrapping
        modeShortcutHintLabel.maximumNumberOfLines = 0
        modeShortcutHintLabel.stringValue = "Click the shortcut field, then press the combination you want to use for quick mode switching."

        configureAppearanceControl()

        let shortcutControl = NSStackView(views: [shortcutRecorderField, shortcutHintLabel])
        shortcutControl.orientation = .vertical
        shortcutControl.spacing = 8
        shortcutControl.alignment = .leading

        let modeShortcutControl = NSStackView(views: [modeShortcutRecorderField, modeShortcutHintLabel])
        modeShortcutControl.orientation = .vertical
        modeShortcutControl.spacing = 8
        modeShortcutControl.alignment = .leading

        let overviewSection = makeGroupedSection(rows: [
            makePreferenceRow(title: "Activation Shortcut", control: shortcutControl),
            makePreferenceRow(title: "Mode Switch Shortcut", control: modeShortcutControl),
            makePreferenceRow(title: "Appearance", control: interfaceThemeControl),
            makePreferenceRow(title: "Recognition Language", control: homeLanguageLabel),
            makePreferenceRow(title: "Mode Switching", control: homeModeShortcutLabel),
            makePreferenceRow(title: "Permissions", control: homePermissionSummaryLabel),
            makePreferenceRow(title: "ASR", control: homeASRLabel),
            makePreferenceRow(title: "Text Processing", control: homeLLMLabel)
        ])

        let leftStack = NSStackView(views: [
            makeFeatureHeader(
                icon: "waveform.and.mic",
                eyebrow: "General",
                title: "A tighter control center for dictation, translation, and post-processing.",
                description: "VoicePi stays in the menu bar, lets you keep a dedicated record shortcut, and can also cycle text-processing modes from a separate global shortcut."
            ),
            overviewSection,
            homeSummaryLabel
        ])
        leftStack.orientation = .vertical
        leftStack.spacing = SettingsLayoutMetrics.pageSpacing
        leftStack.alignment = .leading

        let statusRail = NSStackView(views: [
            makeFeatureCard(
                icon: "keyboard",
                title: "Trigger",
                description: "Standard shortcuts work without Input Monitoring. Advanced shortcuts use Input Monitoring, and Accessibility handles advanced suppression plus final paste injection."
            ),
            makeFeatureCard(
                icon: "sparkles.rectangle.stack",
                title: "Flow",
                description: "Keep ASR local with Apple Speech or switch to a remote backend, then optionally refine or translate the final transcript."
            ),
            makeActionCard(
                title: "Made With Love By pi-dal",
                description: "VoicePi is an open-source dictation utility built to feel compact, quiet, and intentional instead of form-heavy.",
                actions: [
                    makePrimaryActionButton(title: "View Repo", action: #selector(openRepository)),
                    makeSecondaryActionButton(title: "About VoicePi", action: #selector(openAboutSection))
                ],
                verticalActions: true
            )
        ])
        statusRail.orientation = .vertical
        statusRail.spacing = SettingsLayoutMetrics.pageSpacing
        statusRail.alignment = .leading
        statusRail.translatesAutoresizingMaskIntoConstraints = false
        statusRail.widthAnchor.constraint(equalToConstant: 208).isActive = true

        contentStack.addArrangedSubview(makeTwoColumnSection(left: leftStack, right: statusRail, leftPriority: 0.68))

        homeView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: homeView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: homeView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: homeView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: homeView.bottomAnchor)
        ])
    }

    private func buildPermissionsView() {
        let contentStack = makePageStack()

        permissionsHintLabel.font = .systemFont(ofSize: 12.5)
        permissionsHintLabel.textColor = .secondaryLabelColor
        permissionsHintLabel.alignment = .left
        permissionsHintLabel.lineBreakMode = .byWordWrapping
        permissionsHintLabel.maximumNumberOfLines = 0
        permissionsHintLabel.stringValue = PermissionsCopy.permissionsHint

        microphoneStatusLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        microphoneStatusLabel.alignment = .center

        speechStatusLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        speechStatusLabel.alignment = .center

        accessibilityStatusLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        accessibilityStatusLabel.alignment = .center

        inputMonitoringStatusLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        inputMonitoringStatusLabel.alignment = .center

        let permissionGrid = makeTwoColumnGrid([
            makePermissionCard(
                icon: "mic.fill",
                title: "Microphone",
                description: "Required for capturing your voice while you hold the shortcut.",
                statusLabel: microphoneStatusLabel,
                primaryButton: makePrimaryActionButton(title: "Open Settings", action: #selector(openMicrophoneSettings)),
                secondaryButtons: []
            ),
            makePermissionCard(
                icon: "waveform",
                title: "Speech Recognition",
                description: "Required for on-device and Apple speech transcription services.",
                statusLabel: speechStatusLabel,
                primaryButton: makePrimaryActionButton(title: "Open Settings", action: #selector(openSpeechSettings)),
                secondaryButtons: []
            ),
            makePermissionCard(
                icon: "figure.wave",
                title: "Accessibility",
                description: PermissionsCopy.accessibilityDescription,
                statusLabel: accessibilityStatusLabel,
                primaryButton: makePrimaryActionButton(title: "Open Settings", action: #selector(openAccessibilitySettingsFromSettings)),
                secondaryButtons: []
            ),
            makePermissionCard(
                icon: "slider.horizontal.3",
                title: "Input Monitoring",
                description: PermissionsCopy.inputMonitoringDescription,
                statusLabel: inputMonitoringStatusLabel,
                primaryButton: makePrimaryActionButton(title: "Open Settings", action: #selector(openInputMonitoringSettings)),
                secondaryButtons: []
            )
        ])

        contentStack.addArrangedSubview(makeSectionHeader(title: "Permissions", subtitle: PermissionsCopy.permissionsSectionSubtitle))
        contentStack.addArrangedSubview(permissionsHintLabel)
        contentStack.addArrangedSubview(permissionGrid)
        contentStack.addArrangedSubview(makeActionCard(
            title: "Permission Strategy",
            description: PermissionsCopy.strategyDescription,
            actions: [
                makePrimaryActionButton(title: "Refresh", action: #selector(refreshPermissions))
            ]
        ))
        contentStack.setCustomSpacing(20, after: permissionGrid)

        permissionsView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: permissionsView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: permissionsView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: permissionsView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: permissionsView.bottomAnchor)
        ])
    }

    private func buildASRView() {
        let contentStack = makePageStack()

        asrBackendPopup.removeAllItems()
        asrBackendPopup.addItems(withTitles: ASRBackend.allCases.map(\.title))
        asrBackendPopup.target = self
        asrBackendPopup.action = #selector(asrBackendChanged(_:))

        asrBaseURLField.placeholderString = "https://api.example.com/v1"
        asrAPIKeyField.placeholderString = "sk-..."
        asrModelField.placeholderString = "gpt-4o-mini-transcribe"
        asrPromptField.placeholderString = "Optional hint for terminology or context"

        asrTestButton.target = self
        asrTestButton.action = #selector(testRemoteASRConfiguration)

        asrSaveButton.target = self
        asrSaveButton.action = #selector(saveRemoteASRConfiguration)
        asrSaveButton.keyEquivalent = "\r"

        let configurationSection = makeGroupedSection(rows: [
            makePreferenceRow(title: "Backend", control: asrBackendPopup),
            makePreferenceRow(title: "API Base URL", control: asrBaseURLField),
            makePreferenceRow(title: "API Key", control: asrAPIKeyField),
            makePreferenceRow(title: "Model", control: asrModelField),
            makePreferenceRow(title: "Prompt", control: asrPromptField)
        ])

        let buttons = makeButtonGroup([
            makeSecondaryActionButton(title: "Test Connection", action: #selector(testRemoteASRConfiguration)),
            makePrimaryActionButton(title: "Save", action: #selector(saveRemoteASRConfiguration))
        ])

        contentStack.addArrangedSubview(makeSectionHeader(title: "ASR", subtitle: "Choose between built-in Apple Speech and a remote OpenAI-compatible transcription model."))
        contentStack.addArrangedSubview(makeBodyLabel("Use the remote backend when you want stronger large-model transcription quality. VoicePi will record locally, upload the captured audio after release, then inject the returned transcript."))
        contentStack.addArrangedSubview(configurationSection)
        contentStack.addArrangedSubview(buttons)
        contentStack.addArrangedSubview(asrStatusView)

        asrView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: asrView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: asrView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: asrView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: asrView.bottomAnchor),

            asrBaseURLField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            asrAPIKeyField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            asrModelField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            asrPromptField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
    }

    private func buildLLMView() {
        let contentStack = makePageStack()

        baseURLField.placeholderString = "https://api.example.com/v1"
        apiKeyField.placeholderString = "sk-..."
        modelField.placeholderString = "gpt-4o-mini"
        configurePostProcessingPopups()
        configurePromptTemplateControls()

        testButton.target = self
        testButton.action = #selector(testConfiguration)

        saveButton.target = self
        saveButton.action = #selector(saveConfiguration)
        saveButton.keyEquivalent = "\r"

        let resolvedPromptControl = NSStackView(views: [resolvedPromptSummaryLabel, resolvedPromptPreviewButton])
        resolvedPromptControl.orientation = .vertical
        resolvedPromptControl.alignment = .leading
        resolvedPromptControl.spacing = 8

        let configurationSection = makeGroupedSection(rows: [
            makePreferenceRow(title: "Mode", control: postProcessingModePopup),
            makePreferenceRow(title: "Translate Provider", control: translationProviderPopup),
            makePreferenceRow(title: "Target Language", control: targetLanguagePopup),
            makePreferenceRow(title: "API Base URL", control: baseURLField),
            makePreferenceRow(title: "API Key", control: apiKeyField),
            makePreferenceRow(title: "Model", control: modelField),
            makePreferenceRow(title: "Default Prompt Template", control: defaultPromptTemplatePopup),
            makePreferenceRow(title: "VoicePi Override", control: appPromptOverridePopup),
            makePreferenceRow(title: "Template Options", control: promptOptionRowsStack),
            makePreferenceRow(title: "Resolved Prompt", control: resolvedPromptControl)
        ])

        let buttons = makeButtonGroup([
            makeSecondaryActionButton(title: "Test Connection", action: #selector(testConfiguration)),
            makePrimaryActionButton(title: "Save", action: #selector(saveConfiguration))
        ])

        contentStack.addArrangedSubview(makeSectionHeader(title: "Text Processing", subtitle: "Choose between no processing, conservative LLM refinement, or explicit translation."))
        contentStack.addArrangedSubview(makeBodyLabel("Refinement always uses the LLM provider. Translation defaults to Apple Translate, and target-language output is folded into the LLM prompt whenever refinement mode is active."))
        contentStack.addArrangedSubview(makeBodyLabel("Prompt templates control only the configurable middle section. Core ASR guardrails and language output instructions remain code-controlled."))
        contentStack.addArrangedSubview(configurationSection)
        contentStack.addArrangedSubview(buttons)
        contentStack.addArrangedSubview(llmStatusView)

        llmView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: llmView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: llmView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: llmView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: llmView.bottomAnchor),

            postProcessingModePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            translationProviderPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            targetLanguagePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            baseURLField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            apiKeyField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            modelField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            defaultPromptTemplatePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            appPromptOverridePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            promptOptionRowsStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
    }

    private func buildAboutView() {
        let contentStack = makePageStack()

        aboutVersionLabel.font = .systemFont(ofSize: 13)
        aboutVersionLabel.alignment = .left
        aboutBuildLabel.font = .systemFont(ofSize: 13)
        aboutBuildLabel.alignment = .left
        aboutAuthorLabel.font = .systemFont(ofSize: 13)
        aboutAuthorLabel.alignment = .left
        aboutWebsiteLabel.font = .systemFont(ofSize: 13)
        aboutWebsiteLabel.alignment = .left
        aboutWebsiteLabel.lineBreakMode = .byTruncatingTail
        aboutGitHubLabel.font = .systemFont(ofSize: 13)
        aboutGitHubLabel.alignment = .left
        aboutGitHubLabel.lineBreakMode = .byTruncatingTail
        aboutXLabel.font = .systemFont(ofSize: 13)
        aboutXLabel.alignment = .left
        aboutXLabel.lineBreakMode = .byTruncatingTail
        aboutUpdateStatusLabel.font = .systemFont(ofSize: 12)
        aboutUpdateStatusLabel.alignment = .left
        aboutUpdateStatusLabel.textColor = .secondaryLabelColor
        aboutUpdateStatusLabel.lineBreakMode = .byWordWrapping
        aboutUpdateStatusLabel.maximumNumberOfLines = 4
        aboutCheckForUpdatesButton.heightAnchor.constraint(
            equalToConstant: SettingsLayoutMetrics.actionButtonHeight
        ).isActive = true

        let versionSection = makeGroupedSection(customViews: [
            makeAboutMetaRow(title: "Version", valueView: aboutVersionLabel),
            makeAboutMetaRow(title: "Build", valueView: aboutBuildLabel),
            makeAboutMetaRow(title: "Author", valueView: aboutAuthorLabel),
            makeAboutLinkRow(
                title: "Website",
                valueView: aboutWebsiteLabel,
                buttonTitle: "Open",
                action: #selector(openPersonalWebsite)
            ),
            makeAboutLinkRow(
                title: "GitHub",
                valueView: aboutGitHubLabel,
                buttonTitle: "Open",
                action: #selector(openGitHubProfile)
            ),
            makeAboutLinkRow(
                title: "X",
                valueView: aboutXLabel,
                buttonTitle: "Open",
                action: #selector(openXProfile)
            )
        ])
        versionSection.translatesAutoresizingMaskIntoConstraints = false
        versionSection.widthAnchor.constraint(greaterThanOrEqualToConstant: 188).isActive = true
        versionSection.setContentHuggingPriority(.required, for: .horizontal)
        versionSection.setContentCompressionResistancePriority(.required, for: .horizontal)

        let overviewCard = makeAboutOverviewCard(
            title: "VoicePi",
            description: "VoicePi is a lightweight macOS dictation utility that lives in the menu bar, captures speech with a shortcut, optionally refines or translates transcripts, and pastes the final text into the active app."
        )

        let capabilitiesCard = makeFeatureCard(
            icon: "text.badge.checkmark",
            title: "Project Focus",
            description: "Fast dictation, conservative transcript cleanup, safe paste injection, and a compact settings experience that feels closer to Raycast than a generic form."
        )

        contentStack.addArrangedSubview(makeSectionHeader(title: "About", subtitle: "Version info and a concise overview of what VoicePi does."))
        contentStack.addArrangedSubview(makeTwoColumnSection(
            left: makeVerticalStack([overviewCard, capabilitiesCard], spacing: 12),
            right: versionSection,
            leftPriority: 0.66
        ))

        aboutView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: aboutView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: aboutView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: aboutView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: aboutView.bottomAnchor)
        ])
    }

    private func loadCurrentValues() {
        if let index = ASRBackend.allCases.firstIndex(of: model.asrBackend) {
            asrBackendPopup.selectItem(at: index)
        }
        asrBaseURLField.stringValue = model.remoteASRConfiguration.baseURL
        asrAPIKeyField.stringValue = model.remoteASRConfiguration.apiKey
        asrModelField.stringValue = model.remoteASRConfiguration.model
        asrPromptField.stringValue = model.remoteASRConfiguration.prompt
        baseURLField.stringValue = model.llmConfiguration.baseURL
        apiKeyField.stringValue = model.llmConfiguration.apiKey
        modelField.stringValue = model.llmConfiguration.model
        selectPopupItem(in: postProcessingModePopup, matching: model.postProcessingMode.rawValue)
        selectPopupItem(
            in: translationProviderPopup,
            matching: TranslationProvider.displayProvider(
                mode: model.postProcessingMode,
                storedProvider: model.translationProvider,
                appleTranslateSupported: appleTranslateSupported
            ).rawValue
        )
        selectPopupItem(in: targetLanguagePopup, matching: model.targetLanguage.rawValue)
        loadPromptTemplateSelections()

        if !shortcutRecorderField.isRecordingShortcut {
            shortcutRecorderField.shortcut = model.activationShortcut
        }
        if !modeShortcutRecorderField.isRecordingShortcut {
            modeShortcutRecorderField.shortcut = model.modeCycleShortcut
        }

        interfaceThemeControl.selectedSegment = SettingsPresentation.selectedThemeIndex(for: model.interfaceTheme)

        let aboutPresentation = SettingsPresentation.aboutPresentation(infoDictionary: Bundle.main.infoDictionary)
        aboutVersionLabel.stringValue = aboutPresentation.version
        aboutBuildLabel.stringValue = aboutPresentation.build
        aboutAuthorLabel.stringValue = aboutPresentation.author
        aboutWebsiteLabel.stringValue = aboutPresentation.websiteDisplay
        aboutGitHubLabel.stringValue = aboutPresentation.githubDisplay
        aboutXLabel.stringValue = aboutPresentation.xDisplay
        aboutUpdateStatusLabel.stringValue = aboutUpdateStatusText
    }

    private func refreshHomeSection() {
        let presentation = SettingsPresentation.homeSectionPresentation(model: model)
        homeShortcutLabel.stringValue = presentation.shortcutSummary
        homeModeShortcutLabel.stringValue = presentation.modeShortcutSummary
        homeLanguageLabel.stringValue = presentation.languageSummary
        homePermissionSummaryLabel.stringValue = presentation.permissionSummary
        homeASRLabel.stringValue = presentation.asrSummary
        homeLLMLabel.stringValue = presentation.llmSummary
        shortcutHintLabel.stringValue = presentation.shortcutHint
        modeShortcutHintLabel.stringValue = presentation.modeShortcutHint
        homeSummaryLabel.stringValue = presentation.statusSummary
        homeSummaryLabel.textColor = presentation.statusTone == .error ? .systemRed : .secondaryLabelColor
    }

    private func refreshASRSection() {
        let configuration = currentRemoteASRConfigurationFromFields()
        let isRemoteBackend = currentSelectedASRBackend() == .remoteOpenAICompatible

        asrBaseURLField.isEnabled = isRemoteBackend
        asrAPIKeyField.isEnabled = isRemoteBackend
        asrModelField.isEnabled = isRemoteBackend
        asrPromptField.isEnabled = isRemoteBackend
        asrTestButton.isEnabled = isRemoteBackend

        if !isRemoteBackend {
            setASRFeedback(.neutral("Apple Speech is active. VoicePi will use the built-in streaming recognizer."))
        } else if configuration.isConfigured {
            setASRFeedback(.neutral("Remote large-model ASR is selected and configured."))
        } else {
            setASRFeedback(.neutral("Remote large-model ASR is selected, but API Base URL, API Key, and Model are still required."))
        }
    }

    private func refreshPermissionLabels() {
        applyPermissionStatus(model.microphoneAuthorization, to: microphoneStatusLabel)
        applyPermissionStatus(model.speechAuthorization, to: speechStatusLabel)
        applyPermissionStatus(model.accessibilityAuthorization, to: accessibilityStatusLabel)
        applyPermissionStatus(model.inputMonitoringAuthorization, to: inputMonitoringStatusLabel)
    }

    private func refreshLLMSection() {
        let mode = currentPostProcessingMode()
        let provider = currentTranslationProvider()
        let targetLanguage = currentTargetLanguage()
        let configuration = currentConfigurationFromFields()
        let usesLLM = mode == .refinement || (mode == .translation && provider == .llm)

        selectPopupItem(
            in: translationProviderPopup,
            matching: TranslationProvider.displayProvider(
                mode: mode,
                storedProvider: model.translationProvider,
                appleTranslateSupported: appleTranslateSupported
            ).rawValue
        )

        translationProviderPopup.isEnabled = mode == .translation && appleTranslateSupported
        testButton.isEnabled = usesLLM
        let shouldEnablePromptControls = mode == .refinement
        defaultPromptTemplatePopup.isEnabled = shouldEnablePromptControls
        appPromptOverridePopup.isEnabled = shouldEnablePromptControls
        setPromptOptionControlsEnabled(shouldEnablePromptControls)
        resolvedPromptPreviewButton.isEnabled = shouldEnablePromptControls

        setLLMFeedback(.neutral(
            LLMSectionFeedback.message(
                mode: mode,
                provider: provider,
                configuration: configuration,
                selectedLanguage: model.selectedLanguage,
                targetLanguage: targetLanguage,
                appleTranslateSupported: appleTranslateSupported
            )
        ))
    }

    private func currentConfigurationFromFields() -> LLMConfiguration {
        LLMConfiguration(
            baseURL: baseURLField.stringValue,
            apiKey: apiKeyField.stringValue,
            model: modelField.stringValue,
            refinementPrompt: model.llmConfiguration.refinementPrompt
        )
    }

    private func currentPostProcessingMode() -> PostProcessingMode {
        let index = max(0, postProcessingModePopup.indexOfSelectedItem)
        return PostProcessingMode.allCases[index]
    }

    private func currentTranslationProvider() -> TranslationProvider {
        let providers = availableTranslationProviders()
        let index = max(0, translationProviderPopup.indexOfSelectedItem)
        return providers[min(index, providers.count - 1)]
    }

    private func currentTargetLanguage() -> SupportedLanguage {
        let index = max(0, targetLanguagePopup.indexOfSelectedItem)
        return SupportedLanguage.allCases[index]
    }

    private func currentSelectedASRBackend() -> ASRBackend {
        let index = max(0, asrBackendPopup.indexOfSelectedItem)
        return ASRBackend.allCases[index]
    }

    private func currentRemoteASRConfigurationFromFields() -> RemoteASRConfiguration {
        RemoteASRConfiguration(
            baseURL: asrBaseURLField.stringValue,
            apiKey: asrAPIKeyField.stringValue,
            model: asrModelField.stringValue,
            prompt: asrPromptField.stringValue
        )
    }

    private func permissionStatusText(for state: AuthorizationState) -> String {
        SettingsPresentation.permissionPresentation(for: state).title
    }

    private func statusTitle(for state: AuthorizationState) -> String {
        SettingsPresentation.permissionPresentation(for: state).title
    }

    private func selectSection(_ section: SettingsSection) {
        currentSection = section

        for (candidate, button) in sectionButtons {
            let isSelected = candidate == section
            button.state = isSelected ? .on : .off
            if let styledButton = button as? StyledSettingsButton {
                styledButton.applyAppearance(isSelected: isSelected)
            }
        }

        homeView.isHidden = section != .home
        permissionsView.isHidden = section != .permissions
        asrView.isHidden = section != .asr
        llmView.isHidden = section != .llm
        aboutView.isHidden = section != .about
    }

    @objc
    private func sectionChanged(_ sender: NSButton) {
        guard let section = SettingsSection(rawValue: sender.tag) else { return }
        selectSection(section)
    }

    @objc
    private func openPermissionsSection() {
        selectSection(.permissions)
    }

    @objc
    private func openLLMSection() {
        selectSection(.llm)
    }

    @objc
    private func openASRSection() {
        selectSection(.asr)
    }

    @objc
    private func openAboutSection() {
        selectSection(.about)
    }

    @objc
    private func checkForUpdates() {
        aboutUpdateStatusLabel.stringValue = "Checking GitHub Releases…"
        aboutCheckForUpdatesButton.isEnabled = false

        Task { @MainActor [weak self] in
            guard let self else { return }
            let status = await delegate?.settingsWindowControllerDidRequestCheckForUpdates(self)
                ?? "No update handler is available."
            self.aboutUpdateStatusText = status
            self.aboutUpdateStatusLabel.stringValue = status
            self.aboutCheckForUpdatesButton.isEnabled = true
        }
    }

    @objc
    private func interfaceThemeChanged(_ sender: NSSegmentedControl) {
        let index = max(0, sender.selectedSegment)
        model.interfaceTheme = InterfaceTheme.allCases[index]
        applyThemeAppearance()
        refreshPermissionLabels()
    }

    @objc
    private func openPersonalWebsite() {
        openExternalURL(AboutProfile.websiteURL)
    }

    @objc
    private func openGitHubProfile() {
        openExternalURL(AboutProfile.githubURL)
    }

    @objc
    private func openRepository() {
        openExternalURL(AboutProfile.repositoryURL)
    }

    @objc
    private func openInspirationAuthor() {
        openExternalURL(AboutProfile.inspirationAuthorURL)
    }

    @objc
    private func openInspirationPost() {
        openExternalURL(AboutProfile.inspirationPostURL)
    }

    @objc
    private func openXProfile() {
        openExternalURL(AboutProfile.xURL)
    }

    @objc
    private func asrBackendChanged(_ sender: NSPopUpButton) {
        let backend = currentSelectedASRBackend()
        model.setASRBackend(backend)
        delegate?.settingsWindowController(self, didSelectASRBackend: backend)
        refreshHomeSection()
        refreshASRSection()
    }

    @objc
    private func shortcutRecorderChanged(_ sender: ShortcutRecorderField) {
        let shortcut = sender.shortcut

        guard !shortcut.isEmpty else {
            sender.shortcut = model.activationShortcut
            return
        }

        model.setActivationShortcut(shortcut)
        delegate?.settingsWindowController(self, didUpdateActivationShortcut: shortcut)
        reloadFromModel()
        window?.makeFirstResponder(nil)
    }

    @objc
    private func modeShortcutRecorderChanged(_ sender: ShortcutRecorderField) {
        let shortcut = sender.shortcut

        guard !shortcut.isEmpty else {
            sender.shortcut = model.modeCycleShortcut
            return
        }

        model.setModeCycleShortcut(shortcut)
        delegate?.settingsWindowController(self, didUpdateModeCycleShortcut: shortcut)
        reloadFromModel()
        window?.makeFirstResponder(nil)
    }

    @objc
    private func openMicrophoneSettings() {
        delegate?.settingsWindowControllerDidRequestOpenMicrophoneSettings(self)
    }

    @objc
    private func openSpeechSettings() {
        delegate?.settingsWindowControllerDidRequestOpenSpeechSettings(self)
    }

    @objc
    private func openAccessibilitySettingsFromSettings() {
        delegate?.settingsWindowControllerDidRequestOpenAccessibilitySettings(self)
    }

    @objc
    private func openInputMonitoringSettings() {
        delegate?.settingsWindowControllerDidRequestOpenInputMonitoringSettings(self)
    }

    @objc
    private func promptAccessibilityPermission() {
        delegate?.settingsWindowControllerDidRequestPromptAccessibilityPermission(self)
    }

    @objc
    private func refreshPermissions() {
        permissionsHintLabel.stringValue = "Refreshing permission status…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            await delegate?.settingsWindowControllerDidRequestRefreshPermissions(self)
            self.permissionsHintLabel.stringValue = PermissionsCopy.permissionsHint
            self.reloadFromModel()
        }
    }

    @objc
    private func postProcessingModeChanged(_ sender: NSPopUpButton) {
        refreshLLMSection()
    }

    @objc
    private func translationProviderChanged(_ sender: NSPopUpButton) {
        refreshLLMSection()
    }

    @objc
    private func targetLanguageChanged(_ sender: NSPopUpButton) {
        refreshLLMSection()
    }

    @objc
    private func defaultPromptTemplateChanged(_ sender: NSPopUpButton) {
        updatePromptSelection(for: .globalDefault, from: sender)
        refreshPromptTemplateControls()
    }

    @objc
    private func appPromptOverrideChanged(_ sender: NSPopUpButton) {
        updatePromptSelection(for: .appOverride, from: sender)
        refreshPromptTemplateControls()
    }

    @objc
    private func promptOptionChanged(_ sender: NSPopUpButton) {
        guard
            let identifier = sender.identifier?.rawValue,
            identifier.hasPrefix("prompt-option-"),
            let optionID = sender.selectedItem?.representedObject as? String,
            let editableTarget = promptTemplateFormState.editableTarget
        else {
            updateResolvedPromptSummary()
            return
        }

        let groupID = String(identifier.dropFirst("prompt-option-".count))
        promptTemplateFormState.setSelectedOption(optionID, for: groupID, in: editableTarget.scope)
        cachePromptSelectionDraft(for: editableTarget.scope)
        updateResolvedPromptSummary()
    }

    @objc
    private func previewResolvedPrompt() {
        let diagnostics = resolvePromptSelectionFromControls()
        let previewText: String

        if let resolved = diagnostics.resolvedSelection {
            previewText = resolved.middleSection ?? "No template selected. Core prompt behavior only."
        } else if let error = diagnostics.error {
            previewText = error.diagnosticDescription
        } else {
            previewText = "No template selected. Core prompt behavior only."
        }

        presentResolvedPromptPreview(text: previewText)
    }

    @objc
    private func saveRemoteASRConfiguration() {
        let configuration = currentRemoteASRConfigurationFromFields()
        let backend = currentSelectedASRBackend()

        model.setASRBackend(backend)
        model.saveRemoteASRConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model,
            prompt: configuration.prompt
        )

        setASRFeedback(.neutral("Saved."))
        delegate?.settingsWindowController(self, didSelectASRBackend: backend)
        delegate?.settingsWindowController(self, didSaveRemoteASRConfiguration: configuration)
        refreshHomeSection()
        refreshASRSection()
    }

    @objc
    private func testRemoteASRConfiguration() {
        let configuration = currentRemoteASRConfigurationFromFields()

        guard currentSelectedASRBackend() == .remoteOpenAICompatible else {
            setASRFeedback(.error("Switch to the remote backend before testing the remote ASR connection."))
            return
        }

        guard configuration.isConfigured else {
            setASRFeedback(.error("Please complete API Base URL, API Key, and Model before testing."))
            return
        }

        setASRButtonsEnabled(false)
        setASRFeedback(.loading())

        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await delegate?.settingsWindowController(self, didRequestRemoteASRTest: configuration)

            self.setASRFeedback(ConnectionTestFeedback.remoteASRTestResult(result), animated: true)

            self.setASRButtonsEnabled(true)
        }
    }

    @objc
    private func saveConfiguration() {
        var configuration = currentConfigurationFromFields()
        let mode = currentPostProcessingMode()
        model.setPostProcessingMode(mode)
        if mode == .translation {
            model.setTranslationProvider(currentTranslationProvider())
        }
        model.setTargetLanguage(currentTargetLanguage())
        savePromptTemplateSelections()
        if mode == .refinement {
            configuration.refinementPrompt = resolvedPromptTextFromControls() ?? ""
        }
        model.saveLLMConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model,
            refinementPrompt: mode == .refinement ? configuration.refinementPrompt : nil
        )
        setLLMFeedback(.neutral("Saved."))
        delegate?.settingsWindowController(self, didSave: configuration)
        refreshHomeSection()
        refreshLLMSection()
    }

    @objc
    private func testConfiguration() {
        var configuration = currentConfigurationFromFields()
        let mode = currentPostProcessingMode()
        let provider = currentTranslationProvider()
        let usesLLM = mode == .refinement || (mode == .translation && provider == .llm)

        guard usesLLM else {
            setLLMFeedback(.error("LLM testing is only available when refinement or LLM translation is selected."))
            return
        }

        guard configuration.isConfigured else {
            setLLMFeedback(.error("Please complete API Base URL, API Key, and Model before testing."))
            return
        }

        setLLMButtonsEnabled(false)
        setLLMFeedback(.loading())

        if mode == .refinement {
            configuration.refinementPrompt = resolvedPromptTextFromControls() ?? ""
        } else {
            configuration.refinementPrompt = ""
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await delegate?.settingsWindowController(self, didRequestTest: configuration)

            self.setLLMFeedback(ConnectionTestFeedback.llmTestResult(result), animated: true)

            setLLMButtonsEnabled(true)
        }
    }

    private func setLLMButtonsEnabled(_ enabled: Bool) {
        let mode = currentPostProcessingMode()
        let provider = currentTranslationProvider()
        let usesLLM = mode == .refinement || (mode == .translation && provider == .llm)
        testButton.isEnabled = enabled && usesLLM
        saveButton.isEnabled = enabled
    }

    private func setASRButtonsEnabled(_ enabled: Bool) {
        asrTestButton.isEnabled = enabled && currentSelectedASRBackend() == .remoteOpenAICompatible
        asrSaveButton.isEnabled = enabled
    }

    private func openExternalURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    private func applyThemeAppearance() {
        window?.appearance = model.interfaceTheme.appearance
        window?.backgroundColor = pageBackgroundColor
        window?.contentView?.layer?.backgroundColor = pageBackgroundColor.cgColor
        asrBackendPopup.syncTheme()
        postProcessingModePopup.syncTheme()
        translationProviderPopup.syncTheme()
        targetLanguagePopup.syncTheme()
        defaultPromptTemplatePopup.syncTheme()
        appPromptOverridePopup.syncTheme()
        for popup in optionPopupsByGroupID.values {
            (popup as? ThemedPopUpButton)?.syncTheme()
        }
        syncAppearanceControlTheme()
        refreshNavigationAppearance()
    }

    private func configurePostProcessingPopups() {
        postProcessingModePopup.removeAllItems()
        postProcessingModePopup.addItems(withTitles: PostProcessingMode.allCases.map(\.title))
        postProcessingModePopup.target = self
        postProcessingModePopup.action = #selector(postProcessingModeChanged(_:))

        translationProviderPopup.removeAllItems()
        translationProviderPopup.addItems(withTitles: availableTranslationProviders().map(\.title))
        translationProviderPopup.target = self
        translationProviderPopup.action = #selector(translationProviderChanged(_:))

        targetLanguagePopup.removeAllItems()
        targetLanguagePopup.addItems(withTitles: SupportedLanguage.allCases.map(\.recognitionDisplayName))
        targetLanguagePopup.target = self
        targetLanguagePopup.action = #selector(targetLanguageChanged(_:))
    }

    private func selectPopupItem(in popup: NSPopUpButton, matching rawValue: String) {
        if popup === postProcessingModePopup,
           let index = PostProcessingMode.allCases.firstIndex(where: { $0.rawValue == rawValue }) {
            popup.selectItem(at: index)
            return
        }

        if popup === translationProviderPopup,
           let index = availableTranslationProviders().firstIndex(where: { $0.rawValue == rawValue }) {
            popup.selectItem(at: index)
            return
        }

        if popup === targetLanguagePopup,
           let index = SupportedLanguage.allCases.firstIndex(where: { $0.rawValue == rawValue }) {
            popup.selectItem(at: index)
        }
    }

    private func refreshNavigationAppearance() {
        for (candidate, button) in sectionButtons {
            (button as? StyledSettingsButton)?.applyAppearance(isSelected: candidate == currentSection)
        }
    }

    private var appleTranslateSupported: Bool {
        AppleTranslateService.isSupported
    }

    private func availableTranslationProviders() -> [TranslationProvider] {
        TranslationProvider.availableProviders(appleTranslateSupported: appleTranslateSupported)
    }

    private func setASRFeedback(_ presentation: ConnectionFeedbackPresentation, animated: Bool = false) {
        asrStatusView.apply(presentation, animated: animated)
    }

    private func setLLMFeedback(_ presentation: ConnectionFeedbackPresentation, animated: Bool = false) {
        llmStatusView.apply(presentation, animated: animated)
    }

    private func configureAppearanceControl() {
        interfaceThemeControl.segmentStyle = .capsule
        interfaceThemeControl.trackingMode = .selectOne
        interfaceThemeControl.target = self
        interfaceThemeControl.action = #selector(interfaceThemeChanged(_:))
        interfaceThemeControl.segmentCount = InterfaceTheme.allCases.count
        interfaceThemeControl.controlSize = .regular

        for (index, theme) in InterfaceTheme.allCases.enumerated() {
            interfaceThemeControl.setLabel(theme.title, forSegment: index)
            interfaceThemeControl.setImage(
                NSImage(systemSymbolName: theme.symbolName, accessibilityDescription: theme.title),
                forSegment: index
            )
            interfaceThemeControl.setWidth(90, forSegment: index)
        }
    }

    private func syncAppearanceControlTheme() {
        interfaceThemeControl.appearance = window?.effectiveAppearance
    }

    private func applyPermissionStatus(_ state: AuthorizationState, to label: NSTextField) {
        let presentation = SettingsPresentation.permissionPresentation(for: state)
        label.stringValue = presentation.title

        switch presentation.tone {
        case .granted:
            label.textColor = interfaceColor(
                light: NSColor.systemGreen.darker(),
                dark: NSColor.systemGreen.lighter()
            )
        case .denied, .restricted:
            label.textColor = interfaceColor(
                light: NSColor.systemRed.darker(),
                dark: NSColor.systemRed.lighter()
            )
        case .unknown:
            label.textColor = .secondaryLabelColor
        }
    }

    private func makeCardView() -> NSView {
        let card = ThemedSurfaceView(style: .card)
        card.setContentHuggingPriority(.required, for: .vertical)
        card.setContentCompressionResistancePriority(.required, for: .vertical)
        return card
    }

    private func pinCardContent(_ content: NSView, into card: NSView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SettingsLayoutMetrics.cardPaddingHorizontal),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -SettingsLayoutMetrics.cardPaddingHorizontal),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: SettingsLayoutMetrics.cardPaddingVertical),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -SettingsLayoutMetrics.cardPaddingVertical)
        ])
    }

    private func makePageStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = SettingsLayoutMetrics.pageSpacing
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func makeGroupedSection(rows: [NSView] = [], customViews: [NSView] = []) -> NSView {
        let card = makeCardView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading

        let items = rows + customViews
        for (index, view) in items.enumerated() {
            stack.addArrangedSubview(view)

            if index < items.count - 1 {
                let separator = NSBox()
                separator.boxType = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.alphaValue = 0.35
                stack.addArrangedSubview(separator)
            }
        }

        pinCardContent(stack, into: card)
        return card
    }

    private func makePreferenceRow(title: String, control: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        control.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [titleLabel, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        row.edgeInsets = NSEdgeInsets(top: SettingsLayoutMetrics.formRowVerticalInset, left: 0, bottom: SettingsLayoutMetrics.formRowVerticalInset, right: 0)

        NSLayoutConstraint.activate([
            titleLabel.widthAnchor.constraint(equalToConstant: 132),
            control.widthAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])

        return row
    }

    private func configurePromptTemplateControls() {
        do {
            promptLibrary = try PromptLibrary.loadBundled()
            promptPolicy = promptLibrary?.policy(for: .voicePi)
            promptLibraryLoadError = nil
        } catch let error as PromptLibraryError {
            promptLibrary = nil
            promptPolicy = nil
            promptLibraryLoadError = error.diagnosticDescription
        } catch {
            promptLibrary = nil
            promptPolicy = nil
            promptLibraryLoadError = String(describing: error)
        }

        promptOptionRowsStack.orientation = .vertical
        promptOptionRowsStack.alignment = .leading
        promptOptionRowsStack.spacing = 10

        resolvedPromptSummaryLabel.font = .systemFont(ofSize: 12)
        resolvedPromptSummaryLabel.textColor = .secondaryLabelColor
        resolvedPromptSummaryLabel.lineBreakMode = .byWordWrapping
        resolvedPromptSummaryLabel.maximumNumberOfLines = 4
        resolvedPromptSummaryLabel.stringValue = "No template selected. Core prompt behavior only."
        resolvedPromptPreviewButton.isEnabled = false

        defaultPromptTemplatePopup.target = self
        defaultPromptTemplatePopup.action = #selector(defaultPromptTemplateChanged(_:))
        appPromptOverridePopup.target = self
        appPromptOverridePopup.action = #selector(appPromptOverrideChanged(_:))

        reloadPromptTemplatePopupItems()
    }

    private func reloadPromptTemplatePopupItems() {
        defaultPromptTemplatePopup.removeAllItems()
        appPromptOverridePopup.removeAllItems()

        defaultPromptTemplatePopup.addItem(withTitle: "None")
        defaultPromptTemplatePopup.lastItem?.representedObject = "none"

        appPromptOverridePopup.addItem(withTitle: "Inherit Global Default")
        appPromptOverridePopup.lastItem?.representedObject = "inherit"
        appPromptOverridePopup.addItem(withTitle: "None")
        appPromptOverridePopup.lastItem?.representedObject = "none"

        if model.promptSelection(for: .voicePi).mode == .legacyCustom {
            appPromptOverridePopup.addItem(withTitle: "Legacy Custom (Migrated)")
            appPromptOverridePopup.lastItem?.representedObject = "legacy-custom"
        }

        guard
            let library = promptLibrary,
            let policy = promptPolicy
        else {
            resolvedPromptSummaryLabel.stringValue = promptLibraryLoadError ?? "Prompt profile library is unavailable."
            return
        }

        for profileID in policy.allowedProfileIDs {
            guard let profile = library.profile(id: profileID) else { continue }

            defaultPromptTemplatePopup.addItem(withTitle: profile.title)
            defaultPromptTemplatePopup.lastItem?.representedObject = "profile:\(profile.id)"

            appPromptOverridePopup.addItem(withTitle: profile.title)
            appPromptOverridePopup.lastItem?.representedObject = "profile:\(profile.id)"
        }
    }

    private func loadPromptTemplateSelections() {
        promptTemplateFormState = .init(
            globalSelection: model.promptSettings.defaultSelection,
            appSelection: model.promptSelection(for: .voicePi)
        )
        promptSelectionDrafts = [:]
        cachePromptSelectionDraft(for: .globalDefault)
        cachePromptSelectionDraft(for: .appOverride)

        selectPromptTemplateItem(
            in: defaultPromptTemplatePopup,
            for: promptTemplateFormState.globalSelection,
            fallbackToken: "none"
        )
        selectPromptTemplateItem(
            in: appPromptOverridePopup,
            for: promptTemplateFormState.appSelection,
            fallbackToken: "inherit"
        )
        refreshPromptTemplateControls()
    }

    private func selectPromptTemplateItem(
        in popup: NSPopUpButton,
        for selection: PromptSelection,
        fallbackToken: String
    ) {
        let token: String
        switch selection.mode {
        case .none:
            token = "none"
        case .inherit:
            token = "inherit"
        case .profile:
            token = selection.profileID.map { "profile:\($0)" } ?? fallbackToken
        case .legacyCustom:
            token = "legacy-custom"
        }

        let index = popup.indexOfItem(withRepresentedObject: token)
        let fallbackIndex = popup.indexOfItem(withRepresentedObject: fallbackToken)
        if index >= 0 {
            popup.selectItem(at: index)
        } else if fallbackIndex >= 0 {
            popup.selectItem(at: fallbackIndex)
        } else {
            popup.selectItem(at: 0)
        }
    }

    private func refreshPromptTemplateControls() {
        rebuildPromptOptionRows()
        updateResolvedPromptSummary()
    }

    private func rebuildPromptOptionRows() {
        optionPopupsByGroupID = [:]

        for view in promptOptionRowsStack.arrangedSubviews {
            promptOptionRowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard
            let library = promptLibrary,
            let policy = promptPolicy,
            let editable = promptTemplateFormState.editableTarget
        else {
            return
        }

        guard editable.selection.mode == .profile, let profileID = editable.selection.profileID else {
            return
        }
        guard let profile = library.profile(id: profileID) else {
            return
        }

        for groupID in profile.optionGroupIDs where policy.visibleOptionGroupIDs.contains(groupID) {
            guard let group = library.optionGroups[groupID], group.selection == .single else { continue }

            let popup = ThemedPopUpButton()
            for option in group.options {
                popup.addItem(withTitle: option.title)
                popup.lastItem?.representedObject = option.id
            }
            popup.target = self
            popup.action = #selector(promptOptionChanged(_:))
            popup.identifier = NSUserInterfaceItemIdentifier(rawValue: "prompt-option-\(groupID)")
            popup.syncTheme()

            if
                let selectedOption = editable.selection.optionSelections[groupID]?.first,
                popup.indexOfItem(withRepresentedObject: selectedOption) >= 0
            {
                let selectedIndex = popup.indexOfItem(withRepresentedObject: selectedOption)
                popup.selectItem(at: selectedIndex)
            } else {
                popup.selectItem(at: 0)
            }

            optionPopupsByGroupID[groupID] = popup
            promptOptionRowsStack.addArrangedSubview(makePreferenceRow(title: group.title, control: popup))
        }
    }

    private func setPromptOptionControlsEnabled(_ enabled: Bool) {
        for popup in optionPopupsByGroupID.values {
            popup.isEnabled = enabled
        }
    }

    private func updatePromptSelection(
        for scope: PromptTemplateScope,
        from popup: NSPopUpButton
    ) {
        let selection = selectionFromPopup(popup, scope: scope)
        promptTemplateFormState.updateSelection(selection, for: scope)
        cachePromptSelectionDraft(for: scope)
    }

    private func cachePromptSelectionDraft(for scope: PromptTemplateScope) {
        let selection = promptTemplateFormState.selection(for: scope)
        guard selection.mode == .profile else { return }
        promptSelectionDrafts[scope] = selection
    }

    private func selectionFromPopup(
        _ popup: NSPopUpButton,
        scope: PromptTemplateScope
    ) -> PromptSelection {
        let token = popup.selectedItem?.representedObject as? String
        let currentSelection = promptTemplateFormState.selection(for: scope)
        let draftSelection = promptSelectionDrafts[scope]

        switch token {
        case "inherit":
            return .inherit
        case "none":
            return .none
        case "legacy-custom":
            return .legacyCustom
        case let token? where token.hasPrefix("profile:"):
            let profileID = String(token.dropFirst("profile:".count))
            if currentSelection.mode == .profile, currentSelection.profileID == profileID {
                return currentSelection
            }
            if let draftSelection, draftSelection.mode == .profile, draftSelection.profileID == profileID {
                return draftSelection
            }
            return .profile(profileID)
        default:
            return scope == .appOverride ? .inherit : .none
        }
    }

    private func savePromptTemplateSelections() {
        var settings = model.promptSettings
        settings.defaultSelection = promptTemplateFormState.globalSelection
        model.promptSettings = settings
        model.setPromptSelection(promptTemplateFormState.appSelection, for: .voicePi)
    }

    private func resolvePromptSelectionFromControls() -> PromptResolutionDiagnostics {
        guard let library = promptLibrary else {
            return .init(
                resolvedSelection: nil,
                error: .unknown(promptLibraryLoadError ?? "Prompt profile library is unavailable.")
            )
        }

        do {
            let resolved = try PromptResolver.resolve(
                appID: .voicePi,
                globalSelection: promptTemplateFormState.globalSelection,
                appSelection: promptTemplateFormState.appSelection,
                library: library,
                legacyCustomPrompt: model.llmConfiguration.refinementPrompt
            )
            return .init(resolvedSelection: resolved, error: nil)
        } catch let error as PromptLibraryError {
            return .init(resolvedSelection: nil, error: .library(error))
        } catch {
            return .init(
                resolvedSelection: nil,
                error: .unknown(String(describing: error))
            )
        }
    }

    private func resolvedPromptTextFromControls() -> String? {
        resolvePromptSelectionFromControls().resolvedSelection?.middleSection
    }

    private func presentResolvedPromptPreview(text: String) {
        let previewSize = NSSize(width: 720, height: 520)
        let contentWidth = previewSize.width - 40
        let contentHeight = previewSize.height - 92
        let sheet = PreviewSheetWindow(
            contentRect: NSRect(origin: .zero, size: previewSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        sheet.title = "Resolved Prompt Preview"
        sheet.setContentSize(previewSize)
        sheet.minSize = previewSize
        sheet.appearance = window?.effectiveAppearance ?? window?.appearance
        sheet.onCloseRequest = { [weak self] in
            self?.closeResolvedPromptPreviewSheet()
        }

        let textView = NSTextView(
            frame: NSRect(
                origin: .zero,
                size: NSSize(width: contentWidth, height: contentHeight)
            )
        )
        textView.isEditable = false
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.minSize = NSSize(width: contentWidth, height: contentHeight)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.containerSize = NSSize(
            width: contentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.sizeToFit()

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView

        let closeButton = makePrimaryActionButton(title: "Close", action: #selector(closeResolvedPromptPreviewSheet))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.keyEquivalent = "\r"

        let contentView = NSView()
        contentView.addSubview(scrollView)
        contentView.addSubview(closeButton)
        sheet.contentView = contentView

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: previewSize.width),
            contentView.heightAnchor.constraint(equalToConstant: previewSize.height),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            scrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -16),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        window?.beginSheet(sheet)
    }

    private func updateResolvedPromptSummary() {
        let diagnostics = resolvePromptSelectionFromControls()
        if let error = diagnostics.error {
            resolvedPromptSummaryLabel.stringValue = error.diagnosticDescription
            return
        }

        guard let resolved = diagnostics.resolvedSelection else {
            resolvedPromptSummaryLabel.stringValue = "No template selected. Core prompt behavior only."
            return
        }

        let title = resolved.title ?? "None"
        switch resolved.source {
        case .appOverride:
            resolvedPromptSummaryLabel.stringValue = "VoicePi override: \(title)"
        case .globalDefault:
            resolvedPromptSummaryLabel.stringValue = "Inherited default: \(title)"
        case .none:
            resolvedPromptSummaryLabel.stringValue = "No template selected. Core prompt behavior only."
        }
    }

    @objc
    private func closeResolvedPromptPreviewSheet() {
        if let sheet = window?.attachedSheet {
            window?.endSheet(sheet)
        }
    }

    private func makeSectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private func makeBodyLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    private func makeValueLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.alignment = .right
        return label
    }

    private func makeActionButton(title: String, action: Selector) -> NSButton {
        let button = StyledSettingsButton(title: title, role: .secondary, target: self, action: action)
        button.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.actionButtonHeight).isActive = true
        return button
    }

    private func makePrimaryActionButton(title: String, action: Selector) -> NSButton {
        let button = StyledSettingsButton(title: title, role: .primary, target: self, action: action)
        button.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.actionButtonHeight).isActive = true
        return button
    }

    private func makeSecondaryActionButton(title: String, action: Selector) -> NSButton {
        let button = StyledSettingsButton(title: title, role: .secondary, target: self, action: action)
        button.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.actionButtonHeight).isActive = true
        return button
    }

    private func makeButtonGroup(_ buttons: [NSButton]) -> NSStackView {
        let stack = NSStackView(views: buttons)
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func makeSectionHeader(title: String, subtitle: String) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.alignment = .left

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 3
        subtitleLabel.alignment = .left

        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.spacing = SettingsLayoutMetrics.sectionHeaderSpacing
        stack.alignment = .leading
        return stack
    }

    private func makeDetailStack(statusLabel: NSTextField, buttons: NSView) -> NSView {
        let stack = NSStackView(views: [statusLabel, buttons])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .trailing
        return stack
    }

    private func makeSectionNavigation() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY

        sectionButtons.removeAll()

        for section in SettingsSection.allCases {
            let button = StyledSettingsButton(title: section.title, role: .navigation, target: self, action: #selector(sectionChanged(_:)))
            button.tag = section.rawValue
            button.setButtonType(.toggle)
            button.image = NSImage(
                systemSymbolName: iconName(for: section),
                accessibilityDescription: section.title
            )?.withSymbolConfiguration(.init(pointSize: 12.5, weight: .medium))
            button.imagePosition = .imageLeading
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.navigationButtonHeight)
            ])

            sectionButtons[section] = button
            stack.addArrangedSubview(button)
        }

        return stack
    }

    private func iconName(for section: SettingsSection) -> String {
        switch section {
        case .home:
            return "house"
        case .permissions:
            return "lock.shield"
        case .asr:
            return "waveform.and.mic"
        case .llm:
            return "sparkles"
        case .about:
            return "info.circle"
        }
    }

    private func makeFeatureHeader(icon: String, eyebrow: String, title: String, description: String) -> NSView {
        let card = makeCardView()

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .medium)

        let eyebrowLabel = NSTextField(labelWithString: eyebrow.uppercased())
        eyebrowLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        eyebrowLabel.textColor = .secondaryLabelColor

        let titleLabel = NSTextField(wrappingLabelWithString: title)
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let descriptionLabel = makeBodyLabel(description)

        let stack = NSStackView(views: [iconView, eyebrowLabel, titleLabel, descriptionLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    private func makeFeatureCard(icon: String, title: String, description: String) -> NSView {
        let card = makeCardView()

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let descriptionLabel = makeBodyLabel(description)

        let stack = NSStackView(views: [iconView, titleLabel, descriptionLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    private func makeFeatureStrip(_ cards: [NSView]) -> NSView {
        let stack = NSStackView(views: cards)
        stack.orientation = .horizontal
        stack.spacing = 14
        stack.distribution = .fillEqually
        stack.alignment = .top
        return stack
    }

    private func makeActionCard(title: String, description: String, actions: [NSButton], verticalActions: Bool = false) -> NSView {
        let card = makeCardView()
        let actionRow = makeButtonGroup(actions)
        actionRow.orientation = verticalActions ? .vertical : .horizontal
        actionRow.spacing = verticalActions ? 8 : 10
        actionRow.alignment = verticalActions ? .leading : .centerY

        let stack = NSStackView(views: [
            makeSectionTitle(title),
            makeBodyLabel(description),
            actionRow
        ])
        stack.orientation = .vertical
        stack.spacing = SettingsLayoutMetrics.pageSpacing - 2
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    private func makeAboutOverviewCard(title: String, description: String) -> NSView {
        let card = makeCardView()

        var views: [NSView] = [
            makeSectionTitle(title),
            makeBodyLabel(description)
        ]

        views.append(contentsOf: StatusBarController.aboutOverviewRowOrder.map { row in
            switch row {
            case .repository:
                return makeSubtleLinkRow(
                    prefix: "Repository:",
                    linkTitle: AboutProfile.repositoryDisplay,
                    action: #selector(openRepository)
                )
            case .builtBy:
                return makeSubtleLinkRow(
                    prefix: "Built With Love By",
                    linkTitle: AboutProfile.author,
                    action: #selector(openGitHubProfile)
                )
            case .inspiredBy:
                return makeSubtleDoubleLinkRow(
                    prefix: "Inspired by",
                    firstLinkTitle: AboutProfile.inspirationAuthorDisplay,
                    firstAction: #selector(openInspirationAuthor),
                    infix: "and",
                    secondLinkTitle: "this tweet",
                    secondAction: #selector(openInspirationPost)
                )
            case .checkForUpdates:
                let stack = NSStackView(views: [aboutCheckForUpdatesButton, aboutUpdateStatusLabel])
                stack.orientation = .vertical
                stack.alignment = .leading
                stack.spacing = 6
                return stack
            }
        })

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    private func makeSubtleCaption(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .tertiaryLabelColor
        label.alignment = .left
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    private func makeSubtleLinkButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.bezelStyle = .inline
        button.setButtonType(.momentaryPushIn)
        button.contentTintColor = .tertiaryLabelColor
        button.font = .systemFont(ofSize: 11.5)
        button.alignment = .left
        button.imagePosition = .noImage
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11.5),
                .foregroundColor: NSColor.tertiaryLabelColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    private func makeSubtleLinkRow(prefix: String, linkTitle: String, action: Selector) -> NSView {
        let row = NSStackView(views: [
            makeSubtleCaption(prefix),
            makeSubtleLinkButton(title: linkTitle, action: action)
        ])
        row.orientation = .horizontal
        row.spacing = 4
        row.alignment = .firstBaseline
        return row
    }

    private func makeSubtleDoubleLinkRow(
        prefix: String,
        firstLinkTitle: String,
        firstAction: Selector,
        infix: String,
        secondLinkTitle: String,
        secondAction: Selector
    ) -> NSView {
        let row = NSStackView(views: [
            makeSubtleCaption(prefix),
            makeSubtleLinkButton(title: firstLinkTitle, action: firstAction),
            makeSubtleCaption(infix),
            makeSubtleLinkButton(title: secondLinkTitle, action: secondAction)
        ])
        row.orientation = .horizontal
        row.spacing = 4
        row.alignment = .firstBaseline
        return row
    }

    private func makeAboutMetaRow(title: String, valueView: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel, valueView])
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        return stack
    }

    private func makeAboutLinkRow(title: String, valueView: NSTextField, buttonTitle: String, action: Selector) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        let button = makeSecondaryActionButton(title: buttonTitle, action: action)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        valueView.maximumNumberOfLines = 1
        valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let valueRow = NSStackView(views: [valueView, NSView(), button])
        valueRow.orientation = .horizontal
        valueRow.alignment = .centerY
        valueRow.spacing = 8

        let stack = NSStackView(views: [titleLabel, valueRow])
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        return stack
    }

    private func makeVerticalStack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = spacing
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func makeTwoColumnSection(left: NSView, right: NSView, leftPriority: CGFloat) -> NSView {
        let stack = NSStackView(views: [left, right])
        stack.orientation = .horizontal
        stack.spacing = SettingsLayoutMetrics.twoColumnSpacing
        stack.alignment = .top
        stack.distribution = .fillProportionally
        left.setContentHuggingPriority(.defaultLow, for: .horizontal)
        right.setContentHuggingPriority(.required, for: .horizontal)
        left.setContentHuggingPriority(.required, for: .vertical)
        right.setContentHuggingPriority(.required, for: .vertical)
        left.widthAnchor.constraint(greaterThanOrEqualTo: right.widthAnchor, multiplier: leftPriority / max(0.01, 1 - leftPriority)).isActive = true
        return stack
    }

    private func makeTwoColumnGrid(_ views: [NSView]) -> NSView {
        let rows = stride(from: 0, to: views.count, by: 2).map { index -> NSView in
            let rowViews = Array(views[index..<min(index + 2, views.count)])
            let row = NSStackView(views: rowViews)
            row.orientation = .horizontal
            row.spacing = SettingsLayoutMetrics.twoColumnSpacing
            row.alignment = .top
            row.distribution = .fillEqually
            return row
        }

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.spacing = SettingsLayoutMetrics.pageSpacing
        stack.alignment = .leading
        return stack
    }

    private func makePermissionCard(
        icon: String,
        title: String,
        description: String,
        statusLabel: NSTextField?,
        primaryButton: NSButton,
        secondaryButtons: [NSButton]
    ) -> NSView {
        let card = makeCardView()

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let descriptionLabel = makeBodyLabel(description)

        let headerStack = NSStackView(views: [iconView, titleLabel, NSView()])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 10

        if let statusLabel {
            let statusPill = makeStatusPill(label: statusLabel)
            headerStack.addArrangedSubview(statusPill)
        }

        var buttons = [primaryButton]
        buttons.append(contentsOf: secondaryButtons)
        let buttonRow = makeButtonGroup(buttons)

        let stack = NSStackView(views: [headerStack, descriptionLabel, buttonRow])
        stack.orientation = .vertical
        stack.spacing = SettingsLayoutMetrics.pageSpacing
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    private func makeStatusPill(label: NSTextField) -> NSView {
        let pill = ThemedSurfaceView(style: .pill)

        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -4)
        ])

        return pill
    }

    private var isDarkTheme: Bool {
        let appearance = window?.effectiveAppearance ?? NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func interfaceColor(light: NSColor, dark: NSColor) -> NSColor {
        isDarkTheme ? dark : light
    }

    private var pageBackgroundColor: NSColor {
        interfaceColor(
            light: NSColor(calibratedRed: 0xF5 / 255.0, green: 0xF3 / 255.0, blue: 0xED / 255.0, alpha: 1),
            dark: NSColor(calibratedWhite: 0.16, alpha: 1)
        )
    }

    private var cardSurfaceColor: NSColor {
        interfaceColor(
            light: NSColor(calibratedWhite: 1.0, alpha: 0.84),
            dark: NSColor(calibratedWhite: 0.215, alpha: 1)
        )
    }

    private var cardBorderColor: NSColor {
        interfaceColor(
            light: NSColor(calibratedWhite: 0.0, alpha: 0.06),
            dark: NSColor(calibratedWhite: 1.0, alpha: 0.06)
        )
    }

    private var statusPillColor: NSColor {
        interfaceColor(
            light: NSColor(calibratedWhite: 0.95, alpha: 1),
            dark: NSColor(calibratedWhite: 0.29, alpha: 1)
        )
    }
}

@MainActor
extension StatusBarController: SettingsWindowControllerDelegate {
    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSave configuration: LLMConfiguration
    ) {
        refreshLLMMenuState()
        refreshStatusSummary()
        delegate?.statusBarController(self, didSave: configuration)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateActivationShortcut shortcut: ActivationShortcut
    ) {
        shortcutMenuItem?.title = shortcutMenuTitle()
        refreshAll()
        delegate?.statusBarController(self, didUpdateActivationShortcut: shortcut)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateModeCycleShortcut shortcut: ActivationShortcut
    ) {
        refreshAll()
        delegate?.statusBarController(self, didUpdateModeCycleShortcut: shortcut)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration
    ) {
        refreshAll()
        delegate?.statusBarController(self, didSaveRemoteASRConfiguration: configuration)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSelectASRBackend backend: ASRBackend
    ) {
        refreshAll()
        delegate?.statusBarController(self, didSelectASRBackend: backend)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestTest configuration: LLMConfiguration
    ) async -> Result<String, Error> {
        await delegate?.statusBarController(self, didRequestTest: configuration)
            ?? .failure(NSError(
                domain: "VoicePi.StatusBarController",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No test handler is available."]
            ))
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestRemoteASRTest configuration: RemoteASRConfiguration
    ) async -> Result<String, Error> {
        await delegate?.statusBarController(self, didRequestRemoteASRTest: configuration)
            ?? .failure(NSError(
                domain: "VoicePi.StatusBarController",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No remote ASR test handler is available."]
            ))
    }

    func settingsWindowControllerDidRequestOpenMicrophoneSettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenMicrophoneSettings(self)
    }

    func settingsWindowControllerDidRequestOpenSpeechSettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenSpeechSettings(self)
    }

    func settingsWindowControllerDidRequestOpenAccessibilitySettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenAccessibilitySettings(self)
    }

    func settingsWindowControllerDidRequestOpenInputMonitoringSettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenInputMonitoringSettings(self)
    }

    func settingsWindowControllerDidRequestPromptAccessibilityPermission(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestPromptAccessibilityPermission(self)
    }

    func settingsWindowControllerDidRequestRefreshPermissions(_ controller: SettingsWindowController) async {
        await delegate?.statusBarControllerDidRequestRefreshPermissions(self)
        refreshAll()
    }

    func settingsWindowControllerDidRequestCheckForUpdates(_ controller: SettingsWindowController) async -> String {
        await delegate?.statusBarControllerDidRequestCheckForUpdates(self)
            ?? "No update handler is available."
    }
}

private extension NSColor {
    func lighter(by amount: CGFloat = 0.18) -> NSColor {
        blended(withFraction: amount, of: .white) ?? self
    }

    func darker(by amount: CGFloat = 0.18) -> NSColor {
        blended(withFraction: amount, of: .black) ?? self
    }
}

@MainActor
private final class PreviewSheetWindow: NSWindow {
    var onCloseRequest: (() -> Void)?

    override func performClose(_ sender: Any?) {
        if let onCloseRequest {
            onCloseRequest()
        } else {
            super.performClose(sender)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        if let onCloseRequest {
            onCloseRequest()
        } else {
            super.cancelOperation(sender)
        }
    }
}

@MainActor
final class StyledSettingsButton: NSButton {
    enum Role {
        case primary
        case secondary
        case navigation
    }

    private let role: Role
    private let navigationHorizontalPadding: CGFloat = 16
    private let navigationIconSpacing: CGFloat = 8
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false

    init(title: String, role: Role, target: AnyObject?, action: Selector) {
        self.role = role
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        bezelStyle = .regularSquare
        controlSize = .regular
        wantsLayer = true
        focusRingType = .none
        font = .systemFont(ofSize: role == .navigation ? 12.5 : 13.5, weight: role == .navigation ? .medium : .semibold)
        imagePosition = .imageLeading
        layer?.masksToBounds = false
        layer?.cornerRadius = role == .navigation ? 11 : 10
        setButtonType(role == .navigation ? .toggle : .momentaryPushIn)
        if role == .navigation {
            imageScaling = .scaleProportionallyDown
            imageHugsTitle = true
        }
        applyAppearance(isSelected: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance(isSelected: role == .navigation && state == .on)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        guard role == .navigation else { return }

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard role == .navigation else { return }
        isHovered = true
        applyAppearance(isSelected: state == .on)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard role == .navigation else { return }
        isHovered = false
        applyAppearance(isSelected: state == .on)
    }

    override func layout() {
        super.layout()

        guard role == .navigation else { return }
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: layer?.cornerRadius ?? 0,
            cornerHeight: layer?.cornerRadius ?? 0,
            transform: nil
        )
    }

    override var isHighlighted: Bool {
        didSet {
            applyAppearance(isSelected: role == .navigation && state == .on)
        }
    }

    func applyAppearance(isSelected: Bool) {
        let isDarkTheme = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let fillColor: NSColor
        let borderColor: NSColor
        let textColor: NSColor
        let shadowColor: NSColor
        let shadowOpacity: Float
        let shadowRadius: CGFloat
        let shadowOffset: CGSize

        switch role {
        case .primary:
            fillColor = isDarkTheme
                ? NSColor(calibratedWhite: isHighlighted ? 0.35 : 0.315, alpha: 1)
                : NSColor(calibratedWhite: isHighlighted ? 0.86 : 0.91, alpha: 1)
            borderColor = isDarkTheme
                ? NSColor(calibratedWhite: 1, alpha: 0.08)
                : NSColor(calibratedWhite: 0, alpha: 0.08)
            textColor = isDarkTheme ? NSColor(calibratedWhite: 0.96, alpha: 1) : NSColor(calibratedWhite: 0.15, alpha: 1)
            shadowColor = .clear
            shadowOpacity = 0
            shadowRadius = 0
            shadowOffset = .zero
        case .secondary:
            fillColor = isDarkTheme
                ? NSColor(calibratedWhite: isHighlighted ? 0.27 : 0.235, alpha: 1)
                : NSColor(calibratedWhite: isHighlighted ? 0.91 : 0.95, alpha: 1)
            borderColor = isDarkTheme
                ? NSColor(calibratedWhite: 1, alpha: 0.08)
                : NSColor(calibratedWhite: 0, alpha: 0.06)
            textColor = isDarkTheme ? NSColor(calibratedWhite: 0.93, alpha: 1) : NSColor(calibratedWhite: 0.22, alpha: 1)
            shadowColor = .clear
            shadowOpacity = 0
            shadowRadius = 0
            shadowOffset = .zero
        case .navigation:
            let showsHoverChrome = isHovered || isHighlighted
            fillColor = isSelected
                ? (isDarkTheme ? NSColor(calibratedWhite: 0.285, alpha: 0.92) : NSColor(calibratedWhite: 0.945, alpha: 1))
                : (showsHoverChrome
                    ? (isDarkTheme ? NSColor(calibratedWhite: 1, alpha: 0.055) : NSColor(calibratedWhite: 1, alpha: 0.74))
                    : .clear)
            borderColor = isSelected
                ? (isDarkTheme ? NSColor(calibratedWhite: 1, alpha: 0.07) : NSColor(calibratedWhite: 0, alpha: 0.05))
                : (showsHoverChrome
                    ? (isDarkTheme ? NSColor(calibratedWhite: 1, alpha: 0.04) : NSColor(calibratedWhite: 0, alpha: 0.04))
                    : .clear)
            textColor = isSelected || showsHoverChrome
                ? (isDarkTheme ? NSColor(calibratedWhite: 0.97, alpha: 1) : NSColor(calibratedWhite: 0.16, alpha: 1))
                : (isDarkTheme ? NSColor(calibratedWhite: 0.72, alpha: 1) : NSColor(calibratedWhite: 0.48, alpha: 1))
            shadowColor = isDarkTheme
                ? NSColor.black.withAlphaComponent(isSelected ? 0.18 : 0.22)
                : NSColor.black.withAlphaComponent(isSelected ? 0.10 : 0.12)
            shadowOpacity = isSelected ? 0.28 : (showsHoverChrome ? 0.55 : 0)
            shadowRadius = isSelected ? 5 : 7
            shadowOffset = CGSize(width: 0, height: -1)
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(role == .navigation ? 0.14 : 0.0)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        layer?.backgroundColor = fillColor.cgColor
        layer?.borderWidth = role == .navigation ? (borderColor == .clear ? 0 : 1) : 1
        layer?.borderColor = borderColor.cgColor
        layer?.shadowColor = shadowColor.cgColor
        layer?.shadowOpacity = shadowOpacity
        layer?.shadowRadius = shadowRadius
        layer?.shadowOffset = shadowOffset
        CATransaction.commit()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: textColor,
                .font: font ?? NSFont.systemFont(ofSize: role == .navigation ? 12 : 13, weight: .semibold),
                .paragraphStyle: paragraph
            ]
        )
        contentTintColor = textColor
        image?.isTemplate = true
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        switch role {
        case .primary, .secondary:
            return NSSize(
                width: base.width + 20,
                height: max(SettingsLayoutMetrics.actionButtonHeight, base.height + 10)
            )
        case .navigation:
            let titleWidth = ceil((attributedTitle.length > 0 ? attributedTitle : NSAttributedString(string: title)).size().width)
            let imageWidth = image.map { ceil($0.size.width) } ?? 0
            let contentWidth = titleWidth + (imageWidth > 0 ? imageWidth + navigationIconSpacing : 0)
            let paddedWidth = contentWidth + navigationHorizontalPadding * 2
            return NSSize(
                width: max(SettingsLayoutMetrics.navigationButtonMinWidth, paddedWidth),
                height: SettingsLayoutMetrics.navigationButtonHeight
            )
        }
    }
}

@MainActor
final class ThemedSurfaceView: NSView {
    enum Style {
        case card
        case pill
    }

    private let style: Style

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = style == .card ? 11 : 11
        syncTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        syncTheme()
    }

    func syncTheme() {
        let isDarkTheme = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        switch style {
        case .card:
            layer?.backgroundColor = (isDarkTheme
                ? NSColor(calibratedWhite: 0.215, alpha: 1)
                : NSColor(calibratedWhite: 1.0, alpha: 0.84)).cgColor
        case .pill:
            layer?.backgroundColor = (isDarkTheme
                ? NSColor(calibratedWhite: 0.29, alpha: 1)
                : NSColor(calibratedWhite: 0.95, alpha: 1)).cgColor
        }

        layer?.borderWidth = 1
        layer?.borderColor = (isDarkTheme
            ? NSColor(calibratedWhite: 1.0, alpha: 0.06)
            : NSColor(calibratedWhite: 0.0, alpha: 0.06)).cgColor
    }
}

@MainActor
final class ThemedPopUpButton: NSPopUpButton {
    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        configure()
    }

    convenience init() {
        self.init(frame: .zero, pullsDown: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        syncTheme()
    }

    override func addItem(withTitle title: String) {
        super.addItem(withTitle: title)
        applyAttributedTitles()
    }

    override func addItems(withTitles itemTitles: [String]) {
        super.addItems(withTitles: itemTitles)
        applyAttributedTitles()
    }

    override func insertItem(withTitle title: String, at index: Int) {
        super.insertItem(withTitle: title, at: index)
        applyAttributedTitles()
    }

    override func removeAllItems() {
        super.removeAllItems()
        applyAttributedTitles()
    }

    private func configure() {
        font = .systemFont(ofSize: 13, weight: .medium)
        controlSize = .regular
        bezelStyle = .rounded
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        syncTheme()
    }

    func syncTheme() {
        let resolvedAppearance = resolvedAppearance()
        let foregroundColor = resolvedForegroundColor()
        appearance = resolvedAppearance
        menu?.appearance = resolvedAppearance
        contentTintColor = foregroundColor
        applyAttributedTitles(foregroundColor: foregroundColor)
    }

    private func applyAttributedTitles(foregroundColor: NSColor? = nil) {
        let color = foregroundColor ?? resolvedForegroundColor()
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ]

        for item in itemArray {
            item.attributedTitle = NSAttributedString(string: item.title, attributes: attributes)
        }

        needsDisplay = true
    }

    private func resolvedForegroundColor() -> NSColor {
        let isDarkTheme = resolvedAppearance().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDarkTheme
            ? NSColor(calibratedWhite: 0.93, alpha: 1)
            : NSColor(calibratedWhite: 0.22, alpha: 1)
    }

    private func resolvedAppearance() -> NSAppearance {
        window?.appearance
            ?? superview?.effectiveAppearance
            ?? NSApp.effectiveAppearance
    }
}

@MainActor
final class ShortcutRecorderField: NSButton {
    var shortcut: ActivationShortcut = .default {
        didSet {
            if !isRecordingShortcut {
                previewShortcut = nil
            }
            updateAppearance()
        }
    }

    private(set) var isRecordingShortcut = false
    private var previewShortcut: ActivationShortcut?
    private var recorderState = ShortcutRecorderState()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setButtonType(.momentaryPushIn)
        bezelStyle = .rounded
        controlSize = .large
        font = .systemFont(ofSize: 13, weight: .semibold)
        wantsLayer = true
        focusRingType = .default
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            isRecordingShortcut = true
            recorderState.reset()
            previewShortcut = nil
            updateAppearance()
        }
        return didBecome
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            isRecordingShortcut = false
            recorderState.reset()
            previewShortcut = nil
            updateAppearance()
        }
        return didResign
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handleKeyDownEvent(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }

        handleKeyDownEvent(event)
    }

    override func keyUp(with event: NSEvent) {
        guard isRecordingShortcut else { return }
        applyRecorderResult(recorderState.handleKeyUp(event.keyCode, modifiers: event.modifierFlags))
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecordingShortcut else { return }

        applyRecorderResult(recorderState.handleFlagsChanged(event.modifierFlags))
    }

    private func handleKeyDownEvent(_ event: NSEvent) {
        guard isRecordingShortcut else { return }
        guard !event.isARepeat else { return }

        applyRecorderResult(recorderState.handleKeyDown(event.keyCode, modifiers: event.modifierFlags))
    }

    private func applyRecorderResult(_ result: ShortcutRecorderResult) {
        previewShortcut = result.previewShortcut

        if let committedShortcut = result.committedShortcut, !committedShortcut.isEmpty {
            shortcut = committedShortcut
            sendAction(action, to: target)
            window?.makeFirstResponder(nil)
            return
        }

        updateAppearance()
    }

    private func updateAppearance() {
        if isRecordingShortcut {
            title = previewShortcut?.displayString ?? "Type Shortcut…"
        } else {
            title = shortcut.displayString
        }
    }
}
