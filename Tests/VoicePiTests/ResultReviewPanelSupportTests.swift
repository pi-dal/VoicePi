import AppKit
import Testing
@testable import VoicePi

struct ResultReviewPanelSupportTests {
    @Test
    func payloadRejectsEmptyTextAndTrimsWhitespace() throws {
        #expect(ResultReviewPanelPayload(text: " \n\t ") == nil)

        let payload = try #require(ResultReviewPanelPayload(text: "  \nReviewed text\n  "))
        #expect(payload.resultText == "Reviewed text")
        #expect(payload.displayText == "Reviewed text")
    }

    @Test
    func layoutCentersPanelAtOneThirdOfVisibleFrame() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = ResultReviewPanelLayout.frame(for: visibleFrame)

        #expect(frame.size.width == 480)
        #expect(frame.size.height == 300)
        #expect(frame.origin.x == 480)
        #expect(frame.origin.y == 300)
    }

    @Test
    func presentationStateExposesExpectedTitles() throws {
        let payload = try #require(ResultReviewPanelPayload(text: "Needs review"))
        let state = ResultReviewPanelPresentationState(payload: payload)

        #expect(state.titleText == "Review Result")
        #expect(state.descriptionText == "Review the output before inserting it back into the target.")
        #expect(state.insertButtonTitle == "Insert")
        #expect(state.copyButtonTitle == "Copy")
        #expect(state.retryButtonTitle == "Retry")
        #expect(state.dismissButtonTitle == "Dismiss")
        #expect(state.displayText == "Needs review")
    }
}
