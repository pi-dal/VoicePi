import AppKit
import Foundation

extension StatusBarController {
    struct PromptBindingCapture {
        let kind: PromptBindingKind
        let value: String

        var summaryTitle: String {
            switch kind {
            case .appBundleID:
                return "Captured App: \(value)"
            case .websiteHost:
                return "Captured Website: \(value)"
            }
        }

        var bindingSubject: String {
            switch kind {
            case .appBundleID:
                return "app \(value)"
            case .websiteHost:
                return "site \(value)"
            }
        }
    }

    enum AboutOverviewRow: Equatable {
        case repository
        case builtBy
        case inspiredBy
    }

    static let aboutOverviewRowOrder: [AboutOverviewRow] = [
        .builtBy,
        .inspiredBy
    ]

    static let primaryMenuActionTitles = [
        "Language",
        "Text Processing",
        "Processors…",
        "Refinement Prompt",
        "Check for Updates…",
        "Settings…",
        "Quit VoicePi"
    ]

    static let strictModeMenuItemTitle = "Strict Mode"

    static let refinementPromptCaptureActionTitles = [
        "Capture Frontmost App",
        "Capture Current Website"
    ]

    static let promptBindingPickerActionTitles = [
        "Bind",
        "New Prompt…",
        "Cancel"
    ]

    static func refinementPromptCaptureActionsEnabled(
        mode: PostProcessingMode,
        isPromptEditorPresented: Bool
    ) -> Bool {
        mode == .refinement && !isPromptEditorPresented
    }

    static func disabledRefinementPromptTitle(_ title: String) -> NSAttributedString {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 1
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        return NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.disabledControlTextColor,
                .shadow: shadow
            ]
        )
    }
}
