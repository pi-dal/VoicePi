import AppKit
import Foundation

struct ResultReviewPanelPayload: Equatable {
    let resultText: String
    let displayText: String

    init?(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        self.resultText = trimmed
        self.displayText = trimmed
    }
}

enum ResultReviewPanelLayout {
    static func frame(for visibleFrame: NSRect) -> NSRect {
        NSRect(
            x: visibleFrame.origin.x + (visibleFrame.size.width / 3.0),
            y: visibleFrame.origin.y + (visibleFrame.size.height / 3.0),
            width: visibleFrame.size.width / 3.0,
            height: visibleFrame.size.height / 3.0
        )
    }
}

struct ResultReviewPanelPresentationState: Equatable {
    let titleText: String
    let descriptionText: String
    let insertButtonTitle: String
    let copyButtonTitle: String
    let retryButtonTitle: String
    let dismissButtonTitle: String
    let displayText: String

    init(payload: ResultReviewPanelPayload) {
        self.titleText = "Review Result"
        self.descriptionText = "Review the output before inserting it back into the target."
        self.insertButtonTitle = "Insert"
        self.copyButtonTitle = "Copy"
        self.retryButtonTitle = "Retry"
        self.dismissButtonTitle = "Dismiss"
        self.displayText = payload.displayText
    }
}
