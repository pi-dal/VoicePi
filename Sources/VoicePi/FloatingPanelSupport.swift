import AppKit

struct FloatingPanelSizingState: Equatable {
    private(set) var lockedRecordingWidth: CGFloat?

    mutating func preferredSize(
        for phase: FloatingPanelController.Phase,
        transcript: String,
        sourcePreview: String?
    ) -> CGSize {
        switch phase {
        case .recording:
            let computedWidth = FloatingPanelSupport.bannerPreferredWidth(
                for: phase,
                transcript: transcript,
                sourcePreview: sourcePreview
            )
            let width = lockedRecordingWidth ?? computedWidth
            lockedRecordingWidth = width
            return CGSize(
                width: width,
                height: FloatingPanelSupport.bannerPreferredHeight(sourcePreview: sourcePreview)
            )
        case .refining:
            lockedRecordingWidth = nil
            return CGSize(
                width: FloatingPanelSupport.bannerPreferredWidth(
                    for: phase,
                    transcript: transcript,
                    sourcePreview: sourcePreview
                ),
                height: FloatingPanelSupport.bannerPreferredHeight(sourcePreview: sourcePreview)
            )
        case .modeSwitch:
            lockedRecordingWidth = nil
            return CGSize(width: 452, height: 136)
        }
    }
}

enum FloatingPanelSupport {
    static let compactBannerWidth: CGFloat = 260
    static let maximumBannerWidth: CGFloat = 660
    static let compactBannerHeight: CGFloat = 56
    static let bannerHorizontalInset: CGFloat = 18
    static let bannerIndicatorWidth: CGFloat = 44
    static let recordingIndicatorSpacing: CGFloat = 14
    static let refiningIndicatorSpacing: CGFloat = 22

    static func displayedTranscript(
        for phase: FloatingPanelController.Phase,
        transcript: String
    ) -> String {
        FloatingPanelTranscriptPresentationState.displayedTranscript(
            for: .init(phase),
            transcript: transcript
        )
    }

    static func bannerPreferredWidth(
        for phase: FloatingPanelController.Phase,
        transcript: String,
        sourcePreview: String? = nil,
        font: NSFont = .systemFont(ofSize: 15, weight: .medium)
    ) -> CGFloat {
        let elasticTextWidth = max(
            160,
            min(
                maximumVisibleTranscriptWidth(for: phase),
                measuredTranscriptWidth(for: transcript, font: font) + 8
            )
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

    static func displayedSourcePreview(_ sourcePreview: String?) -> String? {
        _ = sourcePreview
        return nil
    }

    static func bannerPreferredHeight(sourcePreview: String?) -> CGFloat {
        _ = sourcePreview
        return compactBannerHeight
    }
}

extension FloatingPanelTranscriptPresentationState.Phase {
    init(_ phase: FloatingPanelController.Phase) {
        switch phase {
        case .recording:
            self = .recording
        case .refining:
            self = .refining
        case .modeSwitch:
            self = .modeSwitch
        }
    }
}
