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
                originalText: "Original transcript",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                selectedPromptTitle: PromptPreset.builtInDefault.title,
                availablePrompts: prompts
            ) == nil
        )

        let payload = try #require(
            ResultReviewPanelPayload(
                resultText: "  \nReviewed text\n  ",
                originalText: "  \nOriginal transcript\n  ",
                selectedPromptPresetID: "  user.meeting  ",
                selectedPromptTitle: "  Meeting Notes  ",
                availablePrompts: prompts
            )
        )
        #expect(payload.resultText == "Reviewed text")
        #expect(payload.displayText == "Reviewed text")
        #expect(payload.originalText == "Original transcript")
        #expect(payload.selectedPromptPresetID == "user.meeting")
        #expect(payload.selectedPromptTitle == "Meeting Notes")
        #expect(payload.isRegenerating == false)
    }

    @Test
    func payloadFallsBackToFirstPromptOptionWhenSelectedPromptIsMissing() throws {
        let payload = try #require(
            ResultReviewPanelPayload(
                resultText: "Reviewed",
                originalText: "Original transcript",
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
                originalText: "Original transcript",
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
        #expect(state.originalSectionTitle == "Original")
        #expect(state.promptSectionTitle == "Prompt")
        #expect(state.outputSectionTitle == "Result")
        #expect(state.originalDisplayText == "Original transcript")
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
                originalText: "Original transcript",
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

    @Test
    func promptSelectionStateKeepsAppliedPromptWhilePendingSelectionHasNoNewResult() throws {
        let prompts: [ResultReviewPanelPromptOption] = [
            .init(presetID: PromptPreset.builtInDefaultID, title: "VoicePi Default"),
            .init(presetID: "user.meeting", title: "Meeting Notes")
        ]
        let initialPayload = try #require(
            ResultReviewPanelPayload(
                resultText: "Result from A",
                originalText: "Original transcript",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                selectedPromptTitle: "VoicePi Default",
                availablePrompts: prompts
            )
        )
        var promptSelectionState = ResultReviewPanelPromptSelectionState(payload: initialPayload)
        promptSelectionState.setPendingPromptSelection(to: "user.meeting", options: prompts)

        let relabeledPayload = try #require(
            ResultReviewPanelPayload(
                resultText: "Result from A",
                originalText: "Original transcript",
                selectedPromptPresetID: "user.meeting",
                selectedPromptTitle: "Meeting Notes",
                availablePrompts: prompts
            )
        )
        promptSelectionState.applyPayload(relabeledPayload)

        let presentationState = ResultReviewPanelPresentationState(
            payload: relabeledPayload,
            promptSelectionState: promptSelectionState
        )
        #expect(presentationState.selectedPromptPresetID == PromptPreset.builtInDefaultID)
        #expect(presentationState.selectedPromptTitle == "VoicePi Default")
        #expect(presentationState.promptPickerSelectedPresetID == "user.meeting")
        #expect(presentationState.promptSectionTitle == "Prompt (Pending)")
    }

    @Test
    func promptSelectionStateCommitsPendingPromptAfterNewResultArrives() throws {
        let prompts: [ResultReviewPanelPromptOption] = [
            .init(presetID: PromptPreset.builtInDefaultID, title: "VoicePi Default"),
            .init(presetID: "user.meeting", title: "Meeting Notes")
        ]
        let initialPayload = try #require(
            ResultReviewPanelPayload(
                resultText: "Result from A",
                originalText: "Original transcript",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                selectedPromptTitle: "VoicePi Default",
                availablePrompts: prompts
            )
        )
        var promptSelectionState = ResultReviewPanelPromptSelectionState(payload: initialPayload)
        promptSelectionState.setPendingPromptSelection(to: "user.meeting", options: prompts)
        _ = promptSelectionState.consumePendingPromptPresetIDForRegenerate()

        let regeneratingPayload = try #require(
            ResultReviewPanelPayload(
                resultText: "Result from A",
                originalText: "Original transcript",
                selectedPromptPresetID: "user.meeting",
                selectedPromptTitle: "Meeting Notes",
                availablePrompts: prompts,
                isRegenerating: true
            )
        )
        promptSelectionState.applyPayload(regeneratingPayload)

        let finalPayload = try #require(
            ResultReviewPanelPayload(
                resultText: "Result from B",
                originalText: "Original transcript",
                selectedPromptPresetID: "user.meeting",
                selectedPromptTitle: "Meeting Notes",
                availablePrompts: prompts
            )
        )
        promptSelectionState.applyPayload(finalPayload)
        let presentationState = ResultReviewPanelPresentationState(
            payload: finalPayload,
            promptSelectionState: promptSelectionState
        )
        #expect(presentationState.selectedPromptPresetID == "user.meeting")
        #expect(presentationState.selectedPromptTitle == "Meeting Notes")
        #expect(presentationState.promptPickerSelectedPresetID == "user.meeting")
        #expect(presentationState.promptSectionTitle == "Prompt")
    }

    @Test
    func promptSelectionStateKeepsPendingSelectionAfterFailedRegenerate() throws {
        let prompts: [ResultReviewPanelPromptOption] = [
            .init(presetID: PromptPreset.builtInDefaultID, title: "VoicePi Default"),
            .init(presetID: "user.meeting", title: "Meeting Notes")
        ]
        let initialPayload = try #require(
            ResultReviewPanelPayload(
                resultText: "Result from A",
                originalText: "Original transcript",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                selectedPromptTitle: "VoicePi Default",
                availablePrompts: prompts
            )
        )
        var promptSelectionState = ResultReviewPanelPromptSelectionState(payload: initialPayload)
        promptSelectionState.setPendingPromptSelection(to: "user.meeting", options: prompts)
        _ = promptSelectionState.consumePendingPromptPresetIDForRegenerate()

        let failedPayload = try #require(
            ResultReviewPanelPayload(
                resultText: "Result from A",
                originalText: "Original transcript",
                selectedPromptPresetID: "user.meeting",
                selectedPromptTitle: "Meeting Notes",
                availablePrompts: prompts
            )
        )
        promptSelectionState.applyPayload(failedPayload)
        let presentationState = ResultReviewPanelPresentationState(
            payload: failedPayload,
            promptSelectionState: promptSelectionState
        )
        #expect(presentationState.selectedPromptPresetID == PromptPreset.builtInDefaultID)
        #expect(presentationState.selectedPromptTitle == "VoicePi Default")
        #expect(presentationState.promptPickerSelectedPresetID == "user.meeting")
        #expect(presentationState.promptSectionTitle == "Prompt (Pending)")
    }
}
