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
        #expect(SettingsWindowChrome.minimumSize.width == 720)
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
                == "Set a processor shortcut to start a dedicated voice capture that always runs through the selected processor."
        )
        #expect(
            SettingsWindowSupport.processorShortcutHintText(for: standardShortcut)
                == "Current shortcut: ⌘ + P. It starts a dedicated processor capture, and standard shortcuts work without Input Monitoring."
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
                == "Current shortcut: ⌘ + P + O. It starts a dedicated processor capture. Advanced shortcuts require Input Monitoring, and Accessibility lets VoicePi suppress the shortcut before it reaches the frontmost app."
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
                == "Set a prompt-cycle shortcut to quickly rotate the global Active Prompt before recording."
        )
        #expect(
            SettingsWindowSupport.promptCycleShortcutHintText(for: standardShortcut)
                == "Current shortcut: ⌘ + P. It cycles the global Active Prompt by one preset per press, and standard shortcuts work without Input Monitoring."
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
                == "Current shortcut: ⌘ + P + O. It cycles the global Active Prompt by one preset per press. Advanced shortcuts require Input Monitoring, and Accessibility lets VoicePi suppress the shortcut before it reaches the frontmost app."
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
}
