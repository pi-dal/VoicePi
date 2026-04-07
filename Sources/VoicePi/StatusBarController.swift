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
    private struct PromptBindingCapture {
        let kind: PromptBindingKind
        let value: String

        var summaryTitle: String {
            switch kind {
            case .appBundleID:
                return "Captured App: \(value)"
            case .websiteHost:
                return "Captured Website: \(value)"
            }
        }

        var bindingSubject: String {
            switch kind {
            case .appBundleID:
                return "app \(value)"
            case .websiteHost:
                return "site \(value)"
            }
        }
    }

    enum AboutOverviewRow: Equatable {
        case repository
        case builtBy
        case inspiredBy
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
    private var updatePanelController: AppUpdatePanelController?
    private var aboutUpdatePresentation = AppUpdateExperience.cardPresentation(for: .idle(source: .unknown))
    private var aboutUpdatePrimaryAction: (() -> Void)?
    private var aboutUpdateSecondaryAction: (() -> Void)?
    private var updatePanelActionHandler: ((AppUpdateActionRole) -> Void)?

    private var isRecording = false
    private var transientStatus: String?
    private var promptDestinationInspector = PromptDestinationInspector()

    static let aboutOverviewRowOrder: [AboutOverviewRow] = [
        .builtBy,
        .inspiredBy
    ]

    static let primaryMenuActionTitles = [
        "Language",
        "Text Processing",
        "Refinement Prompt",
        "Check for Updates…",
        "Settings…",
        "Quit VoicePi"
    ]

    static let refinementPromptCaptureActionTitles = [
        "Capture Frontmost App",
        "Capture Current Website"
    ]

    static let promptBindingPickerActionTitles = [
        "Bind",
        "New Prompt…",
        "Cancel"
    ]

    static func refinementPromptCaptureActionsEnabled(
        mode: PostProcessingMode,
        isPromptEditorPresented: Bool
    ) -> Bool {
        mode == .refinement && !isPromptEditorPresented
    }

    static func disabledRefinementPromptTitle(_ title: String) -> NSAttributedString {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 1
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        return NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.disabledControlTextColor,
                .shadow: shadow
            ]
        )
    }

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

    func setAboutUpdateExperience(
        _ presentation: AppUpdateCardPresentation,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        aboutUpdatePresentation = presentation
        aboutUpdatePrimaryAction = primaryAction
        aboutUpdateSecondaryAction = secondaryAction
        settingsWindowController?.setAboutUpdatePresentation(
            presentation,
            primaryAction: primaryAction,
            secondaryAction: secondaryAction
        )
    }

    func presentUpdatePanel(
        _ presentation: AppUpdatePanelPresentation,
        actionHandler: @escaping (AppUpdateActionRole) -> Void
    ) {
        updatePanelActionHandler = actionHandler
        if updatePanelController == nil {
            updatePanelController = AppUpdatePanelController()
        }
        updatePanelController?.interfaceAppearance = model.interfaceTheme.appearance
        updatePanelController?.present(
            presentation,
            actionHandler: { [weak self] role in
                self?.updatePanelActionHandler?(role)
            }
        )
    }

    func dismissUpdatePanel() {
        updatePanelController?.dismissPanel()
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
            settingsWindowController?.setAboutUpdatePresentation(
                aboutUpdatePresentation,
                primaryAction: aboutUpdatePrimaryAction,
                secondaryAction: aboutUpdateSecondaryAction
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
            let title: String
            if mode == .refinement {
                let promptTitle = model.resolvedPromptPreset().title
                title = "\(mode.title) (\(promptTitle))"
            } else {
                title = mode.title
            }

            let item = NSMenuItem(
                title: title,
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

        llmMenu.addItem(.separator())

        let promptRoot = NSMenuItem(title: "Refinement Prompt", action: nil, keyEquivalent: "")
        let promptMenu = NSMenu(title: "Refinement Prompt")
        promptRoot.submenu = promptMenu
        llmMenu.addItem(promptRoot)
        rebuildRefinementPromptMenu(promptMenu)
    }

    private func rebuildRefinementPromptMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let canSelectPrompt = model.postProcessingMode == .refinement
        let captureActionsEnabled = Self.refinementPromptCaptureActionsEnabled(
            mode: model.postProcessingMode,
            isPromptEditorPresented: settingsWindowController?.isPromptEditorSheetPresented == true
        )
        let currentSelection = model.promptWorkspace.activeSelection
        let allPresets = [PromptPreset.builtInDefault] + model.starterPromptPresets()
            + model.promptWorkspace.userPresets.sorted(by: {
                $0.resolvedTitle.localizedCaseInsensitiveCompare($1.resolvedTitle) == .orderedAscending
            })

        for preset in allPresets {
            let item = NSMenuItem(
                title: preset.resolvedTitle,
                action: #selector(selectRefinementPromptFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.id
            switch currentSelection.mode {
            case .builtInDefault:
                item.state = preset.id == PromptPreset.builtInDefaultID ? .on : .off
            case .preset:
                item.state = preset.id == currentSelection.presetID ? .on : .off
            }
            item.isEnabled = canSelectPrompt
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let captureFrontmostAppItem = NSMenuItem(
            title: Self.refinementPromptCaptureActionTitles[0],
            action: #selector(captureFrontmostAppForPromptBinding),
            keyEquivalent: ""
        )
        captureFrontmostAppItem.target = self
        captureFrontmostAppItem.isEnabled = captureActionsEnabled
        menu.addItem(captureFrontmostAppItem)

        let captureCurrentWebsiteItem = NSMenuItem(
            title: Self.refinementPromptCaptureActionTitles[1],
            action: #selector(captureCurrentWebsiteForPromptBinding),
            keyEquivalent: ""
        )
        captureCurrentWebsiteItem.target = self
        captureCurrentWebsiteItem.isEnabled = captureActionsEnabled
        menu.addItem(captureCurrentWebsiteItem)

        if !canSelectPrompt {
            for item in menu.items {
                item.state = .off
                item.indentationLevel = 1
                item.attributedTitle = Self.disabledRefinementPromptTitle(item.title)
            }
        }
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
    private func selectRefinementPromptFromMenu(_ sender: NSMenuItem) {
        guard model.postProcessingMode == .refinement else { return }
        guard let presetID = sender.representedObject as? String else { return }

        if presetID == PromptPreset.builtInDefaultID {
            model.setActivePromptSelection(.builtInDefault)
        } else {
            model.setActivePromptSelection(.preset(presetID))
        }

        refreshLLMMenuState()
        refreshStatusSummary()
        settingsWindowController?.reloadFromModel()
        let title = model.resolvedPromptPreset().title
        setTransientStatus("Prompt: \(title)")
    }

    @objc
    private func captureFrontmostAppForPromptBinding() {
        let destination = promptDestinationInspector.currentDestinationContext()
        capturePromptBinding(
            kind: .appBundleID,
            capturedRawValue: destination.appBundleID,
            unavailableMessage: "Couldn't capture a frontmost app bundle ID."
        )
    }

    @objc
    private func captureCurrentWebsiteForPromptBinding() {
        let destination = promptDestinationInspector.currentDestinationContext()
        capturePromptBinding(
            kind: .websiteHost,
            capturedRawValue: destination.websiteHost,
            unavailableMessage: "Couldn't capture a website host from the frontmost browser tab."
        )
    }

    private func capturePromptBinding(
        kind: PromptBindingKind,
        capturedRawValue: String?,
        unavailableMessage: String
    ) {
        guard let captured = PromptBindingActions.normalizedCapturedValue(capturedRawValue, kind: kind) else {
            setTransientStatus(unavailableMessage)
            return
        }

        presentPromptBindingPicker(
            for: PromptBindingCapture(kind: kind, value: captured)
        )
    }

    private func applyPromptBindingCapture(
        _ capture: PromptBindingCapture,
        to target: PromptBindingTarget
    ) {
        guard let result = PromptBindingActions.apply(
            capturedRawValue: capture.value,
            kind: capture.kind,
            target: target,
            model: model
        ) else {
            setTransientStatus("Couldn't save the captured binding.")
            return
        }

        let statusText: String
        switch result.status {
        case .added:
            statusText = "Bound \(capture.bindingSubject) to \(result.preset.resolvedTitle)"
        case .alreadyPresent:
            statusText = "\(result.preset.resolvedTitle) already includes \(capture.bindingSubject)"
        }

        refreshAll()
        setTransientStatus(statusText)
    }

    private func presentPromptBindingPicker(for capture: PromptBindingCapture) {
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 28), pullsDown: false)
        let targets = PromptBindingActions.pickerTargets(model: model)
        for (index, target) in targets.enumerated() {
            popup.addItem(withTitle: target.title)
            popup.lastItem?.tag = index
        }

        let alert = NSAlert()
        alert.messageText = capture.summaryTitle
        alert.informativeText = "Choose a prompt to bind. Starter prompts and VoicePi Default will be copied into a new editable prompt before saving the binding."
        alert.accessoryView = popup
        alert.addButton(withTitle: Self.promptBindingPickerActionTitles[0])
        alert.addButton(withTitle: Self.promptBindingPickerActionTitles[1])
        alert.addButton(withTitle: Self.promptBindingPickerActionTitles[2])

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let selectedIndex = max(0, popup.indexOfSelectedItem)
            let target = targets[min(selectedIndex, targets.count - 1)].target
            applyPromptBindingCapture(capture, to: target)
        case .alertSecondButtonReturn:
            showSettingsWindow(section: .llm)
            settingsWindowController?.presentNewPromptEditor(
                prefillingCapturedValue: capture.value,
                kind: capture.kind
            )
            setTransientStatus("Editing new prompt for \(capture.bindingSubject)")
        default:
            setTransientStatus("Cancelled binding \(capture.bindingSubject)")
        }
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
    enum PromptBindingEntryAction {
        case createFromDefault
        case createFromStarter
        case editUser
    }

    static let promptBindingActionBarTitle = "Bindings"
    static let promptBindingsButtonTitle = "Bindings"
    static let captureFrontmostAppButtonTitle = "Capture Frontmost App"
    static let captureCurrentWebsiteButtonTitle = "Capture Current Website"
    static let promptEditorBodyHintText = "Add the instructions VoicePi should apply here. Leave it empty to keep the default refinement rules and only use this prompt for bindings."
    static let promptEditorBodyFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let promptEditorBodyTextInset = NSSize(width: 14, height: 12)

    static func promptEditorSheetTitle(for preset: PromptPreset) -> String {
        isNewPromptDraft(preset) ? "New Prompt" : "Edit Prompt"
    }

    static func promptEditorPrimaryActionTitle(for preset: PromptPreset) -> String {
        isNewPromptDraft(preset) ? "Create Prompt" : "Save Prompt"
    }

    private static func isNewPromptDraft(_ preset: PromptPreset) -> Bool {
        preset.source == .user
            && preset.title == "New Prompt"
            && preset.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
    private let aboutRepositoryLabel = NSTextField(labelWithString: "")
    private let aboutWebsiteLabel = NSTextField(labelWithString: "")
    private let aboutGitHubLabel = NSTextField(labelWithString: "")
    private let aboutXLabel = NSTextField(labelWithString: "")
    private let aboutUpdateTitleLabel = NSTextField(labelWithString: "")
    private let aboutUpdateSummaryLabel = NSTextField(labelWithString: "")
    private let aboutUpdateStatusLabel = NSTextField(labelWithString: "")
    private let aboutUpdateSourceLabel = NSTextField(labelWithString: "")
    private let aboutUpdateStrategyLabel = NSTextField(labelWithString: "")
    private let aboutUpdateProgressLabel = NSTextField(labelWithString: "")
    private let aboutUpdateProgressIndicator = NSProgressIndicator()
    private lazy var aboutUpdatePrimaryButton = StyledSettingsButton(
        title: "Check for Updates",
        role: .primary,
        target: self,
        action: #selector(handleAboutUpdatePrimaryAction)
    )
    private lazy var aboutUpdateSecondaryButton = StyledSettingsButton(
        title: "View Release",
        role: .secondary,
        target: self,
        action: #selector(handleAboutUpdateSecondaryAction)
    )
    private let interfaceThemeControl = NSSegmentedControl()

    private let baseURLField = NSTextField(string: "")
    private let apiKeyField = NSSecureTextField(string: "")
    private let modelField = NSTextField(string: "")
    private let activePromptPopup = ThemedPopUpButton()
    private let resolvedPromptSummaryLabel = NSTextField(labelWithString: "")
    private lazy var resolvedPromptPreviewButton = StyledSettingsButton(
        title: "Preview",
        role: .secondary,
        target: self,
        action: #selector(previewResolvedPrompt)
    )
    private lazy var editPromptButton = StyledSettingsButton(
        title: "Edit",
        role: .secondary,
        target: self,
        action: #selector(editPromptPreset)
    )
    private lazy var newPromptButton = StyledSettingsButton(
        title: "New",
        role: .secondary,
        target: self,
        action: #selector(createPromptPreset)
    )
    private lazy var promptBindingsButton = StyledSettingsButton(
        title: Self.promptBindingsButtonTitle,
        role: .secondary,
        target: self,
        action: #selector(openPromptBindingsEditor)
    )
    private lazy var deletePromptButton = StyledSettingsButton(
        title: "Delete",
        role: .secondary,
        target: self,
        action: #selector(deletePromptPreset)
    )
    private let asrBackendPopup = ThemedPopUpButton()
    private let asrBaseURLField = NSTextField(string: "")
    private let asrAPIKeyField = NSSecureTextField(string: "")
    private let asrModelField = NSTextField(string: "")
    private let asrVolcengineAppIDField = NSTextField(string: "")
    private let asrPromptField = NSTextField(string: "")
    private lazy var asrVolcengineAppIDRow = makePreferenceRow(
        title: "Volcengine AppID",
        control: asrVolcengineAppIDField
    )
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
    private var aboutUpdatePresentation = AppUpdateExperience.cardPresentation(for: .idle(source: .unknown))
    private var aboutUpdatePrimaryAction: (() -> Void)?
    private var aboutUpdateSecondaryAction: (() -> Void)?
    private var promptLibrary: PromptLibrary?
    private var promptLibraryLoadError: String?
    private var promptWorkspaceDraft = PromptWorkspaceSettings()
    private var promptDestinationInspector = PromptDestinationInspector()
    private var promptEditorDraft: PromptPreset?
    private weak var promptEditorNameField: NSTextField?
    private weak var promptEditorAppBindingsField: NSTextField?
    private weak var promptEditorWebsiteHostsField: NSTextField?
    private weak var promptEditorBindingStatusLabel: NSTextField?
    private weak var promptEditorBodyTextView: NSTextView?

    var isPromptEditorSheetPresented: Bool {
        promptEditorDraft != nil || window?.attachedSheet != nil
    }

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

    func setAboutUpdatePresentation(
        _ presentation: AppUpdateCardPresentation,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        aboutUpdatePresentation = presentation
        aboutUpdatePrimaryAction = primaryAction
        aboutUpdateSecondaryAction = secondaryAction
        applyAboutUpdatePresentation()
    }

    func reloadFromModel() {
        applyThemeAppearance()
        loadCurrentValues()
        refreshPermissionLabels()
        refreshHomeSection()
        refreshASRSection()
        refreshLLMSection()
    }

    @objc
    private func handleAboutUpdatePrimaryAction() {
        aboutUpdatePrimaryAction?()
    }

    @objc
    private func handleAboutUpdateSecondaryAction() {
        aboutUpdateSecondaryAction?()
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

        asrAPIKeyField.placeholderString = "sk-..."
        asrPromptField.placeholderString = "Optional add-on hints (appended after VoicePi default ASR bias prompt)"
        applyASRPlaceholders(for: model.asrBackend)

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
            asrVolcengineAppIDRow,
            makePreferenceRow(title: "Prompt", control: asrPromptField)
        ])

        let buttons = makeButtonGroup([
            makeSecondaryActionButton(title: "Test Connection", action: #selector(testRemoteASRConfiguration)),
            makePrimaryActionButton(title: "Save", action: #selector(saveRemoteASRConfiguration))
        ])

        contentStack.addArrangedSubview(makeSectionHeader(title: "ASR", subtitle: "Choose Apple Speech, OpenAI-compatible ASR, Aliyun ASR, or Volcengine ASR."))
        contentStack.addArrangedSubview(makeBodyLabel("Use a remote backend when you want stronger large-model transcription quality. OpenAI-compatible ASR uploads captured audio after release, while Aliyun and Volcengine stream realtime audio over WebSocket and inject final text on release."))
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
            asrVolcengineAppIDField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            asrPromptField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
    }

    private func buildLLMView() {
        let contentStack = makePageStack()

        baseURLField.placeholderString = "https://api.example.com/v1"
        apiKeyField.placeholderString = "sk-..."
        modelField.placeholderString = "gpt-4o-mini"
        configurePostProcessingPopups()
        configurePromptWorkspaceControls()

        testButton.target = self
        testButton.action = #selector(testConfiguration)

        saveButton.target = self
        saveButton.action = #selector(saveConfiguration)
        saveButton.keyEquivalent = "\r"

        let resolvedPromptControl = NSStackView(views: [resolvedPromptSummaryLabel])
        resolvedPromptControl.orientation = .vertical
        resolvedPromptControl.alignment = .leading
        resolvedPromptControl.spacing = 8

        let promptActionsRow = makeButtonGroup([
            editPromptButton,
            newPromptButton,
            promptBindingsButton,
            deletePromptButton,
            resolvedPromptPreviewButton
        ])

        let configurationSection = makeGroupedSection(rows: [
            makePreferenceRow(title: "Mode", control: postProcessingModePopup),
            makePreferenceRow(title: "Translate Provider", control: translationProviderPopup),
            makePreferenceRow(title: "Target Language", control: targetLanguagePopup),
            makePreferenceRow(title: "API Base URL", control: baseURLField),
            makePreferenceRow(title: "API Key", control: apiKeyField),
            makePreferenceRow(title: "Model", control: modelField),
            makePreferenceRow(title: "Active Prompt", control: activePromptPopup),
            makePreferenceRow(title: "Prompt Summary", control: resolvedPromptControl),
            makePreferenceRow(title: "Prompt Actions", control: promptActionsRow)
        ])

        let buttons = makeButtonGroup([
            makeSecondaryActionButton(title: "Test Connection", action: #selector(testConfiguration)),
            makePrimaryActionButton(title: "Save", action: #selector(saveConfiguration))
        ])

        contentStack.addArrangedSubview(makeSectionHeader(title: "Text Processing", subtitle: "Choose between no processing, conservative LLM refinement, or explicit translation."))
        contentStack.addArrangedSubview(makeBodyLabel("Refinement always uses the LLM provider. Translation defaults to Apple Translate, and target-language output is folded into the LLM prompt whenever refinement mode is active."))
        contentStack.addArrangedSubview(makeBodyLabel("When Active Prompt is VoicePi Default, VoicePi checks any saved app and website bindings first, then falls back to the built-in default prompt. Starter prompts give you a baseline, and user prompts let you take full control over the editable middle section."))
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
            activePromptPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
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
        aboutRepositoryLabel.font = .systemFont(ofSize: 13)
        aboutRepositoryLabel.alignment = .left
        aboutRepositoryLabel.lineBreakMode = .byTruncatingTail
        aboutWebsiteLabel.font = .systemFont(ofSize: 13)
        aboutWebsiteLabel.alignment = .left
        aboutWebsiteLabel.lineBreakMode = .byTruncatingTail
        aboutGitHubLabel.font = .systemFont(ofSize: 13)
        aboutGitHubLabel.alignment = .left
        aboutGitHubLabel.lineBreakMode = .byTruncatingTail
        aboutXLabel.font = .systemFont(ofSize: 13)
        aboutXLabel.alignment = .left
        aboutXLabel.lineBreakMode = .byTruncatingTail
        aboutUpdateTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        aboutUpdateSummaryLabel.font = .systemFont(ofSize: 12.5)
        aboutUpdateSummaryLabel.textColor = .secondaryLabelColor
        aboutUpdateSummaryLabel.lineBreakMode = .byWordWrapping
        aboutUpdateSummaryLabel.maximumNumberOfLines = 0
        aboutUpdateStatusLabel.font = .systemFont(ofSize: 11.5, weight: .semibold)
        aboutUpdateStatusLabel.textColor = .secondaryLabelColor
        aboutUpdateSourceLabel.font = .systemFont(ofSize: 12)
        aboutUpdateSourceLabel.textColor = .secondaryLabelColor
        aboutUpdateStrategyLabel.font = .systemFont(ofSize: 12)
        aboutUpdateStrategyLabel.textColor = .secondaryLabelColor
        aboutUpdateStrategyLabel.lineBreakMode = .byWordWrapping
        aboutUpdateStrategyLabel.maximumNumberOfLines = 0
        aboutUpdateProgressLabel.font = .systemFont(ofSize: 11.5)
        aboutUpdateProgressLabel.textColor = .tertiaryLabelColor
        aboutUpdateProgressIndicator.isIndeterminate = false
        aboutUpdateProgressIndicator.minValue = 0
        aboutUpdateProgressIndicator.maxValue = 1
        aboutUpdateProgressIndicator.controlSize = .small
        aboutUpdatePrimaryButton.heightAnchor.constraint(
            equalToConstant: SettingsLayoutMetrics.actionButtonHeight
        ).isActive = true
        aboutUpdateSecondaryButton.heightAnchor.constraint(
            equalToConstant: SettingsLayoutMetrics.actionButtonHeight
        ).isActive = true

        let versionSection = makeGroupedSection(customViews: [
            makeAboutMetaRow(title: "Version", valueView: aboutVersionLabel),
            makeAboutMetaRow(title: "Build", valueView: aboutBuildLabel),
            makeAboutMetaRow(title: "Author", valueView: aboutAuthorLabel),
            makeAboutLinkRow(
                title: "Repository",
                valueView: aboutRepositoryLabel,
                buttonTitle: "Open",
                action: #selector(openRepository)
            ),
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
            description: "VoicePi is a lightweight macOS dictation utility that lives in the menu bar, captures speech with a shortcut, optionally refines or translates transcripts, and pastes the final text into the active app.",
            supplementaryContent: makeUpdateExperienceSection()
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
        asrVolcengineAppIDField.stringValue = model.remoteASRConfiguration.volcengineAppID
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
        loadPromptWorkspaceSelections()

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
        aboutRepositoryLabel.stringValue = aboutPresentation.repositoryLinkDisplay
        aboutWebsiteLabel.stringValue = aboutPresentation.websiteDisplay
        aboutGitHubLabel.stringValue = aboutPresentation.githubDisplay
        aboutXLabel.stringValue = aboutPresentation.xDisplay
        applyAboutUpdatePresentation()
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
        let selectedBackend = currentSelectedASRBackend()
        let configuration = currentRemoteASRConfigurationFromFields()
        let isRemoteBackend = selectedBackend.isRemoteBackend
        let requiresVolcengineAppID = selectedBackend == .remoteVolcengineASR

        applyASRPlaceholders(for: selectedBackend)

        asrBaseURLField.isEnabled = isRemoteBackend
        asrAPIKeyField.isEnabled = isRemoteBackend
        asrModelField.isEnabled = isRemoteBackend
        asrVolcengineAppIDField.isEnabled = isRemoteBackend && requiresVolcengineAppID
        asrPromptField.isEnabled = isRemoteBackend
        asrTestButton.isEnabled = isRemoteBackend
        asrVolcengineAppIDRow.isHidden = !requiresVolcengineAppID

        if !isRemoteBackend {
            setASRFeedback(.neutral("Apple Speech is active. VoicePi will use the built-in streaming recognizer."))
        } else if configuration.isConfigured(for: selectedBackend) {
            setASRFeedback(.neutral("\(selectedBackend.title) is selected and configured."))
        } else {
            setASRFeedback(.neutral("\(selectedBackend.title) is selected, but \(remoteASRRequiredFieldsText(for: selectedBackend)) are still required."))
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
        setPromptWorkspaceControlsEnabled(shouldEnablePromptControls)

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
            refinementPrompt: ""
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

    private func applyASRPlaceholders(for backend: ASRBackend) {
        asrBaseURLField.placeholderString = backend.remoteBaseURLPlaceholder
        asrModelField.placeholderString = backend.remoteModelPlaceholder
        asrVolcengineAppIDField.placeholderString = backend.remoteAppIDPlaceholder
    }

    private func currentRemoteASRConfigurationFromFields() -> RemoteASRConfiguration {
        RemoteASRConfiguration(
            baseURL: asrBaseURLField.stringValue,
            apiKey: asrAPIKeyField.stringValue,
            model: asrModelField.stringValue,
            prompt: asrPromptField.stringValue,
            volcengineAppID: asrVolcengineAppIDField.stringValue
        )
    }

    private func remoteASRRequiredFieldsText(for backend: ASRBackend) -> String {
        switch backend {
        case .remoteVolcengineASR:
            return "API Base URL, API Key, Model, and Volcengine AppID"
        case .remoteOpenAICompatible, .remoteAliyunASR:
            return "API Base URL, API Key, and Model"
        case .appleSpeech:
            return "configuration fields"
        }
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
        model.setPostProcessingMode(currentPostProcessingMode())
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
    private func activePromptChanged(_ sender: NSPopUpButton) {
        promptWorkspaceDraft.activeSelection = promptSelectionFromPopup(sender)
        updatePromptEditorState()
    }

    @objc
    private func editPromptPreset() {
        guard
            let selectedPreset = selectedPromptPresetFromDraft(),
            selectedPreset.source == .user
        else {
            return
        }

        presentPromptEditorSheet(for: selectedPreset)
    }

    @objc
    private func createPromptPreset() {
        let draft = Self.makeNewUserPromptDraft()
        presentPromptEditorSheet(for: draft)
    }

    static func bindingEntryAction(for source: PromptPresetSource) -> PromptBindingEntryAction {
        switch source {
        case .builtInDefault:
            return .createFromDefault
        case .starter:
            return .createFromStarter
        case .user:
            return .editUser
        }
    }

    static func makeNewUserPromptDraft(template: PromptPreset? = nil) -> PromptPreset {
        let id = "user.\(UUID().uuidString.lowercased())"
        guard let template else {
            return PromptPreset(
                id: id,
                title: "New Prompt",
                body: "",
                source: .user
            )
        }

        return PromptPreset(
            id: id,
            title: "\(template.resolvedTitle) Copy",
            body: template.body,
            source: .user,
            appBundleIDs: template.appBundleIDs,
            websiteHosts: template.websiteHosts
        )
    }

    static func makeNewUserPromptDraft(
        prefillingCapturedValue capturedRawValue: String,
        kind: PromptBindingKind
    ) -> PromptPreset {
        let normalized = PromptBindingActions.normalizedCapturedValue(capturedRawValue, kind: kind)
        return PromptPreset(
            id: "user.\(UUID().uuidString.lowercased())",
            title: "New Prompt",
            body: "",
            source: .user,
            appBundleIDs: kind == .appBundleID ? [normalized].compactMap { $0 } : [],
            websiteHosts: kind == .websiteHost ? [normalized].compactMap { $0 } : []
        )
    }

    struct PromptEditorBodyPalette: Equatable {
        let text: NSColor
        let background: NSColor
        let insertionPoint: NSColor
    }

    struct PromptEditorBodyContainerChrome: Equatable {
        let background: NSColor
        let border: NSColor
        let cornerRadius: CGFloat
    }

    static func promptEditorBodyPalette(for appearance: NSAppearance?) -> PromptEditorBodyPalette {
        let resolvedAppearance = appearance ?? NSApp.effectiveAppearance
        let isDarkTheme = resolvedAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let background = isDarkTheme
            ? NSColor(calibratedWhite: 0.205, alpha: 1)
            : NSColor(
                calibratedRed: 0xFC / 255.0,
                green: 0xFB / 255.0,
                blue: 0xF8 / 255.0,
                alpha: 1
            )

        return PromptEditorBodyPalette(
            text: .labelColor,
            background: background,
            insertionPoint: .labelColor
        )
    }

    static func promptEditorBodyContainerChrome(for appearance: NSAppearance?) -> PromptEditorBodyContainerChrome {
        let resolvedAppearance = appearance ?? NSApp.effectiveAppearance
        let isDarkTheme = resolvedAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        return PromptEditorBodyContainerChrome(
            background: isDarkTheme
                ? NSColor(calibratedWhite: 0.24, alpha: 1)
                : NSColor(
                    calibratedRed: 0xF6 / 255.0,
                    green: 0xF3 / 255.0,
                    blue: 0xEC / 255.0,
                    alpha: 1
                ),
            border: isDarkTheme
                ? NSColor(calibratedWhite: 1, alpha: 0.08)
                : NSColor(calibratedWhite: 0, alpha: 0.08),
            cornerRadius: 12
        )
    }

    func presentNewPromptEditor(
        prefillingCapturedValue capturedRawValue: String,
        kind: PromptBindingKind
    ) {
        selectSection(.llm)
        presentPromptEditorSheet(
            for: Self.makeNewUserPromptDraft(
                prefillingCapturedValue: capturedRawValue,
                kind: kind
            )
        )
    }
    @objc
    private func openPromptBindingsEditor() {
        guard let selectedPreset = selectedPromptPresetFromDraft() else { return }

        switch Self.bindingEntryAction(for: selectedPreset.source) {
        case .editUser:
            presentPromptEditorSheet(for: selectedPreset)
        case .createFromStarter:
            presentPromptEditorSheet(for: Self.makeNewUserPromptDraft(template: selectedPreset))
        case .createFromDefault:
            presentPromptEditorSheet(for: Self.makeNewUserPromptDraft())
        }
    }

    @objc
    private func deletePromptPreset() {
        guard
            let selectedPreset = selectedPromptPresetFromDraft(),
            selectedPreset.source == .user
        else {
            return
        }

        promptWorkspaceDraft.deleteUserPreset(id: selectedPreset.id)
        reloadPromptPopupItems()
        updatePromptEditorState()
    }

    @objc
    private func previewResolvedPrompt() {
        let previewText: String
        if promptWorkspaceDraft.activeSelection == .builtInDefault {
            let boundPresets = promptWorkspaceDraft.userPresets.filter {
                !$0.appBundleIDs.isEmpty || !$0.websiteHosts.isEmpty
            }

            if boundPresets.isEmpty {
                previewText = resolvedPromptTextFromControls()
                    ?? "VoicePi Default adds no extra editable middle section."
            } else {
                let bindingLines = boundPresets.map { preset in
                    let appSummary = preset.appBundleIDs.isEmpty
                        ? "Apps none"
                        : "Apps \(preset.appBundleIDs.joined(separator: ", "))"
                    let websiteSummary = preset.websiteHosts.isEmpty
                        ? "Sites none"
                        : "Sites \(preset.websiteHosts.joined(separator: ", "))"
                    return "- \(preset.resolvedTitle): \(appSummary) • \(websiteSummary)"
                }.joined(separator: "\n")

                previewText = """
                VoicePi Default remains the fallback when no manual binding matches.

                Automatic bindings:
                \(bindingLines)
                """
            }
        } else {
            previewText = resolvedPromptTextFromControls()
                ?? "VoicePi Default adds no extra editable middle section."
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
            prompt: configuration.prompt,
            volcengineAppID: configuration.volcengineAppID
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
        let selectedBackend = currentSelectedASRBackend()

        guard selectedBackend.isRemoteBackend else {
            setASRFeedback(.error("Switch to the remote backend before testing the remote ASR connection."))
            return
        }

        guard configuration.isConfigured(for: selectedBackend) else {
            setASRFeedback(.error("Please complete \(remoteASRRequiredFieldsText(for: selectedBackend)) before testing."))
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
        model.promptWorkspace = promptWorkspaceDraft
        if mode == .refinement {
            configuration.refinementPrompt = resolvedPromptTextFromControls() ?? ""
        } else {
            configuration.refinementPrompt = ""
        }
        model.saveLLMConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model,
            refinementPrompt: ""
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
        asrTestButton.isEnabled = enabled && currentSelectedASRBackend().isRemoteBackend
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
        activePromptPopup.syncTheme()
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

    private func starterPromptPresets() -> [PromptPreset] {
        model.starterPromptPresets()
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

    private func configurePromptWorkspaceControls() {
        do {
            promptLibrary = try PromptLibrary.loadBundled()
            promptLibraryLoadError = nil
        } catch let error as PromptLibraryError {
            promptLibrary = nil
            promptLibraryLoadError = error.diagnosticDescription
        } catch {
            promptLibrary = nil
            promptLibraryLoadError = String(describing: error)
        }

        resolvedPromptSummaryLabel.font = .systemFont(ofSize: 12)
        resolvedPromptSummaryLabel.textColor = .secondaryLabelColor
        resolvedPromptSummaryLabel.lineBreakMode = .byWordWrapping
        resolvedPromptSummaryLabel.maximumNumberOfLines = 4
        resolvedPromptSummaryLabel.stringValue = "Active prompt: VoicePi Default"
        resolvedPromptPreviewButton.isEnabled = false

        activePromptPopup.target = self
        activePromptPopup.action = #selector(activePromptChanged(_:))

        reloadPromptPopupItems()
    }

    private func reloadPromptPopupItems() {
        activePromptPopup.removeAllItems()

        activePromptPopup.addItem(withTitle: PromptPreset.builtInDefault.title)
        activePromptPopup.lastItem?.representedObject = "default"

        for preset in starterPromptPresets() {
            activePromptPopup.addItem(withTitle: preset.title)
            activePromptPopup.lastItem?.representedObject = "preset:\(preset.id)"
        }

        for preset in promptWorkspaceDraft.userPresets.sorted(by: {
            $0.resolvedTitle.localizedCaseInsensitiveCompare($1.resolvedTitle) == .orderedAscending
        }) {
            activePromptPopup.addItem(withTitle: preset.resolvedTitle)
            activePromptPopup.lastItem?.representedObject = "preset:\(preset.id)"
        }
    }

    private func loadPromptWorkspaceSelections() {
        promptWorkspaceDraft = model.promptWorkspace
        reloadPromptPopupItems()
        selectPromptWorkspaceItem(in: activePromptPopup, for: promptWorkspaceDraft.activeSelection)
        promptEditorDraft = nil
        updatePromptEditorState()
    }

    private func selectPromptWorkspaceItem(
        in popup: NSPopUpButton,
        for selection: PromptActiveSelection
    ) {
        let token: String
        switch selection.mode {
        case .builtInDefault:
            token = "default"
        case .preset:
            token = selection.presetID.map { "preset:\($0)" } ?? "default"
        }

        let index = popup.indexOfItem(withRepresentedObject: token)
        if index >= 0 {
            popup.selectItem(at: index)
        } else {
            popup.selectItem(at: 0)
        }
    }

    private func promptSelectionFromPopup(_ popup: NSPopUpButton) -> PromptActiveSelection {
        guard let token = popup.selectedItem?.representedObject as? String else {
            return .builtInDefault
        }

        switch token {
        case "default":
            return .builtInDefault
        case let token where token.hasPrefix("preset:"):
            return .preset(String(token.dropFirst("preset:".count)))
        default:
            return .builtInDefault
        }
    }

    private func selectedPromptPresetFromDraft() -> PromptPreset? {
        switch promptWorkspaceDraft.activeSelection.mode {
        case .builtInDefault:
            return PromptPreset.builtInDefault
        case .preset:
            guard let presetID = promptWorkspaceDraft.activeSelection.presetID else { return nil }
            if let userPreset = promptWorkspaceDraft.userPreset(id: presetID) {
                return userPreset
            }
            return starterPromptPresets().first(where: { $0.id == presetID })
        }
    }

    private func updatePromptEditorState() {
        let selectedPreset = selectedPromptPresetFromDraft() ?? PromptPreset.builtInDefault
        editPromptButton.isEnabled = selectedPreset.source == .user
        deletePromptButton.isEnabled = selectedPreset.source == .user

        updateResolvedPromptSummary()
    }

    private func setPromptWorkspaceControlsEnabled(_ enabled: Bool) {
        activePromptPopup.isEnabled = enabled
        editPromptButton.isEnabled = enabled && (selectedPromptPresetFromDraft()?.source == .user)
        newPromptButton.isEnabled = enabled
        promptBindingsButton.isEnabled = enabled
        deletePromptButton.isEnabled = enabled && (selectedPromptPresetFromDraft()?.source == .user)
        resolvedPromptPreviewButton.isEnabled = enabled
    }

    private func resolvedPromptFromControls() -> ResolvedPromptPreset {
        let library = promptLibrary ?? PromptLibrary(
            optionGroups: [:],
            profiles: [:],
            fragments: [:],
            appPolicies: [:]
        )

        return PromptWorkspaceResolver.resolve(
            workspace: promptWorkspaceDraft,
            library: library
        )
    }

    private func resolvedPromptTextFromControls() -> String? {
        return resolvedPromptFromControls().middleSection
    }

    private func presentPromptEditorSheet(for preset: PromptPreset) {
        guard preset.source == .user else { return }

        promptEditorDraft = preset

        let sheetSize = NSSize(width: 760, height: 664)
        let sheet = PreviewSheetWindow(
            contentRect: NSRect(origin: .zero, size: sheetSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        sheet.title = Self.promptEditorSheetTitle(for: preset)
        sheet.setContentSize(sheetSize)
        sheet.minSize = sheetSize
        sheet.appearance = window?.effectiveAppearance ?? window?.appearance
        sheet.onCloseRequest = { [weak self] in
            self?.cancelPromptEditorSheet()
        }

        let nameLabel = NSTextField(labelWithString: "Prompt Name")
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor = .secondaryLabelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameField = NSTextField(string: preset.resolvedTitle)
        nameField.placeholderString = "Short name, for example Meeting Notes"
        nameField.font = .systemFont(ofSize: 14, weight: .medium)
        nameField.controlSize = .large
        nameField.translatesAutoresizingMaskIntoConstraints = false

        let bindingsTitleLabel = NSTextField(labelWithString: "Automatic Bindings")
        bindingsTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bindingsTitleLabel.textColor = .labelColor
        bindingsTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bindingsSubtitleLabel = NSTextField(
            wrappingLabelWithString: "Use captures to target this prompt to the frontmost app or current site while Active Prompt stays on VoicePi Default."
        )
        bindingsSubtitleLabel.font = .systemFont(ofSize: 12)
        bindingsSubtitleLabel.textColor = .secondaryLabelColor
        bindingsSubtitleLabel.maximumNumberOfLines = 0
        bindingsSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let captureFrontmostAppButton = makeSecondaryActionButton(
            title: Self.captureFrontmostAppButtonTitle,
            action: #selector(captureFrontmostAppBinding)
        )
        captureFrontmostAppButton.translatesAutoresizingMaskIntoConstraints = false

        let captureCurrentWebsiteButton = makeSecondaryActionButton(
            title: Self.captureCurrentWebsiteButtonTitle,
            action: #selector(captureCurrentWebsiteBinding)
        )
        captureCurrentWebsiteButton.translatesAutoresizingMaskIntoConstraints = false

        let bindingActionButtons = NSStackView(views: [captureFrontmostAppButton, captureCurrentWebsiteButton])
        bindingActionButtons.orientation = .vertical
        bindingActionButtons.alignment = .leading
        bindingActionButtons.distribution = .fill
        bindingActionButtons.spacing = 8
        bindingActionButtons.translatesAutoresizingMaskIntoConstraints = false

        let bindingStatusLabel = NSTextField(labelWithString: "")
        bindingStatusLabel.font = .systemFont(ofSize: 12)
        bindingStatusLabel.textColor = .secondaryLabelColor
        bindingStatusLabel.lineBreakMode = .byWordWrapping
        bindingStatusLabel.maximumNumberOfLines = 0
        bindingStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        let appBindingsLabel = NSTextField(labelWithString: "App Bundle IDs")
        appBindingsLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        appBindingsLabel.textColor = .secondaryLabelColor
        appBindingsLabel.translatesAutoresizingMaskIntoConstraints = false

        let appBindingsField = NSTextField(string: preset.appBundleIDs.joined(separator: ", "))
        appBindingsField.placeholderString = "com.tinyspeck.slackmacgap, com.figma.Desktop"
        appBindingsField.translatesAutoresizingMaskIntoConstraints = false

        let websiteBindingsLabel = NSTextField(labelWithString: "Website Hosts")
        websiteBindingsLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        websiteBindingsLabel.textColor = .secondaryLabelColor
        websiteBindingsLabel.translatesAutoresizingMaskIntoConstraints = false

        let websiteBindingsField = NSTextField(string: preset.websiteHosts.joined(separator: ", "))
        websiteBindingsField.placeholderString = "mail.google.com, trello.com, *.notion.so"
        websiteBindingsField.translatesAutoresizingMaskIntoConstraints = false

        let bindingsHintLabel = NSTextField(
            wrappingLabelWithString: "You can type comma-separated bundle IDs or hosts manually if capture is not enough."
        )
        bindingsHintLabel.font = .systemFont(ofSize: 12)
        bindingsHintLabel.textColor = .secondaryLabelColor
        bindingsHintLabel.maximumNumberOfLines = 0
        bindingsHintLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = NSTextField(labelWithString: "Instructions")
        bodyLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bodyLabel.textColor = .labelColor
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyHintLabel = NSTextField(
            wrappingLabelWithString: Self.promptEditorBodyHintText
        )
        bodyHintLabel.font = .systemFont(ofSize: 12)
        bodyHintLabel.textColor = .secondaryLabelColor
        bodyHintLabel.maximumNumberOfLines = 0
        bodyHintLabel.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView(frame: .zero)
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.font = Self.promptEditorBodyFont
        textView.textContainerInset = Self.promptEditorBodyTextInset
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.autoresizingMask = .width
        let bodyPalette = Self.promptEditorBodyPalette(for: sheet.appearance)
        textView.textColor = bodyPalette.text
        textView.backgroundColor = bodyPalette.background
        textView.insertionPointColor = bodyPalette.insertionPoint
        textView.typingAttributes = [
            .font: textView.font ?? Self.promptEditorBodyFont,
            .foregroundColor: bodyPalette.text
        ]
        textView.string = preset.body

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        let bodyContainerChrome = Self.promptEditorBodyContainerChrome(for: sheet.appearance)
        let bodyContainer = NSView()
        bodyContainer.translatesAutoresizingMaskIntoConstraints = false
        bodyContainer.wantsLayer = true
        bodyContainer.layer?.cornerRadius = bodyContainerChrome.cornerRadius
        bodyContainer.layer?.borderWidth = 1
        bodyContainer.layer?.borderColor = bodyContainerChrome.border.cgColor
        bodyContainer.layer?.backgroundColor = bodyContainerChrome.background.cgColor
        bodyContainer.addSubview(scrollView)

        let cancelButton = makeSecondaryActionButton(
            title: "Cancel",
            action: #selector(cancelPromptEditorSheet)
        )
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.keyEquivalent = "\u{1b}"

        let saveButton = makePrimaryActionButton(
            title: Self.promptEditorPrimaryActionTitle(for: preset),
            action: #selector(savePromptEditorSheet)
        )
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.keyEquivalent = "\r"
        saveButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 118).isActive = true
        cancelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 94).isActive = true

        let buttonRow = NSStackView(views: [NSView(), cancelButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let nameStack = NSStackView(views: [nameLabel, nameField])
        nameStack.orientation = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = SettingsLayoutMetrics.promptEditorFieldSpacing
        nameField.widthAnchor.constraint(equalTo: nameStack.widthAnchor).isActive = true

        let bindingsStack = NSStackView(views: [
            bindingsTitleLabel,
            bindingsSubtitleLabel,
            bindingActionButtons,
            bindingStatusLabel,
            appBindingsLabel,
            appBindingsField,
            websiteBindingsLabel,
            websiteBindingsField,
            bindingsHintLabel
        ])
        bindingsStack.orientation = .vertical
        bindingsStack.alignment = .leading
        bindingsStack.spacing = SettingsLayoutMetrics.promptEditorFieldSpacing
        bindingsStack.setCustomSpacing(SettingsLayoutMetrics.promptEditorSectionSpacing, after: bindingsSubtitleLabel)
        bindingsStack.setCustomSpacing(SettingsLayoutMetrics.promptEditorSectionSpacing, after: bindingStatusLabel)
        bindingsStack.setCustomSpacing(SettingsLayoutMetrics.promptEditorSectionSpacing, after: appBindingsField)
        bindingsStack.setCustomSpacing(SettingsLayoutMetrics.promptEditorSectionSpacing, after: websiteBindingsField)
        bindingActionButtons.widthAnchor.constraint(equalTo: bindingsStack.widthAnchor).isActive = true
        bindingStatusLabel.widthAnchor.constraint(equalTo: bindingsStack.widthAnchor).isActive = true
        appBindingsField.widthAnchor.constraint(equalTo: bindingsStack.widthAnchor).isActive = true
        websiteBindingsField.widthAnchor.constraint(equalTo: bindingsStack.widthAnchor).isActive = true
        bindingsHintLabel.widthAnchor.constraint(equalTo: bindingsStack.widthAnchor).isActive = true

        let bindingsCard = makeCardView()
        pinCardContent(bindingsStack, into: bindingsCard)
        bindingsCard.translatesAutoresizingMaskIntoConstraints = false
        bindingsCard.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.promptEditorSidebarWidth).isActive = true

        let bodyStack = NSStackView(views: [bodyLabel, bodyHintLabel, bodyContainer])
        bodyStack.orientation = .vertical
        bodyStack.alignment = .leading
        bodyStack.spacing = SettingsLayoutMetrics.promptEditorFieldSpacing
        bodyContainer.widthAnchor.constraint(equalTo: bodyStack.widthAnchor).isActive = true
        bodyHintLabel.widthAnchor.constraint(equalTo: bodyStack.widthAnchor).isActive = true

        let bodyCard = makeCardView()
        pinCardContent(bodyStack, into: bodyCard)
        bodyCard.translatesAutoresizingMaskIntoConstraints = false

        let contentSplit = NSStackView(views: [bindingsCard, bodyCard])
        contentSplit.orientation = .horizontal
        contentSplit.alignment = .top
        contentSplit.distribution = .fill
        contentSplit.spacing = SettingsLayoutMetrics.promptEditorSectionSpacing
        contentSplit.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView(views: [nameStack, contentSplit])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = SettingsLayoutMetrics.promptEditorSectionSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        nameStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        contentSplit.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        bodyCard.widthAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true

        let contentView = NSView()
        contentView.addSubview(contentStack)
        contentView.addSubview(buttonRow)
        sheet.contentView = contentView

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: sheetSize.width),
            contentView.heightAnchor.constraint(equalToConstant: sheetSize.height),

            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SettingsLayoutMetrics.promptEditorOuterInset),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SettingsLayoutMetrics.promptEditorOuterInset),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SettingsLayoutMetrics.promptEditorOuterInset),
            contentStack.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -SettingsLayoutMetrics.promptEditorSectionSpacing),

            bodyContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsLayoutMetrics.promptEditorBodyMinHeight),

            scrollView.leadingAnchor.constraint(equalTo: bodyContainer.leadingAnchor, constant: 1),
            scrollView.trailingAnchor.constraint(equalTo: bodyContainer.trailingAnchor, constant: -1),
            scrollView.topAnchor.constraint(equalTo: bodyContainer.topAnchor, constant: 1),
            scrollView.bottomAnchor.constraint(equalTo: bodyContainer.bottomAnchor, constant: -1),

            buttonRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SettingsLayoutMetrics.promptEditorOuterInset),
            buttonRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SettingsLayoutMetrics.promptEditorOuterInset),
            buttonRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SettingsLayoutMetrics.promptEditorOuterInset)
        ])

        promptEditorNameField = nameField
        promptEditorAppBindingsField = appBindingsField
        promptEditorWebsiteHostsField = websiteBindingsField
        promptEditorBindingStatusLabel = bindingStatusLabel
        promptEditorBodyTextView = textView

        if let attachedSheet = window?.attachedSheet {
            window?.endSheet(attachedSheet)
        }
        window?.beginSheet(sheet)
        sheet.initialFirstResponder = textView
        sheet.makeFirstResponder(textView)
    }

    @objc
    private func savePromptEditorSheet() {
        guard var draft = promptEditorDraft else {
            closePromptEditorSheet()
            return
        }

        let title = promptEditorNameField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = promptEditorBodyTextView?.string ?? draft.body
        let appBundleIDs = promptBindingValues(from: promptEditorAppBindingsField?.stringValue ?? "")
        let websiteHosts = promptBindingValues(from: promptEditorWebsiteHostsField?.stringValue ?? "")
        draft = PromptPreset(
            id: draft.id,
            title: title.isEmpty ? "Untitled Prompt" : title,
            body: body,
            source: draft.source,
            appBundleIDs: appBundleIDs,
            websiteHosts: websiteHosts
        )

        promptWorkspaceDraft.saveUserPreset(draft)
        promptWorkspaceDraft.activeSelection = .preset(draft.id)
        reloadPromptPopupItems()
        selectPromptWorkspaceItem(in: activePromptPopup, for: .preset(draft.id))
        updatePromptEditorState()
        closePromptEditorSheet()
    }

    @objc
    private func cancelPromptEditorSheet() {
        closePromptEditorSheet()
    }

    @objc
    private func captureFrontmostAppBinding() {
        let destination = promptDestinationInspector.currentDestinationContext()
        applyCapturedPromptBinding(
            kind: .appBundleID,
            capturedRawValue: destination.appBundleID,
            field: promptEditorAppBindingsField,
            unavailableMessage: "Couldn't capture a frontmost app bundle ID. Bring the target app to the front and try again."
        )
    }

    @objc
    private func captureCurrentWebsiteBinding() {
        let destination = promptDestinationInspector.currentDestinationContext()
        applyCapturedPromptBinding(
            kind: .websiteHost,
            capturedRawValue: destination.websiteHost,
            field: promptEditorWebsiteHostsField,
            unavailableMessage: "Couldn't capture a website host from the frontmost browser tab. Make sure Safari or a supported Chromium browser is frontmost."
        )
    }

    private func closePromptEditorSheet() {
        promptEditorDraft = nil
        promptEditorNameField = nil
        promptEditorAppBindingsField = nil
        promptEditorWebsiteHostsField = nil
        promptEditorBindingStatusLabel = nil
        promptEditorBodyTextView = nil
        if let sheet = window?.attachedSheet {
            window?.endSheet(sheet)
        }
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
        let resolved = resolvedPromptFromControls()
        switch resolved.source {
        case .builtInDefault:
            resolvedPromptSummaryLabel.stringValue = "Active prompt: \(resolved.title)"
        case .starter:
            resolvedPromptSummaryLabel.stringValue = "Active starter prompt: \(resolved.title)"
        case .user:
            resolvedPromptSummaryLabel.stringValue = "Active custom prompt: \(resolved.title)"
        }

        if let selectedPreset = selectedPromptPresetFromDraft(),
           let bindingSummary = promptBindingSummary(for: selectedPreset) {
            resolvedPromptSummaryLabel.stringValue += " • \(bindingSummary)"
        } else if promptWorkspaceDraft.activeSelection == .builtInDefault {
            let automaticBindingsCount = promptWorkspaceDraft.userPresets.filter {
                !$0.appBundleIDs.isEmpty || !$0.websiteHosts.isEmpty
            }.count
            if automaticBindingsCount > 0 {
                let noun = automaticBindingsCount == 1 ? "bound prompt" : "bound prompts"
                resolvedPromptSummaryLabel.stringValue += " • Automatic mode checks \(automaticBindingsCount) \(noun)"
            }
        }

        if let promptLibraryLoadError {
            resolvedPromptSummaryLabel.stringValue += " (\(promptLibraryLoadError))"
        }
    }

    static func bindingValues(from text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func mergeBindingFieldText(
        existingText: String,
        capturedRawValue: String?,
        kind: PromptBindingKind
    ) -> String {
        PromptBindingActions.mergeBindingValues(
            existingValues: bindingValues(from: existingText),
            capturedRawValue: capturedRawValue,
            kind: kind
        ).joined(separator: ", ")
    }

    private func promptBindingValues(from text: String) -> [String] {
        Self.bindingValues(from: text)
    }

    private func applyCapturedPromptBinding(
        kind: PromptBindingKind,
        capturedRawValue: String?,
        field: NSTextField?,
        unavailableMessage: String
    ) {
        guard let field else { return }

        guard let captured = PromptBindingActions.normalizedCapturedValue(capturedRawValue, kind: kind) else {
            setPromptEditorBindingStatus(unavailableMessage, isError: true)
            return
        }

        let previousValues = Set(
            PromptBindingActions.mergeBindingValues(
                existingValues: Self.bindingValues(from: field.stringValue),
                capturedRawValue: nil,
                kind: kind
            )
        )
        field.stringValue = Self.mergeBindingFieldText(
            existingText: field.stringValue,
            capturedRawValue: captured,
            kind: kind
        )

        if previousValues.contains(captured) {
            setPromptEditorBindingStatus("Already added: \(captured)")
            return
        }

        setPromptEditorBindingStatus("Added \(captured)")
    }

    private func setPromptEditorBindingStatus(_ message: String, isError: Bool = false) {
        promptEditorBindingStatusLabel?.stringValue = message
        promptEditorBindingStatusLabel?.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private func promptBindingSummary(for preset: PromptPreset) -> String? {
        var parts: [String] = []

        if !preset.appBundleIDs.isEmpty {
            let noun = preset.appBundleIDs.count == 1 ? "app" : "apps"
            parts.append("\(preset.appBundleIDs.count) \(noun)")
        }

        if !preset.websiteHosts.isEmpty {
            let noun = preset.websiteHosts.count == 1 ? "site" : "sites"
            parts.append("\(preset.websiteHosts.count) \(noun)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
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

    private func makeAboutOverviewCard(
        title: String,
        description: String,
        supplementaryContent: NSView? = nil
    ) -> NSView {
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
            }
        })

        if let supplementaryContent {
            let divider = NSBox()
            divider.boxType = .separator
            views.append(divider)
            views.append(supplementaryContent)
        }

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    private func makeUpdateExperienceSection() -> NSView {
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle", accessibilityDescription: "Updates")
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)

        let headerStack = NSStackView(views: [iconView, aboutUpdateTitleLabel, NSView(), makeStatusPill(label: aboutUpdateStatusLabel)])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8

        let detailStack = NSStackView(views: [aboutUpdateSourceLabel, aboutUpdateStrategyLabel])
        detailStack.orientation = .vertical
        detailStack.spacing = 4
        detailStack.alignment = .leading

        let progressStack = NSStackView(views: [aboutUpdateProgressLabel, aboutUpdateProgressIndicator])
        progressStack.orientation = .vertical
        progressStack.spacing = 6
        progressStack.alignment = .leading

        let buttonRow = makeButtonGroup([aboutUpdatePrimaryButton, aboutUpdateSecondaryButton])

        let stack = NSStackView(views: [headerStack, aboutUpdateSummaryLabel, detailStack, progressStack, buttonRow])
        stack.orientation = .vertical
        stack.spacing = SettingsLayoutMetrics.pageSpacing
        stack.alignment = .leading
        return stack
    }

    private func applyAboutUpdatePresentation() {
        aboutUpdateTitleLabel.stringValue = aboutUpdatePresentation.title
        aboutUpdateSummaryLabel.stringValue = aboutUpdatePresentation.summary
        aboutUpdateStatusLabel.stringValue = aboutUpdatePresentation.statusText
        aboutUpdateSourceLabel.stringValue = aboutUpdatePresentation.sourceText
        aboutUpdateStrategyLabel.stringValue = aboutUpdatePresentation.strategyText

        aboutUpdatePrimaryButton.title = aboutUpdatePresentation.primaryAction.title
        aboutUpdatePrimaryButton.isEnabled = aboutUpdatePresentation.primaryAction.isEnabled && aboutUpdatePrimaryAction != nil
        aboutUpdatePrimaryButton.applyAppearance(isSelected: false)

        if let secondary = aboutUpdatePresentation.secondaryAction {
            aboutUpdateSecondaryButton.title = secondary.title
            aboutUpdateSecondaryButton.isHidden = false
            aboutUpdateSecondaryButton.isEnabled = secondary.isEnabled && aboutUpdateSecondaryAction != nil
            aboutUpdateSecondaryButton.applyAppearance(isSelected: false)
        } else {
            aboutUpdateSecondaryButton.isHidden = true
            aboutUpdateSecondaryButton.isEnabled = false
        }

        if let progress = aboutUpdatePresentation.progress {
            aboutUpdateProgressLabel.stringValue = progress.label
            aboutUpdateProgressLabel.isHidden = false
            aboutUpdateProgressIndicator.isHidden = false
            aboutUpdateProgressIndicator.isIndeterminate = progress.isIndeterminate
            if progress.isIndeterminate {
                aboutUpdateProgressIndicator.startAnimation(nil)
            } else {
                aboutUpdateProgressIndicator.stopAnimation(nil)
                aboutUpdateProgressIndicator.doubleValue = progress.fraction ?? 0
            }
        } else {
            aboutUpdateProgressLabel.isHidden = true
            aboutUpdateProgressIndicator.isHidden = true
            aboutUpdateProgressIndicator.stopAnimation(nil)
        }
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

@MainActor
private final class AppUpdatePanelController: NSWindowController, NSWindowDelegate {
    private let titleLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "")
    private let strategyLabel = NSTextField(labelWithString: "")
    private let progressLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let releaseNotesTitleLabel = NSTextField(labelWithString: "Release Notes")
    private let releaseNotesTextView = NSTextView(
        frame: NSRect(
            x: 0,
            y: 0,
            width: SettingsLayoutMetrics.updatePanelWidth
                - (SettingsLayoutMetrics.updatePanelOuterInset * 2)
                - (SettingsLayoutMetrics.cardPaddingHorizontal * 2),
            height: SettingsLayoutMetrics.updatePanelNotesHeight
        )
    )
    private let releaseNotesScrollView = NSScrollView()
    private lazy var primaryButton = StyledSettingsButton(
        title: "",
        role: .primary,
        target: self,
        action: #selector(handlePrimaryAction)
    )
    private lazy var secondaryButton = StyledSettingsButton(
        title: "",
        role: .secondary,
        target: self,
        action: #selector(handleSecondaryAction)
    )
    private lazy var tertiaryButton = StyledSettingsButton(
        title: "",
        role: .secondary,
        target: self,
        action: #selector(handleTertiaryAction)
    )

    private var primaryRole: AppUpdateActionRole = .dismiss
    private var secondaryRole: AppUpdateActionRole?
    private var tertiaryRole: AppUpdateActionRole?
    private var actionHandler: ((AppUpdateActionRole) -> Void)?
    var interfaceAppearance: NSAppearance? {
        didSet {
            window?.appearance = interfaceAppearance
            syncTheme()
        }
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: SettingsLayoutMetrics.updatePanelWidth,
                height: SettingsLayoutMetrics.updatePanelMinHeight
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoicePi Update"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(
            width: SettingsLayoutMetrics.updatePanelWidth,
            height: SettingsLayoutMetrics.updatePanelMinHeight
        )
        window.titlebarAppearsTransparent = true
        window.center()

        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(
        _ presentation: AppUpdatePanelPresentation,
        actionHandler: @escaping (AppUpdateActionRole) -> Void
    ) {
        self.actionHandler = actionHandler
        syncTheme()
        apply(presentation)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismissPanel() {
        close()
    }

    func windowWillClose(_ notification: Notification) {
        actionHandler = nil
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        syncTheme()

        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.lineBreakMode = .byWordWrapping
        summaryLabel.maximumNumberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 11.5, weight: .semibold)
        statusLabel.textColor = .secondaryLabelColor
        sourceLabel.font = .systemFont(ofSize: 12)
        sourceLabel.textColor = .secondaryLabelColor
        strategyLabel.font = .systemFont(ofSize: 12)
        strategyLabel.textColor = .secondaryLabelColor
        strategyLabel.lineBreakMode = .byWordWrapping
        strategyLabel.maximumNumberOfLines = 0
        progressLabel.font = .systemFont(ofSize: 11.5)
        progressLabel.textColor = .tertiaryLabelColor
        progressIndicator.controlSize = .small
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.isIndeterminate = false
        releaseNotesTitleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        releaseNotesTextView.isEditable = false
        releaseNotesTextView.isSelectable = true
        releaseNotesTextView.isAutomaticLinkDetectionEnabled = true
        releaseNotesTextView.isHorizontallyResizable = false
        releaseNotesTextView.isVerticallyResizable = true
        releaseNotesTextView.autoresizingMask = [.width]
        releaseNotesTextView.drawsBackground = false
        releaseNotesTextView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        releaseNotesTextView.textContainerInset = NSSize(width: 0, height: 4)
        releaseNotesTextView.textColor = .secondaryLabelColor
        releaseNotesTextView.font = .systemFont(ofSize: 12)
        releaseNotesTextView.minSize = NSSize(
            width: releaseNotesTextView.frame.width,
            height: SettingsLayoutMetrics.updatePanelNotesHeight
        )
        releaseNotesTextView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        releaseNotesTextView.textContainer?.containerSize = NSSize(
            width: releaseNotesTextView.frame.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        releaseNotesTextView.textContainer?.widthTracksTextView = true
        releaseNotesScrollView.drawsBackground = false
        releaseNotesScrollView.hasVerticalScroller = true
        releaseNotesScrollView.hasHorizontalScroller = false
        releaseNotesScrollView.documentView = releaseNotesTextView
        releaseNotesScrollView.translatesAutoresizingMaskIntoConstraints = false
        releaseNotesScrollView.heightAnchor.constraint(
            equalToConstant: SettingsLayoutMetrics.updatePanelNotesHeight
        ).isActive = true

        let statusPill = ThemedSurfaceView(style: .pill)
        statusPill.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -10),
            statusLabel.topAnchor.constraint(equalTo: statusPill.topAnchor, constant: 4),
            statusLabel.bottomAnchor.constraint(equalTo: statusPill.bottomAnchor, constant: -4)
        ])

        let headerRow = NSStackView(views: [titleLabel, NSView(), statusPill])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 10

        let detailStack = NSStackView(views: [sourceLabel, strategyLabel])
        detailStack.orientation = .vertical
        detailStack.spacing = 4
        detailStack.alignment = .leading

        let progressStack = NSStackView(views: [progressLabel, progressIndicator])
        progressStack.orientation = .vertical
        progressStack.spacing = 6
        progressStack.alignment = .leading

        let notesStack = NSStackView(views: [releaseNotesTitleLabel, releaseNotesScrollView])
        notesStack.orientation = .vertical
        notesStack.spacing = 8
        notesStack.alignment = .leading

        let buttonRow = NSStackView(views: [primaryButton, secondaryButton, tertiaryButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY

        let container = ThemedSurfaceView(style: .card)
        container.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView(views: [headerRow, summaryLabel, detailStack, progressStack, notesStack, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        contentView.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SettingsLayoutMetrics.updatePanelOuterInset),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SettingsLayoutMetrics.updatePanelOuterInset),
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SettingsLayoutMetrics.updatePanelOuterInset),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SettingsLayoutMetrics.updatePanelOuterInset),

            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: SettingsLayoutMetrics.cardPaddingHorizontal),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -SettingsLayoutMetrics.cardPaddingHorizontal),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: SettingsLayoutMetrics.cardPaddingVertical),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -SettingsLayoutMetrics.cardPaddingVertical),

            progressIndicator.widthAnchor.constraint(equalTo: stack.widthAnchor),
            releaseNotesScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func syncTheme() {
        guard let window, let contentView = window.contentView else { return }
        window.appearance = interfaceAppearance
        let appearance = interfaceAppearance ?? window.effectiveAppearance
        let isDarkTheme = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let pageBackgroundColor = isDarkTheme
            ? NSColor(calibratedWhite: 0.16, alpha: 1)
            : NSColor(calibratedRed: 0xF5 / 255.0, green: 0xF3 / 255.0, blue: 0xED / 255.0, alpha: 1)
        window.backgroundColor = pageBackgroundColor
        contentView.layer?.backgroundColor = pageBackgroundColor.cgColor
    }

    private func apply(_ presentation: AppUpdatePanelPresentation) {
        titleLabel.stringValue = presentation.title
        summaryLabel.stringValue = presentation.summary
        statusLabel.stringValue = presentation.statusText
        sourceLabel.stringValue = presentation.sourceText
        strategyLabel.stringValue = presentation.strategyText

        primaryButton.title = presentation.primaryAction.title
        primaryButton.isEnabled = presentation.primaryAction.isEnabled
        primaryButton.applyAppearance(isSelected: false)
        primaryRole = presentation.primaryAction.role

        if let secondary = presentation.secondaryAction {
            secondaryButton.isHidden = false
            secondaryButton.title = secondary.title
            secondaryButton.isEnabled = secondary.isEnabled
            secondaryButton.applyAppearance(isSelected: false)
            secondaryRole = secondary.role
        } else {
            secondaryButton.isHidden = true
            secondaryButton.isEnabled = false
            secondaryRole = nil
        }

        if let tertiary = presentation.tertiaryAction {
            tertiaryButton.isHidden = false
            tertiaryButton.title = tertiary.title
            tertiaryButton.isEnabled = tertiary.isEnabled
            tertiaryButton.applyAppearance(isSelected: false)
            tertiaryRole = tertiary.role
        } else {
            tertiaryButton.isHidden = true
            tertiaryButton.isEnabled = false
            tertiaryRole = nil
        }

        if let progress = presentation.progress {
            progressLabel.isHidden = false
            progressIndicator.isHidden = false
            progressLabel.stringValue = progress.label
            progressIndicator.isIndeterminate = progress.isIndeterminate
            if progress.isIndeterminate {
                progressIndicator.startAnimation(nil)
            } else {
                progressIndicator.stopAnimation(nil)
                progressIndicator.doubleValue = progress.fraction ?? 0
            }
        } else {
            progressLabel.isHidden = true
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(nil)
        }

        if let notes = presentation.releaseNotes {
            releaseNotesTitleLabel.isHidden = false
            releaseNotesScrollView.isHidden = false
            releaseNotesTextView.textStorage?.setAttributedString(
                AppUpdateReleaseNotesRenderer.attributedString(from: notes)
            )
            releaseNotesTextView.sizeToFit()
        } else {
            releaseNotesTitleLabel.isHidden = true
            releaseNotesScrollView.isHidden = true
            releaseNotesTextView.string = ""
        }
    }

    @objc
    private func handlePrimaryAction() {
        actionHandler?(primaryRole)
    }

    @objc
    private func handleSecondaryAction() {
        if let secondaryRole {
            actionHandler?(secondaryRole)
        }
    }

    @objc
    private func handleTertiaryAction() {
        if let tertiaryRole {
            actionHandler?(tertiaryRole)
        }
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
        return isRecordingShortcut && !event.isARepeat
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
