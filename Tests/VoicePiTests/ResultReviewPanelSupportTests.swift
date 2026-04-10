import AppKit
import Testing
@testable import VoicePi

struct ResultReviewPanelSupportTests {
    @Test
    func payloadRejectsEmptyTextAndTrimsWhitespace() throws {
        #expect(ResultReviewPanelPayload(text: " \n\t ") == nil)

        let payload = try #require(ResultReviewPanelPayload(text: "  \nReviewed text\n  "))
        #expect(payload.resultText == "Reviewed text")
        #expect(payload.promptText.isEmpty)
        #expect(payload.displayText == "Reviewed text")
        #expect(payload.isLikelyUnchangedFromSource == false)
    }

    @Test
    func payloadFlagsWhenOutputIsUnchangedFromSource() throws {
        let payload = try #require(
            ResultReviewPanelPayload(
                text: "  reviewed text  ",
                sourceText: "reviewed text"
            )
        )
        #expect(payload.isLikelyUnchangedFromSource)
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
        let payload = try #require(ResultReviewPanelPayload(text: "Needs review"))
        let state = ResultReviewPanelPresentationState(payload: payload)

        #expect(state.titleText == "VoicePi")
        #expect(state.promptSectionTitle == "Prompt")
        #expect(state.outputSectionTitle == "Answer")
        #expect(state.promptCopyButtonTitle == "Copy")
        #expect(state.outputCopyButtonTitle == "Copy")
        #expect(state.promptCopyText.isEmpty)
        #expect(state.outputCopyText == "Needs review")
        #expect(state.promptDisplayText == "No prompt captured.")
        #expect(state.outputDisplayText == "Needs review")
    }

    @Test
    func presentationStateShowsSanitizedPromptWhenAvailable() throws {
        let payload = try #require(ResultReviewPanelPayload(text: "Same", sourceText: "  Prompt input  "))
        let state = ResultReviewPanelPresentationState(payload: payload)
        #expect(state.promptDisplayText == "Prompt input")
    }
}
