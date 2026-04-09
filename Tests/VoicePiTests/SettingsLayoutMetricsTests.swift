import Testing
@testable import VoicePi

struct SettingsLayoutMetricsTests {
    @Test
    @MainActor
    func settingsLayoutMetricsMatchUnifiedContentRhythm() {
        #expect(SettingsLayoutMetrics.pageSpacing == 12)
        #expect(SettingsLayoutMetrics.cardPaddingHorizontal == 18)
        #expect(SettingsLayoutMetrics.cardPaddingVertical == 16)
        #expect(SettingsLayoutMetrics.sectionHeaderSpacing == 4)
        #expect(SettingsLayoutMetrics.formRowVerticalInset == 9)
        #expect(SettingsLayoutMetrics.twoColumnSpacing == 12)
        #expect(SettingsLayoutMetrics.actionButtonHeight == 32)
        #expect(SettingsLayoutMetrics.navigationButtonHeight == 52)
        #expect(SettingsLayoutMetrics.navigationButtonMinWidth == 72)
    }

    @Test
    @MainActor
    func aboutProfileUsesCompactHandles() {
        #expect(AboutProfile.author == "pi-dal")
        #expect(AboutProfile.websiteDisplay == "pi-dal.com")
        #expect(AboutProfile.githubDisplay == "@pi-dal")
        #expect(AboutProfile.xDisplay == "@pidal20")
    }

    @Test
    @MainActor
    func aboutOverviewPlacesUpdateActionAfterInspirationRow() {
        #expect(
            StatusBarController.aboutOverviewRowOrder == [
                .builtBy,
                .inspiredBy
            ]
        )
    }

    @Test
    @MainActor
    func updatePanelUsesSettingsAlignedMetrics() {
        #expect(SettingsLayoutMetrics.updatePanelWidth == 436)
        #expect(SettingsLayoutMetrics.updatePanelMinHeight == 408)
        #expect(SettingsLayoutMetrics.updatePanelNotesHeight == 120)
        #expect(SettingsLayoutMetrics.updatePanelOuterInset == 18)
    }

    @Test
    @MainActor
    func promptEditorUsesDedicatedSheetRhythm() {
        #expect(SettingsLayoutMetrics.promptEditorOuterInset == 18)
        #expect(SettingsLayoutMetrics.promptEditorSectionSpacing == 12)
        #expect(SettingsLayoutMetrics.promptEditorFieldSpacing == 8)
        #expect(SettingsLayoutMetrics.promptEditorBodyMinHeight == 240)
        #expect(SettingsLayoutMetrics.promptEditorSidebarWidth == 272)
    }
}
