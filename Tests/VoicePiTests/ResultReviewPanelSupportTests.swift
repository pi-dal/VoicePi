import AppKit
import Testing
@testable import VoicePi

struct ResultReviewPanelSupportTests {
    @Test
    func payloadRejectsEmptyTextAndTrimsWhitespace() throws {
        let prompts: [ResultReviewPanelPromptOption] = [
            .init(presetID: PromptPreset.builtInDefaultID, title: "VoicePi Default"),
            .init(presetID: "user.meeting", title: "Meeting Notes")
        ]
        #expect(
            ResultReviewPanelPayload(
                resultText: " \n\t ",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                selectedPromptTitle: PromptPreset.builtInDefault.title,
                availablePrompts: prompts
            ) == nil
        )

        let payload = try #require(
            ResultReviewPanelPayload(
                resultText: "  \nReviewed text\n  ",
                selectedPromptPresetID: "  user.meeting  ",
                selectedPromptTitle: "  Meeting Notes  ",
                availablePrompts: prompts
            )
        )
        #expect(payload.resultText == "Reviewed text")
        #expect(payload.displayText == "Reviewed text")
        #expect(payload.selectedPromptPresetID == "user.meeting")
        #expect(payload.selectedPromptTitle == "Meeting Notes")
        #expect(payload.isRegenerating == false)
    }

    @Test
    func payloadFallsBackToFirstPromptOptionWhenSelectedPromptIsMissing() throws {
        let payload = try #require(
            ResultReviewPanelPayload(
                resultText: "Reviewed",
                selectedPromptPresetID: "user.unknown",
                selectedPromptTitle: "Unknown",
                availablePrompts: [
                    .init(presetID: PromptPreset.builtInDefaultID, title: "VoicePi Default"),
                    .init(presetID: "user.focus", title: "Focus Mode")
                ]
            )
        )
        #expect(payload.selectedPromptPresetID == PromptPreset.builtInDefaultID)
        #expect(payload.selectedPromptTitle == "VoicePi Default")
    }

    @Test
    func layoutCentersPanelWithinOneThirdWidthAndCenteredHeight() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = ResultReviewPanelLayout.frame(for: visibleFrame)

        #expect(abs(frame.size.width - 480) < 0.001)
        #expect(abs(frame.size.height - 378) < 0.001)
        #expect(frame.origin.x == 480)
        #expect(frame.origin.y == 261)
    }

    @Test
    func presentationStateExposesExpectedTitles() throws {
        let payload = try #require(
            ResultReviewPanelPayload(
                resultText: "Needs review",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                selectedPromptTitle: "VoicePi Default",
                availablePrompts: [
                    .init(presetID: PromptPreset.builtInDefaultID, title: "VoicePi Default"),
                    .init(presetID: "user.focus", title: "Focus Mode")
                ]
            )
        )
        let state = ResultReviewPanelPresentationState(payload: payload)

        #expect(state.titleText == "VoicePi")
        #expect(state.promptSectionTitle == "Prompt")
        #expect(state.outputSectionTitle == "Answer")
        #expect(state.outputCopyButtonTitle == "Copy")
        #expect(state.outputCopyText == "Needs review")
        #expect(state.outputDisplayText == "Needs review")
        #expect(state.selectedPromptPresetID == PromptPreset.builtInDefaultID)
        #expect(state.selectedPromptTitle == "VoicePi Default")
        #expect(state.regenerateButtonTitle == "Regenerate")
        #expect(state.isRegenerateEnabled)
        #expect(state.isPromptPickerEnabled)
    }

    @Test
    func presentationStateShowsRegeneratingState() throws {
        let payload = try #require(
            ResultReviewPanelPayload(
                resultText: "Same",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                selectedPromptTitle: "VoicePi Default",
                availablePrompts: [.init(presetID: PromptPreset.builtInDefaultID, title: "VoicePi Default")],
                isRegenerating: true
            )
        )
        let state = ResultReviewPanelPresentationState(payload: payload)
        #expect(state.regenerateButtonTitle == "Regenerating…")
        #expect(state.isRegenerateEnabled == false)
        #expect(state.isPromptPickerEnabled == false)
    }
}
