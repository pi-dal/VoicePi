import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func makeHomeShortcutRow(
        icon: String,
        title: String,
        summaryLabel: NSTextField,
        control: NSView
    ) -> NSView {
        let accentColor = NSColor(name: nil) { appearance in
            SettingsWindowTheme.palette(for: appearance).accent
        }

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
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
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = NSColor(name: nil) { appearance in
            SettingsWindowTheme.homeShortcutTitleColor(for: appearance)
        }

        let textStack = NSStackView(views: [titleLabel, summaryLabel])
        textStack.orientation = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)

        let rowContent = NSStackView(views: [iconContainer, textStack, NSView(), control])
        rowContent.orientation = .horizontal
        rowContent.spacing = 12
        rowContent.alignment = .centerY

        return makeCompactListRow(content: rowContent)
    }

    func makeHomeShortcutsCard() -> NSView {
        let rows = [
            makeHomeShortcutRow(
                icon: "mic.fill",
                title: "Toggle Listening",
                summaryLabel: homeShortcutLabel,
                control: shortcutRecorderField
            ),
            makeHomeShortcutRow(
                icon: "stop.fill",
                title: "Stop / Cancel",
                summaryLabel: homeCancelShortcutLabel,
                control: cancelShortcutRecorderField
            ),
            makeHomeShortcutRow(
                icon: "headphones",
                title: "Mode Switch",
                summaryLabel: homeModeShortcutLabel,
                control: modeShortcutRecorderField
            ),
            makeHomeShortcutRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Prompt Cycle",
                summaryLabel: homePromptShortcutLabel,
                control: promptShortcutRecorderField
            ),
            makeHomeShortcutRow(
                icon: "point.3.connected.trianglepath.dotted",
                title: "Processor Shortcut",
                summaryLabel: homeProcessorShortcutLabel,
                control: processorShortcutRecorderField
            )
        ]

        let stack = NSStackView(views: [makeSectionTitle("Shortcuts")] + rows)
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading

        let card = makeCardView()
        pinCardContent(stack, into: card)
        return card
    }

    func makeHomeReadinessCard() -> NSView {
        let card = makeCardView()

        let titleLabel = makeSectionTitle("Readiness")

        let readinessRing = NSView()
        readinessRing.translatesAutoresizingMaskIntoConstraints = false
        readinessRing.wantsLayer = true
        readinessRing.layer?.cornerRadius = 92
        readinessRing.layer?.borderWidth = 10
        readinessRing.layer?.borderColor = currentThemePalette.accent.withAlphaComponent(0.88).cgColor
        readinessRing.layer?.backgroundColor = currentThemePalette.accent.withAlphaComponent(0.04).cgColor

        homeReadinessIconView.translatesAutoresizingMaskIntoConstraints = false
        readinessRing.addSubview(homeReadinessIconView)
        NSLayoutConstraint.activate([
            readinessRing.widthAnchor.constraint(equalToConstant: 184),
            readinessRing.heightAnchor.constraint(equalToConstant: 184),
            homeReadinessIconView.centerXAnchor.constraint(equalTo: readinessRing.centerXAnchor),
            homeReadinessIconView.centerYAnchor.constraint(equalTo: readinessRing.centerYAnchor)
        ])

        let centeredContent = NSStackView(views: [
            readinessRing,
            homeReadinessTitleLabel,
            homeSummaryLabel,
            homePrimaryActionButton
        ])
        centeredContent.orientation = .vertical
        centeredContent.spacing = 18
        centeredContent.alignment = .centerX
        centeredContent.translatesAutoresizingMaskIntoConstraints = false
        homePrimaryActionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 216).isActive = true

        let centerContainer = NSView()
        centerContainer.translatesAutoresizingMaskIntoConstraints = false
        centerContainer.addSubview(centeredContent)
        NSLayoutConstraint.activate([
            centeredContent.centerXAnchor.constraint(equalTo: centerContainer.centerXAnchor),
            centeredContent.centerYAnchor.constraint(equalTo: centerContainer.centerYAnchor),
            centeredContent.leadingAnchor.constraint(greaterThanOrEqualTo: centerContainer.leadingAnchor),
            centeredContent.trailingAnchor.constraint(lessThanOrEqualTo: centerContainer.trailingAnchor),
            centeredContent.topAnchor.constraint(greaterThanOrEqualTo: centerContainer.topAnchor),
            centeredContent.bottomAnchor.constraint(lessThanOrEqualTo: centerContainer.bottomAnchor)
        ])

        let stack = NSStackView(views: [titleLabel, centerContainer])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        centerContainer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        pinCardContent(stack, into: card)
        centerContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 460).isActive = true
        return card
    }

    func makeHomeSelectorCard(
        sectionTitle: String,
        icon: String,
        titleLabel: NSTextField,
        subtitleLabel: NSTextField,
        control: NSView
    ) -> NSView {
        let accentColor = NSColor(name: nil) { appearance in
            SettingsWindowTheme.palette(for: appearance).accent
        }

        let sectionLabel = makeSectionTitle(sectionTitle)

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: sectionTitle)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
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

        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail

        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: 122).isActive = true
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [iconContainer, textStack, NSView(), control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let stack = NSStackView(views: [sectionLabel, row])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading

        let card = makeCardView()
        pinCardContent(stack, into: card, horizontalPadding: 14, verticalPadding: 14)
        return card
    }

    func makeASRLocalModeHintView() -> NSView {
        let hint = ThemedSurfaceView(style: .row)
        hint.translatesAutoresizingMaskIntoConstraints = false

        let accentColor = NSColor(name: nil) { appearance in
            SettingsWindowTheme.palette(for: appearance).accent
        }

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "Local mode")
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconView.contentTintColor = accentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Local mode active")
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        let bodyLabel = NSTextField(labelWithString: "Local mode uses Apple Speech and does not need remote configuration.")
        bodyLabel.font = .systemFont(ofSize: 12.5)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.maximumNumberOfLines = 2

        let textStack = NSStackView(views: [titleLabel, bodyLabel])
        textStack.orientation = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let content = NSStackView(views: [iconView, textStack])
        content.orientation = .horizontal
        content.spacing = 10
        content.alignment = .top
        content.translatesAutoresizingMaskIntoConstraints = false

        pinCardContent(content, into: hint, horizontalPadding: 14, verticalPadding: 12)
        return hint
    }

    func makeAboutBrandCard() -> NSView {
        let iconView = NSImageView()
        iconView.image = settingsBrandIcon()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 118),
            iconView.heightAnchor.constraint(equalToConstant: 118)
        ])

        let titleLabel = NSTextField(labelWithString: "VoicePi")
        titleLabel.font = .systemFont(ofSize: 40, weight: .bold)
        titleLabel.textColor = .labelColor

        aboutVersionLabel.font = .systemFont(ofSize: 17, weight: .medium)
        aboutVersionLabel.textColor = .labelColor
        aboutBuildLabel.font = .systemFont(ofSize: 17, weight: .medium)
        aboutBuildLabel.textColor = .labelColor

        let versionRow = NSStackView(views: [makeSubtleCaption("Version"), aboutVersionLabel])
        versionRow.orientation = .horizontal
        versionRow.spacing = 8
        versionRow.alignment = .firstBaseline
        let buildRow = NSStackView(views: [makeSubtleCaption("Build"), aboutBuildLabel])
        buildRow.orientation = .horizontal
        buildRow.spacing = 8
        buildRow.alignment = .firstBaseline

        let titleStack = NSStackView(views: [titleLabel, versionRow, buildRow])
        titleStack.orientation = .vertical
        titleStack.spacing = 10
        titleStack.alignment = .leading

        let heroRow = NSStackView(views: [iconView, titleStack])
        heroRow.orientation = .horizontal
        heroRow.spacing = 24
        heroRow.alignment = .centerY

        let descriptionLabel = makeBodyLabel(
            "Your voice. Your workflow. VoicePi stays compact, local-first, and ready for fast dictation."
        )
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        descriptionLabel.maximumNumberOfLines = 0

        let visitButton = makeAboutActionRowButton(
            title: "Visit Repository",
            symbolName: "logo.github",
            action: #selector(openRepository)
        )
        let issueButton = makeAboutActionRowButton(
            title: "Report an Issue",
            symbolName: "bubble.left.and.exclamationmark.bubble.right",
            action: #selector(openRepositoryIssues)
        )
        let buttons = NSStackView(views: [visitButton, issueButton])
        buttons.orientation = .vertical
        buttons.spacing = 14
        buttons.alignment = .leading
        visitButton.widthAnchor.constraint(equalTo: buttons.widthAnchor).isActive = true
        issueButton.widthAnchor.constraint(equalTo: buttons.widthAnchor).isActive = true

        let stack = NSStackView(views: [heroRow, descriptionLabel, buttons])
        stack.orientation = .vertical
        stack.spacing = 24
        stack.alignment = .leading

        let card = makeCardView()
        pinCardContent(stack, into: card, horizontalPadding: 28, verticalPadding: 28)
        return card
    }

    func makeAboutCreditsCard() -> NSView {
        let legacyNoteLabel = makeBodyLabel(AboutProfile.legacyCreditsNote)
        legacyNoteLabel.font = .systemFont(ofSize: 13)
        let builtByRow = makeSubtleLinkRow(
            prefix: "Built With Love By",
            linkTitle: AboutProfile.author,
            action: #selector(openGitHubProfile)
        )
        let inspiredByRow = makeSubtleDoubleLinkRow(
            prefix: "Inspired by",
            firstLinkTitle: AboutProfile.inspirationAuthorDisplay,
            firstAction: #selector(openInspirationAuthor),
            infix: "and",
            secondLinkTitle: "this tweet",
            secondAction: #selector(openInspirationPost)
        )

        return makeSimpleSummaryCard(
            title: "Credits",
            bodyViews: [legacyNoteLabel, builtByRow, inspiredByRow]
        )
    }

    func makeAboutFooter() -> NSView {
        let copyrightLabel = makeSubtleCaption("VoicePi is released as open source under the MIT License.")
        copyrightLabel.alignment = .center

        let linksRow = NSStackView(views: [
            makeSubtleLinkButton(title: AboutProfile.footerRepositoryDisplay, action: #selector(openRepository)),
            makeSubtleCaption("•"),
            makeSubtleLinkButton(title: AboutProfile.licenseDisplay, action: #selector(openLicense))
        ])
        linksRow.orientation = .horizontal
        linksRow.spacing = 10
        linksRow.alignment = .firstBaseline

        let stack = NSStackView(views: [copyrightLabel, linksRow])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16)
        ])
        return container
    }

}
