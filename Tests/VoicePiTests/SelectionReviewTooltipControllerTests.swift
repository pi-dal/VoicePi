import Testing
@testable import VoicePi

struct SelectionReviewTooltipControllerTests {
    @Test
    func payloadDefaultsToReviewActionTitle() {
        let payload = SelectionReviewTooltipPayload()
        #expect(payload.regenerateButtonTitle == "Review")
    }

    @Test
    func payloadTrimsAndTruncatesDisplayText() {
        let payload = SelectionReviewTooltipPayload(
            titleText: "  \(String(repeating: "T", count: 80))  ",
            summaryText: "  \(String(repeating: "S", count: 120))  ",
            regenerateButtonTitle: "  \(String(repeating: "R", count: 40))  ",
            dismissButtonTitle: "  \(String(repeating: "D", count: 40))  "
        )

        #expect(payload.titleText.hasSuffix("…"))
        #expect(payload.titleText.count == 57)
        #expect(payload.summaryText.hasSuffix("…"))
        #expect(payload.summaryText.count == 85)
        #expect(payload.regenerateButtonTitle.hasSuffix("…"))
        #expect(payload.regenerateButtonTitle.count == 29)
        #expect(payload.dismissButtonTitle.hasSuffix("…"))
        #expect(payload.dismissButtonTitle.count == 29)
    }
}
