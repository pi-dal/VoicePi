import Testing
@testable import VoicePi

struct FloatingPanelControllerTests {
    @Test
    func refiningBannerStaysCompactForShortStatusText() {
        let width = FloatingPanelSupport.bannerPreferredWidth(
            for: .refining,
            transcript: FloatingPanelSupport.displayedTranscript(for: .refining, transcript: "")
        )

        #expect(width >= 260)
        #expect(width < 320)
    }

    @Test
    func refiningBannerExpandsForLongStatusText() {
        let shortWidth = FloatingPanelSupport.bannerPreferredWidth(
            for: .refining,
            transcript: "Refining..."
        )
        let longWidth = FloatingPanelSupport.bannerPreferredWidth(
            for: .refining,
            transcript: "Refining with Customer Success Follow-up Email"
        )

        #expect(longWidth > shortWidth)
    }

    @Test
    func displayedTranscriptUsesPhaseSpecificFallbackCopy() {
        #expect(FloatingPanelSupport.displayedTranscript(for: .recording, transcript: "   ") == "正在聆听…")
        #expect(FloatingPanelSupport.displayedTranscript(for: .refining, transcript: "\n") == "Refining...")
        #expect(FloatingPanelSupport.displayedTranscript(for: .modeSwitch, transcript: "Translate") == "Translate")
    }

    @Test
    func sourcePreviewIsSuppressedInFloatingBanner() {
        #expect(FloatingPanelSupport.displayedSourcePreview("  selected source  ") == nil)
        #expect(FloatingPanelSupport.displayedSourcePreview(" \n\t ") == nil)
    }

    @Test
    func bannerHeightIgnoresSourcePreview() {
        #expect(FloatingPanelSupport.bannerPreferredHeight(sourcePreview: nil) == 56)
        #expect(FloatingPanelSupport.bannerPreferredHeight(sourcePreview: "reference text") == 56)
    }

    @Test
    func transcriptPresentationStateSkipsLayoutWorkForRepeatedDisplayedText() {
        var state = FloatingPanelTranscriptPresentationState()

        let first = state.prepareUpdate(for: .recording, transcript: "hello")
        let second = state.prepareUpdate(for: .recording, transcript: "hello")

        #expect(first.requiresLayoutRecalculation)
        #expect(!second.requiresLayoutRecalculation)
        #expect(second.displayedText == "hello")
    }

    @Test
    func transcriptPresentationStateTreatsRecordingPlaceholderAsStableText() {
        var state = FloatingPanelTranscriptPresentationState()

        let first = state.prepareUpdate(for: .recording, transcript: "   ")
        let second = state.prepareUpdate(for: .recording, transcript: "\n")

        #expect(first.displayedText == "正在聆听…")
        #expect(!second.requiresLayoutRecalculation)
    }

    @Test
    func transcriptPresentationStateInvalidatesLayoutWhenPhaseChanges() {
        var state = FloatingPanelTranscriptPresentationState()

        _ = state.prepareUpdate(for: .recording, transcript: "hello")
        let refining = state.prepareDisplayedText("hello", for: .refining)

        #expect(refining.requiresLayoutRecalculation)
        #expect(refining.displayedText == "hello")
    }
}
