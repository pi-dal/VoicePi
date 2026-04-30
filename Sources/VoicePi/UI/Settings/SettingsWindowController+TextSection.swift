import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func buildASRView() {
        let contentStack = makePageStack()
        addPageSection(makeProviderSubviewControl(selectedSubview: .asr), to: contentStack)

        asrRemoteProviderPopup.removeAllItems()
        asrRemoteProviderPopup.addItems(withTitles: RemoteASRProvider.allCases.map(\.rawValue))
        asrRemoteProviderPopup.target = self
        asrRemoteProviderPopup.action = #selector(remoteASRProviderChanged(_:))

        asrAPIKeyField.placeholderString = "sk-..."
        asrPromptField.placeholderString = "Optional add-on hints (appended after VoicePi default ASR bias prompt)"
        applyASRPlaceholders(for: model.asrBackend)

        asrTestButton.target = self
        asrTestButton.action = #selector(testRemoteASRConfiguration)

        asrSaveButton.target = self
        asrSaveButton.action = #selector(saveRemoteASRConfiguration)
        asrSaveButton.keyEquivalent = "\r"

        asrBackendCardsStack.orientation = .vertical
        asrBackendCardsStack.spacing = 12
        asrBackendCardsStack.alignment = .leading
        asrBackendCardsStack.distribution = .fill
        asrBackendCardViews = [:]
        replaceArrangedSubviews(
            in: asrBackendCardsStack,
            with: ASRBackendMode.allCases.map(makeASRBackendChoiceCard(for:))
        )

        let configurationSection = makeGroupedSection(rows: [
            makePreferenceRow(title: "Remote Provider", control: asrRemoteProviderPopup),
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
        let localModeHintView = makeASRLocalModeHintView()
        asrRemoteConfigurationSection = configurationSection
        asrConnectionActionButtons = buttons
        asrLocalModeHintView = localModeHintView

        asrConnectionDetailsContentStack.orientation = .vertical
        asrConnectionDetailsContentStack.spacing = 10
        asrConnectionDetailsContentStack.alignment = .leading
        asrConnectionDetailsContentStack.distribution = .fill
        replaceArrangedSubviews(in: asrConnectionDetailsContentStack, with: [localModeHintView])

        asrSummaryLabel.font = .systemFont(ofSize: 12.5)
        asrSummaryLabel.textColor = .secondaryLabelColor
        asrSummaryLabel.alignment = .left
        asrSummaryLabel.lineBreakMode = .byWordWrapping
        asrSummaryLabel.maximumNumberOfLines = 0

        let backendCard = makeSimpleSummaryCard(
            title: "ASR Backend",
            subtitle: "Pick Local or Remote. For Remote, choose OpenAI-compatible, Aliyun, or Volcengine in Connection Details.",
            bodyViews: [
                asrBackendCardsStack,
                asrSummaryLabel
            ]
        )

        let connectionCard = makeSimpleSummaryCard(
            title: "Connection Details",
            subtitle: "Keep the current backend fields and save flow unchanged.",
            bodyViews: [asrConnectionDetailsContentStack]
        )

        let statusCard = makeSimpleSummaryCard(
            title: "Live Status",
            subtitle: "Feedback updates immediately when the backend changes or after you test a remote endpoint.",
            bodyViews: [asrStatusView]
        )
        let rightColumn = makeVerticalStack(
            [connectionCard, statusCard],
            spacing: SettingsLayoutMetrics.pageSpacing
        )

        contentStack.addArrangedSubview(
            makeTwoColumnSection(left: backendCard, right: rightColumn, leftPriority: 0.46)
        )

        installScrollablePage(contentStack, in: asrView, section: .asr)

        NSLayoutConstraint.activate([
            asrRemoteProviderPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            asrBaseURLField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            asrAPIKeyField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            asrModelField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            asrVolcengineAppIDField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            asrPromptField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
    }

    func buildProviderLLMView() {
        let contentStack = makePageStack()
        addPageSection(makeProviderSubviewControl(selectedSubview: .llm), to: contentStack)

        baseURLField.placeholderString = "https://api.example.com/v1"
        apiKeyField.placeholderString = "sk-..."
        modelField.placeholderString = "gpt-4o-mini"

        llmSummaryLabel.font = .systemFont(ofSize: 12.5)
        llmSummaryLabel.textColor = .secondaryLabelColor
        llmSummaryLabel.alignment = .left
        llmSummaryLabel.lineBreakMode = .byWordWrapping
        llmSummaryLabel.maximumNumberOfLines = 0

        let providerSummaryCard = makeSimpleSummaryCard(
            title: "LLM Provider",
            subtitle: "Used when Text settings choose LLM-backed refinement or translation.",
            bodyViews: [
                llmSummaryLabel,
                makeSubtleCaption("Text rules stay in the Text tab. Provider only manages the backing endpoint and model.")
            ]
        )

        let configurationSection = makeGroupedSection(rows: [
            makePreferenceRow(title: "API Base URL", control: baseURLField),
            makePreferenceRow(title: "API Key", control: apiKeyField),
            makePreferenceRow(title: "Model", control: modelField)
        ])
        let actionButtons = makeButtonGroup([
            makeSecondaryActionButton(title: "Test Connection", action: #selector(testConfiguration)),
            makePrimaryActionButton(title: "Save", action: #selector(saveConfiguration))
        ])
        let connectionContent = makeVerticalStack(
            [configurationSection, makeSubtleCaption(Self.thinkingHelpText), actionButtons],
            spacing: 10
        )

        let connectionCard = makeSimpleSummaryCard(
            title: "Connection Details",
            subtitle: "Configure the OpenAI-compatible endpoint and model VoicePi uses for LLM tasks.",
            bodyViews: [connectionContent]
        )

        let statusCard = makeSimpleSummaryCard(
            title: "Live Status",
            subtitle: "Feedback reflects whether current Text rules require this provider and whether the connection can be tested.",
            bodyViews: [llmStatusView]
        )
        let rightColumn = makeVerticalStack([connectionCard, statusCard], spacing: SettingsLayoutMetrics.pageSpacing)

        addPageSection(
            makeTwoColumnSection(left: providerSummaryCard, right: rightColumn, leftPriority: 0.46),
            to: contentStack
        )

        installScrollablePage(contentStack, in: providerLLMView, section: .provider)

        NSLayoutConstraint.activate([
            baseURLField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            apiKeyField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            modelField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
    }

    func buildLLMView() {
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

        let mainPanel = makeTextTabMainPanel()
        let previewCard = makeTextTabLivePreviewCard()
        contentStack.addArrangedSubview(mainPanel)
        contentStack.addArrangedSubview(previewCard)

        installScrollablePage(contentStack, in: llmView, section: .llm)

        NSLayoutConstraint.activate([
            postProcessingModePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            translationProviderPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            targetLanguagePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            thinkingPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            activePromptPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])
    }

    func makeTextTabLeftSidebar() -> NSView {
        let actionRow = makePreferenceRow(title: "Action", control: postProcessingModePopup)
        let refinementRow = makePreferenceRow(
            title: Self.refinementProviderLabel,
            control: refinementProviderPopup
        )
        let translationRow = makePreferenceRow(
            title: "Translate Provider",
            control: translationProviderPopup
        )
        let targetLanguageRow = makePreferenceRow(title: "Target Language", control: targetLanguagePopup)
        let thinkingRow = makePreferenceRow(title: Self.thinkingLabel, control: thinkingPopup)
        llmRefinementProviderRow = refinementRow
        llmTranslationProviderRow = translationRow
        llmTargetLanguageRow = targetLanguageRow
        llmThinkingRow = thinkingRow

        let strictModeRow = makeSummaryDetailRow(
            title: Self.strictModeToggleLabel,
            detailLabel: promptRulesStrictModeLabel,
            accessory: promptStrictModeSwitch
        )

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.addArrangedSubview(makeSectionTitle("Refinement & Translation"))
        stack.addArrangedSubview(actionRow)
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(refinementRow)
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(translationRow)
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(targetLanguageRow)
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(thinkingRow)
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(strictModeRow)
        stack.addArrangedSubview(makeSubtleCaption("Keep code and formatting intact."))
        return stack
    }

    func makeTextTabMainPanel() -> NSView {
        let card = makeCardView()
        let leftColumn = makeTextTabLeftSidebar()
        let rightColumn = makeTextTabRightPreview()

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true

        let layout = NSStackView(views: [leftColumn, divider, rightColumn])
        layout.orientation = .horizontal
        layout.spacing = 18
        layout.alignment = .top
        layout.distribution = .fill

        leftColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        leftColumn.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        rightColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rightColumn.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        pinCardContent(layout, into: card)
        NSLayoutConstraint.activate([
            leftColumn.widthAnchor.constraint(equalTo: rightColumn.widthAnchor, multiplier: 0.95),
            leftColumn.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
            rightColumn.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])

        return card
    }

    func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.alphaValue = 0.35
        return separator
    }

    func makeTextTabRightPreview() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.addArrangedSubview(makeSectionTitle("System Prompt"))
        let promptSelectionRow = makePreferenceRow(title: "Active Prompt", control: activePromptPopup)
        stack.addArrangedSubview(promptSelectionRow)

        let promptPreviewSurface = ThemedSurfaceView(style: .row)
        promptPreviewSurface.translatesAutoresizingMaskIntoConstraints = false
        promptPreviewSurface.addSubview(resolvedPromptBodyScrollView)
        NSLayoutConstraint.activate([
            resolvedPromptBodyScrollView.leadingAnchor.constraint(equalTo: promptPreviewSurface.leadingAnchor),
            resolvedPromptBodyScrollView.trailingAnchor.constraint(equalTo: promptPreviewSurface.trailingAnchor),
            resolvedPromptBodyScrollView.topAnchor.constraint(equalTo: promptPreviewSurface.topAnchor),
            resolvedPromptBodyScrollView.bottomAnchor.constraint(equalTo: promptPreviewSurface.bottomAnchor),
            promptPreviewSurface.heightAnchor.constraint(equalToConstant: 156)
        ])
        stack.addArrangedSubview(promptPreviewSurface)

        let promptCountLabel = makeSubtleCaption("0 / 500")
        promptCountLabel.alignment = .right
        textPromptCharacterCountLabel = promptCountLabel
        let promptCountRow = NSStackView(views: [NSView(), promptCountLabel])
        promptCountRow.orientation = .horizontal
        promptCountRow.alignment = .centerY
        promptCountRow.spacing = 8
        stack.addArrangedSubview(promptCountRow)

        let promptActions = makeButtonGroup([
            editPromptButton,
            newPromptButton,
            promptBindingsButton,
            deletePromptButton
        ])
        stack.addArrangedSubview(promptActions)

        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeSectionTitle("Processing Rules"))
        let rulesRows = NSStackView(views: [
            makeTextTabRuleRow(
                title: "Binding Coverage",
                detailLabel: promptRulesBindingCoverageLabel,
                iconView: promptRulesBindingCoverageIconView
            )
        ])
        rulesRows.orientation = .vertical
        rulesRows.spacing = 8
        rulesRows.alignment = .leading
        stack.addArrangedSubview(rulesRows)

        NSLayoutConstraint.activate([
            promptSelectionRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            promptPreviewSurface.widthAnchor.constraint(equalTo: stack.widthAnchor),
            promptCountRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            promptActions.widthAnchor.constraint(equalTo: stack.widthAnchor),
            rulesRows.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        return stack
    }

    func makeTextTabRuleRow(
        title: String,
        detailLabel: NSTextField,
        iconView: NSImageView
    ) -> NSView {
        iconView.image = NSImage(systemSymbolName: "square", accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13.5, weight: .medium)
        titleLabel.textColor = .labelColor

        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 2
        detailLabel.lineBreakMode = .byWordWrapping

        let textStack = NSStackView(views: [titleLabel, detailLabel])
        textStack.orientation = .vertical
        textStack.spacing = 3
        textStack.alignment = .leading

        let row = NSStackView(views: [iconView, textStack])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        return row
    }

    func applyTextPromptRulePresentation(
        _ presentation: TextPromptRulePresentation,
        iconView: NSImageView,
        detailLabel: NSTextField
    ) {
        detailLabel.stringValue = presentation.detailText
        iconView.image = NSImage(
            systemSymbolName: presentation.symbolName,
            accessibilityDescription: detailLabel.stringValue
        )
        iconView.contentTintColor = presentation.isActive
            ? currentThemePalette.accent
            : .secondaryLabelColor
    }

    func makeTextTabLivePreviewCard() -> NSView {
        let card = makeCardView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading

        let livePreviewInputField = NSTextField(string: "um so the the update to VoicePi is amazing")
        livePreviewInputField.translatesAutoresizingMaskIntoConstraints = false
        livePreviewInputField.placeholderString = "Type text to preview processing output…"
        livePreviewInputField.isBordered = false
        livePreviewInputField.drawsBackground = false
        livePreviewInputField.font = .systemFont(ofSize: 20, weight: .regular)
        livePreviewInputField.textColor = .labelColor
        livePreviewInputField.focusRingType = .none

        let outputLabel = NSTextField(wrappingLabelWithString: "The update to VoicePi is amazing.")
        outputLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        outputLabel.textColor = currentThemePalette.accent
        outputLabel.maximumNumberOfLines = 3
        outputLabel.lineBreakMode = .byWordWrapping

        let arrowLabel = NSTextField(labelWithString: "→")
        arrowLabel.font = .systemFont(ofSize: 34, weight: .light)
        arrowLabel.textColor = .tertiaryLabelColor
        arrowLabel.setContentHuggingPriority(.required, for: .horizontal)

        let flowRow = NSStackView(views: [livePreviewInputField, arrowLabel, outputLabel])
        flowRow.orientation = .horizontal
        flowRow.alignment = .centerY
        flowRow.spacing = 18

        let outputTitleLabel = makeSectionTitle("Preview")
        stack.addArrangedSubview(outputTitleLabel)
        stack.addArrangedSubview(flowRow)

        NSLayoutConstraint.activate([
            livePreviewInputField.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            outputLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            flowRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        textLivePreviewInputField = livePreviewInputField
        textLivePreviewOutputLabel = outputLabel

        if let observer = textLivePreviewInputObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        textLivePreviewInputObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification,
            object: livePreviewInputField,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleTextLivePreviewUpdate()
            }
        }

        livePreviewInputField.target = self
        livePreviewInputField.action = #selector(textLivePreviewInputCommitted(_:))

        pinCardContent(stack, into: card)
        return card
    }

    @objc
    func textLivePreviewInputCommitted(_ sender: NSTextField) {
        scheduleTextLivePreviewUpdate(immediate: true)
    }

    func scheduleTextLivePreviewUpdate(immediate: Bool = false) {
        textLivePreviewDebounceTimer?.invalidate()

        if immediate {
            updateTextLivePreviewOutput()
            return
        }

        textLivePreviewDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateTextLivePreviewOutput()
            }
        }
    }

    func updateTextLivePreviewOutput() {
        guard let inputField = textLivePreviewInputField,
              let outputLabel = textLivePreviewOutputLabel else {
            return
        }

        let inputText = inputField.stringValue
        guard !inputText.isEmpty else {
            outputLabel.stringValue = ""
            return
        }

        let mode = currentPostProcessingMode()
        textLivePreviewRequestID += 1
        let requestID = textLivePreviewRequestID

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let outputLabel = self.textLivePreviewOutputLabel else { return }
            guard requestID == self.textLivePreviewRequestID else { return }

            let processed: String

            switch mode {
            case .disabled:
                processed = inputText

            case .translation:
                // Use translation service
                do {
                    let targetLang = self.currentTargetLanguage()
                    let provider = self.currentTranslationProvider()
                    let effectiveProvider = TranslationProvider.displayProvider(
                        mode: mode,
                        storedProvider: provider,
                        appleTranslateSupported: AppleTranslateService.isSupported
                    )

                    if effectiveProvider == .llm {
                        let config = Self.livePreviewLLMConfiguration(
                            from: self.currentConfigurationFromFields(),
                            mode: mode,
                            refinementProvider: .llm,
                            resolvedPromptText: self.resolvedPromptTextFromControls()
                        )
                        guard config.isConfigured else {
                            processed = "[LLM not configured]"
                            guard requestID == self.textLivePreviewRequestID else { return }
                            outputLabel.stringValue = processed
                            outputLabel.textColor = .systemOrange
                            return
                        }
                        let refiner = LLMRefiner()
                        let result = try await refiner.refine(
                            text: inputText,
                            configuration: config,
                            mode: .translation,
                            targetLanguage: targetLang
                        )
                        processed = result
                    } else {
                        let translator = AppleTranslateService()
                        let sourceLanguage = self.model.selectedLanguage
                        processed = try await translator.translate(
                            text: inputText,
                            sourceLanguage: sourceLanguage,
                            targetLanguage: targetLang
                        )
                    }
                } catch {
                    processed = "[Translation error: \(error.localizedDescription)]"
                }

            case .refinement:
                // Use refinement (either LLM or external processor)
                do {
                    let refinementProvider = self.currentRefinementProvider()
                    let prompt = self.resolvedPromptTextFromControls() ?? ""

                    if refinementProvider == .llm {
                        let config = Self.livePreviewLLMConfiguration(
                            from: self.currentConfigurationFromFields(),
                            mode: mode,
                            refinementProvider: refinementProvider,
                            resolvedPromptText: prompt
                        )
                        guard config.isConfigured else {
                            processed = "[LLM not configured]"
                            guard requestID == self.textLivePreviewRequestID else { return }
                            outputLabel.stringValue = processed
                            outputLabel.textColor = .systemOrange
                            return
                        }
                        let refiner = LLMRefiner()
                        let result = try await refiner.refine(
                            text: inputText,
                            configuration: config,
                            mode: .refinement,
                            targetLanguage: nil
                        )
                        processed = result
                    } else if refinementProvider == .externalProcessor {
                        if let processor = self.model.selectedExternalProcessorEntry(),
                           processor.isEnabled {
                            let invocation = try AlmaCLIInvocationBuilder().build(
                                executablePath: processor.executablePath,
                                prompt: prompt,
                                additionalArguments: processor.additionalArguments.map(\.value).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                            )
                            let runner = ExternalProcessorRunner()
                            let result = try await runner.run(invocation: invocation, stdin: inputText)
                            processed = result
                        } else {
                            processed = "[No processor configured or enabled]"
                        }
                    } else {
                        processed = inputText
                    }
                } catch {
                    processed = "[Refinement error: \(error.localizedDescription)]"
                }
            }

            guard requestID == self.textLivePreviewRequestID else { return }
            outputLabel.stringValue = processed
            outputLabel.textColor = processed.hasPrefix("[") ? .systemOrange : self.currentThemePalette.accent
        }
    }

}
