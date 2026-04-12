import Foundation
import Testing
@testable import VoicePi

struct HistoryStoreTests {
    @Test
    @MainActor
    func appModelHistoryPersistsAcrossReloadsAndKeepsNewestFirst() throws {
        let fileManager = FileManager()
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("VoicePiTests.History.\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let historyURL = root.appendingPathComponent("History.json", isDirectory: false)
        let defaults = UserDefaults(suiteName: "VoicePiTests.historyPersists.\(UUID().uuidString)")!
        let store = HistoryStore(historyFileURL: historyURL, fileManager: fileManager)
        let model = AppModel(defaults: defaults, historyStore: store)

        model.recordHistoryEntry(text: "First transcript")
        model.recordHistoryEntry(text: "Second transcript")

        let reloaded = AppModel(defaults: defaults, historyStore: store)

        #expect(reloaded.historyEntries.count == 2)
        #expect(reloaded.historyEntries[0].text == "Second transcript")
        #expect(reloaded.historyEntries[1].text == "First transcript")
    }

    @Test
    @MainActor
    func appModelCanDeleteHistoryEntryAndPersistRemoval() throws {
        let fileManager = FileManager()
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("VoicePiTests.History.Delete.\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let historyURL = root.appendingPathComponent("History.json", isDirectory: false)
        let defaults = UserDefaults(suiteName: "VoicePiTests.historyDelete.\(UUID().uuidString)")!
        let store = HistoryStore(historyFileURL: historyURL, fileManager: fileManager)
        let model = AppModel(defaults: defaults, historyStore: store)

        model.recordHistoryEntry(text: "First transcript")
        model.recordHistoryEntry(text: "Second transcript")
        let deletedID = try #require(model.historyEntries.first?.id)

        model.deleteHistoryEntry(id: deletedID)

        #expect(model.historyEntries.count == 1)
        #expect(model.historyEntries.contains(where: { $0.id == deletedID }) == false)

        let reloaded = AppModel(defaults: defaults, historyStore: store)
        #expect(reloaded.historyEntries.count == 1)
        #expect(reloaded.historyEntries.contains(where: { $0.id == deletedID }) == false)
    }

    @Test
    func historyStoreTrimsWhitespaceSkipsEmptyEntriesAndCapsSavedHistory() throws {
        let fileManager = FileManager()
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("VoicePiTests.History.Cap.\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let historyURL = root.appendingPathComponent("History.json", isDirectory: false)
        let store = HistoryStore(historyFileURL: historyURL, fileManager: fileManager)

        try store.appendEntry(text: "  kept  ")
        try store.appendEntry(text: "   ")

        for index in 0..<HistoryStore.maximumEntryCount + 4 {
            try store.appendEntry(text: "Item \(index)")
        }

        let document = try store.loadHistory()

        #expect(document.entries.count == HistoryStore.maximumEntryCount)
        #expect(document.entries.first?.text == "Item \(HistoryStore.maximumEntryCount + 3)")
        #expect(document.entries.contains(where: { $0.text == "kept" }) == false)
        #expect(document.entries.contains(where: { $0.text.isEmpty }) == false)
    }
}
