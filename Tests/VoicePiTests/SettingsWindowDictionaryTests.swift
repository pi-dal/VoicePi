import AppKit
import Foundation
import Testing
@testable import VoicePi

@MainActor
struct SettingsWindowDictionaryTests {
    @Test
    func settingsNavigationIncludesLibrarySection() {
        #expect(SettingsSection.allCases.contains(.dictionary))
        #expect(SettingsSection.dictionary.title == "Library")
    }

    @Test
    func settingsNavigationPlacesDictionaryAfterPermissions() {
        let sections = SettingsSection.allCases
        let permissionsIndex = sections.firstIndex(of: .permissions)
        let dictionaryIndex = sections.firstIndex(of: .dictionary)

        #expect(permissionsIndex != nil)
        #expect(dictionaryIndex != nil)
        #expect(dictionaryIndex == permissionsIndex.map { $0 + 1 })
    }

    @Test
    @MainActor
    func settingsNavigationIncludesDedicatedExternalProcessorsSection() {
        #expect(SettingsSection.allCases.contains(.externalProcessors))
        #expect(SettingsSection.externalProcessors.title == "Processors")
        #expect(SettingsSection.llm.title == "Text")
    }

    @Test
    func settingsNavigationUsesProviderInsteadOfTopLevelASR() {
        #expect(SettingsSection.navigationCases.map(\.title) == [
            "Home",
            "Permissions",
            "Library",
            "Text",
            "Provider",
            "Processors",
            "About"
        ])
    }

    @Test
    func settingsNavigationHidesHistoryFromTopNavigation() {
        #expect(SettingsSection.allCases.contains(.history))
        #expect(SettingsSection.navigationCases.contains(.history) == false)
        #expect(SettingsSection.navigationCases.contains(.dictionary))
    }

    @Test
    @MainActor
    func settingsNavigationPlacesExternalProcessorsAfterText() {
        let sections = SettingsSection.navigationCases
        let llmIndex = sections.firstIndex(of: .llm)
        let providerIndex = sections.firstIndex(where: { $0.title == "Provider" })
        let externalProcessorsIndex = sections.firstIndex(of: .externalProcessors)

        #expect(llmIndex != nil)
        #expect(providerIndex != nil)
        #expect(externalProcessorsIndex != nil)
        #expect(providerIndex == llmIndex.map { $0 + 1 })
        #expect(externalProcessorsIndex == providerIndex.map { $0 + 1 })
    }

    @Test
    func dictionarySummaryIncludesTermAndSuggestionCounts() {
        let entries = [
            DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre"]),
            DictionaryEntry(canonical: "Cloudflare", aliases: ["cloud flare"])
        ]
        let suggestions = [
            DictionarySuggestion(
                originalFragment: "kuber",
                correctedFragment: "Kubernetes",
                proposedCanonical: "Kubernetes",
                proposedAliases: ["kuber"]
            )
        ]

        let presentation = SettingsPresentation.dictionarySectionPresentation(
            entries: entries,
            suggestions: suggestions
        )

        #expect(presentation.termCount == 2)
        #expect(presentation.suggestionCount == 1)
        #expect(presentation.summaryText == "Dictionary terms: 2 • Suggestions: 1")
        #expect(presentation.pendingReviewText == "1 suggestion pending review.")
    }

    @Test
    func dictionaryRowPresentationIncludesCanonicalAliasAndEnabledState() {
        let entry = DictionaryEntry(
            canonical: "Cloudflare",
            aliases: ["cloud flare", "cloudflair"],
            tag: "Infra",
            isEnabled: false
        )

        let presentation = SettingsPresentation.dictionaryRowPresentation(entry: entry)

        #expect(presentation.canonical == "Cloudflare")
        #expect(presentation.bindingSummary == "cloud flare, cloudflair")
        #expect(presentation.tagLabel == "Infra")
        #expect(presentation.enabledStateText == "Disabled")
    }

    @Test
    func dictionaryPendingReviewTextSupportsPluralCounts() {
        let suggestions = [
            DictionarySuggestion(
                originalFragment: "vue js",
                correctedFragment: "Vue.js",
                proposedCanonical: "Vue.js"
            ),
            DictionarySuggestion(
                originalFragment: "type script",
                correctedFragment: "TypeScript",
                proposedCanonical: "TypeScript"
            )
        ]

        let presentation = SettingsPresentation.dictionarySectionPresentation(
            entries: [],
            suggestions: suggestions
        )

        #expect(presentation.pendingReviewText == "2 suggestions pending review.")
    }

    @Test
    func dictionaryRowPresentationUsesFallbackAliasCopyWhenNoAliasesExist() {
        let entry = DictionaryEntry(canonical: "PostgreSQL", aliases: [])

        let presentation = SettingsPresentation.dictionaryRowPresentation(entry: entry)

        #expect(presentation.bindingSummary == "No bindings")
        #expect(presentation.tagLabel == "No tag")
    }

    @Test
    func dictionaryTermsRowsHeightClampsForSmallAndLargeLists() {
        #expect(SettingsWindowSupport.dictionaryTermsRowsHeight(forVisibleRowCount: 1) == 56)
        #expect(SettingsWindowSupport.dictionaryTermsRowsHeight(forVisibleRowCount: 2) == 122)
        #expect(SettingsWindowSupport.dictionaryTermsRowsHeight(forVisibleRowCount: 10) == 254)
    }

    @Test
    func dictionaryCollectionsGroupEntriesByTagAndIncludeSuggestions() {
        let entries = [
            DictionaryEntry(canonical: "Cloudflare", aliases: ["cloud flare"], tag: "Infra"),
            DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre"], tag: "Infra"),
            DictionaryEntry(canonical: "Python", aliases: ["py"], tag: "Languages"),
            DictionaryEntry(canonical: "VoicePi", aliases: [])
        ]
        let suggestions = [
            DictionarySuggestion(
                originalFragment: "tensor flow",
                correctedFragment: "TensorFlow",
                proposedCanonical: "TensorFlow"
            )
        ]

        let collections = SettingsWindowSupport.dictionaryCollections(
            entries: entries,
            suggestions: suggestions
        )

        #expect(collections.map(\.title) == ["All Terms", "Infra", "Languages", "Suggestions"])
        #expect(collections.map(\.count) == [4, 2, 1, 1])
        #expect(collections.map(\.selection) == [
            .allTerms,
            .tag("Infra"),
            .tag("Languages"),
            .suggestions
        ])
    }

    @Test
    func dictionaryFilteringCombinesCollectionAndSearchQuery() {
        let entries = [
            DictionaryEntry(canonical: "Cloudflare", aliases: ["cloud flare"], tag: "Infra"),
            DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre"], tag: "Infra"),
            DictionaryEntry(canonical: "Python", aliases: ["py"], tag: "Languages")
        ]

        let filtered = SettingsWindowSupport.filteredDictionaryEntries(
            entries,
            query: "py",
            selection: .tag("Languages")
        )

        #expect(filtered.map(\.canonical) == ["Python"])
    }
}
