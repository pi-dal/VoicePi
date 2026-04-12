import AppKit

enum FloatingPanelSupport {
    static let compactBannerWidth: CGFloat = 260
    static let maximumBannerWidth: CGFloat = 660
    static let bannerHorizontalInset: CGFloat = 18
    static let bannerIndicatorWidth: CGFloat = 44
    static let recordingIndicatorSpacing: CGFloat = 14
    static let refiningIndicatorSpacing: CGFloat = 22

    static func displayedTranscript(
        for phase: FloatingPanelController.Phase,
        transcript: String
    ) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        switch phase {
        case .recording:
            return trimmed.isEmpty ? "正在聆听…" : transcript
        case .refining:
            return trimmed.isEmpty ? "Refining..." : transcript
        case .modeSwitch:
            return transcript
        }
    }

    static func bannerPreferredWidth(
        for phase: FloatingPanelController.Phase,
        transcript: String,
        font: NSFont = .systemFont(ofSize: 15, weight: .medium)
    ) -> CGFloat {
        let elasticTextWidth = max(
            160,
            min(maximumVisibleTranscriptWidth(for: phase), measuredTranscriptWidth(for: transcript, font: font) + 8)
        )
        let indicatorSpacing = phase == .refining ? refiningIndicatorSpacing : recordingIndicatorSpacing
        let computedWidth =
            bannerHorizontalInset + bannerIndicatorWidth + indicatorSpacing + elasticTextWidth + bannerHorizontalInset
        return max(compactBannerWidth, computedWidth)
    }

    static func maximumVisibleTranscriptWidth(for phase: FloatingPanelController.Phase) -> CGFloat {
        let indicatorSpacing = phase == .refining ? refiningIndicatorSpacing : recordingIndicatorSpacing
        return maximumBannerWidth - bannerHorizontalInset - bannerIndicatorWidth - indicatorSpacing - bannerHorizontalInset
    }

    static func measuredTranscriptWidth(
        for transcript: String,
        font: NSFont = .systemFont(ofSize: 15, weight: .medium)
    ) -> CGFloat {
        let text = transcript as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil(text.size(withAttributes: attributes).width)
    }
}
