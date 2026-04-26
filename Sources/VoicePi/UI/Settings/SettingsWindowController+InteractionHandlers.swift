import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    @objc
    func interfaceThemeChanged(_ sender: NSPopUpButton) {
        let index = max(0, sender.indexOfSelectedItem)
        model.interfaceTheme = InterfaceTheme.allCases[index]
        applyThemeAppearance()
        reloadFromModel()
    }

    @objc
    func homeLanguageChanged(_ sender: NSPopUpButton) {
        let index = max(0, sender.indexOfSelectedItem)
        let language = SupportedLanguage.allCases[index]
        model.selectedLanguage = language
        delegate?.settingsWindowController(self, didSelect: language)
        refreshHomeSection()
    }

    @objc
    func startListeningFromHome() {
        delegate?.settingsWindowControllerDidRequestStartRecording(self)
    }

    @objc
    func openPersonalWebsite() {
        openExternalURL(AboutProfile.websiteURL)
    }

    @objc
    func openGitHubProfile() {
        openExternalURL(AboutProfile.githubURL)
    }

    @objc
    func openRepository() {
        openExternalURL(AboutProfile.repositoryURL)
    }

    @objc
    func openRepositoryIssues() {
        openExternalURL("\(AboutProfile.repositoryURL)/issues")
    }

    @objc
    func openLicense() {
        openExternalURL(AboutProfile.licenseURL)
    }

    @objc
    func openInspirationAuthor() {
        openExternalURL(AboutProfile.inspirationAuthorURL)
    }

    @objc
    func openInspirationPost() {
        openExternalURL(AboutProfile.inspirationPostURL)
    }

    @objc
    func openXProfile() {
        openExternalURL(AboutProfile.xURL)
    }

    @objc
    func remoteASRProviderChanged(_ sender: NSPopUpButton) {
        guard selectedASRBackendMode == .remote else { return }
        applySelectedASRBackendChange()
    }

    @objc
    func refinementProviderChanged(_ sender: NSPopUpButton) {
        model.setRefinementProvider(currentRefinementProvider())
        refreshHomeSection()
        refreshLLMSection()
    }

    @objc
    func shortcutRecorderChanged(_ sender: ShortcutRecorderField) {
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
    func cancelShortcutRecorderChanged(_ sender: ShortcutRecorderField) {
        let shortcut = sender.shortcut

        guard !shortcut.isEmpty else {
            sender.shortcut = model.cancelShortcut
            return
        }

        model.setCancelShortcut(shortcut)
        delegate?.settingsWindowController(self, didUpdateCancelShortcut: shortcut)
        reloadFromModel()
        window?.makeFirstResponder(nil)
    }

    @objc
    func modeShortcutRecorderChanged(_ sender: ShortcutRecorderField) {
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
    func promptShortcutRecorderChanged(_ sender: ShortcutRecorderField) {
        let shortcut = sender.shortcut

        guard !shortcut.isEmpty else {
            sender.shortcut = model.promptCycleShortcut
            return
        }

        model.setPromptCycleShortcut(shortcut)
        delegate?.settingsWindowController(self, didUpdatePromptCycleShortcut: shortcut)
        reloadFromModel()
        window?.makeFirstResponder(nil)
    }

    @objc
    func processorShortcutRecorderChanged(_ sender: ShortcutRecorderField) {
        let shortcut = sender.shortcut

        guard !shortcut.isEmpty else {
            sender.shortcut = model.processorShortcut
            return
        }

        model.setProcessorShortcut(shortcut)
        delegate?.settingsWindowController(self, didUpdateProcessorShortcut: shortcut)
        reloadFromModel()
        window?.makeFirstResponder(nil)
    }

    @objc
    func openMicrophoneSettings() {
        delegate?.settingsWindowControllerDidRequestOpenMicrophoneSettings(self)
    }

    @objc
    func openMicrophoneSettingsFromCard(_ sender: NSClickGestureRecognizer) {
        openMicrophoneSettings()
    }

    @objc
    func openSpeechSettings() {
        delegate?.settingsWindowControllerDidRequestOpenSpeechSettings(self)
    }

    @objc
    func openSpeechSettingsFromCard(_ sender: NSClickGestureRecognizer) {
        openSpeechSettings()
    }

    @objc
    func openAccessibilitySettingsFromSettings() {
        delegate?.settingsWindowControllerDidRequestOpenAccessibilitySettings(self)
    }

    @objc
    func openAccessibilitySettingsFromCard(_ sender: NSClickGestureRecognizer) {
        openAccessibilitySettingsFromSettings()
    }

    @objc
    func openInputMonitoringSettings() {
        delegate?.settingsWindowControllerDidRequestOpenInputMonitoringSettings(self)
    }

    @objc
    func openInputMonitoringSettingsFromCard(_ sender: NSClickGestureRecognizer) {
        openInputMonitoringSettings()
    }

    @objc
    func openSystemSettingsOverview() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc
    func promptAccessibilityPermission() {
        delegate?.settingsWindowControllerDidRequestPromptAccessibilityPermission(self)
    }

    func refreshPermissions(showProgressCopy: Bool) {
        if showProgressCopy {
            permissionsHintLabel.stringValue = "Refreshing permission status…"
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await delegate?.settingsWindowControllerDidRequestRefreshPermissions(self)
            self.permissionsHintLabel.stringValue = PermissionsCopy.permissionsFooterNote
            self.reloadFromModel()
        }
    }

    @objc
    func refreshPermissions() {
        refreshPermissions(showProgressCopy: true)
    }

    @objc
    func refreshPermissionsFromFooter() {
        refreshPermissions()
    }

    @objc
    func postProcessingModeChanged(_ sender: NSPopUpButton) {
        model.setPostProcessingMode(currentPostProcessingMode())
        refreshLLMSection()
    }

    @objc
    func translationProviderChanged(_ sender: NSPopUpButton) {
        refreshLLMSection()
    }

    @objc
    func targetLanguageChanged(_ sender: NSPopUpButton) {
        refreshLLMSection()
    }

    @objc
    func activePromptChanged(_ sender: NSPopUpButton) {
        promptWorkspaceDraft.activeSelection = promptSelectionFromPopup(sender)
        updatePromptEditorState()
    }

    @objc
    func promptStrictModeChanged(_ sender: NSSwitch) {
        promptWorkspaceDraft.strictModeEnabled = sender.state == .on
        updatePromptEditorState()
    }

    @objc
    func editPromptPreset() {
        guard
            let selectedPreset = selectedPromptPresetFromDraft(),
            selectedPreset.source == .user
        else {
            return
        }

        presentPromptEditorSheet(for: selectedPreset)
    }

    @objc
    func createPromptPreset() {
        let draft = Self.makeNewUserPromptDraft()
        presentPromptEditorSheet(for: draft)
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
    func openPromptBindingsEditor() {
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
    func deletePromptPreset() {
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
    func saveRemoteASRConfiguration() {
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
    func testRemoteASRConfiguration() {
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
    func saveConfiguration() {
        var configuration = currentConfigurationFromFields()
        let mode = currentPostProcessingMode()
        let refinementProvider = currentRefinementProvider()
        model.setPostProcessingMode(mode)
        if mode == .translation {
            model.setTranslationProvider(currentTranslationProvider())
        }
        model.setTargetLanguage(currentTargetLanguage())
        model.promptWorkspace = promptWorkspaceDraft
        if mode == .refinement && refinementProvider == .llm {
            configuration.refinementPrompt = resolvedPromptTextFromControls() ?? ""
        } else {
            configuration.refinementPrompt = ""
        }
        model.saveLLMConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model,
            refinementPrompt: "",
            enableThinking: .some(configuration.enableThinking)
        )
        setLLMFeedback(.neutral("Saved."))
        delegate?.settingsWindowController(self, didSave: configuration)
        refreshHomeSection()
        refreshLLMSection()
    }

    @objc
    func testConfiguration() {
        var configuration = currentConfigurationFromFields()
        let mode = currentPostProcessingMode()
        let provider = currentTranslationProvider()
        let refinementProvider = currentRefinementProvider()
        let usesLLM = (mode == .refinement && refinementProvider == .llm)
            || (mode == .translation && provider == .llm)

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

        if mode == .refinement && refinementProvider == .llm {
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

    func setLLMButtonsEnabled(_ enabled: Bool) {
        let mode = currentPostProcessingMode()
        let provider = currentTranslationProvider()
        let refinementProvider = currentRefinementProvider()
        let usesLLM = (mode == .refinement && refinementProvider == .llm)
            || (mode == .translation && provider == .llm)
        testButton.isEnabled = enabled && usesLLM
        saveButton.isEnabled = enabled
    }

    func setASRButtonsEnabled(_ enabled: Bool) {
        asrTestButton.isEnabled = enabled && currentSelectedASRBackend().isRemoteBackend
        asrSaveButton.isEnabled = enabled
    }

    func buttonProxy(withIdentifier identifier: String) -> NSButton {
        let button = NSButton()
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        return button
    }

    func showMenu(_ menu: NSMenu, anchoredTo sender: NSView) {
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    func dictionaryTermID(from sender: NSButton) -> UUID? {
        guard let value = sender.identifier?.rawValue else {
            return nil
        }
        return UUID(uuidString: value)
    }

    func historyEntryID(from sender: NSButton) -> UUID? {
        guard let value = sender.identifier?.rawValue else {
            return nil
        }
        return UUID(uuidString: value)
    }

    func presentDictionaryTermEditor(
        title: String,
        confirmTitle: String,
        canonical: String = "",
        aliases: [String] = [],
        tag: String? = nil
    ) -> (canonical: String, aliases: [String], tag: String?)? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Edit one term at a time. Aliases are comma-separated. Tags can be created or rebound here."

        let canonicalField = NSTextField(string: canonical)
        canonicalField.placeholderString = "Canonical term"
        let aliasesField = NSTextField(string: aliases.joined(separator: ", "))
        aliasesField.placeholderString = "alias one, alias two"
        let tagField = NSTextField(string: tag ?? "")
        tagField.placeholderString = "Tag (optional)"

        let accessoryStack = NSStackView(views: [
            makeDictionaryEditorRow(title: "Canonical", field: canonicalField),
            makeDictionaryEditorRow(title: "Aliases", field: aliasesField),
            makeDictionaryEditorRow(title: "Tag", field: tagField)
        ])
        accessoryStack.orientation = .vertical
        accessoryStack.spacing = 10
        accessoryStack.alignment = .leading
        accessoryStack.translatesAutoresizingMaskIntoConstraints = false

        let accessoryContainer = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 124))
        accessoryContainer.addSubview(accessoryStack)
        NSLayoutConstraint.activate([
            accessoryStack.leadingAnchor.constraint(equalTo: accessoryContainer.leadingAnchor),
            accessoryStack.trailingAnchor.constraint(equalTo: accessoryContainer.trailingAnchor),
            accessoryStack.topAnchor.constraint(equalTo: accessoryContainer.topAnchor),
            accessoryStack.bottomAnchor.constraint(equalTo: accessoryContainer.bottomAnchor),
            accessoryStack.widthAnchor.constraint(equalToConstant: 420)
        ])
        alert.accessoryView = accessoryContainer
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let normalizedCanonical = DictionaryNormalization.trimmed(canonicalField.stringValue)
        guard !normalizedCanonical.isEmpty else { return nil }
        let normalizedAliases = DictionaryNormalization.uniqueAliases(
            Self.bindingValues(from: aliasesField.stringValue),
            excluding: normalizedCanonical
        )
        let normalizedTag = DictionaryNormalization.optionalTrimmed(tagField.stringValue)

        return (normalizedCanonical, normalizedAliases, normalizedTag)
    }

    func makeDictionaryEditorRow(title: String, field: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = NSStackView(views: [titleLabel, field])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
        return row
    }

    func presentDictionaryImportEditor(
        title: String = "Import Dictionary Terms",
        confirmTitle: String = "Import",
        informativeText: String = "Paste one canonical term per line."
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = informativeText

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 190))
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        let scrollView = NSScrollView(frame: textView.frame)
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        let accessoryContainer = NSView(frame: scrollView.frame)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        accessoryContainer.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: accessoryContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: accessoryContainer.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: accessoryContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: accessoryContainer.bottomAnchor),
            scrollView.widthAnchor.constraint(equalToConstant: 420),
            scrollView.heightAnchor.constraint(equalToConstant: 190)
        ])

        alert.accessoryView = accessoryContainer
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return textView.string
    }

    func copyStringToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @objc
    func copyHistoryEntry(_ sender: NSButton) {
        guard let rawIdentifier = sender.identifier?.rawValue,
              let entry = historyEntryByIdentifier[rawIdentifier] else {
            return
        }
        copyStringToPasteboard(entry.text)
    }

    @objc
    func deleteHistoryEntry(_ sender: NSButton) {
        guard
            let id = historyEntryID(from: sender),
            historyEntryByIdentifier[id.uuidString] != nil
        else {
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete history entry?"
        alert.informativeText = "This transcript will be removed from history."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Close")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        model.deleteHistoryEntry(id: id)
        reloadFromModel()
    }

    func openExternalURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

}
