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
    func settingsNavigationHidesHistoryFromTopNavigation() {
        #expect(SettingsSection.allCases.contains(.history))
        #expect(SettingsSection.navigationCases.contains(.history) == false)
        #expect(SettingsSection.navigationCases.contains(.dictionary))
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

    @Test
    func dictionaryRowPresentationUsesFallbackAliasCopyWhenNoAliasesExist() {
        let entry = DictionaryEntry(canonical: "PostgreSQL", aliases: [])

        let presentation = SettingsPresentation.dictionaryRowPresentation(entry: entry)

        #expect(presentation.aliasSummary == "No aliases")
    }

    @Test
    @MainActor
    func dictionaryTermsCardDoesNotStretchWhenShowingFewRows() {
        let controller = makeController()
        controller.show(section: .dictionary)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let labels = textLabels(in: controller.window?.contentView)
        guard let termsLabel = labels.first(where: { $0.stringValue == "Terms" }) else {
            Issue.record("Expected Terms section title.")
            return
        }

        guard let termsCard = cardAncestor(of: termsLabel) else {
            Issue.record("Expected Terms card ancestor.")
            return
        }

        #expect(termsCard.frame.height < 260)
    }

    @Test
    @MainActor
    func dictionarySuggestionsCardDoesNotStretchWhenEmpty() {
        let controller = makeController()
        controller.show(section: .dictionary)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let labels = textLabels(in: controller.window?.contentView)
        guard let suggestionsLabel = labels.first(where: { $0.stringValue == "Suggestions" }) else {
            Issue.record("Expected Suggestions section title.")
            return
        }

        guard let suggestionsCard = cardAncestor(of: suggestionsLabel) else {
            Issue.record("Expected Suggestions card ancestor.")
            return
        }

        #expect(suggestionsCard.frame.height < 140)
    }

    private func makeController() -> SettingsWindowController {
        let defaults = UserDefaults(suiteName: "VoicePiTests.settingsDictionary.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.importDictionaryTerms(fromPlainText: """
        agent.md|agent md
        spec|spd
        """)
        return SettingsWindowController(model: model, delegate: nil)
    }

    private func allViews(in root: NSView?) -> [NSView] {
        guard let root else { return [] }
        return [root] + root.subviews.flatMap(allViews)
    }

    private func textLabels(in root: NSView?) -> [NSTextField] {
        allViews(in: root).compactMap { $0 as? NSTextField }
    }

    private func cardAncestor(of view: NSView) -> ThemedSurfaceView? {
        var current = view.superview
        while let currentView = current {
            if let card = currentView as? ThemedSurfaceView {
                return card
            }
            current = currentView.superview
        }
        return nil
    }
}
