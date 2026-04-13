import AppKit
import Testing
@testable import VoicePi

@MainActor
struct ResultReviewPanelControllerTests {
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
}
