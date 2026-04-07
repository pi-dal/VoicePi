import Testing
@testable import VoicePi

@MainActor
struct FloatingPanelControllerTests {
    @Test
    func immediateHideRunsCompletionWithoutWaitingForAnimation() {
        let controller = FloatingPanelController()
        controller.showRecording(transcript: "hello")

        var didComplete = false
        controller.hide(immediately: true) {
            didComplete = true
        }

        #expect(didComplete)
        #expect(controller.window?.isVisible == false)
    }
}
