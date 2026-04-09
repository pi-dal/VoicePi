import AppKit
import Testing
@testable import VoicePi

@MainActor
struct ResultReviewPanelControllerTests {
    @Test
    func windowCanBecomeKeyForKeyboardShortcuts() {
        let controller = ResultReviewPanelController()

        let panel = controller.window

        #expect(panel is NSPanel)
        #expect(panel?.canBecomeKey == true)
        #expect(panel?.canBecomeMain == true)
    }
}
