import AppKit
import Testing
@testable import VoicePi

@MainActor
struct DictionarySuggestionToastControllerTests {
    @Test
    func toastButtonsUseSettingsButtonChrome() throws {
        let controller = DictionarySuggestionToastController()
        controller.applyInterfaceTheme(.light)

        controller.show(
            payload: DictionarySuggestionToastPayload(
                sessionID: UUID(),
                suggestion: DictionarySuggestion(
                    originalFragment: "teh",
                    correctedFragment: "the",
                    proposedCanonical: "the"
                )
            )
        )

        let contentView = try #require(controller.window?.contentView)
        let approveButton = try #require(findButton(in: contentView, withTitle: DictionarySuggestionToastController.approveTitle))
        let reviewButton = try #require(findButton(in: contentView, withTitle: DictionarySuggestionToastController.reviewTitle))
        let dismissButton = try #require(findButton(in: contentView, withTitle: DictionarySuggestionToastController.dismissTitle))
        let approveBackground = try #require(approveButton.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)))
        let reviewBackground = try #require(reviewButton.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)))
        let dismissBackground = try #require(dismissButton.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)))
        let expectedPrimaryChrome = SettingsWindowTheme.buttonChrome(
            for: NSAppearance(named: .aqua),
            role: .primary,
            isSelected: false,
            isHovered: false,
            isHighlighted: false
        )
        let expectedSecondaryChrome = SettingsWindowTheme.buttonChrome(
            for: NSAppearance(named: .aqua),
            role: .secondary,
            isSelected: false,
            isHovered: false,
            isHighlighted: false
        )

        #expect(approveBackground == expectedPrimaryChrome.fill)
        #expect(reviewBackground == expectedSecondaryChrome.fill)
        #expect(dismissBackground == expectedSecondaryChrome.fill)
    }

    @Test
    func toastSurfaceUsesSettingsCardChrome() throws {
        let controller = DictionarySuggestionToastController()
        controller.applyInterfaceTheme(.light)

        controller.show(
            payload: DictionarySuggestionToastPayload(
                sessionID: UUID(),
                suggestion: DictionarySuggestion(
                    originalFragment: "teh",
                    correctedFragment: "the",
                    proposedCanonical: "the"
                )
            )
        )

        let blurView = try #require(controller.window?.contentView?.subviews.first as? NSView)
        let backgroundColor = try #require(blurView.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)))
        let borderColor = try #require(blurView.layer?.borderColor.flatMap(NSColor.init(cgColor:)))
        let expectedChrome = SettingsWindowTheme.surfaceChrome(
            for: NSAppearance(named: .aqua),
            style: .card
        )

        #expect(backgroundColor == expectedChrome.background)
        #expect(borderColor == expectedChrome.border)
    }

    private func findButton(in view: NSView, withTitle title: String) -> NSButton? {
        if let button = view as? NSButton, button.title == title {
            return button
        }
        for subview in view.subviews {
            if let match = findButton(in: subview, withTitle: title) {
                return match
            }
        }
        return nil
    }
}
