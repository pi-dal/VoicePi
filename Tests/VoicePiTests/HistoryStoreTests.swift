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
    func appModelHistoryTracksDurationAndTextUsageStats() throws {
        let fileManager = FileManager()
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("VoicePiTests.History.Stats.\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let historyURL = root.appendingPathComponent("History.json", isDirectory: false)
        let defaults = UserDefaults(suiteName: "VoicePiTests.historyStats.\(UUID().uuidString)")!
        let store = HistoryStore(historyFileURL: historyURL, fileManager: fileManager)
        let model = AppModel(defaults: defaults, historyStore: store)

        model.recordHistoryEntry(
            text: "你好 hello world",
            recordingDurationMilliseconds: 12_345
        )

        let entry = try #require(model.historyEntries.first)
        #expect(entry.characterCount == 2)
        #expect(entry.wordCount == 2)
        #expect(entry.recordingDurationMilliseconds == 12_345)
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
    func historyStoreDeletesLegacyHistoryAndResetsToCurrentSchema() throws {
        struct LegacyHistoryEntry: Codable {
            let id: UUID
            let text: String
            let createdAt: Date
        }

        struct LegacyHistoryDocument: Codable {
            let entries: [LegacyHistoryEntry]
        }

        let fileManager = FileManager()
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("VoicePiTests.History.Legacy.\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let historyURL = root.appendingPathComponent("History.json", isDirectory: false)
        let store = HistoryStore(historyFileURL: historyURL, fileManager: fileManager)
        let legacyDocument = LegacyHistoryDocument(entries: [
            LegacyHistoryEntry(
                id: UUID(),
                text: "测试 hello world",
                createdAt: Date()
            )
        ])

        let legacyData = try JSONEncoder().encode(legacyDocument)
        try legacyData.write(to: historyURL, options: .atomic)

        let document = try store.loadHistory()
        #expect(document.entries.isEmpty)

        let persistedData = try Data(contentsOf: historyURL)
        let persistedDocument = try JSONDecoder().decode(HistoryDocument.self, from: persistedData)
        #expect(persistedDocument.entries.isEmpty)
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
