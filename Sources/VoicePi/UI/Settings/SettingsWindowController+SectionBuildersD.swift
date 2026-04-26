import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func replaceArrangedSubviews(in stack: NSStackView, with views: [NSView]) {
        for arrangedSubview in stack.arrangedSubviews {
            stack.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        for view in views {
            stack.addArrangedSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    func makeAboutOverviewCard(
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

    func makeUpdateExperienceSection() -> NSView {
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

    func applyAboutUpdatePresentation() {
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

    func makeSubtleCaption(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .tertiaryLabelColor
        label.alignment = .left
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    func makeSubtleLinkButton(title: String, action: Selector) -> NSButton {
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

    func makeSubtleLinkRow(prefix: String, linkTitle: String, action: Selector) -> NSView {
        let row = NSStackView(views: [
            makeSubtleCaption(prefix),
            makeSubtleLinkButton(title: linkTitle, action: action)
        ])
        row.orientation = .horizontal
        row.spacing = 4
        row.alignment = .firstBaseline
        return row
    }

    func makeSubtleDoubleLinkRow(
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

    func makeAboutMetaRow(title: String, valueView: NSTextField) -> NSView {
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

    func makeAboutLinkRow(title: String, valueView: NSTextField, buttonTitle: String, action: Selector) -> NSView {
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

    func makeVerticalStack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = spacing
        stack.alignment = .leading
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func makeTwoColumnSection(left: NSView, right: NSView, leftPriority: CGFloat) -> NSView {
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

    func makeDictionaryContentSection(left: NSView, right: NSView) -> NSView {
        let stack = NSStackView(views: [left, right])
        stack.orientation = .horizontal
        stack.spacing = SettingsLayoutMetrics.twoColumnSpacing
        stack.alignment = .top
        stack.distribution = .fill
        left.setContentHuggingPriority(.required, for: .horizontal)
        left.setContentCompressionResistancePriority(.required, for: .horizontal)
        right.setContentHuggingPriority(.defaultLow, for: .horizontal)
        right.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        left.setContentHuggingPriority(.required, for: .vertical)
        right.setContentHuggingPriority(.required, for: .vertical)
        return stack
    }

    func makeTwoColumnGrid(_ views: [NSView]) -> NSView {
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

    func makeCompactPermissionRow(
        icon: String,
        title: String,
        description: String,
        statusLabel: NSTextField,
        actionButton: NSButton
    ) -> NSView {
        let accentColor = NSColor(name: nil) { appearance in
            SettingsWindowTheme.palette(for: appearance).accent
        }

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.contentTintColor = accentColor
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        let descriptionLabel = makeBodyLabel(description)
        descriptionLabel.maximumNumberOfLines = 2

        let textStack = NSStackView(views: [titleLabel, descriptionLabel])
        textStack.orientation = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading

        let statusStack = NSStackView(views: [makeStatusPill(label: statusLabel), actionButton])
        statusStack.orientation = .horizontal
        statusStack.spacing = 10
        statusStack.alignment = .centerY
        statusStack.setContentHuggingPriority(.required, for: .horizontal)
        statusStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        let rowContent = NSStackView(views: [iconView, textStack, NSView(), statusStack])
        rowContent.orientation = .horizontal
        rowContent.alignment = .centerY
        rowContent.spacing = 12

        return makeCompactListRow(content: rowContent)
    }

    func makePermissionOverviewCard(
        icon: String,
        title: String,
        description: String,
        statusLabel: NSTextField,
        statusIconView: NSImageView,
        action: Selector
    ) -> NSView {
        let accentColor = NSColor(name: nil) { appearance in
            SettingsWindowTheme.palette(for: appearance).accent
        }

        let card = ThemedSurfaceView(style: .row)
        card.toolTip = "Open \(title) settings"
        card.translatesAutoresizingMaskIntoConstraints = false

        let tapGesture = NSClickGestureRecognizer(target: self, action: action)
        card.addGestureRecognizer(tapGesture)

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        iconView.contentTintColor = accentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 14
        iconContainer.layer?.backgroundColor = accentColor.withAlphaComponent(0.18).cgColor
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = accentColor.withAlphaComponent(0.08).cgColor
        iconContainer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 46),
            iconContainer.heightAnchor.constraint(equalToConstant: 46),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])
        iconContainer.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor

        let descriptionLabel = NSTextField(labelWithString: description)
        descriptionLabel.font = .systemFont(ofSize: 12.5)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 2

        let textStack = NSStackView(views: [titleLabel, descriptionLabel])
        textStack.orientation = .vertical
        textStack.spacing = 3
        textStack.alignment = .leading
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 76).isActive = true

        let statusStack = NSStackView(views: [statusLabel, statusIconView])
        statusStack.orientation = .horizontal
        statusStack.spacing = 12
        statusStack.alignment = .centerY
        statusStack.setContentHuggingPriority(.required, for: .horizontal)
        statusStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        let rowContent = NSStackView(views: [iconContainer, textStack, NSView(), statusStack])
        rowContent.orientation = .horizontal
        rowContent.alignment = .centerY
        rowContent.spacing = 14

        pinCardContent(
            rowContent,
            into: card,
            horizontalPadding: 18,
            verticalPadding: 14
        )
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 84).isActive = true
        return card
    }

    func makePermissionCard(
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

    func makeStatusPill(label: NSTextField) -> NSView {
        let pill = ThemedSurfaceView(style: .pill)

        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -9),
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -3)
        ])

        return pill
    }

    var isDarkTheme: Bool {
        SettingsWindowTheme.isDark(currentThemeAppearance)
    }

    var pageBackgroundColor: NSColor {
        currentThemePalette.pageBackground
    }

    var cardBorderColor: NSColor {
        SettingsWindowTheme.surfaceChrome(for: currentThemeAppearance, style: .card).border
    }

    var currentThemeAppearance: NSAppearance? {
        window?.effectiveAppearance ?? window?.appearance ?? NSApp.effectiveAppearance
    }

    var currentThemePalette: SettingsWindowThemePalette {
        SettingsWindowTheme.palette(for: currentThemeAppearance)
    }

    func interfaceColor(light: NSColor, dark: NSColor) -> NSColor {
        isDarkTheme ? dark : light
    }
}
