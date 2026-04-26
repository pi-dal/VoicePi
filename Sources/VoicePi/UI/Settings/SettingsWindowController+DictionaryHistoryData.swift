import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func pointInAnyHistoryUsageMetricCard(_ point: NSPoint, container: NSView) -> Bool {
        for card in historyUsageMetricCardViews.values {
            guard !card.isHidden else { continue }
            let frame = card.convert(card.bounds, to: container)
            if frame.contains(point) {
                return true
            }
        }
        return false
    }

    func pointInHistoryUsageDetailCard(_ point: NSPoint, container: NSView) -> Bool {
        guard !historyUsageDetailCard.isHidden else { return false }
        let frame = historyUsageDetailCard.convert(historyUsageDetailCard.bounds, to: container)
        return frame.contains(point)
    }

    func pointInHistoryUsageTimeRangePopup(_ point: NSPoint, container: NSView) -> Bool {
        guard !historyUsageTimeRangePopup.isHidden else { return false }
        let frame = historyUsageTimeRangePopup.convert(historyUsageTimeRangePopup.bounds, to: container)
        return frame.contains(point)
    }

    func refreshHistorySection() {
        let usageStats = HistoryUsageStats(entries: model.historyEntries)
        historySummaryLabel.stringValue = SettingsWindowSupport.historySummaryText(
            forEntryCount: model.historyEntries.count
        )
        historyUsageStatsLabel.stringValue = SettingsWindowSupport.historyUsageStatsText(
            for: usageStats
        )
        refreshHistoryUsageMetricCards(using: usageStats)
        syncHistoryUsageTimeRangePopupSelection()
        applyHistoryUsageMetricSelectionState()
        refreshHistoryUsageDetail(entries: model.historyEntries)

        if currentSection == .history {
            rebuildHistoryRows()
        } else {
            historyEntryByIdentifier = [:]
            replaceArrangedSubviews(in: historyRowsStack, with: [])
        }
    }

    func filteredDictionaryEntries() -> [DictionaryEntry] {
        SettingsWindowSupport.filteredDictionaryEntries(
            model.dictionaryEntries,
            query: dictionarySearchField.stringValue,
            selection: dictionarySelectedCollection
        )
    }

    func rebuildDictionaryTermRows() {
        let entries = filteredDictionaryEntries()
        guard !entries.isEmpty else {
            updateDictionaryTermsRowsHeight(forVisibleRowCount: 1)
            let message = dictionarySearchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? dictionaryEmptyStateText()
                : "No terms match your search."
            let messageLabel = makeBodyLabel(message)
            replaceArrangedSubviews(
                in: dictionaryTermRowsStack,
                with: [messageLabel]
            )
            return
        }

        updateDictionaryTermsRowsHeight(forVisibleRowCount: entries.count)
        replaceArrangedSubviews(
            in: dictionaryTermRowsStack,
            with: entries.map(makeDictionaryTermRow(entry:))
        )
    }

    func rebuildDictionarySuggestionRows() {
        guard !model.dictionarySuggestions.isEmpty else {
            updateDictionarySuggestionRowsHeight(forVisibleRowCount: 1)
            let messageLabel = makeBodyLabel("No pending suggestions.")
            replaceArrangedSubviews(
                in: dictionarySuggestionRowsStack,
                with: [messageLabel]
            )
            return
        }

        let suggestions = model.dictionarySuggestions.sorted { lhs, rhs in
            lhs.capturedAt > rhs.capturedAt
        }

        updateDictionarySuggestionRowsHeight(forVisibleRowCount: suggestions.count)
        replaceArrangedSubviews(
            in: dictionarySuggestionRowsStack,
            with: suggestions.map(makeDictionarySuggestionRow(suggestion:))
        )
    }

    func syncDictionaryContentPresentation() {
        let filteredCount = filteredDictionaryEntries().count
        let totalTermCount = model.dictionaryEntries.count
        let suggestionCount = model.dictionarySuggestions.count
        dictionaryCollectionsFooterLabel.textColor = currentThemePalette.accent

        switch dictionarySelectedCollection {
        case .allTerms:
            dictionaryContentTitleLabel.stringValue = "All Terms"
            dictionaryContentSubtitleLabel.stringValue =
                filteredCount == totalTermCount
                    ? "\(totalTermCount) term\(totalTermCount == 1 ? "" : "s") in your library."
                    : "\(filteredCount) matching term\(filteredCount == 1 ? "" : "s") from \(totalTermCount)."
            dictionaryCollectionsFooterLabel.stringValue = "\(totalTermCount) terms"
        case let .tag(tag):
            dictionaryContentTitleLabel.stringValue = tag
            dictionaryContentSubtitleLabel.stringValue =
                filteredCount == 0
                    ? "No terms currently use this tag."
                    : "\(filteredCount) tagged term\(filteredCount == 1 ? "" : "s")."
            dictionaryCollectionsFooterLabel.stringValue = "\(filteredCount) tagged"
        case .suggestions:
            dictionaryContentTitleLabel.stringValue = "Suggestions"
            dictionaryContentSubtitleLabel.stringValue =
                suggestionCount == 0
                    ? "No pending suggestions."
                    : "\(suggestionCount) suggestion\(suggestionCount == 1 ? "" : "s") awaiting review."
            dictionaryCollectionsFooterLabel.stringValue = "\(suggestionCount) pending"
        }

        let showsSuggestions = dictionarySelectedCollection == .suggestions
        dictionarySearchField.isEnabled = !showsSuggestions
        dictionaryTermHeaderRow.isHidden = showsSuggestions
        dictionaryTermsRowsScrollView?.isHidden = showsSuggestions
        dictionarySuggestionRowsScrollView?.isHidden = !showsSuggestions
    }

    func dictionaryEmptyStateText() -> String {
        switch dictionarySelectedCollection {
        case .allTerms:
            return "No dictionary terms yet."
        case let .tag(tag):
            return "No terms tagged “\(tag)” yet."
        case .suggestions:
            return "No pending suggestions."
        }
    }

    func makeDictionaryTermRow(entry: DictionaryEntry) -> NSView {
        let presentation = SettingsPresentation.dictionaryRowPresentation(entry: entry)

        let canonicalLabel = NSTextField(labelWithString: presentation.canonical)
        canonicalLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        canonicalLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        canonicalLabel.lineBreakMode = .byTruncatingTail
        canonicalLabel.maximumNumberOfLines = 1
        canonicalLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true

        let bindingLabel = makeSubtleCaption(presentation.bindingSummary)
        bindingLabel.maximumNumberOfLines = 2
        bindingLabel.lineBreakMode = .byTruncatingTail
        bindingLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bindingLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

        let tagBadge = makeDictionaryTagBadge(text: presentation.tagLabel, isActive: entry.tag != nil)
        tagBadge.setContentHuggingPriority(.required, for: .horizontal)
        tagBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stateLabel = NSTextField(labelWithString: presentation.enabledStateText)
        stateLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        stateLabel.textColor = entry.isEnabled
            ? interfaceColor(light: NSColor.systemGreen.darker(), dark: NSColor.systemGreen.lighter())
            : .tertiaryLabelColor
        stateLabel.alignment = .right
        stateLabel.setContentHuggingPriority(.required, for: .horizontal)
        stateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        stateLabel.maximumNumberOfLines = 1
        stateLabel.lineBreakMode = .byTruncatingTail
        stateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true

        let actionsButton = makeOverflowActionButton(
            accessibilityLabel: "Term actions",
            action: #selector(showDictionaryTermActions(_:))
        )
        actionsButton.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)

        let row = NSStackView(views: [
            canonicalLabel,
            bindingLabel,
            tagBadge,
            NSView(),
            stateLabel,
            actionsButton
        ])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        return makeCompactListRow(content: row)
    }

    func makeDictionarySuggestionRow(suggestion: DictionarySuggestion) -> NSView {
        let summaryLabel = NSTextField(labelWithString: "\"\(suggestion.originalFragment)\" → \"\(suggestion.correctedFragment)\"")
        summaryLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        summaryLabel.maximumNumberOfLines = 1
        summaryLabel.lineBreakMode = .byTruncatingTail

        let sourceText = suggestion.sourceApplication?.isEmpty == false
            ? "Source: \(suggestion.sourceApplication!)"
            : "Source: Unknown app"
        let detailLabel = makeSubtleCaption(
            "Canonical: \(suggestion.proposedCanonical) • \(sourceText)"
        )
        detailLabel.maximumNumberOfLines = 1
        detailLabel.lineBreakMode = .byTruncatingTail

        let textStack = NSStackView(views: [summaryLabel, detailLabel])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let actionsButton = makeOverflowActionButton(
            accessibilityLabel: "Suggestion actions",
            action: #selector(showDictionarySuggestionActions(_:))
        )
        actionsButton.identifier = NSUserInterfaceItemIdentifier(suggestion.id.uuidString)

        let row = NSStackView(views: [textStack, NSView(), actionsButton])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        return makeCompactListRow(content: row)
    }

    func makeDictionaryListSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.alphaValue = 0.35
        return separator
    }

    func currentConfigurationFromFields() -> LLMConfiguration {
        LLMConfiguration(
            baseURL: baseURLField.stringValue,
            apiKey: apiKeyField.stringValue,
            model: modelField.stringValue,
            refinementPrompt: "",
            enableThinking: currentEnableThinking()
        )
    }

    func currentPostProcessingMode() -> PostProcessingMode {
        let index = max(0, postProcessingModePopup.indexOfSelectedItem)
        return PostProcessingMode.allCases[index]
    }

    func currentTranslationProvider() -> TranslationProvider {
        let providers = availableTranslationProviders()
        let index = max(0, translationProviderPopup.indexOfSelectedItem)
        return providers[min(index, providers.count - 1)]
    }

    func currentRefinementProvider() -> RefinementProvider {
        let index = max(0, refinementProviderPopup.indexOfSelectedItem)
        return RefinementProvider.allCases[index]
    }

    func currentTargetLanguage() -> SupportedLanguage {
        let index = max(0, targetLanguagePopup.indexOfSelectedItem)
        return SupportedLanguage.allCases[index]
    }

    func currentEnableThinking() -> Bool? {
        Self.enableThinkingForSelectionIndex(
            max(0, thinkingPopup.indexOfSelectedItem)
        )
    }

    func currentSelectedASRBackend() -> ASRBackend {
        switch selectedASRBackendMode {
        case .local:
            return .appleSpeech
        case .remote:
            return currentSelectedRemoteASRProvider().backend
        }
    }

    func currentSelectedRemoteASRProvider() -> RemoteASRProvider {
        let index = max(0, asrRemoteProviderPopup.indexOfSelectedItem)
        return RemoteASRProvider.allCases[min(index, RemoteASRProvider.allCases.count - 1)]
    }

    func makeASRBackendChoiceCard(for mode: ASRBackendMode) -> NSView {
        let card = ASRBackendModeChoiceView(
            mode: mode,
            target: self,
            action: #selector(selectASRBackendFromCard(_:))
        )
        card.translatesAutoresizingMaskIntoConstraints = false
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        asrBackendCardViews[mode] = card
        return card
    }

    func refreshASRBackendChoiceSelection(_ selectedMode: ASRBackendMode) {
        for (mode, card) in asrBackendCardViews {
            card.isSelectedChoice = mode == selectedMode
        }
    }

    func updateASRConnectionDetailsContent(isRemoteBackend: Bool) {
        guard
            let remoteConfigurationSection = asrRemoteConfigurationSection,
            let connectionActionButtons = asrConnectionActionButtons,
            let localModeHintView = asrLocalModeHintView
        else { return }

        let targetViews = isRemoteBackend
            ? [remoteConfigurationSection, connectionActionButtons]
            : [localModeHintView]
        replaceArrangedSubviews(in: asrConnectionDetailsContentStack, with: targetViews)
    }

    func applyASRPlaceholders(for backend: ASRBackend) {
        asrBaseURLField.placeholderString = backend.remoteBaseURLPlaceholder
        asrModelField.placeholderString = backend.remoteModelPlaceholder
        asrVolcengineAppIDField.placeholderString = backend.remoteAppIDPlaceholder
    }

    func currentRemoteASRConfigurationFromFields() -> RemoteASRConfiguration {
        RemoteASRConfiguration(
            baseURL: asrBaseURLField.stringValue,
            apiKey: asrAPIKeyField.stringValue,
            model: asrModelField.stringValue,
            prompt: asrPromptField.stringValue,
            volcengineAppID: asrVolcengineAppIDField.stringValue
        )
    }

    func remoteASRRequiredFieldsText(for backend: ASRBackend) -> String {
        switch backend {
        case .remoteVolcengineASR:
            return "API Base URL, API Key, Model, and Volcengine AppID"
        case .remoteOpenAICompatible, .remoteAliyunASR:
            return "API Base URL, API Key, and Model"
        case .appleSpeech:
            return "configuration fields"
        }
    }

    func applySelectedASRBackendChange() {
        let backend = currentSelectedASRBackend()
        model.setASRBackend(backend)
        delegate?.settingsWindowController(self, didSelectASRBackend: backend)
        refreshHomeSection()
        refreshASRSection()
    }

    @objc
    func selectASRBackendFromCard(_ sender: ASRBackendModeChoiceView) {
        selectedASRBackendMode = sender.mode
        applySelectedASRBackendChange()
    }

    func permissionStatusText(for state: AuthorizationState) -> String {
        SettingsPresentation.permissionPresentation(for: state).title
    }

    func statusTitle(for state: AuthorizationState) -> String {
        SettingsPresentation.permissionPresentation(for: state).title
    }

    func navigationSection(for section: SettingsSection) -> SettingsSection {
        section == .history ? .dictionary : section
    }

    func selectSection(_ section: SettingsSection) {
        let previousSection = currentSection
        currentSection = section
        let selectedNavigationSection = navigationSection(for: section)

        if section == .history, previousSection != .history {
            historyUsageSelectedMetric = nil
            applyHistoryUsageMetricSelectionState()
            refreshHistoryUsageDetail(entries: model.historyEntries)
        }

        for (candidate, button) in sectionButtons {
            let isSelected = candidate == selectedNavigationSection
            button.state = isSelected ? .on : .off
            if let styledButton = button as? StyledSettingsButton {
                styledButton.applyAppearance(isSelected: isSelected)
            }
        }

        homeView.isHidden = section != .home
        permissionsView.isHidden = section != .permissions
        dictionaryView.isHidden = section != .dictionary
        historyView.isHidden = section != .history
        asrView.isHidden = section != .asr
        llmView.isHidden = section != .llm
        externalProcessorsView.isHidden = section != .externalProcessors
        aboutView.isHidden = section != .about

        if section == .history {
            rebuildHistoryRows()
        }

        if section == .permissions, previousSection != .permissions {
            refreshPermissions()
        }

        syncLibrarySubviewControls(for: section)
    }

    @objc
    func sectionChanged(_ sender: NSButton) {
        guard let section = SettingsSection(rawValue: sender.tag) else { return }
        if section == .dictionary {
            selectSection(.history)
            return
        }
        selectSection(section)
    }

    @objc
    func openPermissionsSection() {
        selectSection(.permissions)
    }

    @objc
    func openLLMSection() {
        selectSection(.llm)
    }

    @objc
    func openExternalProcessorManager() {
        presentExternalProcessorManagerSheet()
    }

    @objc
    func openASRSection() {
        selectSection(.asr)
    }

    @objc
    func openAboutSection() {
        selectSection(.about)
    }

    @objc
    func openHistorySection() {
        selectSection(.history)
    }

    @objc
    func openDictionarySection() {
        selectSection(.dictionary)
    }

    @objc
    func dictionarySearchChanged(_ sender: NSSearchField) {
        rebuildDictionaryTermRows()
        syncDictionaryContentPresentation()
    }

    @objc
    func historySearchChanged(_ sender: NSSearchField) {
        historyCurrentPage = 0
        rebuildHistoryRows()
    }

}
