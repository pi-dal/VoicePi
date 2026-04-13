import AppKit
import Testing
@testable import VoicePi

@MainActor
struct SelectionRegenerateHintControllerTests {
    @Test
    func payloadUsesDefaultActionTitle() {
        let payload = SelectionRegenerateHintPayload(
            sessionID: UUID(),
            selectedText: "Refined output"
        )

        #expect(payload.actionTitle == "Regenerate")
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
}
