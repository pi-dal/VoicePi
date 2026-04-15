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
}
