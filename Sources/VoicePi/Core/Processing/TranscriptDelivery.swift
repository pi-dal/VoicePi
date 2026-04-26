import Foundation

enum EditableTextTargetInspection: Equatable {
    case editable
    case notEditable
    case unavailable
}

enum TranscriptDelivery {
    enum Route: Equatable {
        case emptyResult
        case injectableTarget
        case fallbackPanel
    }

    static func route(
        for text: String,
        targetInspection: EditableTextTargetInspection
    ) -> Route {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .emptyResult
        }

        switch targetInspection {
        case .editable:
            return .injectableTarget
        case .notEditable, .unavailable:
            return .fallbackPanel
        }
    }
}
