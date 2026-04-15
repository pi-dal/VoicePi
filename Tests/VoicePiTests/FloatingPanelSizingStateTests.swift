import Testing
@testable import VoicePi

struct FloatingPanelSizingStateTests {
    @Test
    func recordingWidthLocksAtSessionStart() {
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

        #expect(expandedAttempt.width == initial.width)
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
