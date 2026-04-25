import AppKit
import Testing
@testable import VoicePi

@MainActor
struct SettingsWindowLayoutTests {
    @Test
    func settingsWindowChromeUsesExpectedCopyAndWidth() {
        #expect(SettingsWindowChrome.title == "VoicePi Settings")
        #expect(
            SettingsWindowChrome.subtitle
                == "Quick controls for permissions, dictation, dictionary, and processor settings."
        )
        #expect(SettingsWindowChrome.defaultSize.width == 820)
        #expect(SettingsWindowChrome.defaultSize.height == 600)
        #expect(SettingsWindowChrome.minimumSize.width == 720)
        #expect(SettingsWindowChrome.minimumSize.height == 600)
    }

    @Test
    func settingsWindowShowDoesNotPresentWindowDuringTests() {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.settingsWindowShowDoesNotPresentWindowDuringTests.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)

        controller.show(section: .history)

        #expect(controller.window?.isVisible == false)
    }

    @Test
    func settingsWindowThemeUsesWarmLightPalette() {
        let palette = SettingsWindowTheme.palette(for: NSAppearance(named: .aqua))
        let cardChrome = SettingsWindowTheme.surfaceChrome(for: NSAppearance(named: .aqua), style: .card)
        let headerChrome = SettingsWindowTheme.surfaceChrome(for: NSAppearance(named: .aqua), style: .header)
        let selectedNavigationChrome = SettingsWindowTheme.buttonChrome(
            for: NSAppearance(named: .aqua),
            role: .navigation,
            isSelected: true,
            isHovered: false,
            isHighlighted: false
        )

        #expect(
            palette.pageBackground == NSColor(
                calibratedRed: 0xF6 / 255.0,
                green: 0xF0 / 255.0,
                blue: 0xE8 / 255.0,
                alpha: 1
            )
        )
        #expect(
            palette.accent == NSColor(
                calibratedRed: 0x3E / 255.0,
                green: 0x64 / 255.0,
                blue: 0x4A / 255.0,
                alpha: 1
            )
        )
        #expect(
            cardChrome.background == NSColor(
                calibratedRed: 0xFC / 255.0,
                green: 0xF8 / 255.0,
                blue: 0xF1 / 255.0,
                alpha: 0.94
            )
        )
        #expect(cardChrome.cornerRadius == 14)
        #expect(
            headerChrome.background == NSColor(
                calibratedRed: 0xF7 / 255.0,
                green: 0xF2 / 255.0,
                blue: 0xEA / 255.0,
                alpha: 0.985
            )
        )
        #expect(headerChrome.cornerRadius == 0)
        #expect(
            selectedNavigationChrome.fill == NSColor.black.withAlphaComponent(0.015)
        )
        #expect(selectedNavigationChrome.border == .clear)
        #expect(selectedNavigationChrome.cornerRadius == 0)
        #expect(
            selectedNavigationChrome.text == palette.accent
        )
    }

    @Test
    func settingsWindowThemeUsesGraphiteDarkPalette() {
        let palette = SettingsWindowTheme.palette(for: NSAppearance(named: .darkAqua))
        let cardChrome = SettingsWindowTheme.surfaceChrome(for: NSAppearance(named: .darkAqua), style: .card)
        let headerChrome = SettingsWindowTheme.surfaceChrome(for: NSAppearance(named: .darkAqua), style: .header)
        let primaryButtonChrome = SettingsWindowTheme.buttonChrome(
            for: NSAppearance(named: .darkAqua),
            role: .primary,
            isSelected: false,
            isHovered: false,
            isHighlighted: false
        )
        let selectedNavigationChrome = SettingsWindowTheme.buttonChrome(
            for: NSAppearance(named: .darkAqua),
            role: .navigation,
            isSelected: true,
            isHovered: false,
            isHighlighted: false
        )

        #expect(
            palette.pageBackground == NSColor(
                calibratedRed: 0x16 / 255.0,
                green: 0x1A / 255.0,
                blue: 0x1C / 255.0,
                alpha: 1
            )
        )
        #expect(
            cardChrome.background == NSColor(
                calibratedRed: 0x1B / 255.0,
                green: 0x1F / 255.0,
                blue: 0x21 / 255.0,
                alpha: 0.90
            )
        )
        #expect(cardChrome.cornerRadius == 14)
        #expect(
            headerChrome.background == NSColor(
                calibratedRed: 0x18 / 255.0,
                green: 0x1C / 255.0,
                blue: 0x1E / 255.0,
                alpha: 0.98
            )
        )
        #expect(headerChrome.cornerRadius == 0)
        #expect(
            primaryButtonChrome.fill == NSColor(
                calibratedRed: 0x2F / 255.0,
                green: 0x69 / 255.0,
                blue: 0x39 / 255.0,
                alpha: 0.96
            )
        )
        #expect(
            primaryButtonChrome.text == NSColor(
                calibratedRed: 0xF4 / 255.0,
                green: 0xF8 / 255.0,
                blue: 0xF4 / 255.0,
                alpha: 1
            )
        )
        #expect(selectedNavigationChrome.border == .clear)
        #expect(selectedNavigationChrome.cornerRadius == 0)
        #expect(
            selectedNavigationChrome.fill == NSColor.white.withAlphaComponent(0.020)
        )
        #expect(
            selectedNavigationChrome.text == palette.accent
        )
        #expect(SettingsWindowTheme.homeShortcutIconColor(for: NSAppearance(named: .darkAqua)) == palette.subtitleText)
        #expect(
            SettingsWindowTheme.homeReadinessTitleColor(for: NSAppearance(named: .darkAqua), isError: false)
                == NSColor(
                    calibratedRed: 0xF1 / 255.0,
                    green: 0xF5 / 255.0,
                    blue: 0xF2 / 255.0,
                    alpha: 1
                )
        )
        #expect(SettingsWindowTheme.featureEyebrowTextColor(for: NSAppearance(named: .darkAqua)) == palette.subtitleText)
        #expect(SettingsWindowTheme.processorEnabledTextColor(for: NSAppearance(named: .darkAqua)) == palette.titleText)
    }

    @Test
    func topNavigationUsesFullWidthSegmentLayout() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.topNavigationUsesFullWidthSegmentLayout.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let navigationStack = try #require(findStack(in: contentView) { stack in
            guard stack.orientation == .horizontal else { return false }
            let labels = Set(stackDescendantLabels(in: stack))
            return labels.contains("Home")
                && labels.contains("Permissions")
                && labels.contains("Library")
                && labels.contains("ASR")
                && labels.contains("Text")
                && labels.contains("Processors")
                && labels.contains("About")
        })

        #expect(navigationStack.distribution == .fillEqually)
        #expect(navigationStack.spacing == 2)
        #expect(abs(navigationStack.frame.minX) < 0.5)
        #expect(abs(navigationStack.frame.width - contentView.bounds.width) < 0.5)
        #expect(abs(navigationStack.frame.minY) < 0.5)
        #expect(abs(navigationStack.frame.height - SettingsLayoutMetrics.headerHeight) < 0.5)
    }

    @Test
    func settingsControlsUseCompactReferenceSizing() {
        let navigationButton = StyledSettingsButton(
            title: "Home",
            role: .navigation,
            target: nil,
            action: #selector(NSResponder.cancelOperation(_:))
        )
        let primaryButton = StyledSettingsButton(
            title: "Start Listening",
            role: .primary,
            target: nil,
            action: #selector(NSResponder.cancelOperation(_:))
        )
        let popUpButton = ThemedPopUpButton()
        let recorderField = ShortcutRecorderField(frame: .zero)

        #expect(abs(controlFontPointSize(for: navigationButton) - 12) < 0.1)
        #expect(abs(controlFontPointSize(for: primaryButton) - 13) < 0.1)
        #expect(abs(controlFontPointSize(for: popUpButton) - 13) < 0.1)
        #expect(recorderField.controlSize == .regular)
        #expect(abs(controlFontPointSize(for: recorderField) - 12.5) < 0.1)
    }

    @Test
    func themedPopUpButtonsUseNeutralReferenceChrome() {
        let popUpButton = ThemedPopUpButton()
        popUpButton.appearance = NSAppearance(named: .darkAqua)
        popUpButton.syncTheme()

        #expect(popUpButton.focusRingType == .none)
        #expect(popUpButton.isBordered == false)
        #expect(popUpButton.wantsLayer == true)
        #expect(popUpButton.layer?.cornerRadius == 11)
    }

    @Test
    func processorShortcutHintExplainsEmptyAndStandardShortcutModes() {
        let standardShortcut = ActivationShortcut(
            keyCodes: [35],
            modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue
        )
        let emptyShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)

        #expect(
            SettingsWindowSupport.processorShortcutHintText(for: emptyShortcut)
                == "Set a processor shortcut to start a dedicated processor capture."
        )
        #expect(
            SettingsWindowSupport.processorShortcutHintText(for: standardShortcut)
                == "Current shortcut: ⌘ + P. Starts a dedicated processor capture. Standard shortcuts work without Input Monitoring."
        )
    }

    @Test
    func processorShortcutHintExplainsAdvancedShortcutMode() {
        let advancedShortcut = ActivationShortcut(
            keyCodes: [35, 31],
            modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue
        )

        #expect(
            SettingsWindowSupport.processorShortcutHintText(for: advancedShortcut)
                == "Current shortcut: ⌘ + P + O. Starts a dedicated processor capture. Advanced shortcuts require Input Monitoring. Accessibility lets VoicePi suppress it first."
        )
    }

    @Test
    func processorShortcutHintDoesNotDuplicatePunctuationForPeriodKey() {
        let periodShortcut = ActivationShortcut(
            keyCodes: [47],
            modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue
        )

        #expect(
            SettingsWindowSupport.processorShortcutHintText(for: periodShortcut)
                == "Current shortcut: ⌘ + . Starts a dedicated processor capture. Standard shortcuts work without Input Monitoring."
        )
    }

    @Test
    func promptCycleShortcutHintExplainsEmptyAndStandardShortcutModes() {
        let standardShortcut = ActivationShortcut(
            keyCodes: [35],
            modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue
        )
        let emptyShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)

        #expect(
            SettingsWindowSupport.promptCycleShortcutHintText(for: emptyShortcut)
                == "Set a prompt-cycle shortcut to rotate the Active Prompt before recording."
        )
        #expect(
            SettingsWindowSupport.promptCycleShortcutHintText(for: standardShortcut)
                == "Current shortcut: ⌘ + P. Cycles the Active Prompt. Standard shortcuts work without Input Monitoring."
        )
    }

    @Test
    func promptCycleShortcutHintExplainsAdvancedShortcutMode() {
        let advancedShortcut = ActivationShortcut(
            keyCodes: [35, 31],
            modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue
        )

        #expect(
            SettingsWindowSupport.promptCycleShortcutHintText(for: advancedShortcut)
                == "Current shortcut: ⌘ + P + O. Cycles the Active Prompt. Advanced shortcuts require Input Monitoring. Accessibility lets VoicePi suppress it first."
        )
    }

    @Test
    func externalProcessorsSectionPresentationHandlesEmptyAndSelectedStates() {
        let entry = ExternalProcessorEntry(
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "/usr/local/bin/alma",
            additionalArguments: [
                ExternalProcessorArgument(value: "--format"),
                ExternalProcessorArgument(value: "markdown")
            ],
            isEnabled: true
        )

        let emptyPresentation = SettingsWindowSupport.externalProcessorsSectionPresentation(
            entries: [],
            selectedEntry: nil
        )
        let selectedPresentation = SettingsWindowSupport.externalProcessorsSectionPresentation(
            entries: [entry],
            selectedEntry: entry
        )

        #expect(emptyPresentation.summaryText == "No processor selected yet.")
        #expect(
            emptyPresentation.detailText
                == "Add a processor to configure an external command and arguments."
        )
        #expect(
            selectedPresentation.summaryText
                == "Alma CLI"
        )
        #expect(
            selectedPresentation.detailText
                == "/usr/local/bin/alma --format markdown"
        )
    }

    @Test
    func externalProcessorManagerPresentationHidesPickerWhenNoEntriesExist() {
        let entry = ExternalProcessorEntry(
            name: "  Saved Processor  ",
            kind: .almaCLI,
            executablePath: "alma"
        )
        let emptyState = ExternalProcessorManagerState()
        let selectedState = ExternalProcessorManagerState(entries: [entry], selectedEntryID: entry.id)

        #expect(ExternalProcessorManagerPresentation.showsActiveProcessorPicker(for: emptyState) == false)
        #expect(
            ExternalProcessorManagerPresentation.feedbackText(for: emptyState)
                == SettingsWindowController.externalProcessorManagerEmptyStateText
        )
        #expect(ExternalProcessorManagerPresentation.showsActiveProcessorPicker(for: selectedState))
        #expect(
            ExternalProcessorManagerPresentation.feedbackText(for: selectedState)
                == "Selected: Saved Processor"
        )
    }

    @Test
    func homeShortcutControlsUseSingleShortcutCard() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.homeShortcutControlsUseSingleShortcutCard.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))

        #expect(labels.contains("Shortcuts"))
        #expect(labels.contains("Toggle Listening"))
        #expect(labels.contains("Stop / Cancel"))
        #expect(labels.contains("Mode Switch"))
        #expect(labels.contains("Prompt Cycle"))
        #expect(labels.contains("Processor Shortcut"))
    }

    @Test
    func eachSettingsSectionUsesScrollableContent() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.eachSettingsSectionUsesScrollableContent.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)
        let contentContainer = try #require(contentView.subviews.last)

        contentView.layoutSubtreeIfNeeded()

        #expect(contentContainer.subviews.count == 8)

        for sectionView in contentContainer.subviews {
            let sectionIsScrollable = sectionView is NSScrollView || containsScrollView(in: sectionView)
            #expect(sectionIsScrollable)
        }
    }

    @Test
    func settingsPagesDoNotRepeatStandaloneSectionHeadersInsideContent() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.settingsPagesDoNotRepeatStandaloneSectionHeadersInsideContent.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let repeatedSectionHeaders = findLabels(in: contentView) { label in
            let sectionTitles = ["Permissions", "Library", "ASR", "Text Processing", "Processors", "About"]
            guard sectionTitles.contains(label.stringValue) else { return false }
            return abs(label.font?.pointSize ?? 0 - 24) < 0.1
        }

        #expect(repeatedSectionHeaders.isEmpty)
    }

    @Test
    func homeSectionUsesReferenceStyleCardsInsteadOfLegacyMarketingRail() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.homeSectionUsesReferenceStyleCardsInsteadOfLegacyMarketingRail.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))

        #expect(labels.contains("Shortcuts"))
        #expect(labels.contains("Readiness"))
        #expect(labels.contains("Language"))
        #expect(labels.contains("Appearance"))
        #expect(labels.contains("Start Listening"))
        #expect(!labels.contains("General"))
        #expect(!labels.contains("Made With Love By pi-dal"))
    }

    @Test
    func aboutSectionUsesDedicatedUpdatesAndCreditsCards() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.aboutSectionUsesDedicatedUpdatesAndCreditsCards.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))

        #expect(labels.contains("Updates"))
        #expect(labels.contains("Credits"))
        #expect(labels.contains("Visit Repository"))
        #expect(labels.contains("Report an Issue"))
        #expect(!labels.contains("Project Focus"))
    }

    @Test
    func aboutSectionUsesLegacyCreditsCopyAndOpenSourceFooter() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.aboutSectionUsesLegacyCreditsCopyAndOpenSourceFooter.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        controller.show(section: .about)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))

        #expect(labels.contains(
            "VoicePi is a lightweight macOS dictation utility that lives in the menu bar, captures speech with a shortcut, optionally refines or translates transcripts, and pastes the final text into the active app."
        ))
        #expect(labels.contains("Built With Love By"))
        #expect(labels.contains("Inspired by"))
        #expect(findButton(in: contentView, title: "pi-dal") != nil)
        #expect(findButton(in: contentView, title: "yetone") != nil)
        #expect(findButton(in: contentView, title: "this tweet") != nil)
        #expect(findButton(in: contentView, title: "License (MIT)") != nil)
        #expect(findButton(in: contentView, title: "Repository") != nil)
    }

    @Test
    func aboutSectionUsesLargerBrandTreatment() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.aboutSectionUsesLargerBrandTreatment.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        controller.show(section: .about)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let brandCard = try #require(findCard(in: contentView) { card in
            let labels = Set(stackDescendantLabels(in: card))
            return labels.contains("Visit Repository")
                && labels.contains("Report an Issue")
                && labels.contains("VoicePi")
        })
        let titleLabel = try #require(findLabels(in: brandCard) { $0.stringValue == "VoicePi" }.first)
        let brandIcon = try #require(findImageViews(in: brandCard).max(by: { $0.frame.width < $1.frame.width }))

        #expect((titleLabel.font?.pointSize ?? 0) >= 34)
        #expect(brandIcon.frame.width >= 88)
        #expect(brandIcon.frame.height >= 88)
    }

    @Test
    func aboutSectionUsesFullWidthActionRowsForPrimaryLinks() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.aboutSectionUsesFullWidthActionRowsForPrimaryLinks.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        controller.show(section: .about)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let brandCard = try #require(findCard(in: contentView) { card in
            let labels = Set(stackDescendantLabels(in: card))
            return labels.contains("Visit Repository")
                && labels.contains("Report an Issue")
                && labels.contains("VoicePi")
        })
        let visitButton = try #require(findButton(in: brandCard, title: "Visit Repository"))
        let issueButton = try #require(findButton(in: brandCard, title: "Report an Issue"))

        for button in [visitButton, issueButton] {
            let iconViews = findImageViews(in: button)
            #expect(iconViews.count >= 2)
            #expect(iconViews.first?.image != nil)
            #expect(iconViews.last?.image != nil)
            #expect(button.frame.width >= brandCard.frame.width * 0.78)
            #expect(button.frame.height >= 52)
        }
    }

    @Test
    func aboutSectionUsesAirierBrandComposition() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.aboutSectionUsesAirierBrandComposition.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        controller.show(section: .about)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let brandCard = try #require(findCard(in: contentView) { card in
            let labels = Set(stackDescendantLabels(in: card))
            return labels.contains("Visit Repository")
                && labels.contains("Report an Issue")
                && labels.contains("VoicePi")
        })
        let topRow = try #require(findStack(in: contentView) { stack in
            guard stack.orientation == .horizontal else { return false }
            let labels = Set(stackDescendantLabels(in: stack))
            return labels.contains("Visit Repository")
                && labels.contains("Report an Issue")
                && labels.contains("Updates")
                && labels.contains("Credits")
        })
        let brandIcon = try #require(findImageViews(in: brandCard).max(by: { $0.frame.width < $1.frame.width }))
        let visitButton = try #require(findButton(in: brandCard, title: "Visit Repository"))
        let issueButton = try #require(findButton(in: brandCard, title: "Report an Issue"))
        let rightColumn = topRow.arrangedSubviews[1]

        #expect(brandIcon.frame.width >= 112)
        #expect(brandIcon.frame.height >= 112)
        #expect(visitButton.frame.height >= 64)
        #expect(issueButton.frame.height >= 64)
        #expect(abs(brandCard.frame.height - rightColumn.frame.height) <= 8)
    }

    @Test
    func historySectionStacksOverviewChartsAboveSearchableList() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.historySectionStacksOverviewChartsAboveSearchableList.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        model.historyEntries = [
            HistoryEntry(
                text: "Meeting Notes\nDiscussed launch work.",
                characterCount: 120,
                wordCount: 20,
                recordingDurationMilliseconds: 45_000
            )
        ]

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.show(section: .history)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        var labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))

        #expect(labels.contains("Overview"))
        #expect(findButton(in: contentView, title: "Filter") != nil)
        #expect(findButton(in: contentView, title: "Export") != nil)
        #expect(labels.contains("Characters"))
        #expect(labels.contains("Recording time"))

        let metricRow = try #require(findStack(in: contentView) { stack in
            guard stack.orientation == .horizontal else { return false }
            let metricCards = stack.arrangedSubviews.compactMap { $0 as? ThemedSurfaceView }
            guard metricCards.count == 4 else { return false }
            return metricCards.allSatisfy {
                $0.identifier?.rawValue.hasPrefix("history.usage.metric.") == true
            }
        })
        #expect(metricRow.arrangedSubviews.count == 4)

        let sessionsCard = try #require(findCard(in: contentView) { card in
            card.identifier?.rawValue == "history.usage.metric.\(HistoryUsageMetric.sessions.rawValue)"
        })
        let tapGesture = try #require(
            sessionsCard.gestureRecognizers
                .compactMap { $0 as? NSClickGestureRecognizer }
                .first
        )
        _ = (tapGesture.target as? NSObject)?.perform(tapGesture.action, with: tapGesture)

        contentView.layoutSubtreeIfNeeded()
        labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))

        #expect(labels.contains("Sessions Trend"))
        #expect(labels.contains("Sessions Heatmap"))

        let detailCard = try #require(findCard(in: contentView) { card in
            card.identifier?.rawValue == "history.usage.detail"
        })
        #expect(detailCard.isHidden == false)

        let historyDocumentView = try #require(findView(in: contentView) { view in
            view.identifier?.rawValue == "history.document"
        })
        let backgroundTap = try #require(
            historyDocumentView.gestureRecognizers
                .compactMap { $0 as? NSClickGestureRecognizer }
                .first
        )
        _ = (backgroundTap.target as? NSObject)?.perform(backgroundTap.action, with: backgroundTap)

        contentView.layoutSubtreeIfNeeded()
        #expect(detailCard.isHidden)
    }

    @Test
    func dictionarySectionPlacesSearchToolbarAboveCollectionsColumn() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.dictionarySectionPlacesSearchToolbarAboveCollectionsColumn.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        controller.show(section: .dictionary)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let searchField = try #require(findView(in: contentView) { view in
            guard let searchField = view as? NSSearchField else { return false }
            return searchField.placeholderString == "Search terms..."
        })
        let addButton = try #require(findButton(in: contentView, title: "Add Term"))
        let leftColumn = try #require(findStack(in: contentView) { stack in
            guard stack.orientation == .vertical else { return false }
            guard stack.arrangedSubviews.count == 2 else { return false }
            let labels = Set(stackDescendantLabels(in: stack))
            return labels.contains("Collections")
                && labels.contains("All Terms")
                && findView(in: stack) { view in
                    guard let searchField = view as? NSSearchField else { return false }
                    return searchField.placeholderString == "Search terms..."
                } != nil
                && findButton(in: stack, title: "Add Term") != nil
        })

        let searchFrame = searchField.convert(searchField.bounds, to: contentView)
        let addButtonFrame = addButton.convert(addButton.bounds, to: contentView)
        let leftColumnFrame = leftColumn.convert(leftColumn.bounds, to: contentView)

        #expect(searchFrame.minX >= leftColumnFrame.minX - 1)
        #expect(addButtonFrame.maxX <= leftColumnFrame.maxX + 1)
        #expect(searchFrame.minY >= leftColumnFrame.minY - 1)
        #expect(searchFrame.maxY <= leftColumnFrame.maxY + 1)
        #expect(addButtonFrame.minY >= leftColumnFrame.minY - 1)
        #expect(addButtonFrame.maxY <= leftColumnFrame.maxY + 1)
    }

    @Test
    func dictionarySectionKeepsContentCardWidthStableAcrossCollectionChanges() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.dictionarySectionKeepsContentCardWidthStableAcrossCollectionChanges.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        model.dictionaryEntries = [
            DictionaryEntry(canonical: "agent.md", aliases: ["agent md"]),
            DictionaryEntry(canonical: "spec", aliases: ["spd"]),
            DictionaryEntry(canonical: "关掉 thinking", aliases: ["one deal thinking"]),
            DictionaryEntry(canonical: "改写", aliases: ["矮显"])
        ]
        model.dictionarySuggestions = [
            DictionarySuggestion(
                originalFragment: "现在我在里边的 Terminal",
                correctedFragment: "的 Terminal",
                proposedCanonical: "的 Terminal",
                sourceApplication: "com.openai.atlas"
            ),
            DictionarySuggestion(
                originalFragment: "提交本地的代码要学习上一次 commit message 的格式",
                correctedFragment: "提交本地的代码要学习上一次 commit message 的格式与规范",
                proposedCanonical: "es",
                sourceApplication: "com.openai.codex"
            )
        ]

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.show(section: .dictionary)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let contentCard = try #require(findCard(in: contentView) { card in
            let labels = Set(stackDescendantLabels(in: card))
            return labels.contains("All Terms")
                && labels.contains("TERM")
                && labels.contains("BINDINGS")
                && labels.contains("STATE")
        })
        let allTermsWidth = contentCard.frame.width

        let suggestionsCollectionCard = try #require(findCard(in: contentView) { card in
            card.identifier?.rawValue == "dictionary.collection.Suggestions"
        })
        let tapGesture = try #require(
            suggestionsCollectionCard.gestureRecognizers
                .compactMap { $0 as? NSClickGestureRecognizer }
                .first
        )
        _ = (tapGesture.target as? NSObject)?.perform(tapGesture.action, with: tapGesture)

        contentView.layoutSubtreeIfNeeded()

        let labelsAfterSelection = Set(stackDescendantLabels(in: contentCard))
        #expect(labelsAfterSelection.contains("Suggestions"))
        #expect(abs(contentCard.frame.width - allTermsWidth) <= 1)
    }

    @Test
    func dictionarySectionUsesWiderSidebarWithUsableSearchField() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.dictionarySectionUsesWiderSidebarWithUsableSearchField.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        model.dictionaryEntries = [
            DictionaryEntry(canonical: "Cloudflare", aliases: ["cloud flare"]),
            DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre"])
        ]
        model.dictionarySuggestions = [
            DictionarySuggestion(
                originalFragment: "kuber",
                correctedFragment: "Kubernetes",
                proposedCanonical: "Kubernetes"
            )
        ]

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.show(section: .dictionary)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let searchField = try #require(findView(in: contentView) { view in
            guard let field = view as? NSSearchField else { return false }
            return field.placeholderString == "Search terms..."
        })
        let leftColumn = try #require(findStack(in: contentView) { stack in
            guard stack.orientation == .vertical else { return false }
            let labels = Set(stackDescendantLabels(in: stack))
            return labels.contains("Collections")
                && labels.contains("All Terms")
                && findView(in: stack) { view in
                    guard let field = view as? NSSearchField else { return false }
                    return field.placeholderString == "Search terms..."
                } != nil
        })

        #expect(leftColumn.frame.width >= 300)
        #expect(searchField.frame.width >= 220)
    }

    @Test
    func dictionaryCollectionsKeepLongTitlesSeparatedFromCountBadge() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.dictionaryCollectionsKeepLongTitlesSeparatedFromCountBadge.\(UUID().uuidString)"
        )!
        let longTag = "Extremely Long Collection Name For Overflow Handling"
        let model = AppModel(defaults: defaults)
        model.dictionaryEntries = (0..<11).map { index in
            DictionaryEntry(
                canonical: "Entry \(index)",
                aliases: ["Alias \(index)"],
                tag: longTag
            )
        }

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.show(section: .dictionary)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let row = try #require(findCard(in: contentView) { card in
            card.identifier?.rawValue == "dictionary.collection.\(longTag)"
        })
        let titleLabel = try #require(findLabel(in: row, stringValue: longTag))
        let countLabel = try #require(findLabel(in: row, stringValue: "11"))

        let titleFrame = titleLabel.convert(titleLabel.bounds, to: row)
        let countFrame = countLabel.convert(countLabel.bounds, to: row)

        #expect(titleLabel.lineBreakMode == .byTruncatingTail)
        #expect(titleFrame.maxX <= countFrame.minX - 8)
    }

    @Test
    func librarySubviewControlUsesCustomTabPillStyle() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.librarySubviewControlUsesCustomTabPillStyle.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        controller.show(section: .history)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let control = try #require(findView(in: contentView) { view in
            view is LibrarySubviewTabControl
        } as? LibrarySubviewTabControl)

        #expect(control.selectedSection == .history)
        #expect(control.historyButton.isSegmentSelected)
        #expect(control.dictionaryButton.isSegmentSelected == false)
        #expect(findView(in: control, matching: { $0 is NSSegmentedControl }) == nil)

        let historyIndicator = try #require(findView(in: control) { view in
            view.identifier?.rawValue == "library.subview.indicator.history"
        })
        let dictionaryIndicator = try #require(findView(in: control) { view in
            view.identifier?.rawValue == "library.subview.indicator.dictionary"
        })

        #expect(historyIndicator.isHidden == false)
        #expect(dictionaryIndicator.isHidden)
    }

    @Test
    func librarySubviewControlUsesWarmLightChromeAndLowerIndicatorSpacing() throws {
        let control = LibrarySubviewTabControl(
            selectedSection: .history,
            target: nil,
            historyAction: #selector(NSObject.description),
            dictionaryAction: #selector(NSObject.description)
        )
        control.appearance = NSAppearance(named: .aqua)
        control.frame = NSRect(x: 0, y: 0, width: 248, height: 42)
        control.layoutSubtreeIfNeeded()

        let palette = SettingsWindowTheme.palette(for: NSAppearance(named: .aqua))
        let chrome = SettingsWindowTheme.surfaceChrome(for: NSAppearance(named: .aqua), style: .pill)
        let backgroundColor = try #require(control.layer?.backgroundColor?.nsColor)
        let selectedColor = try #require(control.historyButton.titleLabel.textColor)
        let unselectedColor = try #require(control.dictionaryButton.titleLabel.textColor)
        let titleFrame = control.historyButton.titleLabel.frame
        let indicatorFrame = control.historyButton.indicatorView.frame

        #expect(backgroundColor.isApproximatelyEqual(to: chrome.background))
        #expect(selectedColor.isApproximatelyEqual(to: palette.accent))
        #expect(unselectedColor.isApproximatelyEqual(to: palette.titleText))
        #expect(indicatorFrame.minY - titleFrame.maxY >= 6)
    }

    @Test
    func historySectionTimeFiltersUseLeadingCalendarIcons() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.historySectionTimeFiltersUseLeadingCalendarIcons.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        controller.show(section: .history)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let rangePopup = try #require(findView(in: contentView) { view in
            guard let popup = view as? ThemedPopUpButton else { return false }
            return popup.titleOfSelectedItem == "1 Week"
        } as? ThemedPopUpButton)
        let dateFilterPopup = try #require(findView(in: contentView) { view in
            guard let popup = view as? ThemedPopUpButton else { return false }
            return popup.titleOfSelectedItem == "All Dates"
        } as? ThemedPopUpButton)

        #expect(rangePopup.leadingSymbolName == "calendar")
        #expect(dateFilterPopup.leadingSymbolName == "calendar.badge.clock")
        #expect(rangePopup.frame.width >= 100)
        #expect(rangePopup.frame.width <= 110)
    }

    @Test
    func externalProcessorManagerSheetDoesNotAttachWindowDuringTests() {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.externalProcessorManagerSheetDoesNotAttachWindowDuringTests.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        let entry = ExternalProcessorEntry(
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "/usr/local/bin/alma",
            isEnabled: true
        )
        model.setExternalProcessorEntries([entry])
        model.setSelectedExternalProcessorEntryID(entry.id)

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.openExternalProcessorManagerSheetFromShortcut()

        #expect(controller.window?.isVisible == false)
        #expect(controller.window?.attachedSheet == nil)
        #expect(controller.externalProcessorManagerSheetContentViewForTesting != nil)
    }

    @Test
    func promptEditorSheetDoesNotAttachWindowDuringTests() {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.promptEditorSheetDoesNotAttachWindowDuringTests.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)

        controller.presentNewPromptEditor(prefillingCapturedValue: "com.apple.TextEdit", kind: .appBundleID)

        #expect(controller.window?.isVisible == false)
        #expect(controller.window?.attachedSheet == nil)
        #expect(controller.promptEditorSheetContentViewForTesting != nil)
    }

    @Test
    func advancedSectionsUseNamedCardsInsteadOfSingleBareFormBlocks() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.advancedSectionsUseNamedCardsInsteadOfSingleBareFormBlocks.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))

        #expect(labels.contains("ASR Backend"))
        #expect(labels.contains("Connection Details"))
        #expect(labels.contains("Refinement & Translation"))
        #expect(labels.contains("System Prompt"))
        #expect(labels.contains("Processing Rules"))
        #expect(labels.contains("Preview"))
        #expect(!labels.contains("Provider Connection"))
        #expect(labels.contains("External Processors"))
        #expect(labels.contains("Selected Processor"))
    }

    @Test
    func asrSectionShowsVisibleBackendChoiceCardsInsteadOfOnlyPopupSelection() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.asrSectionShowsVisibleBackendChoiceCardsInsteadOfOnlyPopupSelection.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))

        #expect(labels.contains("Local"))
        #expect(labels.contains("Remote"))
        #expect(labels.contains("On-device"))
        #expect(labels.contains("Cloud"))
        #expect(labels.contains("Uses the built-in Apple Speech recognizer."))
        #expect(labels.contains("Routes transcription through a configurable cloud ASR provider."))
        #expect(labels.contains("Local mode active"))
        #expect(labels.contains("Local mode uses Apple Speech and does not need remote configuration."))
        #expect(labels.contains("Live Status"))
        #expect(labels.contains("Connection Details"))
        #expect(!labels.contains("Remote Provider"))

        #expect(!labels.contains("Remote OpenAI-Compatible ASR"))
        #expect(!labels.contains("Aliyun ASR"))
        #expect(!labels.contains("Volcengine ASR"))
    }

    @Test
    func homeSectionKeepsUtilityCardsInsidePrimaryTwoColumnComposition() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.homeSectionKeepsUtilityCardsInsidePrimaryTwoColumnComposition.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let primaryLayout = findStack(in: contentView) { stack in
            guard stack.orientation == .horizontal else { return false }
            let labels = Set(stackDescendantLabels(in: stack))
            return labels.contains("Shortcuts")
                && labels.contains("Readiness")
                && labels.contains("Language")
                && labels.contains("Appearance")
        }

        #expect(primaryLayout != nil)
    }

    @Test
    func processorsSectionMatchesRedesignedManagementLayout() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.processorsSectionMatchesRedesignedManagementLayout.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        let entry = ExternalProcessorEntry(
            name: "OpenAI Summarizer",
            kind: .almaCLI,
            executablePath: "/usr/local/bin/ai-summarize",
            additionalArguments: [
                ExternalProcessorArgument(value: "--model"),
                ExternalProcessorArgument(value: "gpt-4o-mini")
            ],
            isEnabled: true
        )
        model.setExternalProcessorEntries([entry])
        model.setSelectedExternalProcessorEntryID(entry.id)

        let controller = SettingsWindowController(model: model, delegate: nil)
        let contentView = try #require(controller.window?.contentView)
        controller.show(section: .externalProcessors)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))
        let topRow = try #require(findStack(in: contentView) { stack in
            guard stack.orientation == .horizontal else { return false }
            let labels = Set(stackDescendantLabels(in: stack))
            return labels.contains("External Processors")
                && labels.contains("Processors Help")
                && labels.contains("Selected Processor")
        })
        let leftColumn = try #require(findStack(in: contentView) { stack in
            guard stack.orientation == .vertical else { return false }
            let labels = Set(stackDescendantLabels(in: stack))
            return labels.contains("External Processors")
                && labels.contains("Selected Processor")
                && !labels.contains("Processors Help")
        })

        #expect(labels.contains("External Processors"))
        #expect(labels.contains("Processors Help"))
        #expect(labels.contains("Name"))
        #expect(labels.contains("Command"))
        #expect(labels.contains("Arguments"))
        #expect(labels.contains("Enabled"))
        #expect(labels.contains("Selected Processor"))
        #expect(labels.contains("Reorder"))
        #expect(labels.contains("Toggle"))
        #expect(labels.contains("Output"))
        #expect(labels.contains("Examples"))
        #expect(labels.contains("OpenAI Summarizer"))

        let addProcessorButton = findButton(in: topRow, title: "+ Add Processor")
        #expect(addProcessorButton != nil)
        #expect(findButton(in: leftColumn, title: "Test Run") != nil)
        #expect(findButton(in: topRow, title: "Edit") == nil)
        #expect(findButton(in: leftColumn, title: "Edit") == nil)
        #expect(findButton(in: topRow, title: "Remove") == nil)
        #expect(findButton(in: leftColumn, title: "Remove") == nil)
    }

    @Test
    func processorsSectionUsesBalancedTopRowWidthsAndReadableHeaders() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.processorsSectionUsesBalancedTopRowWidthsAndReadableHeaders.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        let entry = ExternalProcessorEntry(
            name: "OpenAI Summarizer",
            kind: .almaCLI,
            executablePath: "/usr/local/bin/ai-summarize",
            additionalArguments: [
                ExternalProcessorArgument(value: "--model"),
                ExternalProcessorArgument(value: "gpt-4o-mini")
            ],
            isEnabled: true
        )
        model.setExternalProcessorEntries([entry])
        model.setSelectedExternalProcessorEntryID(entry.id)

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.show(section: .externalProcessors)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let topRow = try #require(findStack(in: contentView) { stack in
            guard stack.orientation == .horizontal else { return false }
            let labels = Set(stackDescendantLabels(in: stack))
            return labels.contains("External Processors")
                && labels.contains("Processors Help")
                && labels.contains("Selected Processor")
        })

        #expect(topRow.arrangedSubviews.count == 2)
        let leftWidth = topRow.arrangedSubviews[0].frame.width
        let rightWidth = topRow.arrangedSubviews[1].frame.width
        #expect(rightWidth >= topRow.frame.width * 0.30)
        #expect(rightWidth <= topRow.frame.width * 0.44)
        #expect(leftWidth > rightWidth)

        let argumentsHeader = try #require(findLabels(in: topRow) { $0.stringValue == "Arguments" }.first)
        let enabledHeader = try #require(findLabels(in: topRow) { $0.stringValue == "Enabled" }.first)
        #expect(argumentsHeader.frame.width >= 72)
        #expect(enabledHeader.frame.width >= 72)
    }

    @Test
    func processorsOverviewRowShowsExplicitCommandPathAndImageOnlyEditAction() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.processorsOverviewRowShowsExplicitCommandPathAndImageOnlyEditAction.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        let entry = ExternalProcessorEntry(
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "/usr/local/bin/alma",
            additionalArguments: [ExternalProcessorArgument(value: "--short")],
            isEnabled: true
        )
        model.setExternalProcessorEntries([entry])
        model.setSelectedExternalProcessorEntryID(entry.id)

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.show(section: .externalProcessors)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))
        #expect(labels.contains("/usr/local/bin/alma"))

        let editButton = try #require(findButton(in: contentView) { button in
            button.accessibilityLabel() == "Edit processor Alma CLI"
        })
        #expect(editButton.title.isEmpty)
        #expect(editButton.imagePosition == .imageOnly)
        #expect(editButton.image != nil)
    }

    @Test
    func processorsOverviewRowUsesPathFriendlyCommandLabelStyling() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.processorsOverviewRowUsesPathFriendlyCommandLabelStyling.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        let entry = ExternalProcessorEntry(
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "/usr/local/bin/alma",
            additionalArguments: [ExternalProcessorArgument(value: "--short")],
            isEnabled: true
        )
        model.setExternalProcessorEntries([entry])
        model.setSelectedExternalProcessorEntryID(entry.id)

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.show(section: .externalProcessors)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let commandLabel = try #require(findLabels(in: contentView) { label in
            label.stringValue == "/usr/local/bin/alma"
        }.first)
        let commandFont = try #require(commandLabel.font)

        #expect(commandLabel.lineBreakMode == .byTruncatingMiddle)
        #expect(commandFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }

    @Test
    func externalProcessorManagerSheetShowsExpandedEntryFields() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.externalProcessorManagerSheetShowsExpandedEntryFields.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        let entry = ExternalProcessorEntry(
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "alma",
            additionalArguments: [ExternalProcessorArgument(value: "--short")],
            isEnabled: true
        )
        model.setExternalProcessorEntries([entry])
        model.setSelectedExternalProcessorEntryID(entry.id)

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.openExternalProcessorManagerSheetFromShortcut()

        let sheetContentView = try #require(controller.externalProcessorManagerSheetContentViewForTesting)
        sheetContentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: sheetContentView) { _ in true }.map(\.stringValue))
        #expect(labels.contains("Active Processor"))
        #expect(labels.contains("Name"))
        #expect(labels.contains("Kind"))
        #expect(labels.contains("Executable"))
        #expect(labels.contains("Enabled"))
        #expect(labels.contains("Arguments"))
        #expect(findButton(in: sheetContentView, title: "Test") != nil)
        #expect(findButton(in: sheetContentView, title: "Remove") != nil)

        let entryCard = try #require(findCard(in: sheetContentView) { card in
            let labels = Set(stackDescendantLabels(in: card))
            return labels.contains("Alma CLI")
                && labels.contains("Executable")
                && labels.contains("Arguments")
        })
        #expect(entryCard.frame.height >= 250)
    }

    @Test
    func externalProcessorManagerSheetUsesCompactControlsCard() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.externalProcessorManagerSheetUsesCompactControlsCard.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        let entry = ExternalProcessorEntry(
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "/usr/local/bin/alma",
            isEnabled: true
        )
        model.setExternalProcessorEntries([entry])
        model.setSelectedExternalProcessorEntryID(entry.id)

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.openExternalProcessorManagerSheetFromShortcut()

        let sheetContentView = try #require(controller.externalProcessorManagerSheetContentViewForTesting)
        sheetContentView.layoutSubtreeIfNeeded()

        let controlsCard = try #require(findCard(in: sheetContentView) { card in
            let labels = Set(stackDescendantLabels(in: card))
            return labels.contains("Active Processor")
                && labels.contains("Done")
                && labels.contains("Selected: Alma CLI")
        })
        #expect(controlsCard.frame.height <= 170)
    }

    @Test
    func externalProcessorManagerSheetShowsDedicatedCommandPreviewSection() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.externalProcessorManagerSheetShowsDedicatedCommandPreviewSection.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        let entry = ExternalProcessorEntry(
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "/usr/local/bin/alma",
            additionalArguments: [
                ExternalProcessorArgument(value: "--text"),
                ExternalProcessorArgument(value: "{input}")
            ],
            isEnabled: true
        )
        model.setExternalProcessorEntries([entry])
        model.setSelectedExternalProcessorEntryID(entry.id)

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.openExternalProcessorManagerSheetFromShortcut()

        let sheetContentView = try #require(controller.externalProcessorManagerSheetContentViewForTesting)
        sheetContentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: sheetContentView) { _ in true }.map(\.stringValue))
        #expect(labels.contains("Command Preview"))
        #expect(labels.contains("/usr/local/bin/alma --text {input}"))
    }

    @Test
    func settingsContentDoesNotRepeatBrandHeaderInsideWindowBody() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.settingsContentDoesNotRepeatBrandHeaderInsideWindowBody.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))

        #expect(!labels.contains(SettingsWindowChrome.title))
        #expect(!labels.contains(SettingsWindowChrome.subtitle))
    }

    @Test
    func textSectionUsesPromptPreviewAndRulesComposition() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.textSectionUsesPromptPreviewAndRulesComposition.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let systemPromptCard = findStack(in: contentView) { stack in
            guard stack.orientation == .vertical else { return false }
            let labels = stackDescendantLabels(in: stack)
            return labels.contains("System Prompt")
                && labels.contains("Active Prompt")
        }

        let processingRulesCard = findStack(in: contentView) { stack in
            guard stack.orientation == .vertical else { return false }
            let labels = stackDescendantLabels(in: stack)
            return labels.contains("Processing Rules")
                && labels.contains("Binding Coverage")
                && !labels.contains("Prompt Preview")
        }

        #expect(systemPromptCard != nil)
        #expect(processingRulesCard != nil)
        if let systemPromptCard {
            #expect(findButton(in: systemPromptCard, title: "Edit") != nil)
            #expect(findButton(in: systemPromptCard, title: "New") != nil)
            #expect(findButton(in: systemPromptCard, title: "Bindings") != nil)
            #expect(findButton(in: systemPromptCard, title: "Delete") != nil)
            #expect(findButton(in: systemPromptCard, title: "Preview") == nil)
        }
    }

    @Test
    func permissionsSectionUsesCompactRowsAndUnifiedFooterActions() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.permissionsSectionUsesCompactRowsAndUnifiedFooterActions.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))
        let footerActions = findStack(in: contentView) { stack in
            guard stack.orientation == .horizontal else { return false }
            let labels = stackDescendantLabels(in: stack)
            return labels.contains(PermissionsCopy.permissionsFooterNote)
                && labels.contains("Refresh")
                && labels.contains("Open Settings...")
        }
        let compactPermissionRows = findStack(in: contentView) { stack in
            guard stack.orientation == .vertical else { return false }
            let labels = stackDescendantLabels(in: stack)
            return labels.contains("Microphone")
                && labels.contains("Speech Recognition")
                && labels.contains("Accessibility")
                && labels.contains("Input Monitoring")
                && stack.arrangedSubviews.count == 4
                && stack.arrangedSubviews.allSatisfy { $0 is ThemedSurfaceView }
        }

        #expect(labels.contains("Permissions"))
        #expect(labels.contains(PermissionsCopy.permissionsFooterNote))
        #expect(!labels.contains("Permission Strategy"))
        #expect(compactPermissionRows != nil)
        #expect(footerActions != nil)
    }

    @Test
    func permissionsSectionUsesReducedCardHeightWithoutChangingWidth() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.permissionsSectionUsesReducedCardHeightWithoutChangingWidth.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let compactPermissionRows = try #require(findStack(in: contentView) { stack in
            guard stack.orientation == .vertical else { return false }
            let labels = stackDescendantLabels(in: stack)
            return labels.contains("Microphone")
                && labels.contains("Speech Recognition")
                && labels.contains("Accessibility")
                && labels.contains("Input Monitoring")
                && stack.arrangedSubviews.count == 4
                && stack.arrangedSubviews.allSatisfy { $0 is ThemedSurfaceView }
        })

        let rowHeights = compactPermissionRows.arrangedSubviews.map(\.frame.height)
        #expect(rowHeights.count == 4)
        #expect(rowHeights.allSatisfy { $0 <= 92 })
        #expect(rowHeights.allSatisfy { $0 >= 80 })
        #expect(compactPermissionRows.arrangedSubviews.allSatisfy { abs($0.frame.width - compactPermissionRows.frame.width) < 0.5 })
    }

    @Test
    func permissionsSectionUsesSecondaryOpenSettingsButtonChrome() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.permissionsSectionUsesSecondaryOpenSettingsButtonChrome.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let button = try #require(findButton(in: contentView, title: "Open Settings...") as? StyledSettingsButton)
        let fillCGColor = try #require(button.layer?.backgroundColor)
        let fillColor = try #require(fillCGColor.nsColor)
        let expectedChrome = SettingsWindowTheme.buttonChrome(
            for: button.effectiveAppearance,
            role: .secondary,
            isSelected: false,
            isHovered: false,
            isHighlighted: false
        )

        #expect(fillColor.isApproximatelyEqual(to: expectedChrome.fill))
    }

    @Test
    func permissionsSectionExposesManualRefreshButton() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.permissionsSectionExposesManualRefreshButton.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let refreshButton = try #require(findButton(in: contentView, title: "Refresh") as? StyledSettingsButton)
        let fillCGColor = try #require(refreshButton.layer?.backgroundColor)
        let fillColor = try #require(fillCGColor.nsColor)
        let expectedChrome = SettingsWindowTheme.buttonChrome(
            for: refreshButton.effectiveAppearance,
            role: .secondary,
            isSelected: false,
            isHovered: false,
            isHighlighted: false
        )

        #expect(fillColor.isApproximatelyEqual(to: expectedChrome.fill))
    }

    @Test
    func permissionsSectionRefreshesWhenWindowBecomesKeyAgain() async throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.permissionsSectionRefreshesWhenWindowBecomesKeyAgain.\(UUID().uuidString)"
        )!
        let delegate = SettingsWindowControllerDelegateSpy()
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: delegate)

        controller.show(section: .permissions)
        try? await Task.sleep(nanoseconds: 20_000_000)
        delegate.refreshPermissionRequestCount = 0

        controller.windowDidResignKey(
            Notification(name: NSWindow.didResignKeyNotification, object: controller.window)
        )

        controller.windowDidBecomeKey(
            Notification(name: NSWindow.didBecomeKeyNotification, object: controller.window)
        )
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(delegate.refreshPermissionRequestCount == 1)
    }
}

@MainActor
private func findStack(
    in view: NSView,
    matching predicate: (NSStackView) -> Bool
) -> NSStackView? {
    if let stack = view as? NSStackView, predicate(stack) {
        return stack
    }

    for subview in view.subviews {
        if let match = findStack(in: subview, matching: predicate) {
            return match
        }
    }

    return nil
}

@MainActor
private func findCard(
    in view: NSView,
    matching predicate: (ThemedSurfaceView) -> Bool
) -> ThemedSurfaceView? {
    if let card = view as? ThemedSurfaceView, predicate(card) {
        return card
    }

    for subview in view.subviews {
        if let match = findCard(in: subview, matching: predicate) {
            return match
        }
    }

    return nil
}

@MainActor
private func findView(
    in view: NSView,
    matching predicate: (NSView) -> Bool
) -> NSView? {
    if predicate(view) {
        return view
    }

    for subview in view.subviews {
        if let match = findView(in: subview, matching: predicate) {
            return match
        }
    }

    return nil
}

@MainActor
private func findLabel(in view: NSView, stringValue: String) -> NSTextField? {
    if let label = view as? NSTextField, label.stringValue == stringValue {
        return label
    }

    for subview in view.subviews {
        if let match = findLabel(in: subview, stringValue: stringValue) {
            return match
        }
    }

    return nil
}

@MainActor
private func stackDescendantLabels(in view: NSView) -> [String] {
    var labels: [String] = []

    if let label = view as? NSTextField, !label.stringValue.isEmpty {
        labels.append(label.stringValue)
    }

    for subview in view.subviews {
        labels.append(contentsOf: stackDescendantLabels(in: subview))
    }

    return labels
}

@MainActor
private func findButton(
    in view: NSView,
    title: String
) -> NSButton? {
    if let button = view as? NSButton, button.title == title {
        return button
    }

    for subview in view.subviews {
        if let match = findButton(in: subview, title: title) {
            return match
        }
    }

    return nil
}

@MainActor
private func findButton(
    in view: NSView,
    matching predicate: (NSButton) -> Bool
) -> NSButton? {
    if let button = view as? NSButton, predicate(button) {
        return button
    }

    for subview in view.subviews {
        if let match = findButton(in: subview, matching: predicate) {
            return match
        }
    }

    return nil
}

@MainActor
private func findImageViews(in view: NSView) -> [NSImageView] {
    var matches: [NSImageView] = []

    if let imageView = view as? NSImageView {
        matches.append(imageView)
    }

    for subview in view.subviews {
        matches.append(contentsOf: findImageViews(in: subview))
    }

    return matches
}

@MainActor
private func findLabels(
    in view: NSView,
    matching predicate: (NSTextField) -> Bool
) -> [NSTextField] {
    var matches: [NSTextField] = []

    if let label = view as? NSTextField, predicate(label) {
        matches.append(label)
    }

    for subview in view.subviews {
        matches.append(contentsOf: findLabels(in: subview, matching: predicate))
    }

    return matches
}

@MainActor
private func containsScrollView(in view: NSView) -> Bool {
    if view is NSScrollView {
        return true
    }

    for subview in view.subviews {
        if containsScrollView(in: subview) {
            return true
        }
    }

    return false
}

@MainActor
private func controlFontPointSize(for control: NSControl) -> CGFloat {
    if let font = control.font {
        return font.pointSize
    }

    if let cellFont = control.cell?.font {
        return cellFont.pointSize
    }

    if let button = control as? NSButton,
       button.attributedTitle.length > 0,
       let titleFont = button.attributedTitle.attribute(.font, at: 0, effectiveRange: nil) as? NSFont {
        return titleFont.pointSize
    }

    return 0
}

@MainActor
private final class SettingsWindowControllerDelegateSpy: SettingsWindowControllerDelegate {
    var refreshPermissionRequestCount = 0

    func settingsWindowControllerDidRequestStartRecording(_ controller: SettingsWindowController) {}

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSave configuration: LLMConfiguration
    ) {}

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestTest configuration: LLMConfiguration
    ) async -> Result<String, Error> {
        .success("")
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration
    ) {}

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestRemoteASRTest configuration: RemoteASRConfiguration
    ) async -> Result<String, Error> {
        .success("")
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSelectASRBackend backend: ASRBackend
    ) {}

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSelect language: SupportedLanguage
    ) {}

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateActivationShortcut shortcut: ActivationShortcut
    ) {}

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateCancelShortcut shortcut: ActivationShortcut
    ) {}

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateModeCycleShortcut shortcut: ActivationShortcut
    ) {}

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdatePromptCycleShortcut shortcut: ActivationShortcut
    ) {}

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateProcessorShortcut shortcut: ActivationShortcut
    ) {}

    func settingsWindowControllerDidRequestOpenMicrophoneSettings(_ controller: SettingsWindowController) {}

    func settingsWindowControllerDidRequestOpenSpeechSettings(_ controller: SettingsWindowController) {}

    func settingsWindowControllerDidRequestOpenAccessibilitySettings(_ controller: SettingsWindowController) {}

    func settingsWindowControllerDidRequestOpenInputMonitoringSettings(_ controller: SettingsWindowController) {}

    func settingsWindowControllerDidRequestPromptAccessibilityPermission(_ controller: SettingsWindowController) {}

    func settingsWindowControllerDidRequestRefreshPermissions(_ controller: SettingsWindowController) async {
        refreshPermissionRequestCount += 1
    }

    func settingsWindowControllerDidRequestCheckForUpdates(_ controller: SettingsWindowController) async -> String {
        ""
    }

    func settingsWindowControllerDidSelectInterfaceTheme(
        _ controller: SettingsWindowController,
        theme: InterfaceTheme
    ) {}
}

private extension CGColor {
    var nsColor: NSColor? {
        NSColor(cgColor: self)
    }
}

private extension NSColor {
    func isApproximatelyEqual(to other: NSColor, tolerance: CGFloat = 0.002) -> Bool {
        guard
            let lhs = usingColorSpace(.deviceRGB),
            let rhs = other.usingColorSpace(.deviceRGB)
        else {
            return false
        }

        return abs(lhs.redComponent - rhs.redComponent) <= tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) <= tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) <= tolerance
            && abs(lhs.alphaComponent - rhs.alphaComponent) <= tolerance
    }
}
