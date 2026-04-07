import AppKit
import Testing
@testable import VoicePi

@MainActor
struct InputFallbackPanelControllerTests {
    @Test
    func panelStartsCollapsedForLongText() throws {
        let controller = InputFallbackPanelController()
        let payload = try #require(InputFallbackPanelPayload(text: String(repeating: "fallback panel text ", count: 12)))

        controller.show(payload: payload)

        #expect(controller.titleText == "No Input Field Detected")
        #expect(controller.descriptionText == "VoicePi couldn't paste automatically. Copy and paste it yourself.")
        #expect(controller.isExpanded == false)
        #expect(controller.toggleTitle == "Show Full Text")
        #expect(controller.displayedText != payload.fullText)
        #expect(controller.window?.frame.height == 135)

        controller.hide()
    }

    @Test
    func panelCanExpandToShowFullText() throws {
        let controller = InputFallbackPanelController()
        let payload = try #require(InputFallbackPanelPayload(text: String(repeating: "expand me please ", count: 12)))

        controller.show(payload: payload)
        controller.toggleExpansion()

        #expect(controller.isExpanded)
        #expect(controller.displayedText == payload.fullText)
        #expect(controller.toggleTitle == "Hide Full Text")

        controller.hide()
    }

    @Test
    func copyUsesFullTextAndClosesPanel() throws {
        let clipboard = TestClipboardWriter()
        let controller = InputFallbackPanelController(clipboardWriter: clipboard)
        let payload = try #require(InputFallbackPanelPayload(text: String(repeating: "copy this exact full text ", count: 10)))

        controller.show(payload: payload)
        let didCopy = controller.performCopy()

        #expect(didCopy)
        #expect(clipboard.copiedStrings == [payload.fullText])
        #expect(controller.window?.isVisible == false)
    }

    @Test
    func dismissClosesPanelWithoutCopying() throws {
        let controller = InputFallbackPanelController()
        let payload = try #require(InputFallbackPanelPayload(text: "dismiss me"))

        controller.show(payload: payload)
        controller.performDismiss()

        #expect(controller.window?.isVisible == false)
    }

    @Test
    func panelAutoHidesAfterInactivity() async throws {
        let controller = InputFallbackPanelController(
            autoHideDelay: .milliseconds(40),
            fadeOutDuration: 0.01
        )
        let payload = try #require(InputFallbackPanelPayload(text: "auto hide"))

        controller.show(payload: payload)
        #expect(controller.window?.isVisible == true)

        for _ in 0..<8 {
            if controller.window?.isVisible == false {
                break
            }
            try await Task.sleep(for: .milliseconds(40))
        }

        #expect(controller.window?.isVisible == false)
    }

    @Test
    func panelAcceptsLightAndDarkThemes() throws {
        let controller = InputFallbackPanelController()
        let payload = try #require(InputFallbackPanelPayload(text: "theme text"))

        controller.show(payload: payload)
        controller.applyInterfaceTheme(.dark)
        #expect(
            controller.window?.appearance?.bestMatch(
                from: [NSAppearance.Name.darkAqua, NSAppearance.Name.aqua]
            ) == NSAppearance.Name.darkAqua
        )

        controller.applyInterfaceTheme(.light)
        #expect(
            controller.window?.appearance?.bestMatch(
                from: [NSAppearance.Name.darkAqua, NSAppearance.Name.aqua]
            ) == NSAppearance.Name.aqua
        )

        controller.hide()
    }
}

@MainActor
private final class TestClipboardWriter: ClipboardWriting {
    private(set) var copiedStrings: [String] = []

    func write(string: String) -> Bool {
        copiedStrings.append(string)
        return true
    }
}
