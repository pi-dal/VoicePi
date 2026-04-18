import Testing
@testable import VoicePi

@MainActor
struct SettingsWindowThinkingTests {
    @Test
    func thinkingTitlesStartWithNotSet() {
        let titles = SettingsWindowController.thinkingTitles()

        #expect(titles == ["Not Set", "On", "Off"])
    }

    @Test
    func thinkingSelectionIndexRoundTripsOptionalValues() {
        #expect(SettingsWindowController.thinkingSelectionIndex(for: nil) == 0)
        #expect(SettingsWindowController.enableThinkingForSelectionIndex(0) == nil)

        #expect(SettingsWindowController.thinkingSelectionIndex(for: true) == 1)
        #expect(SettingsWindowController.enableThinkingForSelectionIndex(1) == true)

        #expect(SettingsWindowController.thinkingSelectionIndex(for: false) == 2)
        #expect(SettingsWindowController.enableThinkingForSelectionIndex(2) == false)
    }
}
