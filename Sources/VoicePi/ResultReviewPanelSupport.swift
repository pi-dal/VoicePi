import AppKit
import Foundation

struct ResultReviewPanelPayload: Equatable {
    let resultText: String
    let promptText: String
    let displayText: String
    let isLikelyUnchangedFromSource: Bool

    init?(text: String, sourceText: String? = nil) {
        let sanitizedResult = ExternalProcessorOutputSanitizer.sanitize(text)
        guard !sanitizedResult.isEmpty else {
            return nil
        }

        let sanitizedPrompt = sourceText.map(ExternalProcessorOutputSanitizer.sanitize) ?? ""
        self.resultText = sanitizedResult
        self.promptText = sanitizedPrompt
        self.displayText = sanitizedResult
        self.isLikelyUnchangedFromSource = !sanitizedPrompt.isEmpty
            && ExternalProcessorOutputSanitizer.isSemanticallyUnchanged(
                sanitizedResult,
                comparedTo: sanitizedPrompt
            )
    }
}

enum ResultReviewPanelLayout {
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

struct ResultReviewPanelPresentationState: Equatable {
    let titleText: String
    let promptSectionTitle: String
    let outputSectionTitle: String
    let promptCopyButtonTitle: String
    let outputCopyButtonTitle: String
    let promptCopyText: String
    let outputCopyText: String
    let promptDisplayText: String
    let outputDisplayText: String

    init(payload: ResultReviewPanelPayload) {
        self.titleText = "VoicePi"
        self.promptSectionTitle = "Prompt"
        self.outputSectionTitle = "Answer"
        self.promptCopyButtonTitle = "Copy"
        self.outputCopyButtonTitle = "Copy"
        self.promptCopyText = payload.promptText
        self.outputCopyText = payload.resultText
        self.promptDisplayText = payload.promptText.isEmpty ? "No prompt captured." : payload.promptText
        self.outputDisplayText = payload.displayText
    }
}
