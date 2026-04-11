import AppKit
import Testing
@testable import VoicePi

@MainActor
struct FloatingPanelControllerTests {
    @Test
    func refiningBannerStaysCompactForShortStatusText() async {
        let controller = FloatingPanelController()

        controller.showRefining(transcript: "Refining...")
        defer { controller.hide(immediately: true) }
        await settlePanelAnimations()

        let width = controller.window?.frame.width ?? 0
        #expect(width >= 260)
        #expect(width < 320)
    }

    @Test
    func refiningBannerExpandsForLongStatusText() async {
        let shortController = FloatingPanelController()
        shortController.showRefining(transcript: "Refining...")
        await settlePanelAnimations()
        let shortWidth = shortController.window?.frame.width ?? 0
        shortController.hide(immediately: true)

        let longController = FloatingPanelController()
        defer { longController.hide(immediately: true) }

        longController.showRefining(transcript: "Refining with Customer Success Follow-up Email")
        await settlePanelAnimations()
        let longWidth = longController.window?.frame.width ?? 0

        #expect(longWidth > shortWidth)
    }

    private func settlePanelAnimations() async {
        try? await Task.sleep(nanoseconds: 450_000_000)
    }
}
