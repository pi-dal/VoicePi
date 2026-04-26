import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func loadCurrentValues() {
        if let provider = RemoteASRProvider(backend: model.asrBackend) {
            selectedASRBackendMode = .remote
            selectPopupItem(in: asrRemoteProviderPopup, matching: provider.rawValue)
        } else {
            selectedASRBackendMode = .local
            asrRemoteProviderPopup.selectItem(at: 0)
        }
        asrBaseURLField.stringValue = model.remoteASRConfiguration.baseURL
        asrAPIKeyField.stringValue = model.remoteASRConfiguration.apiKey
        asrModelField.stringValue = model.remoteASRConfiguration.model
        asrVolcengineAppIDField.stringValue = model.remoteASRConfiguration.volcengineAppID
        asrPromptField.stringValue = model.remoteASRConfiguration.prompt
        baseURLField.stringValue = model.llmConfiguration.baseURL
        apiKeyField.stringValue = model.llmConfiguration.apiKey
        modelField.stringValue = model.llmConfiguration.model
        thinkingPopup.selectItem(
            at: Self.thinkingSelectionIndex(for: model.llmConfiguration.enableThinking)
        )
        selectPopupItem(in: postProcessingModePopup, matching: model.postProcessingMode.rawValue)
        selectPopupItem(in: refinementProviderPopup, matching: model.refinementProvider.rawValue)
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
        if !cancelShortcutRecorderField.isRecordingShortcut {
            cancelShortcutRecorderField.shortcut = model.cancelShortcut
        }
        if !modeShortcutRecorderField.isRecordingShortcut {
            modeShortcutRecorderField.shortcut = model.modeCycleShortcut
        }
        if !promptShortcutRecorderField.isRecordingShortcut {
            promptShortcutRecorderField.shortcut = model.promptCycleShortcut
        }
        if !processorShortcutRecorderField.isRecordingShortcut {
            processorShortcutRecorderField.shortcut = model.processorShortcut
        }

        selectPopupItem(in: homeLanguagePopup, matching: model.selectedLanguage.rawValue)
        selectPopupItem(in: interfaceThemePopup, matching: model.interfaceTheme.rawValue)

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

    func refreshHomeSection() {
        let presentation = SettingsPresentation.homeSectionPresentation(model: model)
        homeShortcutLabel.stringValue = presentation.shortcutSummary
        homeCancelShortcutLabel.stringValue = presentation.cancelShortcutSummary
        homeModeShortcutLabel.stringValue = presentation.modeShortcutSummary
        homePromptShortcutLabel.stringValue = presentation.promptShortcutSummary
        homeProcessorShortcutLabel.stringValue = "Processor shortcut: \(model.processorShortcut.menuTitle)"
        homeLanguageLabel.stringValue = model.selectedLanguage.menuTitle
        homeLanguageTitleLabel.stringValue = model.selectedLanguage.recognitionDisplayName
        homeAppearanceTitleLabel.stringValue = model.interfaceTheme.title
        homeAppearanceSubtitleLabel.stringValue = model.interfaceTheme == .system ? "Follow system" : "Selected theme"
        homePermissionSummaryLabel.stringValue = presentation.permissionSummary
        homeASRLabel.stringValue = presentation.asrSummary
        homeLLMLabel.stringValue = presentation.llmSummary
        shortcutHintLabel.stringValue = presentation.shortcutHint
        cancelShortcutHintLabel.stringValue = presentation.cancelShortcutHint
        modeShortcutHintLabel.stringValue = presentation.modeShortcutHint
        promptShortcutHintLabel.stringValue = presentation.promptShortcutHint
        processorShortcutHintLabel.stringValue = processorShortcutHintText(for: model.processorShortcut)
        homeSummaryLabel.stringValue = presentation.statusTone == .error
            ? presentation.statusSummary
            : "All systems go."
        homeSummaryLabel.textColor = presentation.statusTone == .error ? .systemRed : .secondaryLabelColor
        homeReadinessTitleLabel.stringValue = presentation.statusTone == .error ? "Needs Attention" : "Ready"
        homeReadinessTitleLabel.textColor = NSColor(name: nil) { appearance in
            SettingsWindowTheme.homeReadinessTitleColor(
                for: appearance,
                isError: presentation.statusTone == .error
            )
        }
        homeReadinessIconView.image = NSImage(
            systemSymbolName: presentation.statusTone == .error ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
            accessibilityDescription: homeReadinessTitleLabel.stringValue
        )
        homeReadinessIconView.contentTintColor = presentation.statusTone == .error
            ? NSColor.systemOrange
            : currentThemePalette.accent
    }

    func processorShortcutHintText(for shortcut: ActivationShortcut) -> String {
        SettingsWindowSupport.processorShortcutHintText(for: shortcut)
    }

    func promptShortcutHintText(for shortcut: ActivationShortcut) -> String {
        SettingsWindowSupport.promptCycleShortcutHintText(for: shortcut)
    }

    func cancelShortcutHintText(for shortcut: ActivationShortcut) -> String {
        SettingsWindowSupport.cancelShortcutHintText(for: shortcut)
    }

    func refreshASRSection() {
        let selectedBackend = currentSelectedASRBackend()
        let configuration = currentRemoteASRConfigurationFromFields()
        let isRemoteBackend = selectedASRBackendMode == .remote
        let requiresVolcengineAppID = selectedBackend == .remoteVolcengineASR

        applyASRPlaceholders(for: selectedBackend)
        refreshASRBackendChoiceSelection(selectedASRBackendMode)
        updateASRConnectionDetailsContent(isRemoteBackend: isRemoteBackend)

        asrRemoteProviderPopup.isEnabled = isRemoteBackend
        asrBaseURLField.isEnabled = isRemoteBackend
        asrAPIKeyField.isEnabled = isRemoteBackend
        asrModelField.isEnabled = isRemoteBackend
        asrVolcengineAppIDField.isEnabled = isRemoteBackend && requiresVolcengineAppID
        asrPromptField.isEnabled = isRemoteBackend
        asrTestButton.isEnabled = isRemoteBackend
        asrVolcengineAppIDRow.isHidden = !requiresVolcengineAppID
        let providerSummary = isRemoteBackend
            ? " Provider: \(currentSelectedRemoteASRProvider().rawValue)."
            : ""
        asrSummaryLabel.stringValue = "Selected backend: \(selectedBackend.title).\(providerSummary) \(selectedBackend.shortDescription) \(isRemoteBackend ? "Remote credentials are required for streaming." : "No remote credentials are required.")"

        if !isRemoteBackend {
            setASRFeedback(.neutral("Apple Speech is active. VoicePi will use the built-in streaming recognizer."))
        } else if configuration.isConfigured(for: selectedBackend) {
            setASRFeedback(.neutral("\(selectedBackend.title) is selected and configured."))
        } else {
            setASRFeedback(.neutral("\(selectedBackend.title) is selected, but \(remoteASRRequiredFieldsText(for: selectedBackend)) are still required."))
        }
    }

    func refreshPermissionLabels() {
        applyPermissionStatus(
            model.microphoneAuthorization,
            to: microphoneStatusLabel,
            iconView: microphoneStatusIconView
        )
        applyPermissionStatus(
            model.speechAuthorization,
            to: speechStatusLabel,
            iconView: speechStatusIconView
        )
        applyPermissionStatus(
            model.accessibilityAuthorization,
            to: accessibilityStatusLabel,
            iconView: accessibilityStatusIconView
        )
        applyPermissionStatus(
            model.inputMonitoringAuthorization,
            to: inputMonitoringStatusLabel,
            iconView: inputMonitoringStatusIconView
        )
    }

    func refreshLLMSection() {
        let mode = currentPostProcessingMode()
        let provider = currentTranslationProvider()
        let refinementProvider = currentRefinementProvider()
        let targetLanguage = currentTargetLanguage()
        let configuration = currentConfigurationFromFields()
        let usesLLM = (mode == .translation && provider == .llm)
            || (mode == .refinement && refinementProvider == .llm)

        selectPopupItem(
            in: refinementProviderPopup,
            matching: model.refinementProvider.rawValue
        )
        selectPopupItem(
            in: translationProviderPopup,
            matching: TranslationProvider.displayProvider(
                mode: mode,
                storedProvider: model.translationProvider,
                appleTranslateSupported: appleTranslateSupported
            ).rawValue
        )

        refinementProviderPopup.isEnabled = mode == .refinement
        translationProviderPopup.isEnabled = mode == .translation && appleTranslateSupported
        thinkingPopup.isEnabled = usesLLM
        testButton.isEnabled = usesLLM
        llmRefinementProviderRow?.isHidden = mode != .refinement
        llmTranslationProviderRow?.isHidden = mode != .translation
        llmTargetLanguageRow?.isHidden = mode == .disabled
        llmThinkingRow?.isHidden = !usesLLM
        let shouldEnablePromptControls = mode == .refinement && refinementProvider == .llm
        setPromptWorkspaceControlsEnabled(shouldEnablePromptControls)
        llmSummaryLabel.stringValue = LLMSectionFeedback.message(
            mode: mode,
            provider: provider,
            refinementProvider: refinementProvider,
            externalProcessor: model.selectedExternalProcessorEntry(),
            configuration: configuration,
            selectedLanguage: model.selectedLanguage,
            targetLanguage: targetLanguage,
            appleTranslateSupported: appleTranslateSupported
        )

        setLLMFeedback(.neutral(
            llmSummaryLabel.stringValue
        ))
        updatePromptRulesSummary()
        scheduleTextLivePreviewUpdate()
    }

    func refreshExternalProcessorsSection() {
        externalProcessorManagerButton.isEnabled = true
        let presentation = SettingsWindowSupport.externalProcessorsSectionPresentation(
            entries: model.externalProcessorEntries,
            selectedEntry: model.selectedExternalProcessorEntry()
        )
        externalProcessorsSummaryLabel.stringValue = presentation.summaryText
        externalProcessorsDetailLabel.stringValue = presentation.detailText
        rebuildExternalProcessorRows()
    }

    func rebuildExternalProcessorRows() {
        let entries = model.externalProcessorEntries
        guard !entries.isEmpty else {
            replaceArrangedSubviews(
                in: externalProcessorsRowsStack,
                with: [makeBodyLabel("No processors configured yet.")]
            )
            return
        }

        replaceArrangedSubviews(
            in: externalProcessorsRowsStack,
            with: entries.map(makeExternalProcessorOverviewRow(entry:))
        )
    }

    func makeExternalProcessorOverviewRow(entry: ExternalProcessorEntry) -> NSView {
        let handleView = NSImageView()
        handleView.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Order")
        handleView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        handleView.contentTintColor = .secondaryLabelColor
        handleView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = makeProcessorColumnLabel(externalProcessorManagerDisplayTitle(for: entry))
        let commandLabel = makeProcessorCommandLabel(processorCommandPreview(for: entry))
        let argumentsLabel = makeProcessorColumnLabel(rowArgumentsPreview(for: entry))
        nameLabel.toolTip = externalProcessorManagerDisplayTitle(for: entry)
        commandLabel.toolTip = entry.executablePath
        argumentsLabel.toolTip = rowArgumentsPreview(for: entry)
        let enabledSwitch = NSSwitch()
        enabledSwitch.state = entry.isEnabled ? .on : .off
        enabledSwitch.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)
        enabledSwitch.target = self
        enabledSwitch.action = #selector(toggleExternalProcessorFromOverview(_:))

        let actionsLabel = "Edit processor \(externalProcessorManagerDisplayTitle(for: entry))"
        let actionsButton = makeExternalProcessorEditButton(
            accessibilityLabel: actionsLabel,
            action: #selector(openExternalProcessorEntryEditorFromOverview(_:))
        )
        actionsButton.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)

        let rowContent = NSStackView(views: [handleView, nameLabel, commandLabel, argumentsLabel, enabledSwitch, actionsButton])
        rowContent.orientation = .horizontal
        rowContent.spacing = 12
        rowContent.alignment = .centerY
        rowContent.distribution = .fill

        NSLayoutConstraint.activate([
            handleView.widthAnchor.constraint(equalToConstant: 16),
            nameLabel.widthAnchor.constraint(equalToConstant: 152),
            commandLabel.widthAnchor.constraint(equalToConstant: 232),
            argumentsLabel.widthAnchor.constraint(equalToConstant: 108),
            enabledSwitch.widthAnchor.constraint(equalToConstant: 52),
            actionsButton.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.actionButtonHeight)
        ])

        return makeCompactListRow(content: rowContent)
    }

    func updateExternalProcessorModel(
        entries: [ExternalProcessorEntry],
        selectedEntryID: UUID?
    ) {
        model.setExternalProcessorEntries(entries)
        model.setSelectedExternalProcessorEntryID(selectedEntryID)
        if externalProcessorManagerSheetWindow != nil {
            externalProcessorManagerState = ExternalProcessorManagerState(
                entries: entries,
                selectedEntryID: selectedEntryID
            )
            reloadExternalProcessorManagerSheet()
        }
        refreshExternalProcessorsSection()
        refreshLLMSection()
    }

    func openExternalProcessorManager(selecting entryID: UUID?) {
        if let entryID {
            model.setSelectedExternalProcessorEntryID(entryID)
        }

        externalProcessorManagerState = ExternalProcessorManagerState(
            entries: model.externalProcessorEntries,
            selectedEntryID: entryID ?? model.selectedExternalProcessorEntryID ?? model.externalProcessorEntries.first?.id
        )
        presentExternalProcessorManagerSheet()
    }

    func removeExternalProcessorEntry(withID entryID: UUID) {
        let currentState = ExternalProcessorManagerState(
            entries: model.externalProcessorEntries,
            selectedEntryID: model.selectedExternalProcessorEntryID
        )
        let nextState = ExternalProcessorManagerActions.removeEntry(entryID, from: currentState)
        updateExternalProcessorModel(entries: nextState.entries, selectedEntryID: nextState.selectedEntryID)
    }

    func runExternalProcessorTest(
        for entry: ExternalProcessorEntry,
        feedback: @escaping (String) -> Void
    ) {
        let displayTitle = externalProcessorManagerDisplayTitle(for: entry)

        guard entry.isEnabled else {
            feedback("\(displayTitle) is disabled.")
            return
        }

        guard !entry.executablePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            feedback("Please provide an executable path before testing.")
            return
        }

        feedback("Testing \(displayTitle)…")

        Task { @MainActor in
            do {
                let invocation = try AlmaCLIInvocationBuilder().build(
                    executablePath: entry.executablePath,
                    prompt: "VoicePi external processor test",
                    additionalArguments: entry.additionalArguments.map(\.value)
                )
                let runner = ExternalProcessorRunner()
                let output = try await runner.run(invocation: invocation, stdin: "VoicePi test")
                feedback(
                    ExternalProcessorTestFeedback.message(
                        forOutput: output,
                        processorDisplayName: displayTitle
                    )
                )
            } catch {
                feedback(error.localizedDescription)
            }
        }
    }

    @objc
    func addExternalProcessorFromPage() {
        let currentState = ExternalProcessorManagerState(
            entries: model.externalProcessorEntries,
            selectedEntryID: model.selectedExternalProcessorEntryID
        )
        let nextState = ExternalProcessorManagerActions.addEntry(to: currentState)
        updateExternalProcessorModel(entries: nextState.entries, selectedEntryID: nextState.selectedEntryID)
        if let selectedEntryID = nextState.selectedEntryID {
            openExternalProcessorManager(selecting: selectedEntryID)
        }
    }

    @objc
    func testSelectedExternalProcessorEntry() {
        guard let entry = model.selectedExternalProcessorEntry() else {
            externalProcessorsStatusLabel.stringValue = "Enable a processor before running a test."
            externalProcessorsStatusLabel.isHidden = false
            return
        }

        runExternalProcessorTest(for: entry) { [weak self] message in
            self?.externalProcessorsStatusLabel.stringValue = message
            self?.externalProcessorsStatusLabel.isHidden = false
        }
    }

    @objc
    func toggleExternalProcessorFromOverview(_ sender: NSSwitch) {
        guard let entryID = sender.identifier.flatMap({ UUID(uuidString: $0.rawValue) }) else { return }
        var entries = model.externalProcessorEntries
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].isEnabled = sender.state == .on
        updateExternalProcessorModel(entries: entries, selectedEntryID: model.selectedExternalProcessorEntryID)
    }

    @objc
    func openExternalProcessorEntryEditorFromOverview(_ sender: NSButton) {
        guard let entryID = sender.identifier.flatMap({ UUID(uuidString: $0.rawValue) }) else { return }
        openExternalProcessorManager(selecting: entryID)
    }

    func rowArgumentsPreview(for entry: ExternalProcessorEntry) -> String {
        let preview = SettingsWindowSupport.externalProcessorArgumentsPreview(for: entry)
        return preview == "None" ? "" : preview
    }

    func processorCommandPreview(for entry: ExternalProcessorEntry) -> String {
        let executablePath = entry.executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return executablePath
    }

}
