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
    func homeShortcutControlsUseCompactTwoColumnGrid() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.homeShortcutControlsUseCompactTwoColumnGrid.\(UUID().uuidString)"
        )!
        let controller = SettingsWindowController(model: AppModel(defaults: defaults), delegate: nil)
        let contentView = try #require(controller.window?.contentView)

        contentView.layoutSubtreeIfNeeded()

        let firstShortcutRow = try #require(
            findStack(in: contentView) { stack in
                stack.orientation == .horizontal
                    && stack.distribution == .fillEqually
                    && stackDescendantLabels(in: stack).contains("Activation Shortcut")
                    && stackDescendantLabels(in: stack).contains("Cancel Shortcut")
            }
        )
        let secondShortcutRow = try #require(
            findStack(in: contentView) { stack in
                stack.orientation == .horizontal
                    && stack.distribution == .fillEqually
                    && stackDescendantLabels(in: stack).contains("Mode Switch Shortcut")
                    && stackDescendantLabels(in: stack).contains("Prompt Cycle Shortcut")
            }
        )

        #expect(firstShortcutRow.arrangedSubviews.count == 2)
        #expect(secondShortcutRow.arrangedSubviews.count == 2)
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
