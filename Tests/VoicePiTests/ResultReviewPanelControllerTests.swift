import AppKit
import Testing
@testable import VoicePi

@MainActor
struct ResultReviewPanelControllerTests {
    @Test
    func showDoesNotPresentWindowDuringTests() throws {
        let controller = ResultReviewPanelController()

        controller.show(
            payload: try #require(
                ResultReviewPanelPayload(
                    resultText: "Refined text",
                    originalText: "Original text",
                    selectedPromptPresetID: PromptPreset.builtInDefaultID,
                    selectedPromptTitle: PromptPreset.builtInDefault.title,
                    availablePrompts: [
                        .init(
                            presetID: PromptPreset.builtInDefaultID,
                            title: PromptPreset.builtInDefault.title
                        )
                    ]
                )
            )
        )

        #expect(controller.window?.isVisible == false)
    }

    @Test
    func regeneratingPanelDoesNotConsumeReturnAsInsertShortcut() throws {
        let controller = ResultReviewPanelController()
        var insertions: [String] = []
        controller.onInsertRequested = { text in
            insertions.append(text)
        }

        controller.show(
            payload: try #require(
                ResultReviewPanelPayload(
                    resultText: "Refined text",
                    originalText: "Original text",
                    selectedPromptPresetID: PromptPreset.builtInDefaultID,
                    selectedPromptTitle: PromptPreset.builtInDefault.title,
                    availablePrompts: [
                        .init(
                            presetID: PromptPreset.builtInDefaultID,
                            title: PromptPreset.builtInDefault.title
                        )
                    ],
                    isRegenerating: true
                )
            )
        )

        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: controller.window?.windowNumber ?? 0,
                context: nil,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                keyCode: 36
            )
        )

        let consumed = controller.window?.performKeyEquivalent(with: event) ?? false

        #expect(consumed == false)
        #expect(insertions.isEmpty)
    }

    @Test
    func autoRepeatReturnDoesNotTriggerInsertShortcut() throws {
        let controller = ResultReviewPanelController()
        var insertions: [String] = []
        controller.onInsertRequested = { text in
            insertions.append(text)
        }

        controller.show(
            payload: try #require(
                ResultReviewPanelPayload(
                    resultText: "Refined text",
                    originalText: "Original text",
                    selectedPromptPresetID: PromptPreset.builtInDefaultID,
                    selectedPromptTitle: PromptPreset.builtInDefault.title,
                    availablePrompts: [
                        .init(
                            presetID: PromptPreset.builtInDefaultID,
                            title: PromptPreset.builtInDefault.title
                        )
                    ]
                )
            )
        )

        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: controller.window?.windowNumber ?? 0,
                context: nil,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: true,
                keyCode: 36
            )
        )

        let consumed = controller.window?.performKeyEquivalent(with: event) ?? false

        #expect(consumed == false)
        #expect(insertions.isEmpty)
    }

    @Test
    func functionModifiedReturnStillCountsAsInsertShortcut() throws {
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.function],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                keyCode: 36
            )
        )

        #expect(
            ResultReviewPanelController.shouldConsumeConfirmShortcut(
                event,
                isInsertEnabled: true
            )
        )
    }

    @Test
    func promptPresetChangeNotifiesCoordinatorImmediately() throws {
        let controller = ResultReviewPanelController()
        var selections: [String] = []
        controller.onPromptSelectionChanged = { presetID in
            selections.append(presetID)
        }

        let promptOptions: [ResultReviewPanelPromptOption] = [
            .init(presetID: PromptPreset.builtInDefaultID, title: PromptPreset.builtInDefault.title),
            .init(presetID: "user.meeting", title: "Meeting Notes")
        ]
        controller.show(
            payload: try #require(
                ResultReviewPanelPayload(
                    resultText: "Refined text",
                    originalText: "Original text",
                    selectedPromptPresetID: PromptPreset.builtInDefaultID,
                    selectedPromptTitle: PromptPreset.builtInDefault.title,
                    availablePrompts: promptOptions
                )
            )
        )

        let contentView = try #require(controller.window?.contentViewController?.view)
        let popup = try #require(findFirstPromptPopup(in: contentView))
        #expect(popup.numberOfItems >= 2)
        popup.selectItem(at: 1)
        _ = popup.sendAction(popup.action, to: popup.target)

        let selectedPresetID = popup.itemArray[1].representedObject as? String
        #expect(selections.last == selectedPresetID)
    }

    @Test
    func regenerateAlwaysSyncsCurrentlySelectedPromptBeforeRetry() throws {
        let controller = ResultReviewPanelController()
        var selections: [String] = []
        var retryCount = 0
        controller.onPromptSelectionChanged = { presetID in
            selections.append(presetID)
        }
        controller.onRetryRequested = {
            retryCount += 1
        }

        let promptOptions: [ResultReviewPanelPromptOption] = [
            .init(presetID: PromptPreset.builtInDefaultID, title: PromptPreset.builtInDefault.title),
            .init(presetID: "user.meeting", title: "Meeting Notes")
        ]
        controller.show(
            payload: try #require(
                ResultReviewPanelPayload(
                    resultText: "Refined text",
                    originalText: "Original text",
                    selectedPromptPresetID: PromptPreset.builtInDefaultID,
                    selectedPromptTitle: PromptPreset.builtInDefault.title,
                    availablePrompts: promptOptions
                )
            )
        )

        let contentView = try #require(controller.window?.contentViewController?.view)
        let popup = try #require(findFirstPromptPopup(in: contentView))
        popup.selectItem(at: 1)
        _ = popup.sendAction(popup.action, to: popup.target)
        popup.selectItem(at: 0)
        _ = popup.sendAction(popup.action, to: popup.target)

        let regenerateButton = try #require(findButton(in: contentView, withTitle: "Regenerate"))
        _ = regenerateButton.sendAction(regenerateButton.action, to: regenerateButton.target)

        let selectedPresetID = popup.selectedItem?.representedObject as? String
        #expect(retryCount == 1)
        #expect(selections.last == selectedPresetID)
    }

    private func findFirstPromptPopup(in view: NSView) -> NSPopUpButton? {
        if let popup = view as? NSPopUpButton {
            return popup
        }
        for subview in view.subviews {
            if let match = findFirstPromptPopup(in: subview) {
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
