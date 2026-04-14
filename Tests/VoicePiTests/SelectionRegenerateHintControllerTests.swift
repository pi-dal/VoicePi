import AppKit
import Testing
@testable import VoicePi

@MainActor
struct SelectionRegenerateHintControllerTests {
    @Test
    func runtimeEnvironmentDetectsTests() {
        #expect(RuntimeEnvironment.isRunningTests)
    }

    @Test
    func payloadUsesDefaultActionTitle() {
        let payload = SelectionRegenerateHintPayload(
            sessionID: UUID(),
            selectedText: "Refined output"
        )

        #expect(payload.actionTitle == "Review")
        #expect(payload.hintText == "Review selection")
    }

    @Test
    func layoutAnchorsNextToSelectionBoundsAndClampsInsideScreen() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1280, height: 800)
        let anchorRect = NSRect(x: 1200, y: 760, width: 70, height: 18)

        let frame = SelectionRegenerateHintLayout.frame(
            for: visibleFrame,
            anchorRectInScreen: anchorRect,
            panelSize: NSSize(width: 160, height: 44)
        )

        #expect(frame.maxX <= visibleFrame.maxX)
        #expect(frame.maxY <= visibleFrame.maxY)
        #expect(frame.minY >= visibleFrame.minY)
    }

    @Test
    func layoutFallsBackToBottomCenterWhenAnchorIsMissing() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1200, height: 800)

        let frame = SelectionRegenerateHintLayout.frame(
            for: visibleFrame,
            anchorRectInScreen: nil,
            panelSize: NSSize(width: 160, height: 44)
        )

        #expect(frame.midX == round(visibleFrame.midX))
        #expect(frame.minY > visibleFrame.minY)
    }

    @Test
    func paletteAdaptsBetweenLightAndDarkAppearances() throws {
        let lightAppearance = try #require(NSAppearance(named: .aqua))
        let darkAppearance = try #require(NSAppearance(named: .darkAqua))

        let lightPalette = SelectionRegenerateHintPalette(appearance: lightAppearance)
        let darkPalette = SelectionRegenerateHintPalette(appearance: darkAppearance)

        #expect(lightPalette.backgroundColor != darkPalette.backgroundColor)
        #expect(lightPalette.borderColor != darkPalette.borderColor)
        #expect(lightPalette.primaryButtonBackgroundColor != darkPalette.primaryButtonBackgroundColor)
        #expect(lightPalette.primaryButtonTextColor != darkPalette.primaryButtonTextColor)
    }

    @Test
    func showUpdatesPayloadAndPreview() {
        let controller = SelectionRegenerateHintController()
        let payload = SelectionRegenerateHintPayload(
            sessionID: UUID(),
            selectedText: "Sample text inserted by VoicePi",
            hintText: "Regenerate final sentence",
            actionTitle: "Regenerate"
        )

        controller.show(payload: payload)

        #expect(controller.currentPayload == payload)
        #expect(controller.displayedActionTitle == payload.actionTitle)
        #expect(controller.displayedPreviewText == "Sample text inserted by VoicePi")
    }

    @Test
    func showDoesNotPresentWindowDuringTests() {
        let controller = SelectionRegenerateHintController()
        let payload = SelectionRegenerateHintPayload(
            sessionID: UUID(),
            selectedText: "Sample text inserted by VoicePi"
        )

        controller.show(payload: payload)

        #expect(controller.window?.isVisible == false)
    }

    @Test
    func primaryActionInvokesCallbackAndClearsPayload() {
        let controller = SelectionRegenerateHintController()
        let payload = SelectionRegenerateHintPayload(
            sessionID: UUID(),
            selectedText: "Sentence to regenerate"
        )
        controller.show(payload: payload)

        var receivedPayload: SelectionRegenerateHintPayload?
        controller.onPrimaryAction = { receivedPayload = $0 }

        controller.performPrimaryAction()

        #expect(receivedPayload == payload)
        #expect(controller.currentPayload == nil)
        #expect(controller.isHintVisible == false)
    }

    @Test
    func actionButtonKeepsIconAwayFromLeadingEdge() throws {
        let controller = SelectionRegenerateHintController()
        controller.show(
            payload: SelectionRegenerateHintPayload(
                sessionID: UUID(),
                selectedText: "Sentence to regenerate",
                actionTitle: "Review"
            )
        )
        let contentView = try #require(controller.window?.contentView)
        contentView.layoutSubtreeIfNeeded()
        let actionButton = try #require(findFirstButton(in: contentView))

        let imageRect = actionButton.cell?.imageRect(forBounds: actionButton.bounds) ?? .zero
        #expect(imageRect.minX >= 10)
    }

    private func findFirstButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton {
            return button
        }
        for subview in view.subviews {
            if let match = findFirstButton(in: subview) {
                return match
            }
        }
        return nil
    }
}
