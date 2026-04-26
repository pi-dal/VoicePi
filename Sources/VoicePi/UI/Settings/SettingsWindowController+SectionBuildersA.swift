import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func updateResolvedPromptSummary() {
        let resolved = resolvedPromptFromControls()
        switch resolved.source {
        case .builtInDefault:
            resolvedPromptSummaryLabel.stringValue = "Active prompt: \(resolved.title)"
        case .starter:
            resolvedPromptSummaryLabel.stringValue = "Active starter prompt: \(resolved.title)"
        case .user:
            resolvedPromptSummaryLabel.stringValue = "Active custom prompt: \(resolved.title)"
        }
        resolvedPromptSummaryLabel.stringValue += " • \(Self.strictModeSummaryText(enabled: promptWorkspaceDraft.strictModeEnabled))"

        if let selectedPreset = selectedPromptPresetFromDraft(),
           let bindingSummary = promptBindingSummary(for: selectedPreset) {
            resolvedPromptSummaryLabel.stringValue += " • \(bindingSummary)"
        } else if
            promptWorkspaceDraft.strictModeEnabled,
            promptWorkspaceDraft.activeSelection == .builtInDefault
        {
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

        let promptBody = resolved.middleSection?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if promptBody.isEmpty {
            resolvedPromptBodyTextView?.string = Self.builtInDefaultPromptPreviewText
        } else {
            resolvedPromptBodyTextView?.string = promptBody
        }

        updateTextPromptCharacterCount()
        updatePromptRulesSummary()
    }

    func updateTextPromptCharacterCount() {
        guard let countLabel = textPromptCharacterCountLabel else { return }
        let count = resolvedPromptBodyTextView?.string.count ?? 0
        countLabel.stringValue = "\(count) / 500"
    }

    func updatePromptRulesSummary() {
        let presentation = SettingsWindowSupport.textPromptRulesPresentation(
            workspace: promptWorkspaceDraft,
            selectedPreset: selectedPromptPresetFromDraft(),
            resolvedPromptBody: resolvedPromptBodyTextView?.string ?? ""
        )

        promptRulesStrictModeLabel.stringValue = presentation.strictModeDetailText
        applyTextPromptRulePresentation(
            presentation.bindingCoverage,
            iconView: promptRulesBindingCoverageIconView,
            detailLabel: promptRulesBindingCoverageLabel
        )
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

    func promptBindingValues(from text: String) -> [String] {
        Self.bindingValues(from: text)
    }

    func applyCapturedPromptBinding(
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

    func setPromptEditorBindingStatus(_ message: String, isError: Bool = false) {
        promptEditorBindingStatusLabel?.stringValue = message
        promptEditorBindingStatusLabel?.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    func promptBindingSummary(for preset: PromptPreset) -> String? {
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

    func makeSectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12.5, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    func settingsBrandIcon() -> NSImage? {
        if let applicationIconImage = NSApp.applicationIconImage, applicationIconImage.size.width > 0 {
            return applicationIconImage
        }

        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            return image
        }

        return NSImage(systemSymbolName: "waveform", accessibilityDescription: "VoicePi")
    }

    func makeBodyLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    func makeValueLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .labelColor
        label.alignment = .right
        return label
    }

    func makeActionButton(title: String, action: Selector) -> NSButton {
        let button = StyledSettingsButton(title: title, role: .secondary, target: self, action: action)
        button.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.actionButtonHeight).isActive = true
        return button
    }

    func makePrimaryActionButton(title: String, action: Selector) -> NSButton {
        let button = StyledSettingsButton(title: title, role: .primary, target: self, action: action)
        button.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.actionButtonHeight).isActive = true
        return button
    }

    func makeSecondaryActionButton(title: String, action: Selector) -> NSButton {
        let button = StyledSettingsButton(title: title, role: .secondary, target: self, action: action)
        button.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.actionButtonHeight).isActive = true
        return button
    }

    func makeOverflowActionButton(accessibilityLabel: String, action: Selector) -> NSButton {
        let button = makeSecondaryActionButton(title: "", action: action)
        button.image = NSImage(
            systemSymbolName: "ellipsis.circle",
            accessibilityDescription: accessibilityLabel
        )?.withSymbolConfiguration(.init(pointSize: 13, weight: .semibold))
        button.imagePosition = .imageOnly
        button.image?.isTemplate = true
        button.toolTip = accessibilityLabel
        button.setAccessibilityLabel(accessibilityLabel)
        button.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.actionButtonHeight).isActive = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    func makeExternalProcessorEditButton(accessibilityLabel: String, action: Selector) -> NSButton {
        let button = IconOnlySettingsButton(
            symbolName: "square.and.pencil",
            accessibilityLabel: accessibilityLabel,
            target: self,
            action: action
        )
        button.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.actionButtonHeight).isActive = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    func makeCompactListRow(content: NSView) -> NSView {
        let row = ThemedSurfaceView(style: .row)
        content.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            content.topAnchor.constraint(equalTo: row.topAnchor, constant: 9),
            content.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -9)
        ])
        row.setContentHuggingPriority(.required, for: .vertical)
        row.setContentCompressionResistancePriority(.required, for: .vertical)
        return row
    }

    func makeLibrarySubviewControl(selectedSection: SettingsSection) -> NSView {
        let control = LibrarySubviewTabControl(
            selectedSection: selectedSection,
            target: self,
            historyAction: #selector(openHistorySection),
            dictionaryAction: #selector(openDictionarySection)
        )
        librarySubviewControls.append(control)

        let row = NSStackView(views: [control, NSView()])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        return row
    }

    func syncLibrarySubviewControls(for section: SettingsSection) {
        guard section == .history || section == .dictionary else { return }
        for control in librarySubviewControls {
            control.selectedSection = section
        }
    }

    func makeProviderSubviewControl(selectedSubview: ProviderSubview) -> NSView {
        let control = ProviderSubviewTabControl(
            selectedSubview: selectedSubview,
            target: self,
            asrAction: #selector(openProviderASRSubview),
            llmAction: #selector(openProviderLLMSubview)
        )
        providerSubviewControls.append(control)

        let row = NSStackView(views: [control, NSView()])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        return row
    }

    func syncProviderSubviewControls() {
        for control in providerSubviewControls {
            control.selectedSubview = selectedProviderSubview
        }
    }

    func addPageSection(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    func makeFlexiblePageSpacer() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return spacer
    }

    func makeButtonGroup(_ buttons: [NSButton]) -> NSStackView {
        let stack = NSStackView(views: buttons)
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        return stack
    }

    func makeButtonRows(_ rows: [[NSButton]]) -> NSStackView {
        let stack = NSStackView(views: rows.map(makeButtonGroup))
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        return stack
    }

    func makeSectionHeader(title: String, subtitle: String) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14.5, weight: .semibold)
        titleLabel.textColor = currentThemePalette.titleText
        titleLabel.alignment = .left

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = currentThemePalette.subtitleText
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.alignment = .left

        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.spacing = SettingsLayoutMetrics.sectionHeaderSpacing
        stack.alignment = .leading
        return stack
    }

    func makeSectionHeader(title: String) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14.5, weight: .semibold)
        titleLabel.textColor = currentThemePalette.titleText
        titleLabel.alignment = .left
        return titleLabel
    }

    func makeDetailStack(statusLabel: NSTextField, buttons: NSView) -> NSView {
        let stack = NSStackView(views: [statusLabel, buttons])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .trailing
        return stack
    }

    func makeSectionNavigation() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.alignment = .centerY
        stack.distribution = .fillEqually

        sectionButtons.removeAll()

        for section in SettingsSection.navigationCases {
            let button = StyledSettingsButton(title: section.title, role: .navigation, target: self, action: #selector(sectionChanged(_:)))
            button.tag = section.rawValue
            button.setButtonType(.toggle)
            button.image = navigationSectionIcon(for: section)
            button.imagePosition = .imageAbove
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.navigationButtonHeight)
            ])

            sectionButtons[section] = button
            stack.addArrangedSubview(button)
        }

        return stack
    }

    func iconName(for section: SettingsSection) -> String {
        switch section {
        case .home:
            return "house"
        case .permissions:
            return "lock.shield"
        case .dictionary:
            return "books.vertical"
        case .history:
            return "clock.arrow.circlepath"
        case .llm:
            return "sparkles"
        case .provider:
            return "server.rack"
        case .asr:
            return "waveform.and.mic"
        case .externalProcessors:
            return "terminal"
        case .about:
            return "info.circle"
        }
    }

    func navigationSectionIcon(for section: SettingsSection) -> NSImage? {
        guard let symbolImage = NSImage(
            systemSymbolName: iconName(for: section),
            accessibilityDescription: section.title
        )?.withSymbolConfiguration(.init(pointSize: 10.5, weight: .medium)) else {
            return nil
        }

        let paddedSize = NSSize(
            width: symbolImage.size.width,
            height: symbolImage.size.height + Self.navigationIconTopPadding
        )
        let paddedImage = NSImage(size: paddedSize)
        paddedImage.lockFocus()
        symbolImage.draw(
            in: NSRect(origin: .zero, size: symbolImage.size),
            from: NSRect(origin: .zero, size: symbolImage.size),
            operation: .sourceOver,
            fraction: 1
        )
        paddedImage.unlockFocus()
        paddedImage.isTemplate = true
        return paddedImage
    }

    func makeFeatureHeader(icon: String, eyebrow: String, title: String, description: String) -> NSView {
        let card = makeCardView()

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.contentTintColor = currentThemePalette.accent

        let eyebrowLabel = NSTextField(labelWithString: eyebrow.uppercased())
        eyebrowLabel.font = .systemFont(ofSize: 10.5, weight: .semibold)
        eyebrowLabel.textColor = NSColor(name: nil) { appearance in
            SettingsWindowTheme.featureEyebrowTextColor(for: appearance)
        }

        let titleLabel = NSTextField(wrappingLabelWithString: title)
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = currentThemePalette.titleText

        let descriptionLabel = makeBodyLabel(description)

        let stack = NSStackView(views: [iconView, eyebrowLabel, titleLabel, descriptionLabel])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    func makeFeatureCard(icon: String, title: String, description: String) -> NSView {
        let card = makeCardView()

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.contentTintColor = currentThemePalette.accent

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13.5, weight: .semibold)
        titleLabel.textColor = currentThemePalette.titleText

        let descriptionLabel = makeBodyLabel(description)

        let stack = NSStackView(views: [iconView, titleLabel, descriptionLabel])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    func makeFeatureStrip(_ cards: [NSView]) -> NSView {
        let stack = NSStackView(views: cards)
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.alignment = .top
        return stack
    }

    func makeSimpleSummaryCard(
        title: String,
        subtitle: String? = nil,
        bodyViews: [NSView]
    ) -> NSView {
        let card = makeCardView()
        var views: [NSView] = [makeSectionTitle(title)]

        if let subtitle {
            let subtitleLabel = makeSubtleCaption(subtitle)
            subtitleLabel.maximumNumberOfLines = 2
            views.append(subtitleLabel)
        }

        views.append(contentsOf: bodyViews)

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    func makeFormListCard(
        title: String,
        rows: [NSView],
        footerViews: [NSView] = []
    ) -> NSView {
        let card = makeCardView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading

        stack.addArrangedSubview(makeSectionTitle(title))

        for (index, row) in rows.enumerated() {
            stack.addArrangedSubview(row)

            if index < rows.count - 1 || !footerViews.isEmpty {
                let separator = NSBox()
                separator.boxType = .separator
                separator.alphaValue = 0.35
                stack.addArrangedSubview(separator)
            }
        }

        for (index, view) in footerViews.enumerated() {
            stack.addArrangedSubview(view)
            if index < footerViews.count - 1 {
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.heightAnchor.constraint(equalToConstant: 2).isActive = true
                stack.addArrangedSubview(spacer)
            }
        }

        pinCardContent(stack, into: card)
        return card
    }

    func makeSummaryDetailRow(
        title: String,
        detailLabel: NSTextField,
        accessory: NSView? = nil
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [titleLabel, detailLabel])
        textStack.orientation = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading

        var views: [NSView] = [textStack, NSView()]
        if let accessory {
            views.append(accessory)
        }

        let rowContent = NSStackView(views: views)
        rowContent.orientation = .horizontal
        rowContent.alignment = .centerY
        rowContent.spacing = 12
        rowContent.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        return rowContent
    }

    func makeExternalProcessorsListCard() -> NSView {
        let card = makeCardView()
        let subtitleLabel = makeSubtleCaption(
            "External processors let you extend VoicePi with custom commands and scripts."
        )
        subtitleLabel.maximumNumberOfLines = 0

        let headerRow = NSStackView(views: [makeSectionTitle("External Processors"), NSView(), externalProcessorManagerButton])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 10

        let columnsRow = NSStackView(views: [
            makeProcessorHeaderLabel("Name", width: 152),
            makeProcessorHeaderLabel("Command", width: 232),
            makeProcessorHeaderLabel("Arguments", width: 108),
            makeProcessorHeaderLabel("Enabled", width: 76),
            NSView()
        ])
        columnsRow.orientation = .horizontal
        columnsRow.alignment = .centerY
        columnsRow.spacing = 12
        columnsRow.distribution = .fill

        let stack = NSStackView(views: [headerRow, subtitleLabel, columnsRow, externalProcessorsRowsStack])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        headerRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        columnsRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        externalProcessorsRowsStack.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        pinCardContent(stack, into: card)
        return card
    }

    func makeExternalProcessorsSelectedCard() -> NSView {
        let card = makeCardView()
        let headerRow = NSStackView(views: [makeSectionTitle("Selected Processor"), NSView(), externalProcessorsTestButton])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 10

        let stack = NSStackView(views: [
            headerRow,
            externalProcessorsSummaryLabel,
            externalProcessorsDetailLabel,
            externalProcessorsStatusLabel
        ])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        headerRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        pinCardContent(stack, into: card)
        return card
    }

    func makeExternalProcessorsHelpCard() -> NSView {
        let card = makeCardView()
        let introLabel = makeBodyLabel(
            "External processors let you extend VoicePi with custom commands and scripts."
        )

        let helpRows = SettingsWindowSupport.externalProcessorHelpItems.map(makeExternalProcessorHelpItemRow)
        let examplesCard = makeExternalProcessorExamplesCard()
        let footerLabel = makeBodyLabel("Processors are executed in order from top to bottom.")

        let stack = NSStackView(views: [
            makeSectionTitle("Processors Help"),
            introLabel
        ] + helpRows + [examplesCard, footerLabel])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading

        examplesCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        pinCardContent(stack, into: card)
        return card
    }

    func makeExternalProcessorHelpItemRow(_ item: ExternalProcessorHelpItemPresentation) -> NSView {
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: item.title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconView.contentTintColor = currentThemePalette.accent
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let titleLabel = NSTextField(labelWithString: item.title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        let detailLabel = makeBodyLabel(item.detailText)
        let textStack = NSStackView(views: [titleLabel, detailLabel])
        textStack.orientation = .vertical
        textStack.spacing = 3
        textStack.alignment = .leading

        let row = NSStackView(views: [iconView, textStack])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .top
        return row
    }

    func makeExternalProcessorExamplesCard() -> NSView {
        let container = ThemedSurfaceView(style: .row)
        let titleLabel = NSTextField(labelWithString: "Examples")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor

        let exampleLabels = SettingsWindowSupport.externalProcessorHelpExamples.map { example in
            let label = NSTextField(labelWithString: example)
            label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            label.textColor = currentThemePalette.accent
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            return label
        }

        let stack = NSStackView(views: [titleLabel] + exampleLabels)
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        pinCardContent(stack, into: container, horizontalPadding: 14, verticalPadding: 14)
        return container
    }

    func makeProcessorHeaderLabel(_ text: String, width: CGFloat? = nil) -> NSTextField {
        let label = makeSubtleCaption(text)
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        if let width {
            label.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        return label
    }

    func makeProcessorColumnLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }

    func makeProcessorCommandLabel(_ text: String, maximumNumberOfLines: Int = 1) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = maximumNumberOfLines
        return label
    }

}
