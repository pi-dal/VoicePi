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

    @Test
    func panelCardUsesSettingsCardChrome() throws {
        let controller = ExternalProcessorResultPanelController()
        controller.applyInterfaceTheme(.light)

        controller.show(
            payload: try #require(
                ExternalProcessorResultPanelPayload(
                    resultText: "Refined text",
                    originalText: "Original text"
                )
            )
        )

        let cardView = try #require(
            controller.window?.contentViewController?.view.subviews.first as? NSView
        )
        let backgroundColor = try #require(cardView.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)))
        let borderColor = try #require(cardView.layer?.borderColor.flatMap(NSColor.init(cgColor:)))
        let expectedChrome = SettingsWindowTheme.surfaceChrome(
            for: NSAppearance(named: .aqua),
            style: .card
        )

        #expect(backgroundColor == expectedChrome.background)
        #expect(borderColor == expectedChrome.border)
    }

    @Test
    func footerButtonsUseSettingsButtonChrome() throws {
        let controller = ExternalProcessorResultPanelController()
        controller.applyInterfaceTheme(.light)

        controller.show(
            payload: try #require(
                ExternalProcessorResultPanelPayload(
                    resultText: "Refined text",
                    originalText: "Original text"
                )
            )
        )

        let contentView = try #require(controller.window?.contentViewController?.view)
        let retryButton = try #require(findButton(in: contentView, withTitle: "Retry"))
        let insertButton = try #require(findButton(in: contentView, withTitle: "Insert"))
        let retryBackground = try #require(retryButton.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)))
        let insertBackground = try #require(insertButton.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)))
        let expectedRetryChrome = SettingsWindowTheme.buttonChrome(
            for: NSAppearance(named: .aqua),
            role: .secondary,
            isSelected: false,
            isHovered: false,
            isHighlighted: false
        )
        let expectedInsertChrome = SettingsWindowTheme.buttonChrome(
            for: NSAppearance(named: .aqua),
            role: .primary,
            isSelected: false,
            isHovered: false,
            isHighlighted: false
        )

        #expect(retryBackground == expectedRetryChrome.fill)
        #expect(insertBackground == expectedInsertChrome.fill)
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
