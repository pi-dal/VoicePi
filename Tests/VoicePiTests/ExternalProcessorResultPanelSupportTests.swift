import Testing
@testable import VoicePi

struct ExternalProcessorResultPanelSupportTests {
    @Test
    func payloadSanitizesOriginalAndResultText() throws {
        let payload = try #require(
            ExternalProcessorResultPanelPayload(
                resultText: "  Final answer  ",
                originalText: "  Original prompt  "
            )
        )

        #expect(payload.resultText == "Final answer")
        #expect(payload.originalText == "Original prompt")
        #expect(payload.displayText == "Final answer")
    }

    @Test
    func payloadBuildsCompactOriginalPreviewText() throws {
        let payload = try #require(
            ExternalProcessorResultPanelPayload(
                resultText: "Final answer",
                originalText: " First line\n\nSecond line with extra spacing and enough trailing detail to truncate cleanly for the compact source row. "
            )
        )

        #expect(payload.originalPreviewText == "First line Second line with extra spacing and enough trailing detail to truncate cleanly for the compact source row.")
    }

    @Test
    func presentationStateUsesBadgeInsteadOfLongUnchangedSectionTitle() throws {
        let payload = try #require(
            ExternalProcessorResultPanelPayload(
                resultText: "Same answer",
                originalText: "Same answer"
            )
        )

        let state = ExternalProcessorResultPanelPresentationState(payload: payload)
        #expect(state.resultSectionTitle == "Result")
        #expect(state.resultStatusText == "Unchanged")
    }
}
