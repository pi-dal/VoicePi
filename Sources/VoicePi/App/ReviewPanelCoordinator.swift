import AppKit
import Combine
import Foundation

@MainActor
final class ReviewPanelCoordinator {
    weak var appController: AppController?

    private var externalProcessorResultPanelController: ExternalProcessorResultPanelController? {
        appController?.externalProcessorResultPanelController
    }

    private var resultReviewPanelController: ResultReviewPanelController? {
        appController?.resultReviewPanelController
    }

    private var selectionRegenerateHintController: SelectionRegenerateHintController? {
        appController?.selectionRegenerateHintController
    }

    private var model: AppModel? {
        appController?.model
    }

    init() {}

    func configure(with appController: AppController) {
        self.appController = appController
    }

    var refinementReviewSession: AppController.RefinementReviewSession? {
        get { appController?.refinementReviewSession }
        set {
            guard let appController else { return }
            appController.refinementReviewSession = newValue
        }
    }

    var externalProcessorResultSession: AppController.ExternalProcessorResultSession? {
        get { appController?.externalProcessorResultSession }
        set {
            guard let appController else { return }
            appController.externalProcessorResultSession = newValue
        }
    }

    var resultReviewRetryTask: Task<Void, Never>? {
        get { appController?.resultReviewRetryTask }
        set {
            guard let appController else { return }
            appController.resultReviewRetryTask = newValue
        }
    }

    var externalProcessorResultRetryTask: Task<Void, Never>? {
        get { appController?.externalProcessorResultRetryTask }
        set {
            guard let appController else { return }
            appController.externalProcessorResultRetryTask = newValue
        }
    }

    var modeCycleRepeatTask: Task<Void, Never>? {
        get { appController?.modeCycleRepeatTask }
        set {
            guard let appController else { return }
            appController.modeCycleRepeatTask = newValue
        }
    }

    var modeCycleSessionActive: Bool {
        get { appController?.modeCycleSessionActive ?? false }
        set {
            guard let appController else { return }
            appController.modeCycleSessionActive = newValue
        }
    }

    private func presentTransientError(_ message: String) {
        appController?.presentTransientError(message)
    }

    func clearExternalProcessorResultState() {
        externalProcessorResultRetryTask?.cancel()
        externalProcessorResultRetryTask = nil
        externalProcessorResultSession = nil
        externalProcessorResultPanelController?.hide()
    }

    func dismissExternalProcessorResultPanel() {
        clearExternalProcessorResultState()
    }

    func clearResultReviewState() {
        resultReviewRetryTask?.cancel()
        resultReviewRetryTask = nil
        refinementReviewSession = nil
        selectionRegenerateHintController?.hide()
        resultReviewPanelController?.hide()
    }

    func dismissResultReviewPanel() {
        clearResultReviewState()
    }

    func resultReviewPromptOptions() -> [ResultReviewPanelPromptOption] {
        model?.orderedPromptCyclePresets().map {
            .init(presetID: $0.id, title: $0.resolvedTitle)
        } ?? []
    }

    func updateResultReviewPromptSelection(_ presetID: String) {
        guard var session = refinementReviewSession else { return }
        guard let model else { return }

        let resolvedPrompt = model.resolvedPromptPresetForExplicitPresetID(presetID)
        let updatedSelection = AppController.updatedResultReviewPromptSelection(
            selectedPromptPresetID: session.selectedPromptPresetID,
            selectedPromptTitle: session.selectedPromptTitle,
            pendingPromptPresetID: session.pendingPromptPresetID,
            pendingPromptTitle: session.pendingPromptTitle,
            requestedPromptPresetID: resolvedPrompt.presetID ?? PromptPreset.builtInDefaultID,
            requestedPromptTitle: resolvedPrompt.title
        )
        session.selectedPromptPresetID = updatedSelection.selectedPromptPresetID
        session.selectedPromptTitle = updatedSelection.selectedPromptTitle
        session.pendingPromptPresetID = updatedSelection.pendingPromptPresetID
        session.pendingPromptTitle = updatedSelection.pendingPromptTitle
        refinementReviewSession = session
    }

    func presentExternalProcessorResultPanel(
        text: String,
        sourceText: String,
        workflowOverride: AppController.RecordingWorkflowOverride?,
        sourceApplicationBundleID: String?,
        recordingDurationMilliseconds: Int
    ) {
        guard let payload = ExternalProcessorResultPanelPayload(
            resultText: text,
            originalText: sourceText
        ) else {
            presentTransientError("External processor returned unreadable output.")
            return
        }

        externalProcessorResultRetryTask?.cancel()
        externalProcessorResultRetryTask = nil
        externalProcessorResultSession = AppController.ExternalProcessorResultSession(
            payload: payload,
            sourceText: sourceText,
            workflowOverride: workflowOverride,
            sourceApplicationBundleID: sourceApplicationBundleID,
            recordingDurationMilliseconds: max(0, recordingDurationMilliseconds)
        )
        selectionRegenerateHintController?.hide()
        resultReviewPanelController?.hide()
        appController?.floatingPanelController.hide(immediately: true)
        model?.hideOverlay()
        appController?.statusBarController?.setTransientStatus(nil)
        appController?.inputFallbackPanelController.hide()
        externalProcessorResultPanelController?.show(payload: payload)
    }

    func resultReviewPayload(
        for session: AppController.RefinementReviewSession,
        isRegenerating: Bool
    ) -> ResultReviewPanelPayload? {
        let selectedPromptPresetID: String
        let selectedPromptTitle: String
        if isRegenerating,
           let pendingPromptPresetID = session.pendingPromptPresetID,
           let pendingPromptTitle = session.pendingPromptTitle {
            selectedPromptPresetID = pendingPromptPresetID
            selectedPromptTitle = pendingPromptTitle
        } else {
            selectedPromptPresetID = session.selectedPromptPresetID
            selectedPromptTitle = session.selectedPromptTitle
        }

        return ResultReviewPanelPayload(
            resultText: session.currentResultText,
            originalText: AppController.resultReviewSourceText(for: session),
            selectedPromptPresetID: selectedPromptPresetID,
            selectedPromptTitle: selectedPromptTitle,
            availablePrompts: resultReviewPromptOptions(),
            allowsInsert: true,
            isRegenerating: isRegenerating
        )
    }

    func presentResultReviewPanel(
        sourceType: AppController.ResultReviewSourceType,
        resultText: String,
        originalText: String,
        workflow: AppController.ProcessingWorkflowSelection,
        workflowOverride: AppController.RecordingWorkflowOverride?,
        selectionAnchor: AppController.ResultReviewSelectionAnchor,
        selectedPromptPresetIDOverride: String? = nil,
        selectedPromptTitleOverride: String? = nil,
        recordingDurationMilliseconds: Int = 0,
        isRegenerating: Bool = false,
        isAutoOpened: Bool
    ) {
        let sanitizedOriginalText = ExternalProcessorOutputSanitizer.sanitize(originalText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedOriginalText.isEmpty else {
            presentTransientError("Original text is unavailable for review.")
            return
        }

        guard let model else {
            presentTransientError("App model unavailable.")
            return
        }

        let resolvedPrompt = appController?.resolvedRefinementPrompt(for: workflow)
        let selectedPromptPresetID = AppController.normalizedResultReviewPromptPresetID(
            selectedPromptPresetIDOverride
        ) ?? resolvedPrompt?.presetID ?? PromptPreset.builtInDefaultID
        let fallbackPromptTitle = resolvedPrompt?.title ?? PromptPreset.builtInDefault.title
        let selectedPromptTitle = AppController.normalizedResultReviewPromptTitle(
            selectedPromptTitleOverride,
            fallback: fallbackPromptTitle
        )
        let session = AppController.RefinementReviewSession(
            sourceType: sourceType,
            rawTranscript: sanitizedOriginalText,
            selectedPromptPresetID: selectedPromptPresetID,
            selectedPromptTitle: selectedPromptTitle,
            currentResultText: resultText,
            selectionAnchor: selectionAnchor,
            recordingDurationMilliseconds: max(0, recordingDurationMilliseconds),
            workflow: workflow,
            workflowOverride: workflowOverride,
            isAutoOpened: isAutoOpened
        )

        guard let payload = resultReviewPayload(for: session, isRegenerating: isRegenerating) else {
            presentTransientError("External processor returned unreadable output.")
            return
        }

        resultReviewRetryTask?.cancel()
        resultReviewRetryTask = nil
        refinementReviewSession = session
        selectionRegenerateHintController?.hide()
        clearExternalProcessorResultState()
        appController?.floatingPanelController.hide(immediately: true)
        model.hideOverlay()
        appController?.statusBarController?.setTransientStatus(nil)
        appController?.inputFallbackPanelController.hide()
        resultReviewPanelController?.show(payload: payload)
    }
}
