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
            executablePath: "alma",
            isEnabled: false
        )

        let emptyPresentation = SettingsWindowSupport.externalProcessorsSectionPresentation(
            entries: [],
            selectedEntry: nil
        )
        let selectedPresentation = SettingsWindowSupport.externalProcessorsSectionPresentation(
            entries: [entry],
            selectedEntry: entry
        )

        #expect(emptyPresentation.summaryText == "No processors configured yet.")
        #expect(
            emptyPresentation.detailText
                == "Open the Processors tab to add your first backend, set its executable, and add any command-line arguments."
        )
        #expect(
            selectedPresentation.summaryText
                == "Active processor: Alma CLI • Alma CLI • Disabled"
        )
        #expect(
            selectedPresentation.detailText
                == "Manage the processors used by refinement. Each entry can be tested before VoicePi uses it."
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
        #expect(labels.contains("Provider Connection"))
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
    func processorsSectionShowsInlineListHeadersAndPrimaryAddAction() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.processorsSectionShowsInlineListHeadersAndPrimaryAddAction.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let labels = Set(findLabels(in: contentView) { _ in true }.map(\.stringValue))

        #expect(labels.contains("Name"))
        #expect(labels.contains("Command"))
        #expect(labels.contains("Arguments"))
        #expect(labels.contains("Enabled"))
        #expect(labels.contains("Selected Processor"))

        let addProcessorButton = findButton(in: contentView, title: "Add Processor")
        #expect(addProcessorButton != nil)
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
                && labels.contains("Edit")
                && labels.contains("New")
                && labels.contains("Bindings")
                && labels.contains("Delete")
                && labels.contains("Preview")
        }

        let processingRulesCard = findStack(in: contentView) { stack in
            guard stack.orientation == .vertical else { return false }
            let labels = stackDescendantLabels(in: stack)
            return labels.contains("Processing Rules")
                && labels.contains(SettingsWindowController.strictModeToggleLabel)
                && labels.contains("Binding Coverage")
                && labels.contains("Prompt Preview")
        }

        #expect(systemPromptCard != nil)
        #expect(processingRulesCard != nil)
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
