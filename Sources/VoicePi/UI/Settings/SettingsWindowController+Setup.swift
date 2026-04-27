import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = pageBackgroundColor.cgColor
        librarySubviewControls = []

        let navigation = makeSectionNavigation()
        navigation.translatesAutoresizingMaskIntoConstraints = false
        navigation.setContentHuggingPriority(.required, for: .vertical)
        navigation.setContentCompressionResistancePriority(.required, for: .vertical)

        let navigationChrome = ThemedSurfaceView(style: .header)
        navigationChrome.translatesAutoresizingMaskIntoConstraints = false
        navigationChrome.addSubview(navigation)
        NSLayoutConstraint.activate([
            navigation.leadingAnchor.constraint(equalTo: navigationChrome.leadingAnchor),
            navigation.trailingAnchor.constraint(equalTo: navigationChrome.trailingAnchor),
            navigation.topAnchor.constraint(equalTo: navigationChrome.topAnchor),
            navigation.bottomAnchor.constraint(equalTo: navigationChrome.bottomAnchor)
        ])

        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(navigationChrome)
        contentView.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            navigationChrome.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            navigationChrome.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            navigationChrome.topAnchor.constraint(equalTo: contentView.topAnchor),
            navigationChrome.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.headerHeight),

            contentContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            contentContainer.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            contentContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            contentContainer.widthAnchor.constraint(lessThanOrEqualToConstant: SettingsLayoutMetrics.contentMaxWidth),
            contentContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: SettingsLayoutMetrics.contentMinWidth),
            contentContainer.topAnchor.constraint(equalTo: navigationChrome.bottomAnchor, constant: SettingsLayoutMetrics.pageSpacing),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsLayoutMetrics.contentMinHeight)
        ])

        buildHomeView()
        buildPermissionsView()
        buildASRView()
        buildLLMView()
        buildProviderLLMView()
        buildExternalProcessorsView()
        buildAboutView()
        buildDictionaryView()
        buildHistoryView()

        contentContainer.addSubview(homeView)
        contentContainer.addSubview(permissionsView)
        contentContainer.addSubview(asrView)
        contentContainer.addSubview(llmView)
        contentContainer.addSubview(providerLLMView)
        contentContainer.addSubview(externalProcessorsView)
        contentContainer.addSubview(aboutView)
        contentContainer.addSubview(dictionaryView)
        contentContainer.addSubview(historyView)

        [homeView, permissionsView, asrView, llmView, providerLLMView, externalProcessorsView, aboutView, dictionaryView, historyView].forEach { view in
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

    func buildHomeView() {
        let contentStack = makePageStack()
        let dynamicHomeReadinessTitleColor = NSColor(name: nil) { appearance in
            SettingsWindowTheme.homeReadinessTitleColor(for: appearance, isError: false)
        }

        homeLanguageLabel.font = .systemFont(ofSize: 12.5)
        homeLanguageLabel.alignment = .left
        homeLanguageLabel.lineBreakMode = .byWordWrapping
        homeLanguageLabel.maximumNumberOfLines = 1
        homeLanguageLabel.textColor = .secondaryLabelColor
        homeLanguageTitleLabel.font = .systemFont(ofSize: 13.5, weight: .medium)
        homeLanguageTitleLabel.textColor = .labelColor
        homeLanguageSubtitleLabel.font = .systemFont(ofSize: 11.5)
        homeLanguageSubtitleLabel.textColor = .secondaryLabelColor
        homeAppearanceTitleLabel.font = .systemFont(ofSize: 13.5, weight: .medium)
        homeAppearanceTitleLabel.textColor = .labelColor
        homeAppearanceSubtitleLabel.font = .systemFont(ofSize: 11.5)
        homeAppearanceSubtitleLabel.textColor = .secondaryLabelColor

        homeLanguagePopup.removeAllItems()
        homeLanguagePopup.addItems(withTitles: SupportedLanguage.allCases.map(\.rawValue))
        homeLanguagePopup.target = self
        homeLanguagePopup.action = #selector(homeLanguageChanged(_:))

        homeReadinessTitleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        homeReadinessTitleLabel.textColor = dynamicHomeReadinessTitleColor
        homeReadinessTitleLabel.alignment = .center
        homeReadinessIconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 72, weight: .semibold)
        homeReadinessIconView.imageScaling = .scaleProportionallyUpOrDown
        homePermissionSummaryLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        homePermissionSummaryLabel.alignment = .center
        homePermissionSummaryLabel.lineBreakMode = .byWordWrapping
        homePermissionSummaryLabel.maximumNumberOfLines = 0
        homeShortcutLabel.font = .systemFont(ofSize: 12.5)
        homeShortcutLabel.alignment = .left
        homeShortcutLabel.lineBreakMode = .byWordWrapping
        homeShortcutLabel.maximumNumberOfLines = 2
        homeShortcutLabel.textColor = .secondaryLabelColor
        homeCancelShortcutLabel.font = .systemFont(ofSize: 12.5)
        homeCancelShortcutLabel.alignment = .left
        homeCancelShortcutLabel.lineBreakMode = .byWordWrapping
        homeCancelShortcutLabel.maximumNumberOfLines = 2
        homeCancelShortcutLabel.textColor = .secondaryLabelColor
        homeModeShortcutLabel.font = .systemFont(ofSize: 12.5)
        homeModeShortcutLabel.alignment = .left
        homeModeShortcutLabel.lineBreakMode = .byWordWrapping
        homeModeShortcutLabel.maximumNumberOfLines = 2
        homeModeShortcutLabel.textColor = .secondaryLabelColor
        homePromptShortcutLabel.font = .systemFont(ofSize: 12.5)
        homePromptShortcutLabel.alignment = .left
        homePromptShortcutLabel.lineBreakMode = .byWordWrapping
        homePromptShortcutLabel.maximumNumberOfLines = 2
        homePromptShortcutLabel.textColor = .secondaryLabelColor
        homeProcessorShortcutLabel.font = .systemFont(ofSize: 12.5)
        homeProcessorShortcutLabel.alignment = .left
        homeProcessorShortcutLabel.lineBreakMode = .byWordWrapping
        homeProcessorShortcutLabel.maximumNumberOfLines = 2
        homeProcessorShortcutLabel.textColor = .secondaryLabelColor
        homeASRLabel.font = .systemFont(ofSize: 12.5)
        homeASRLabel.alignment = .center
        homeASRLabel.lineBreakMode = .byWordWrapping
        homeASRLabel.maximumNumberOfLines = 0
        homeASRLabel.textColor = .secondaryLabelColor
        homeLLMLabel.font = .systemFont(ofSize: 12.5)
        homeLLMLabel.alignment = .center
        homeLLMLabel.lineBreakMode = .byWordWrapping
        homeLLMLabel.maximumNumberOfLines = 0
        homeLLMLabel.textColor = .secondaryLabelColor
        homeSummaryLabel.font = .systemFont(ofSize: 15, weight: .medium)
        homeSummaryLabel.textColor = .secondaryLabelColor
        homeSummaryLabel.alignment = .center
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

        cancelShortcutRecorderField.target = self
        cancelShortcutRecorderField.action = #selector(cancelShortcutRecorderChanged(_:))
        cancelShortcutHintLabel.font = .systemFont(ofSize: 12)
        cancelShortcutHintLabel.textColor = .secondaryLabelColor
        cancelShortcutHintLabel.alignment = .left
        cancelShortcutHintLabel.lineBreakMode = .byWordWrapping
        cancelShortcutHintLabel.maximumNumberOfLines = 0
        cancelShortcutHintLabel.stringValue = cancelShortcutHintText(for: model.cancelShortcut)

        modeShortcutRecorderField.target = self
        modeShortcutRecorderField.action = #selector(modeShortcutRecorderChanged(_:))
        modeShortcutHintLabel.font = .systemFont(ofSize: 12)
        modeShortcutHintLabel.textColor = .secondaryLabelColor
        modeShortcutHintLabel.alignment = .left
        modeShortcutHintLabel.lineBreakMode = .byWordWrapping
        modeShortcutHintLabel.maximumNumberOfLines = 0
        modeShortcutHintLabel.stringValue = "Click the shortcut field, then press the combination you want to use for quick mode switching."

        promptShortcutRecorderField.target = self
        promptShortcutRecorderField.action = #selector(promptShortcutRecorderChanged(_:))
        promptShortcutHintLabel.font = .systemFont(ofSize: 12)
        promptShortcutHintLabel.textColor = .secondaryLabelColor
        promptShortcutHintLabel.alignment = .left
        promptShortcutHintLabel.lineBreakMode = .byWordWrapping
        promptShortcutHintLabel.maximumNumberOfLines = 0
        promptShortcutHintLabel.stringValue = promptShortcutHintText(for: model.promptCycleShortcut)

        processorShortcutRecorderField.target = self
        processorShortcutRecorderField.action = #selector(processorShortcutRecorderChanged(_:))
        processorShortcutHintLabel.font = .systemFont(ofSize: 12)
        processorShortcutHintLabel.textColor = .secondaryLabelColor
        processorShortcutHintLabel.alignment = .left
        processorShortcutHintLabel.lineBreakMode = .byWordWrapping
        processorShortcutHintLabel.maximumNumberOfLines = 0
        processorShortcutHintLabel.stringValue = processorShortcutHintText(for: model.processorShortcut)

        configureAppearanceControl()
        homePrimaryActionButton.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let shortcutsCard = makeHomeShortcutsCard()
        let readinessCard = makeHomeReadinessCard()
        homeAppearanceSubtitleLabel.stringValue = "Follow system"
        let appearanceCard = makeHomeSelectorCard(
            sectionTitle: "Appearance",
            icon: "circle.lefthalf.filled",
            titleLabel: homeAppearanceTitleLabel,
            subtitleLabel: homeAppearanceSubtitleLabel,
            control: interfaceThemePopup
        )

        homeLanguageSubtitleLabel.stringValue = "Primary language"
        let languageCard = makeHomeSelectorCard(
            sectionTitle: "Language",
            icon: "globe",
            titleLabel: homeLanguageTitleLabel,
            subtitleLabel: homeLanguageSubtitleLabel,
            control: homeLanguagePopup
        )

        let leftColumn = makeVerticalStack(
            [shortcutsCard, languageCard, appearanceCard],
            spacing: SettingsLayoutMetrics.pageSpacing
        )

        languageCard.heightAnchor.constraint(equalToConstant: 112).isActive = true
        appearanceCard.heightAnchor.constraint(equalToConstant: 112).isActive = true
        shortcutsCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor).isActive = true
        languageCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor).isActive = true
        appearanceCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor).isActive = true

        let primaryRow = NSStackView(views: [leftColumn, readinessCard])
        primaryRow.orientation = .horizontal
        primaryRow.spacing = 16
        primaryRow.alignment = .top
        primaryRow.distribution = .fillEqually
        leftColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        leftColumn.setContentCompressionResistancePriority(.required, for: .horizontal)
        readinessCard.setContentHuggingPriority(.defaultLow, for: .horizontal)
        readinessCard.setContentCompressionResistancePriority(.required, for: .horizontal)
        readinessCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor).isActive = true

        contentStack.addArrangedSubview(primaryRow)

        installScrollablePage(contentStack, in: homeView, section: .home)
    }

    func buildPermissionsView() {
        let contentStack = makePageStack()

        let sectionTitleLabel = NSTextField(labelWithString: "Permissions")
        sectionTitleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        sectionTitleLabel.textColor = .labelColor
        sectionTitleLabel.alignment = .left

        [
            microphoneStatusLabel,
            speechStatusLabel,
            accessibilityStatusLabel,
            inputMonitoringStatusLabel
        ].forEach { label in
            label.font = .systemFont(ofSize: 14, weight: .semibold)
            label.alignment = .right
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        [
            microphoneStatusIconView,
            speechStatusIconView,
            accessibilityStatusIconView,
            inputMonitoringStatusIconView
        ].forEach { iconView in
            iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            iconView.imageScaling = .scaleProportionallyDown
            iconView.setContentHuggingPriority(.required, for: .horizontal)
            iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        permissionsHintLabel.font = .systemFont(ofSize: 13)
        permissionsHintLabel.textColor = .secondaryLabelColor
        permissionsHintLabel.alignment = .left
        permissionsHintLabel.lineBreakMode = .byWordWrapping
        permissionsHintLabel.maximumNumberOfLines = 0
        permissionsHintLabel.stringValue = PermissionsCopy.permissionsFooterNote

        let permissionRows = makeVerticalStack([
            makePermissionOverviewCard(
                icon: "mic.fill",
                title: "Microphone",
                description: "Required for capturing audio.",
                statusLabel: microphoneStatusLabel,
                statusIconView: microphoneStatusIconView,
                action: #selector(openMicrophoneSettingsFromCard(_:))
            ),
            makePermissionOverviewCard(
                icon: "waveform",
                title: "Speech Recognition",
                description: "Required for on-device recognition.",
                statusLabel: speechStatusLabel,
                statusIconView: speechStatusIconView,
                action: #selector(openSpeechSettingsFromCard(_:))
            ),
            makePermissionOverviewCard(
                icon: "figure.wave",
                title: "Accessibility",
                description: PermissionsCopy.accessibilityDescription,
                statusLabel: accessibilityStatusLabel,
                statusIconView: accessibilityStatusIconView,
                action: #selector(openAccessibilitySettingsFromCard(_:))
            ),
            makePermissionOverviewCard(
                icon: "keyboard",
                title: "Input Monitoring",
                description: PermissionsCopy.inputMonitoringDescription,
                statusLabel: inputMonitoringStatusLabel,
                statusIconView: inputMonitoringStatusIconView,
                action: #selector(openInputMonitoringSettingsFromCard(_:))
            )
        ], spacing: 16)
        permissionRows.arrangedSubviews.forEach { row in
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: permissionRows.widthAnchor).isActive = true
        }

        let refreshButton = makeSecondaryActionButton(
            title: "Refresh",
            action: #selector(refreshPermissionsFromFooter)
        )
        refreshButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 108).isActive = true
        let openSettingsButton = makeSecondaryActionButton(
            title: "Open Settings...",
            action: #selector(openSystemSettingsOverview)
        )
        openSettingsButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 168).isActive = true

        let actionButtons = makeButtonGroup([refreshButton, openSettingsButton])
        let footerRow = NSStackView(views: [permissionsHintLabel, NSView(), actionButtons] as [NSView])
        footerRow.orientation = .horizontal
        footerRow.spacing = 12
        footerRow.alignment = .centerY

        addPageSection(sectionTitleLabel, to: contentStack)
        addPageSection(permissionRows, to: contentStack)
        addPageSection(footerRow, to: contentStack)

        installScrollablePage(contentStack, in: permissionsView, section: .permissions)
    }

}
