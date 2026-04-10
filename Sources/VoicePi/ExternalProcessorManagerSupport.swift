import Foundation

struct ExternalProcessorManagerState: Equatable {
    var entries: [ExternalProcessorEntry]
    var selectedEntryID: UUID?

    init(
        entries: [ExternalProcessorEntry] = [],
        selectedEntryID: UUID? = nil
    ) {
        self.entries = entries
        self.selectedEntryID = selectedEntryID
    }
}

enum ExternalProcessorManagerActions {
    static func addEntry(to state: ExternalProcessorManagerState) -> ExternalProcessorManagerState {
        let newEntry = ExternalProcessorEntry(
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "alma",
            additionalArguments: [],
            isEnabled: true
        )

        var next = state
        next.entries.append(newEntry)
        next.selectedEntryID = newEntry.id
        return next
    }

    static func addArgument(
        to entryID: UUID,
        state: ExternalProcessorManagerState
    ) -> ExternalProcessorManagerState {
        var next = state
        guard let index = next.entries.firstIndex(where: { $0.id == entryID }) else {
            return next
        }

        next.entries[index].additionalArguments.append(
            ExternalProcessorArgument(value: "")
        )
        return next
    }

    static func removeEntry(
        _ entryID: UUID,
        from state: ExternalProcessorManagerState
    ) -> ExternalProcessorManagerState {
        var nextEntries = state.entries
        guard let index = nextEntries.firstIndex(where: { $0.id == entryID }) else {
            return state
        }

        nextEntries.remove(at: index)

        let nextSelectedID: UUID?
        if state.selectedEntryID == entryID {
            if let successor = nextEntries[safe: index] {
                nextSelectedID = successor.id
            } else {
                nextSelectedID = nextEntries.last?.id
            }
        } else {
            nextSelectedID = state.selectedEntryID
        }

        return ExternalProcessorManagerState(
            entries: nextEntries,
            selectedEntryID: nextSelectedID
        )
    }
}

enum ExternalProcessorTestFeedback {
    static func message(
        forOutput output: String,
        processorDisplayName: String
    ) -> String {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else {
            return "\(processorDisplayName) test failed: empty response."
        }

        return "\(processorDisplayName) test passed: \(trimmedOutput)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
