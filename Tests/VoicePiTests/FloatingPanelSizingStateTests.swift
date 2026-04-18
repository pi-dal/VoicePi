import Testing
@testable import VoicePi

struct FloatingPanelSizingStateTests {
    @Test
    func recordingWidthExpandsToFitLongerTranscriptWithinSession() {
        var state = FloatingPanelSizingState()

        let initial = state.preferredSize(
            for: .recording,
            transcript: "",
            sourcePreview: nil
        )
        let expandedAttempt = state.preferredSize(
            for: .recording,
            transcript: "A much longer realtime partial transcript that would otherwise resize the panel",
            sourcePreview: nil
        )

        #expect(expandedAttempt.width > initial.width)
    }

    @Test
    func recordingWidthDoesNotShrinkAfterGrowingWithinSession() {
        var state = FloatingPanelSizingState()

        let expanded = state.preferredSize(
            for: .recording,
            transcript: "A much longer realtime partial transcript that should establish the session width",
            sourcePreview: nil
        )
        let shorterFollowUp = state.preferredSize(
            for: .recording,
            transcript: "short",
            sourcePreview: nil
        )

        #expect(shorterFollowUp.width == expanded.width)
    }

    @Test
    func recordingWidthStopsGrowingAtMaximumBannerWidth() {
        var state = FloatingPanelSizingState()

        let capped = state.preferredSize(
            for: .recording,
            transcript: String(repeating: "A much longer realtime partial transcript ", count: 40),
            sourcePreview: nil
        )

        #expect(capped.width == FloatingPanelSupport.maximumBannerWidth)
    }

    @Test
    func refiningWidthUnlocksAndExpandsForLongerStatus() {
        var state = FloatingPanelSizingState()

        _ = state.preferredSize(
            for: .recording,
            transcript: "",
            sourcePreview: nil
        )
        let refining = state.preferredSize(
            for: .refining,
            transcript: "Refining with Customer Success Follow-up Email",
            sourcePreview: nil
        )

        #expect(refining.width > FloatingPanelSupport.compactBannerWidth)
    }
}
