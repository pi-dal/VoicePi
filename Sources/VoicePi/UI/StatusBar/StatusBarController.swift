import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
protocol StatusBarControllerDelegate: AnyObject {
    func statusBarControllerDidRequestStartRecording(_ controller: StatusBarController)
    func statusBarControllerDidRequestStopRecording(_ controller: StatusBarController)
    func statusBarController(_ controller: StatusBarController, didSelect language: SupportedLanguage)
    func statusBarController(_ controller: StatusBarController, didSelectASRBackend backend: ASRBackend)
    func statusBarController(_ controller: StatusBarController, didSave configuration: LLMConfiguration)
    func statusBarController(_ controller: StatusBarController, didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration)
    func statusBarController(_ controller: StatusBarController, didUpdateActivationShortcut shortcut: ActivationShortcut)
    func statusBarController(_ controller: StatusBarController, didUpdateCancelShortcut shortcut: ActivationShortcut)
    func statusBarController(_ controller: StatusBarController, didUpdateModeCycleShortcut shortcut: ActivationShortcut)
    func statusBarController(_ controller: StatusBarController, didUpdatePromptCycleShortcut shortcut: ActivationShortcut)
    func statusBarController(_ controller: StatusBarController, didUpdateProcessorShortcut shortcut: ActivationShortcut)
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

@MainActor
final class StatusBarController: NSObject {
    weak var delegate: StatusBarControllerDelegate?

    private let model: AppModel
    private let statusItem: NSStatusItem

    private var menu: NSMenu?
    private weak var languageMenu: NSMenu?
    private weak var llmMenu: NSMenu?
    private weak var statusMenuItem: NSMenuItem?
    private weak var languageStatusMenuItem: NSMenuItem?
    private weak var permissionsStatusMenuItem: NSMenuItem?
    weak var shortcutMenuItem: NSMenuItem?
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

    func showSettingsWindow(section: SettingsSection = .home, scrollToBottom: Bool = false) {
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

        settingsWindowController?.show(section: section, scrollToBottom: scrollToBottom)
        settingsWindowController?.window?.center()
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openExternalProcessorManagerFromShortcut() {
        showSettingsWindow(section: .externalProcessors)
        settingsWindowController?.openExternalProcessorManagerSheetFromShortcut()
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

        let processorsItem = NSMenuItem(
            title: "Processors…",
            action: #selector(openExternalProcessorManagerFromMenu),
            keyEquivalent: ""
        )
        processorsItem.target = self
        menu.addItem(processorsItem)

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

        let strictModeItem = NSMenuItem(
            title: Self.strictModeMenuItemTitle,
            action: #selector(togglePromptStrictModeFromMenu(_:)),
            keyEquivalent: ""
        )
        strictModeItem.target = self
        strictModeItem.state = model.promptWorkspace.strictModeEnabled ? .on : .off
        llmMenu.addItem(strictModeItem)

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

    func refreshLLMMenuState() {
        rebuildLLMMenu()
    }

    func shortcutMenuTitle() -> String {
        "Press \(model.activationShortcut.menuTitle) to Start / Press Again to Paste"
    }

    func refreshStatusSummary() {
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
    private func togglePromptStrictModeFromMenu(_ sender: NSMenuItem) {
        model.setPromptStrictModeEnabled(!model.promptWorkspace.strictModeEnabled)
        refreshLLMMenuState()
        refreshStatusSummary()
        settingsWindowController?.reloadFromModel()
        setTransientStatus(
            SettingsWindowController.strictModeSummaryText(
                enabled: model.promptWorkspace.strictModeEnabled
            )
        )
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
        guard let preparedSave = PromptBindingActions.prepareSave(
            capturedRawValue: capture.value,
            kind: capture.kind,
            target: target,
            model: model
        ) else {
            setTransientStatus("Couldn't save the captured binding.")
            return
        }

        let result: PromptBindingSaveResult
        if !preparedSave.conflicts.isEmpty {
            guard confirmPromptBindingCaptureReassignment(
                conflicts: preparedSave.conflicts,
                destinationPromptTitle: preparedSave.preset.resolvedTitle
            ) else {
                setTransientStatus("Binding unchanged.")
                return
            }
            result = PromptBindingActions.commitPreparedSave(
                preparedSave,
                model: model,
                reassigningConflictingAppBindings: true
            )
        } else {
            result = PromptBindingActions.commitPreparedSave(
                preparedSave,
                model: model
            )
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

    private func confirmPromptBindingCaptureReassignment(
        conflicts: [PromptAppBindingConflict],
        destinationPromptTitle: String
    ) -> Bool {
        let copy = SettingsWindowController.promptAppBindingConflictAlertContent(
            for: conflicts,
            destinationPromptTitle: destinationPromptTitle
        )
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = copy.messageText
        alert.informativeText = copy.informativeText
        alert.addButton(withTitle: "Reassign and Bind")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
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
    private func openExternalProcessorManagerFromMenu() {
        openExternalProcessorManagerFromShortcut()
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
