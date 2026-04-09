import Foundation
import Testing
@testable import VoicePi

@MainActor
struct SettingsWindowDictionaryTests {
    @Test
    func settingsNavigationIncludesDictionarySection() {
        #expect(SettingsSection.allCases.contains(.dictionary))
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
    @MainActor
    func settingsNavigationPlacesExternalProcessorsAfterText() {
        let sections = SettingsSection.allCases
        let llmIndex = sections.firstIndex(of: .llm)
        let externalProcessorsIndex = sections.firstIndex(of: .externalProcessors)

        #expect(llmIndex != nil)
        #expect(externalProcessorsIndex != nil)
        #expect(externalProcessorsIndex == llmIndex.map { $0 + 1 })
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
            isEnabled: false
        )

        let presentation = SettingsPresentation.dictionaryRowPresentation(entry: entry)

        #expect(presentation.canonical == "Cloudflare")
        #expect(presentation.aliasSummary == "cloud flare, cloudflair")
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
}
