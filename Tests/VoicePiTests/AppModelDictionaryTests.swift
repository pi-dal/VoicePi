import AppKit
import Foundation
import Testing
@testable import VoicePi

struct AppModelDictionaryTests {
    @Test
    @MainActor
    func loadsDictionaryEntriesAndSuggestionsFromInjectedStore() throws {
        let fixture = try DictionaryModelStoreFixture()
        defer { fixture.cleanup() }

        let entry = DictionaryEntry(
            canonical: "PostgreSQL",
            aliases: ["postgre"],
            isEnabled: true
        )
        let suggestion = DictionarySuggestion(
            originalFragment: "cloud flare",
            correctedFragment: "Cloudflare",
            proposedCanonical: "Cloudflare",
            proposedAliases: ["cloud flare"],
            sourceApplication: "com.example.editor"
        )
        try fixture.store.saveDictionary(.init(entries: [entry]))
        try fixture.store.saveSuggestions(.init(suggestions: [suggestion]))

        let model = AppModel(
            defaults: fixture.defaults,
            dictionaryStore: fixture.store
        )

        #expect(model.dictionaryEntries == [entry])
        #expect(model.dictionarySuggestions == [suggestion])
    }

    @Test
    @MainActor
    func approvingSuggestionUpdatesFormalDictionaryAndRemovesSuggestion() throws {
        let fixture = try DictionaryModelStoreFixture()
        defer { fixture.cleanup() }

        let suggestion = DictionarySuggestion(
            id: UUID(uuidString: "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb")!,
            originalFragment: "postgre",
            correctedFragment: "PostgreSQL",
            proposedCanonical: "PostgreSQL",
            proposedAliases: ["postgre"]
        )

        try fixture.store.saveDictionary(.init(entries: []))
        try fixture.store.saveSuggestions(.init(suggestions: [suggestion]))

        let model = AppModel(
            defaults: fixture.defaults,
            dictionaryStore: fixture.store
        )

        model.approveDictionarySuggestion(id: suggestion.id)

        #expect(model.dictionarySuggestions.isEmpty)
        #expect(model.dictionaryEntries.count == 1)
        #expect(model.dictionaryEntries[0].canonical == "PostgreSQL")
        #expect(model.dictionaryEntries[0].aliases == ["postgre"])
    }

    @Test
    @MainActor
    func dismissingSuggestionRemovesQueueOnly() throws {
        let fixture = try DictionaryModelStoreFixture()
        defer { fixture.cleanup() }

        let entry = DictionaryEntry(
            canonical: "PostgreSQL",
            aliases: ["postgre"],
            isEnabled: true
        )
        let suggestion = DictionarySuggestion(
            id: UUID(uuidString: "cccccccc-1111-2222-3333-dddddddddddd")!,
            originalFragment: "cloud flare",
            correctedFragment: "Cloudflare",
            proposedCanonical: "Cloudflare",
            proposedAliases: ["cloud flare"]
        )

        try fixture.store.saveDictionary(.init(entries: [entry]))
        try fixture.store.saveSuggestions(.init(suggestions: [suggestion]))

        let model = AppModel(
            defaults: fixture.defaults,
            dictionaryStore: fixture.store
        )

        model.dismissDictionarySuggestion(id: suggestion.id)

        #expect(model.dictionarySuggestions.isEmpty)
        #expect(model.dictionaryEntries == [entry])
    }

    @Test
    @MainActor
    func exposesDictionaryCountsForSettingsAndToastState() throws {
        let fixture = try DictionaryModelStoreFixture()
        defer { fixture.cleanup() }

        try fixture.store.saveDictionary(
            .init(
                entries: [
                    DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre"], isEnabled: true),
                    DictionaryEntry(canonical: "Cloudflare", aliases: ["cloud flare"], isEnabled: false)
                ]
            )
        )
        try fixture.store.saveSuggestions(
            .init(
                suggestions: [
                    DictionarySuggestion(
                        originalFragment: "kuber",
                        correctedFragment: "Kubernetes",
                        proposedCanonical: "Kubernetes",
                        proposedAliases: ["kuber"]
                    )
                ]
            )
        )

        let model = AppModel(
            defaults: fixture.defaults,
            dictionaryStore: fixture.store
        )

        #expect(model.dictionaryTermCount == 2)
        #expect(model.pendingDictionarySuggestionCount == 1)
        #expect(model.enabledDictionaryEntries.map(\.canonical) == ["PostgreSQL"])
    }

    @Test
    @MainActor
    func importingTermsSupportsAliasSyntaxAndMergesExistingCanonical() throws {
        let fixture = try DictionaryModelStoreFixture()
        defer { fixture.cleanup() }

        try fixture.store.saveDictionary(
            .init(entries: [DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre"])])
        )
        try fixture.store.saveSuggestions(.init(suggestions: []))

        let model = AppModel(
            defaults: fixture.defaults,
            dictionaryStore: fixture.store
        )

        model.importDictionaryTerms(fromPlainText: """
        Cloudflare | cloud flare, cloudflair
        PostgreSQL | pgsql
        Python | python
        Kubernetes
        """)

        #expect(model.dictionaryEntries.count == 4)

        let cloudflare = model.dictionaryEntries.first { $0.canonical == "Cloudflare" }
        #expect(cloudflare != nil)
        #expect(cloudflare?.aliases == ["cloud flare", "cloudflair"])

        let postgresql = model.dictionaryEntries.first { $0.canonical == "PostgreSQL" }
        #expect(postgresql != nil)
        #expect(Set(postgresql?.aliases ?? []) == Set(["postgre", "pgsql"]))

        let kubernetes = model.dictionaryEntries.first { $0.canonical == "Kubernetes" }
        #expect(kubernetes != nil)
        #expect(kubernetes?.aliases.isEmpty == true)

        let python = model.dictionaryEntries.first { $0.canonical == "Python" }
        #expect(python != nil)
        #expect(python?.aliases == ["python"])
    }

    @Test
    @MainActor
    func editingTermKeepsAliasWhenOnlyCaseDiffersFromCanonical() throws {
        let fixture = try DictionaryModelStoreFixture()
        defer { fixture.cleanup() }

        try fixture.store.saveDictionary(
            .init(entries: [DictionaryEntry(canonical: "Python", aliases: [])])
        )
        try fixture.store.saveSuggestions(.init(suggestions: []))

        let model = AppModel(
            defaults: fixture.defaults,
            dictionaryStore: fixture.store
        )

        guard let entry = model.dictionaryEntries.first else {
            Issue.record("Expected dictionary entry to exist")
            return
        }

        model.editDictionaryTerm(
            id: entry.id,
            canonical: "Python",
            aliases: ["python"],
            tag: nil
        )

        let updated = model.dictionaryEntries.first { $0.id == entry.id }
        #expect(updated != nil)
        #expect(updated?.aliases == ["python"])
    }

    @Test
    @MainActor
    func addDictionaryTermPersistsTag() throws {
        let fixture = try DictionaryModelStoreFixture()
        defer { fixture.cleanup() }

        try fixture.store.saveDictionary(.init(entries: []))
        try fixture.store.saveSuggestions(.init(suggestions: []))

        let model = AppModel(
            defaults: fixture.defaults,
            dictionaryStore: fixture.store
        )

        model.addDictionaryTerm(
            canonical: "TensorFlow",
            aliases: ["tensor flow"],
            tag: "ML"
        )

        #expect(model.dictionaryEntries.count == 1)
        #expect(model.dictionaryEntries[0].tag == "ML")
    }

    @Test
    @MainActor
    func editingTermUpdatesTag() throws {
        let fixture = try DictionaryModelStoreFixture()
        defer { fixture.cleanup() }

        let entry = DictionaryEntry(
            canonical: "Python",
            aliases: ["py"],
            tag: "Languages"
        )
        try fixture.store.saveDictionary(.init(entries: [entry]))
        try fixture.store.saveSuggestions(.init(suggestions: []))

        let model = AppModel(
            defaults: fixture.defaults,
            dictionaryStore: fixture.store
        )

        model.editDictionaryTerm(
            id: entry.id,
            canonical: "Python",
            aliases: ["py", "python"],
            tag: "Runtime"
        )

        let updated = try #require(model.dictionaryEntries.first { $0.id == entry.id })
        #expect(updated.aliases == ["py", "python"])
        #expect(updated.tag == "Runtime")
    }
}

private struct DictionaryModelStoreFixture {
    let suiteName: String
    let defaults: UserDefaults
    let rootURL: URL
    let store: DictionaryStore

    init() throws {
        suiteName = "VoicePiTests.AppModelDictionary.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoicePiTests.AppModelDictionary.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        store = DictionaryStore(
            dictionaryFileURL: rootURL.appendingPathComponent("Dictionary.json", isDirectory: false),
            suggestionsFileURL: rootURL.appendingPathComponent("DictionarySuggestions.json", isDirectory: false)
        )
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: rootURL)
    }
}
