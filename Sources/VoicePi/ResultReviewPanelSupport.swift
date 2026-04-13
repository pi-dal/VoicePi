import AppKit
import Foundation

struct ResultReviewPanelPromptOption: Equatable {
    let presetID: String
    let title: String

    init(presetID: String, title: String) {
        self.presetID = presetID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ResultReviewPanelPayload: Equatable {
    private static let regenerationStatusCharacterLimit = 96

    let resultText: String
    let promptText: String
    let displayText: String
    let isLikelyUnchangedFromSource: Bool
    let selectedPromptPresetID: String
    let selectedPromptTitle: String
    let availablePrompts: [ResultReviewPanelPromptOption]
    let isRegenerating: Bool
    let regenerationStatusText: String?

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
        let defaultPrompt = ResultReviewPanelPromptOption(
            presetID: PromptPreset.builtInDefaultID,
            title: PromptPreset.builtInDefault.title
        )
        self.selectedPromptPresetID = defaultPrompt.presetID
        self.selectedPromptTitle = defaultPrompt.title
        self.availablePrompts = [defaultPrompt]
        self.isRegenerating = false
        self.regenerationStatusText = nil
    }

    init?(
        resultText: String,
        promptText: String? = nil,
        selectedPromptPresetID: String,
        selectedPromptTitle: String,
        availablePrompts: [ResultReviewPanelPromptOption],
        isRegenerating: Bool = false,
        regenerationStatusText: String? = nil
    ) {
        let sanitizedResult = ExternalProcessorOutputSanitizer.sanitize(resultText)
        guard !sanitizedResult.isEmpty else {
            return nil
        }

        let sanitizedPromptOptions = availablePrompts.map {
            ResultReviewPanelPromptOption(
                presetID: $0.presetID,
                title: $0.title
            )
        }
        let sanitizedPromptText = ExternalProcessorOutputSanitizer.sanitize(promptText ?? "")
        let normalizedSelectedPresetID = selectedPromptPresetID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSelectedPromptTitle = selectedPromptTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedPrompt: ResultReviewPanelPromptOption
        if let selectedOption = sanitizedPromptOptions.first(where: { $0.presetID == normalizedSelectedPresetID }) {
            resolvedPrompt = selectedOption
        } else if let firstOption = sanitizedPromptOptions.first {
            resolvedPrompt = firstOption
        } else {
            resolvedPrompt = ResultReviewPanelPromptOption(
                presetID: normalizedSelectedPresetID.isEmpty
                    ? PromptPreset.builtInDefaultID
                    : normalizedSelectedPresetID,
                title: normalizedSelectedPromptTitle.isEmpty
                    ? PromptPreset.builtInDefault.title
                    : normalizedSelectedPromptTitle
            )
        }

        self.resultText = sanitizedResult
        self.promptText = sanitizedPromptText.isEmpty ? resolvedPrompt.title : sanitizedPromptText
        self.displayText = sanitizedResult
        self.isLikelyUnchangedFromSource = false
        self.selectedPromptPresetID = resolvedPrompt.presetID
        self.selectedPromptTitle = resolvedPrompt.title
        self.availablePrompts = sanitizedPromptOptions.isEmpty ? [resolvedPrompt] : sanitizedPromptOptions
        self.isRegenerating = isRegenerating
        self.regenerationStatusText = isRegenerating
            ? Self.truncatedRegenerationStatusText(regenerationStatusText)
            : nil
    }

    private static func truncatedRegenerationStatusText(_ rawText: String?) -> String? {
        guard let rawText else {
            return nil
        }
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        guard trimmed.count > regenerationStatusCharacterLimit else {
            return trimmed
        }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: regenerationStatusCharacterLimit)
        return String(trimmed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
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
    let selectedPromptPresetID: String
    let selectedPromptTitle: String
    let regenerateButtonTitle: String
    let isRegenerateEnabled: Bool
    let insertButtonTitle: String
    let isInsertEnabled: Bool
    let isPromptPickerEnabled: Bool
    let footerStatusText: String
    let showsFooterProgress: Bool

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
        self.selectedPromptPresetID = payload.selectedPromptPresetID
        self.selectedPromptTitle = payload.selectedPromptTitle
        self.regenerateButtonTitle = payload.isRegenerating ? "Regenerating…" : "Regenerate"
        self.isRegenerateEnabled = !payload.isRegenerating
        self.insertButtonTitle = "Insert"
        self.isInsertEnabled = !payload.isRegenerating && !payload.resultText.isEmpty
        self.isPromptPickerEnabled = !payload.isRegenerating && payload.availablePrompts.count > 1
        self.footerStatusText = payload.isRegenerating
            ? (payload.regenerationStatusText ?? "Regenerating…")
            : "Press Enter to insert."
        self.showsFooterProgress = payload.isRegenerating
    }
}
