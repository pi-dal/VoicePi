import AppKit
import Foundation

struct ExternalProcessorResultPanelPayload: Equatable {
    static let previewCharacterLimit = 120

    let originalText: String
    let originalPreviewText: String
    let resultText: String
    let displayText: String
    let isLikelyUnchangedFromSource: Bool

    init?(resultText: String, originalText: String) {
        let sanitizedOriginal = ExternalProcessorOutputSanitizer.sanitize(originalText)
        guard !sanitizedOriginal.isEmpty else {
            return nil
        }

        let sanitizedResult = ExternalProcessorOutputSanitizer.sanitize(resultText)
        guard !sanitizedResult.isEmpty else {
            return nil
        }

        self.originalText = sanitizedOriginal
        self.originalPreviewText = Self.previewText(
            from: sanitizedOriginal,
            characterLimit: Self.previewCharacterLimit
        )
        self.resultText = sanitizedResult
        self.displayText = sanitizedResult
        self.isLikelyUnchangedFromSource = ExternalProcessorOutputSanitizer.isSemanticallyUnchanged(
            sanitizedResult,
            comparedTo: sanitizedOriginal
        )
    }

    private static func previewText(
        from text: String,
        characterLimit: Int
    ) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > characterLimit else {
            return collapsed
        }
        return String(collapsed.prefix(characterLimit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

enum ExternalProcessorResultPanelLayout {
    static func frame(for visibleFrame: NSRect) -> NSRect {
        let width = max(420, min(visibleFrame.width / 3.0, 680))
        let minHeight = visibleFrame.height / 3.0
        let maxHeight = visibleFrame.height / 2.0
        let height = min(max(visibleFrame.height * 0.42, minHeight), maxHeight)
        return NSRect(
            x: round(visibleFrame.midX - width / 2),
            y: round(visibleFrame.midY - height / 2),
            width: width,
            height: height
        )
    }
}

struct ExternalProcessorResultPanelPresentationState: Equatable {
    let titleText: String
    let originalSectionTitle: String
    let resultSectionTitle: String
    let resultStatusText: String
    let originalCopyButtonTitle: String
    let resultCopyButtonTitle: String
    let retryButtonTitle: String
    let insertButtonTitle: String
    let interactionHintText: String
    let originalCopyText: String
    let originalPreviewText: String
    let resultCopyText: String
    let resultDisplayText: String

    init(payload: ExternalProcessorResultPanelPayload) {
        self.titleText = "VoicePi"
        self.originalSectionTitle = "Source"
        self.resultSectionTitle = "Result"
        self.resultStatusText = payload.isLikelyUnchangedFromSource ? "Unchanged" : ""
        self.originalCopyButtonTitle = "Copy Source"
        self.resultCopyButtonTitle = "Copy Result"
        self.retryButtonTitle = "Retry"
        self.insertButtonTitle = "Insert"
        self.interactionHintText = "Press Enter to insert"
        self.originalCopyText = payload.originalText
        self.originalPreviewText = payload.originalPreviewText
        self.resultCopyText = payload.resultText
        self.resultDisplayText = payload.displayText
    }
}
