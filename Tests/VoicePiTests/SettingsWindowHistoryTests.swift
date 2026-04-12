import Testing
@testable import VoicePi

@MainActor
struct SettingsWindowHistoryTests {
    @Test
    func settingsRoutingIncludesHistorySubview() {
        #expect(SettingsSection.allCases.contains(.history))
        #expect(SettingsSection.navigationCases.contains(.history) == false)
    }

    @Test
    func historySummaryUsesEmptyStateCopyWhenNothingIsSaved() {
        #expect(
            SettingsWindowSupport.historySummaryText(forEntryCount: 0)
                == "No history yet. Final transcript outputs will appear here after successful delivery."
        )
    }

    @Test
    func historySummaryPluralizesSavedOutputs() {
        #expect(SettingsWindowSupport.historySummaryText(forEntryCount: 1) == "Saved outputs: 1 entry")
        #expect(SettingsWindowSupport.historySummaryText(forEntryCount: 4) == "Saved outputs: 4 entries")
    }
}
