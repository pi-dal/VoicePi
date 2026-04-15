import AppKit
import Testing
@testable import VoicePi

@MainActor
struct ExternalProcessorResultPanelControllerTests {
    @Test
    func showDoesNotPresentWindowDuringTests() throws {
        let controller = ExternalProcessorResultPanelController()

        controller.show(
            payload: try #require(
                ExternalProcessorResultPanelPayload(
                    resultText: "Refined text",
                    originalText: "Original text"
                )
            )
        )

        #expect(controller.window?.isVisible == false)
    }

    @Test
    func unchangedResultUsesCompactSourceRowAndBadge() throws {
        let controller = ExternalProcessorResultPanelController()
        controller.show(
            payload: try #require(
                ExternalProcessorResultPanelPayload(
                    resultText: "Same answer",
                    originalText: "Same answer"
                )
            )
        )

        let contentView = try #require(controller.window?.contentViewController?.view)
        #expect(findLabel(in: contentView, withText: "Source") != nil)
        #expect(findLabel(in: contentView, withText: "Result") != nil)
        #expect(findLabel(in: contentView, withText: "Unchanged") != nil)
    }

    private func findLabel(in view: NSView, withText text: String) -> NSTextField? {
        if let label = view as? NSTextField, label.stringValue == text {
            return label
        }
        for subview in view.subviews {
            if let match = findLabel(in: subview, withText: text) {
                return match
            }
        }
        return nil
    }
}
