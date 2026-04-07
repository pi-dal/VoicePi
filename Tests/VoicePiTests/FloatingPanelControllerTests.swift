import AppKit
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

    @Test
    func refiningBannerDisplaysProvidedPromptLabel() {
        let controller = FloatingPanelController()
        controller.showRefining(transcript: "Refining with Slack Reply")

        let labels = allTextFields(in: controller.window?.contentView)
        let texts = labels.map(\.stringValue)

        #expect(texts.contains("Refining with Slack Reply"))
    }

    private func allTextFields(in view: NSView?) -> [NSTextField] {
        guard let view else { return [] }

        var result: [NSTextField] = []
        if let textField = view as? NSTextField {
            result.append(textField)
        }

        for subview in view.subviews {
            result.append(contentsOf: allTextFields(in: subview))
        }

        return result
    }
}
