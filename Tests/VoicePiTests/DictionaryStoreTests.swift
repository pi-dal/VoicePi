import Foundation
import Testing
@testable import VoicePi

struct DictionaryStoreTests {
    @Test
    func loadDictionaryCreatesEmptyDocumentWhenNoFileExists() throws {
        let fixture = try DictionaryStoreFixture()
        defer { fixture.cleanup() }

        let document = try fixture.makeStore().loadDictionary()

        #expect(document.version == DictionarySchemaVersion.current)
        #expect(document.entries.isEmpty)
        #expect(FileManager.default.fileExists(atPath: fixture.dictionaryURL.path))
    }

    @Test
    func saveAndLoadDictionaryPreservesEntryFields() throws {
        let fixture = try DictionaryStoreFixture()
        defer { fixture.cleanup() }

        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_999)
        let entry = DictionaryEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            canonical: "PostgreSQL",
            aliases: ["postgre", "postgres"],
            isEnabled: false,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let store = fixture.makeStore()
        try store.saveDictionary(.init(entries: [entry]))

        let loaded = try store.loadDictionary()
        #expect(loaded.entries == [entry])
    }

    @Test
    func storeUsesCallerSuppliedFileURLs() throws {
        let fixture = try DictionaryStoreFixture()
        defer { fixture.cleanup() }

        let store = fixture.makeStore()

        #expect(store.configuredDictionaryFileURL == fixture.dictionaryURL)
        #expect(store.configuredSuggestionsFileURL == fixture.suggestionsURL)
    }

    @Test
    func loadSuggestionsCreatesEmptyDocumentWhenNoFileExists() throws {
        let fixture = try DictionaryStoreFixture()
        defer { fixture.cleanup() }

        let document = try fixture.makeStore().loadSuggestions()

        #expect(document.version == DictionarySchemaVersion.current)
        #expect(document.suggestions.isEmpty)
        #expect(FileManager.default.fileExists(atPath: fixture.suggestionsURL.path))
    }

    @Test
    func dictionaryAndSuggestionsPersistIndependently() throws {
        let fixture = try DictionaryStoreFixture()
        defer { fixture.cleanup() }

        let store = fixture.makeStore()
        let dictionary = DictionaryDocument(
            entries: [
                DictionaryEntry(
                    canonical: "Cloudflare",
                    aliases: ["cloud flare"],
                    isEnabled: true
                )
            ]
        )
        let suggestions = DictionarySuggestionDocument(
            suggestions: [
                DictionarySuggestion(
                    originalFragment: "postgre",
                    correctedFragment: "PostgreSQL",
                    proposedCanonical: "PostgreSQL",
                    proposedAliases: ["postgre"],
                    sourceApplication: "com.example.app",
                    capturedAt: Date(timeIntervalSince1970: 1_700_001_111)
                )
            ]
        )

        try store.saveDictionary(dictionary)
        try store.saveSuggestions(suggestions)

        #expect(try store.loadDictionary() == dictionary)
        #expect(try store.loadSuggestions() == suggestions)
    }

    @Test
    func removeSuggestionDeletesPendingSuggestion() throws {
        let fixture = try DictionaryStoreFixture()
        defer { fixture.cleanup() }

        let first = DictionarySuggestion(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            originalFragment: "postgre",
            correctedFragment: "PostgreSQL",
            proposedCanonical: "PostgreSQL",
            proposedAliases: ["postgre"]
        )
        let second = DictionarySuggestion(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            originalFragment: "cloud flare",
            correctedFragment: "Cloudflare",
            proposedCanonical: "Cloudflare",
            proposedAliases: ["cloud flare"]
        )

        let store = fixture.makeStore()
        try store.saveSuggestions(.init(suggestions: [first, second]))

        let updated = try store.removeSuggestion(id: first.id)

        #expect(updated.suggestions == [second])
        #expect(try store.loadSuggestions().suggestions == [second])
    }

    @Test
    func approveSuggestionMergesIntoExistingEntryByAliasWithoutDuplicates() throws {
        let fixture = try DictionaryStoreFixture()
        defer { fixture.cleanup() }

        let existing = DictionaryEntry(
            canonical: "PostgreSQL",
            aliases: ["postgre"],
            isEnabled: true
        )
        let suggestion = DictionarySuggestion(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            originalFragment: "postgre",
            correctedFragment: "PostgreSQL",
            proposedCanonical: "PostgreSQL",
            proposedAliases: ["Postgres", "postgre"]
        )

        let store = fixture.makeStore()
        try store.saveDictionary(.init(entries: [existing]))
        try store.saveSuggestions(.init(suggestions: [suggestion]))

        let result = try store.approveSuggestion(id: suggestion.id)

        #expect(result.suggestions.suggestions.isEmpty)
        #expect(result.dictionary.entries.count == 1)
        #expect(result.dictionary.entries[0].canonical == "PostgreSQL")
        #expect(result.dictionary.entries[0].aliases == ["postgre", "Postgres"])
        #expect(try store.loadSuggestions().suggestions.isEmpty)
    }
}

private struct DictionaryStoreFixture {
    let rootURL: URL
    let dictionaryURL: URL
    let suggestionsURL: URL

    init() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoicePiTests.DictionaryStore.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        rootURL = root
        dictionaryURL = root.appendingPathComponent("Dictionary.json", isDirectory: false)
        suggestionsURL = root.appendingPathComponent("DictionarySuggestions.json", isDirectory: false)
    }

    func makeStore() -> DictionaryStore {
        DictionaryStore(
            dictionaryFileURL: dictionaryURL,
            suggestionsFileURL: suggestionsURL
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
