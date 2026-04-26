import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func applyThemeAppearance() {
        window?.appearance = model.interfaceTheme.appearance
        window?.backgroundColor = pageBackgroundColor
        window?.contentView?.layer?.backgroundColor = pageBackgroundColor.cgColor
        asrRemoteProviderPopup.syncTheme()
        postProcessingModePopup.syncTheme()
        refinementProviderPopup.syncTheme()
        thinkingPopup.syncTheme()
        translationProviderPopup.syncTheme()
        targetLanguagePopup.syncTheme()
        activePromptPopup.syncTheme()
        historyUsageTimeRangePopup.syncTheme()
        historyDateFilterPopup.syncTheme()
        syncAppearanceControlTheme()
        refreshNavigationAppearance()
        applyDictionaryCollectionSelectionState()
        applyHistoryUsageMetricSelectionState()
    }

    func configurePostProcessingPopups() {
        postProcessingModePopup.removeAllItems()
        postProcessingModePopup.addItems(withTitles: PostProcessingMode.allCases.map(\.title))
        postProcessingModePopup.target = self
        postProcessingModePopup.action = #selector(postProcessingModeChanged(_:))

        refinementProviderPopup.removeAllItems()
        refinementProviderPopup.addItems(withTitles: RefinementProvider.allCases.map(\.title))
        refinementProviderPopup.target = self
        refinementProviderPopup.action = #selector(refinementProviderChanged(_:))

        thinkingPopup.removeAllItems()
        thinkingPopup.addItems(withTitles: Self.thinkingTitles())

        translationProviderPopup.removeAllItems()
        translationProviderPopup.addItems(withTitles: availableTranslationProviders().map(\.title))
        translationProviderPopup.target = self
        translationProviderPopup.action = #selector(translationProviderChanged(_:))

        targetLanguagePopup.removeAllItems()
        targetLanguagePopup.addItems(withTitles: SupportedLanguage.allCases.map(\.recognitionDisplayName))
        targetLanguagePopup.target = self
        targetLanguagePopup.action = #selector(targetLanguageChanged(_:))
    }

    func selectPopupItem(in popup: NSPopUpButton, matching rawValue: String) {
        if popup === postProcessingModePopup,
           let index = PostProcessingMode.allCases.firstIndex(where: { $0.rawValue == rawValue }) {
            popup.selectItem(at: index)
            return
        }

        if popup === refinementProviderPopup,
           let index = RefinementProvider.allCases.firstIndex(where: { $0.rawValue == rawValue }) {
            popup.selectItem(at: index)
            return
        }

        if popup === translationProviderPopup,
           let index = availableTranslationProviders().firstIndex(where: { $0.rawValue == rawValue }) {
            popup.selectItem(at: index)
            return
        }

        if popup === targetLanguagePopup || popup === homeLanguagePopup,
           let index = SupportedLanguage.allCases.firstIndex(where: { $0.rawValue == rawValue }) {
            popup.selectItem(at: index)
            return
        }

        if popup === asrRemoteProviderPopup,
           let index = RemoteASRProvider.allCases.firstIndex(where: { $0.rawValue == rawValue }) {
            popup.selectItem(at: index)
            return
        }

        if popup === interfaceThemePopup,
           let index = InterfaceTheme.allCases.firstIndex(where: { $0.rawValue == rawValue }) {
            popup.selectItem(at: index)
        }
    }

    func refreshNavigationAppearance() {
        for (candidate, button) in sectionButtons {
            (button as? StyledSettingsButton)?.applyAppearance(isSelected: candidate == currentSection)
        }
    }

    var appleTranslateSupported: Bool {
        AppleTranslateService.isSupported
    }

    func availableTranslationProviders() -> [TranslationProvider] {
        TranslationProvider.availableProviders(appleTranslateSupported: appleTranslateSupported)
    }

    func starterPromptPresets() -> [PromptPreset] {
        model.starterPromptPresets()
    }

    func setASRFeedback(_ presentation: ConnectionFeedbackPresentation, animated: Bool = false) {
        asrStatusView.apply(presentation, animated: animated)
    }

    func setLLMFeedback(_ presentation: ConnectionFeedbackPresentation, animated: Bool = false) {
        llmStatusView.apply(presentation, animated: animated)
    }

    func configureAppearanceControl() {
        interfaceThemePopup.removeAllItems()
        interfaceThemePopup.addItems(withTitles: InterfaceTheme.allCases.map(\.title))
        interfaceThemePopup.target = self
        interfaceThemePopup.action = #selector(interfaceThemeChanged(_:))
        interfaceThemePopup.controlSize = .regular
    }

    func syncAppearanceControlTheme() {
        interfaceThemePopup.appearance = window?.effectiveAppearance
        homeLanguagePopup.appearance = window?.effectiveAppearance
        interfaceThemePopup.syncTheme()
        homeLanguagePopup.syncTheme()
    }

    func applyPermissionStatus(
        _ state: AuthorizationState,
        to label: NSTextField,
        iconView: NSImageView? = nil
    ) {
        let presentation = SettingsPresentation.permissionPresentation(for: state)
        label.stringValue = presentation.title

        let color: NSColor
        let symbolName: String

        switch presentation.tone {
        case .granted:
            color = interfaceColor(
                light: NSColor.systemGreen.darker(),
                dark: NSColor.systemGreen.lighter()
            )
            symbolName = "checkmark.circle.fill"
        case .denied, .restricted:
            color = interfaceColor(
                light: NSColor.systemOrange.darker(),
                dark: NSColor.systemOrange.lighter()
            )
            symbolName = "exclamationmark.circle.fill"
        case .unknown:
            color = .secondaryLabelColor
            symbolName = "questionmark.circle.fill"
        }

        label.textColor = color
        iconView?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: presentation.title)
        iconView?.contentTintColor = color
    }

    func makeCardView() -> NSView {
        let card = ThemedSurfaceView(style: .card)
        card.setContentHuggingPriority(.required, for: .vertical)
        card.setContentCompressionResistancePriority(.required, for: .vertical)
        return card
    }

    func pinCardContent(
        _ content: NSView,
        into card: NSView,
        horizontalPadding: CGFloat = SettingsLayoutMetrics.cardPaddingHorizontal,
        verticalPadding: CGFloat = SettingsLayoutMetrics.cardPaddingVertical
    ) {
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: horizontalPadding),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -horizontalPadding),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: verticalPadding),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -verticalPadding)
        ])
    }

    func makePageStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = SettingsLayoutMetrics.pageSpacing
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func installScrollablePage(
        _ contentStack: NSStackView,
        in container: NSView,
        section: SettingsSection
    ) {
        addPageSection(makeFlexiblePageSpacer(), to: contentStack)

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let documentView = FlippedLayoutView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        pageScrollViews[section] = scrollView

        container.addSubview(scrollView)
        documentView.addSubview(contentStack)

        let clipView = scrollView.contentView
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            documentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: clipView.topAnchor),
            documentView.bottomAnchor.constraint(greaterThanOrEqualTo: clipView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: clipView.widthAnchor),

            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])
    }

    func scrollPage(section: SettingsSection, toBottom: Bool) {
        guard let scrollView = pageScrollViews[section], let documentView = scrollView.documentView else {
            return
        }

        scrollView.layoutSubtreeIfNeeded()
        documentView.layoutSubtreeIfNeeded()

        let targetY: CGFloat
        if toBottom {
            targetY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        } else {
            targetY = 0
        }

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func makeGroupedSection(rows: [NSView] = [], customViews: [NSView] = []) -> NSView {
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

    func makePreferenceRow(title: String, control: NSView) -> NSView {
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

    func makeShortcutPreferenceCard(
        title: String,
        control: NSView,
        hintLabel: NSTextField
    ) -> NSView {
        let card = makeCardView()
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.alignment = .left

        control.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [titleLabel, control, hintLabel])
        stack.orientation = .vertical
        stack.spacing = SettingsLayoutMetrics.compactShortcutCardSpacing
        stack.alignment = .leading

        pinCardContent(
            stack,
            into: card,
            verticalPadding: SettingsLayoutMetrics.compactCardPaddingVertical
        )
        return card
    }

    func configurePromptWorkspaceControls() {
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
        resolvedPromptBodyTextView?.string = Self.builtInDefaultPromptPreviewText
        [promptRulesStrictModeLabel, promptRulesBindingCoverageLabel].forEach { label in
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 2
        }
        promptRulesStrictModeLabel.stringValue = Self.strictModeHelpText
        promptRulesBindingCoverageLabel.stringValue = "No app or website bindings configured."

        promptStrictModeSwitch.target = self
        promptStrictModeSwitch.action = #selector(promptStrictModeChanged(_:))

        activePromptPopup.target = self
        activePromptPopup.action = #selector(activePromptChanged(_:))

        reloadPromptPopupItems()
    }

    func reloadPromptPopupItems() {
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

    func loadPromptWorkspaceSelections() {
        promptWorkspaceDraft = model.promptWorkspace
        reloadPromptPopupItems()
        selectPromptWorkspaceItem(in: activePromptPopup, for: promptWorkspaceDraft.activeSelection)
        promptStrictModeSwitch.state = promptWorkspaceDraft.strictModeEnabled ? .on : .off
        promptEditorDraft = nil
        updatePromptEditorState()
    }

    func selectPromptWorkspaceItem(
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

    func promptSelectionFromPopup(_ popup: NSPopUpButton) -> PromptActiveSelection {
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

    func selectedPromptPresetFromDraft() -> PromptPreset? {
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

    func updatePromptEditorState() {
        let selectedPreset = selectedPromptPresetFromDraft() ?? PromptPreset.builtInDefault
        editPromptButton.isEnabled = selectedPreset.source == .user
        deletePromptButton.isEnabled = selectedPreset.source == .user

        updateResolvedPromptSummary()
        scheduleTextLivePreviewUpdate()
    }

    func setPromptWorkspaceControlsEnabled(_ enabled: Bool) {
        activePromptPopup.isEnabled = enabled
        editPromptButton.isEnabled = enabled && (selectedPromptPresetFromDraft()?.source == .user)
        newPromptButton.isEnabled = enabled
        promptBindingsButton.isEnabled = enabled
        deletePromptButton.isEnabled = enabled && (selectedPromptPresetFromDraft()?.source == .user)
    }

    func resolvedPromptFromControls() -> ResolvedPromptPreset {
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

    func resolvedPromptTextFromControls() -> String? {
        return resolvedPromptFromControls().middleSection
    }

}
