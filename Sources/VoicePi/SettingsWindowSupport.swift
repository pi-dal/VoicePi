import AppKit

enum SettingsWindowChrome {
    static let title = "VoicePi Settings"
    static let subtitle = "Quick controls for permissions, dictation, dictionary, and processor settings."
    static let defaultSize = NSSize(width: 820, height: 560)
    static let minimumSize = NSSize(width: 720, height: 520)
}

struct ExternalProcessorsSectionPresentation: Equatable {
    let summaryText: String
    let detailText: String
}

enum SettingsWindowSupport {
    static func processorShortcutHintText(for shortcut: ActivationShortcut) -> String {
        if shortcut.isEmpty {
            return "Set a processor shortcut to start a dedicated voice capture that always runs through the selected processor."
        }

        if shortcut.isRegisteredHotkeyCompatible {
            return "Current shortcut: \(shortcut.displayString). It starts a dedicated processor capture, and standard shortcuts work without Input Monitoring."
        }

        return "Current shortcut: \(shortcut.displayString). It starts a dedicated processor capture. Advanced shortcuts require Input Monitoring, and Accessibility lets VoicePi suppress the shortcut before it reaches the frontmost app."
    }

    static func historySummaryText(forEntryCount count: Int) -> String {
        guard count > 0 else {
            return "No history yet. Final transcript outputs will appear here after successful delivery."
        }

        let noun = count == 1 ? "entry" : "entries"
        return "Saved outputs: \(count) \(noun)"
    }

    static func externalProcessorsSectionPresentation(
        entries: [ExternalProcessorEntry],
        selectedEntry: ExternalProcessorEntry?
    ) -> ExternalProcessorsSectionPresentation {
        if entries.isEmpty {
            return ExternalProcessorsSectionPresentation(
                summaryText: "No processors configured yet.",
                detailText: "Open the Processors tab to add your first backend, set its executable, and add any command-line arguments."
            )
        }

        if let selectedEntry {
            let stateText = selectedEntry.isEnabled ? "Enabled" : "Disabled"
            return ExternalProcessorsSectionPresentation(
                summaryText: "Active processor: \(selectedEntry.name) • \(selectedEntry.kind.title) • \(stateText)",
                detailText: "Manage the processors used by refinement. Each entry can be tested before VoicePi uses it."
            )
        }

        return ExternalProcessorsSectionPresentation(
            summaryText: "Choose a processor to make it active.",
            detailText: "Manage the processors used by refinement. Each entry can be tested before VoicePi uses it."
        )
    }
}
