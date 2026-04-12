import AppKit
import Foundation

struct ResultReviewPanelPromptOption: Equatable {
    let presetID: String
    let title: String

    init(presetID: String, title: String) {
        let trimmedID = presetID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.presetID = trimmedID.isEmpty ? PromptPreset.builtInDefaultID : trimmedID

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = trimmedTitle.isEmpty ? "Untitled Prompt" : trimmedTitle
    }
}

struct ResultReviewPanelPayload: Equatable {
    let originalText: String
    let resultText: String
    let displayText: String
    let selectedPromptPresetID: String
    let selectedPromptTitle: String
    let availablePrompts: [ResultReviewPanelPromptOption]
    let isRegenerating: Bool

    init?(
        resultText: String,
        originalText: String,
        selectedPromptPresetID: String,
        selectedPromptTitle: String,
        availablePrompts: [ResultReviewPanelPromptOption],
        isRegenerating: Bool = false
    ) {
        let sanitizedOriginal = ExternalProcessorOutputSanitizer.sanitize(originalText)
        guard !sanitizedOriginal.isEmpty else {
            return nil
        }
        let sanitizedResult = ExternalProcessorOutputSanitizer.sanitize(resultText)
        guard !sanitizedResult.isEmpty else {
            return nil
        }

        let normalizedPromptOptions = ResultReviewPanelPayload.normalizedPromptOptions(availablePrompts)
        guard let fallbackPromptOption = normalizedPromptOptions.first else {
            return nil
        }
        let normalizedSelectedPromptID = ResultReviewPanelPayload.normalizedPromptPresetID(selectedPromptPresetID)
        let matchedPromptOption = normalizedPromptOptions.first(where: {
            $0.presetID == normalizedSelectedPromptID
        })
        let effectivePromptOption = matchedPromptOption ?? fallbackPromptOption
        let sanitizedPromptTitle = selectedPromptTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        self.originalText = sanitizedOriginal
        self.resultText = sanitizedResult
        self.displayText = sanitizedResult
        self.selectedPromptPresetID = effectivePromptOption.presetID
        self.selectedPromptTitle = (matchedPromptOption != nil && !sanitizedPromptTitle.isEmpty)
            ? sanitizedPromptTitle
            : effectivePromptOption.title
        self.availablePrompts = normalizedPromptOptions
        self.isRegenerating = isRegenerating
    }

    private static func normalizedPromptPresetID(_ presetID: String) -> String {
        let trimmed = presetID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? PromptPreset.builtInDefaultID : trimmed
    }

    private static func normalizedPromptOptions(
        _ options: [ResultReviewPanelPromptOption]
    ) -> [ResultReviewPanelPromptOption] {
        var normalized: [ResultReviewPanelPromptOption] = []
        var seenPresetIDs: Set<String> = []
        for option in options {
            guard seenPresetIDs.insert(option.presetID).inserted else { continue }
            normalized.append(option)
        }
        if normalized.isEmpty {
            normalized.append(
                ResultReviewPanelPromptOption(
                    presetID: PromptPreset.builtInDefaultID,
                    title: PromptPreset.builtInDefault.title
                )
            )
        }
        return normalized
    }
}

struct ResultReviewPanelPromptSelectionState: Equatable {
    private(set) var appliedPromptPresetID: String
    private(set) var appliedPromptTitle: String
    private(set) var appliedResultText: String
    private(set) var pendingPromptPresetID: String?
    private(set) var pendingPromptTitle: String?

    init(payload: ResultReviewPanelPayload) {
        self.appliedPromptPresetID = payload.selectedPromptPresetID
        self.appliedPromptTitle = payload.selectedPromptTitle
        self.appliedResultText = payload.resultText
        self.pendingPromptPresetID = nil
        self.pendingPromptTitle = nil
    }

    var hasPendingPromptSelection: Bool {
        pendingPromptPresetID != nil
    }

    var promptPickerSelectedPresetID: String {
        pendingPromptPresetID ?? appliedPromptPresetID
    }

    mutating func setPendingPromptSelection(
        to requestedPresetID: String,
        options: [ResultReviewPanelPromptOption]
    ) {
        guard let resolvedOption = resolvedOption(for: requestedPresetID, options: options) else {
            pendingPromptPresetID = nil
            pendingPromptTitle = nil
            return
        }
        guard resolvedOption.presetID != appliedPromptPresetID else {
            pendingPromptPresetID = nil
            pendingPromptTitle = nil
            return
        }
        pendingPromptPresetID = resolvedOption.presetID
        pendingPromptTitle = resolvedOption.title
    }

    mutating func consumePendingPromptPresetIDForRegenerate() -> String? {
        pendingPromptPresetID
    }

    mutating func applyPayload(_ payload: ResultReviewPanelPayload) {
        let didResultChange = payload.resultText != appliedResultText
        if didResultChange {
            appliedResultText = payload.resultText
            appliedPromptPresetID = payload.selectedPromptPresetID
            appliedPromptTitle = payload.selectedPromptTitle
            if pendingPromptPresetID == appliedPromptPresetID {
                pendingPromptPresetID = nil
                pendingPromptTitle = nil
            }
            return
        }

        guard pendingPromptPresetID != nil else {
            appliedResultText = payload.resultText
            appliedPromptPresetID = payload.selectedPromptPresetID
            appliedPromptTitle = payload.selectedPromptTitle
            return
        }
    }

    private func resolvedOption(
        for requestedPresetID: String,
        options: [ResultReviewPanelPromptOption]
    ) -> ResultReviewPanelPromptOption? {
        let normalizedRequestedID = requestedPresetID.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveRequestedID = normalizedRequestedID.isEmpty ? PromptPreset.builtInDefaultID : normalizedRequestedID
        if let matched = options.first(where: { $0.presetID == effectiveRequestedID }) {
            return matched
        }
        return options.first
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
    let originalSectionTitle: String
    let promptSectionTitle: String
    let outputSectionTitle: String
    let originalDisplayText: String
    let outputCopyButtonTitle: String
    let outputCopyText: String
    let outputDisplayText: String
    let selectedPromptPresetID: String
    let selectedPromptTitle: String
    let promptPickerSelectedPresetID: String
    let promptOptions: [ResultReviewPanelPromptOption]
    let regenerateButtonTitle: String
    let isRegenerateEnabled: Bool
    let isPromptPickerEnabled: Bool

    init(
        payload: ResultReviewPanelPayload,
        promptSelectionState: ResultReviewPanelPromptSelectionState? = nil
    ) {
        self.titleText = "VoicePi"
        self.originalSectionTitle = "Original"
        self.promptSectionTitle = (promptSelectionState?.hasPendingPromptSelection == true)
            ? "Prompt (Pending)"
            : "Prompt"
        self.outputSectionTitle = "Result"
        self.originalDisplayText = payload.originalText
        self.outputCopyButtonTitle = "Copy"
        self.outputCopyText = payload.resultText
        self.outputDisplayText = payload.displayText
        self.selectedPromptPresetID = promptSelectionState?.appliedPromptPresetID ?? payload.selectedPromptPresetID
        self.selectedPromptTitle = promptSelectionState?.appliedPromptTitle ?? payload.selectedPromptTitle
        self.promptPickerSelectedPresetID = promptSelectionState?.promptPickerSelectedPresetID
            ?? payload.selectedPromptPresetID
        self.promptOptions = payload.availablePrompts
        self.regenerateButtonTitle = payload.isRegenerating ? "Regenerating…" : "Regenerate"
        self.isRegenerateEnabled = !payload.isRegenerating
        self.isPromptPickerEnabled = !payload.isRegenerating
    }
}
