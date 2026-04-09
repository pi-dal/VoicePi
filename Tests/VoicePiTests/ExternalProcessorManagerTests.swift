import Foundation
import Testing
@testable import VoicePi

struct ExternalProcessorManagerTests {
    @Test
    func addingEntryAppendsEnabledAlmaCLIProfileAndSelectsIt() {
        let state = ExternalProcessorManagerState()

        let updated = ExternalProcessorManagerActions.addEntry(to: state)

        #expect(updated.entries.count == 1)
        #expect(updated.entries[0].kind == .almaCLI)
        #expect(updated.entries[0].name == "Alma CLI")
        #expect(updated.entries[0].executablePath == "alma")
        #expect(updated.entries[0].isEnabled)
        #expect(updated.selectedEntryID == updated.entries[0].id)
    }

    @Test
    func addingArgumentAppendsEmptyRowToMatchingEntry() {
        let entry = ExternalProcessorEntry(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "alma"
        )
        let state = ExternalProcessorManagerState(entries: [entry], selectedEntryID: entry.id)

        let updated = ExternalProcessorManagerActions.addArgument(to: entry.id, state: state)

        #expect(updated.entries.count == 1)
        #expect(updated.entries[0].additionalArguments.count == 1)
        #expect(updated.entries[0].additionalArguments[0].value.isEmpty)
    }

    @Test
    func removingSelectedEntryFallsBackToNextRemainingEntry() {
        let first = ExternalProcessorEntry(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            name: "First",
            kind: .almaCLI,
            executablePath: "alma"
        )
        let second = ExternalProcessorEntry(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            name: "Second",
            kind: .almaCLI,
            executablePath: "alma"
        )
        let state = ExternalProcessorManagerState(entries: [first, second], selectedEntryID: first.id)

        let updated = ExternalProcessorManagerActions.removeEntry(first.id, from: state)

        #expect(updated.entries == [second])
        #expect(updated.selectedEntryID == second.id)
    }

    @Test
    func removingOnlyEntryClearsSelection() {
        let entry = ExternalProcessorEntry(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            name: "Only",
            kind: .almaCLI,
            executablePath: "alma"
        )
        let state = ExternalProcessorManagerState(entries: [entry], selectedEntryID: entry.id)

        let updated = ExternalProcessorManagerActions.removeEntry(entry.id, from: state)

        #expect(updated.entries.isEmpty)
        #expect(updated.selectedEntryID == nil)
    }

    @Test
    func emptyStdoutMarksExternalProcessorTestAsFailed() {
        let message = ExternalProcessorTestFeedback.message(
            forOutput: "   \n",
            processorDisplayName: "Alma CLI"
        )

        #expect(message == "Alma CLI test failed: empty response.")
    }

    @Test
    func nonEmptyStdoutMarksExternalProcessorTestAsPassedWithProcessorName() {
        let message = ExternalProcessorTestFeedback.message(
            forOutput: " refined transcript ",
            processorDisplayName: "Alma CLI"
        )

        #expect(message == "Alma CLI test passed: refined transcript")
    }
}
