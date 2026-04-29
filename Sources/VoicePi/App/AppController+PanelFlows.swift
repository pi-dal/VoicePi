import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

@MainActor
extension AppController {
    func cancelCurrentRecordingAndHideOverlay() {
        recordingSessionCoordinator.cancelRecording()
    }

    func cancelProcessingAndHideOverlay() {
        recordingSessionCoordinator.cancelProcessing()
    }

    func clearActiveRecordingWorkflowState() {
        recordingSessionCoordinator.clearActiveRecordingWorkflowState()
    }

    func presentInputFallbackPanel(_ payload: InputFallbackPanelPayload) {
        floatingPanelController.hide(immediately: true) { [weak self] in
            guard let self else { return }
            self.inputFallbackPanelController.show(payload: payload)
        }
    }

    func presentExternalProcessorResultPanel(
        text: String,
        sourceText: String,
        workflowOverride: RecordingWorkflowOverride?,
        sourceApplicationBundleID: String?,
        recordingDurationMilliseconds: Int
    ) {
        reviewPanelCoordinator.presentExternalProcessorResultPanel(
            text: text,
            sourceText: sourceText,
            workflowOverride: workflowOverride,
            sourceApplicationBundleID: sourceApplicationBundleID,
            recordingDurationMilliseconds: recordingDurationMilliseconds
        )
    }

    func presentResultReviewPanel(
        sourceType: ResultReviewSourceType,
        resultText: String,
        originalText: String,
        workflow: ProcessingWorkflowSelection,
        workflowOverride: RecordingWorkflowOverride?,
        selectionAnchor: ResultReviewSelectionAnchor,
        selectedPromptPresetIDOverride: String? = nil,
        selectedPromptTitleOverride: String? = nil,
        recordingDurationMilliseconds: Int = 0,
        isRegenerating: Bool = false,
        isAutoOpened: Bool
    ) {
        reviewPanelCoordinator.presentResultReviewPanel(
            sourceType: sourceType,
            resultText: resultText,
            originalText: originalText,
            workflow: workflow,
            workflowOverride: workflowOverride,
            selectionAnchor: selectionAnchor,
            selectedPromptPresetIDOverride: selectedPromptPresetIDOverride,
            selectedPromptTitleOverride: selectedPromptTitleOverride,
            recordingDurationMilliseconds: recordingDurationMilliseconds,
            isRegenerating: isRegenerating,
            isAutoOpened: isAutoOpened
        )
    }

    func clearExternalProcessorResultState() {
        reviewPanelCoordinator.clearExternalProcessorResultState()
    }

    func dismissExternalProcessorResultPanel() {
        reviewPanelCoordinator.dismissExternalProcessorResultPanel()
    }

    func updateResultReviewPromptSelection(_ presetID: String) {
        reviewPanelCoordinator.updateResultReviewPromptSelection(presetID)
    }

    func resultReviewPromptOptions() -> [ResultReviewPanelPromptOption] {
        reviewPanelCoordinator.resultReviewPromptOptions()
    }

    func resultReviewPayload(
        for session: RefinementReviewSession,
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
            originalText: Self.resultReviewSourceText(for: session),
            selectedPromptPresetID: selectedPromptPresetID,
            selectedPromptTitle: selectedPromptTitle,
            availablePrompts: resultReviewPromptOptions(),
            allowsInsert: true,
            isRegenerating: isRegenerating
        )
    }

    func clearResultReviewState() {
        reviewPanelCoordinator.clearResultReviewState()
    }

    func dismissResultReviewPanel() {
        reviewPanelCoordinator.dismissResultReviewPanel()
    }

    func retryReviewedText(
        tracksGlobalProcessingState: Bool = false
    ) {
        guard let session = refinementReviewSession else {
            return
        }
        let sourceText = Self.resultReviewSourceText(for: session)
        guard !sourceText.isEmpty else {
            presentTransientError("Original text is unavailable for regenerate.")
            return
        }
        guard Self.canEnterRefinementReviewFlow(
            refinementProvider: session.workflow.refinementProvider,
            llmConfigurationIsConfigured: model.llmConfiguration.isConfigured
        ) else {
            presentTransientError("LLM refinement is not configured yet.")
            return
        }

        resultReviewRetryTask?.cancel()
        if tracksGlobalProcessingState {
            isProcessingRelease = true
        }
        floatingPanelController.hide(immediately: true)
        model.hideOverlay()
        statusBarController?.setTransientStatus(nil)
        if let payload = resultReviewPayload(for: session, isRegenerating: true) {
            resultReviewPanelController.show(payload: payload)
        }
        let sessionID = session.sessionID
        resultReviewRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.resultReviewRetryTask = nil
                if tracksGlobalProcessingState {
                    self.isProcessingRelease = false
                }
                self.floatingPanelController.hide(immediately: true)
                self.model.hideOverlay()
                self.statusBarController?.setTransientStatus(nil)
            }

            let refinedText = await self.refineIfNeeded(
                sourceText,
                workflow: session.workflow,
                workflowOverride: session.workflowOverride,
                promptPresetOverrideID: session.pendingPromptPresetID ?? session.selectedPromptPresetID,
                sourceSnapshot: session.sourceSnapshot,
                refiningPresentationMode: Self.refiningPresentationModeForRegenerate()
            )
            guard !Task.isCancelled else { return }
            guard var latestSession = self.refinementReviewSession,
                  latestSession.sessionID == sessionID else { return }

            let sanitizedRefinedText = ExternalProcessorOutputSanitizer.sanitize(refinedText)
            let didExternalProcessorSucceed = await self.externalProcessorRefiner.didSucceedOnLastInvocation
            let rerunOutcome = Self.resultReviewRegenerateOutcome(
                refinementProvider: latestSession.workflow.refinementProvider,
                sourceText: Self.resultReviewSourceText(for: latestSession),
                previousResultText: latestSession.currentResultText,
                regeneratedText: sanitizedRefinedText,
                didExternalProcessorSucceed: didExternalProcessorSucceed
            )

            if rerunOutcome != .failed {
                if rerunOutcome == .applyRegeneratedText {
                    latestSession.currentResultText = sanitizedRefinedText
                }
                let committedSelection = Self.committedResultReviewPromptSelectionAfterRegenerateSuccess(
                    selectedPromptPresetID: latestSession.selectedPromptPresetID,
                    selectedPromptTitle: latestSession.selectedPromptTitle,
                    pendingPromptPresetID: latestSession.pendingPromptPresetID,
                    pendingPromptTitle: latestSession.pendingPromptTitle
                )
                latestSession.selectedPromptPresetID = committedSelection.selectedPromptPresetID
                latestSession.selectedPromptTitle = committedSelection.selectedPromptTitle
                latestSession.pendingPromptPresetID = committedSelection.pendingPromptPresetID
                latestSession.pendingPromptTitle = committedSelection.pendingPromptTitle
                self.refinementReviewSession = latestSession
            } else {
                if latestSession.workflow.refinementProvider == .externalProcessor {
                    let processorFailureMessage = await self.externalProcessorRefiner
                        .lastFailureMessageOnLastInvocation
                    let trimmedFailureMessage = processorFailureMessage?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let failureMessage = trimmedFailureMessage.isEmpty
                        ? "Regenerate failed. Previous result is kept."
                        : trimmedFailureMessage
                    self.presentTransientError(failureMessage)
                } else {
                    self.presentTransientError("Regenerate failed. Previous result is kept.")
                }
            }

            guard let payload = self.resultReviewPayload(
                for: latestSession,
                isRegenerating: false
            ) else {
                self.clearResultReviewState()
                self.presentTransientError("Regenerate returned unreadable output.")
                return
            }
            self.resultReviewPanelController.show(payload: payload)
        }
    }

    func insertReviewedText(_ text: String) {
        guard let session = refinementReviewSession else { return }
        if session.pendingPromptPresetID != nil {
            presentTransientError("Press Regenerate to apply the selected prompt before inserting.")
            return
        }
        let sourceApplicationBundleID = Self.resultReviewInsertionSourceApplicationBundleID(
            capturedSourceApplicationBundleID: session.selectionAnchor.sourceApplicationBundleID,
            currentFrontmostApplicationBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            targetIdentifier: session.selectionAnchor.targetIdentifier
        )
        let recordingDurationMilliseconds = session.recordingDurationMilliseconds
        let reviewPayload = resultReviewPayload(for: session, isRegenerating: false)
        let trimmedText = ExternalProcessorOutputSanitizer.sanitize(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            clearResultReviewState()
            statusBarController?.setTransientStatus(nil)
            return
        }

        resultReviewPanelController.hide()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.restoreResultReviewSourceApplicationIfNeeded(
                    bundleIdentifier: sourceApplicationBundleID
                )
                try self.restoreAndValidateResultReviewSelection(session.selectionAnchor)
                let injectionRecord = try await self.textInjector.injectAndRecord(text: text)
                self.clearResultReviewState()
                self.statusBarController?.setTransientStatus("Injected")
                self.model.recordHistoryEntry(
                    text: text,
                    recordingDurationMilliseconds: recordingDurationMilliseconds
                )
                let currentSnapshot = self.editableTextTargetInspector.currentSnapshot()
                self.beginPostInjectionLearning(
                    targetSnapshot: currentSnapshot,
                    sourceApplicationOverride: sourceApplicationBundleID,
                    injectionRecord: injectionRecord
                )
                self.startRecentInsertionRewriteTracking(
                    rawTranscript: session.rawTranscript,
                    insertedText: injectionRecord.text,
                    appliedPromptPresetID: session.selectedPromptPresetID,
                    targetSnapshot: currentSnapshot,
                    sourceApplicationBundleID: sourceApplicationBundleID
                )
            } catch {
                if let reviewPayload {
                    self.resultReviewPanelController.show(payload: reviewPayload)
                }
                self.presentTransientError(error.localizedDescription)
            }
        }
    }

    func retryExternalProcessorResultText() {
        guard let session = externalProcessorResultSession else { return }

        externalProcessorResultRetryTask?.cancel()
        externalProcessorResultPanelController.hide()

        externalProcessorResultRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.externalProcessorResultRetryTask = nil
            }

            let workflow = Self.effectiveProcessingWorkflow(
                postProcessingMode: self.model.postProcessingMode,
                refinementProvider: self.model.refinementProvider,
                override: session.workflowOverride
            )
            let refinedText = await self.refineIfNeeded(
                session.sourceText,
                workflow: workflow,
                workflowOverride: session.workflowOverride
            )
            guard !Task.isCancelled else { return }

            let didSucceed = await self.externalProcessorRefiner.didSucceedOnLastInvocation
            let successAction = Self.postProcessingSuccessAction(
                workflowOverride: session.workflowOverride,
                didExternalProcessorSucceed: didSucceed
            )

            if successAction == .presentExternalProcessorResultPanel {
                self.presentExternalProcessorResultPanel(
                    text: refinedText,
                    sourceText: session.sourceText,
                    workflowOverride: session.workflowOverride,
                    sourceApplicationBundleID: session.sourceApplicationBundleID,
                    recordingDurationMilliseconds: session.recordingDurationMilliseconds
                )
                return
            }

            let processorFailureMessage = await self.externalProcessorRefiner.lastFailureMessageOnLastInvocation
            let trimmedFailureMessage = processorFailureMessage?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let failureMessage = trimmedFailureMessage.isEmpty
                ? "Processor retry failed. Previous result is kept."
                : trimmedFailureMessage
            self.externalProcessorResultPanelController.show(payload: session.payload)
            self.presentTransientError(failureMessage)
        }
    }

    func insertExternalProcessorResultText(_ text: String) {
        guard let session = externalProcessorResultSession else { return }

        let trimmedText = ExternalProcessorOutputSanitizer.sanitize(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            clearExternalProcessorResultState()
            statusBarController?.setTransientStatus(nil)
            return
        }

        let currentPayload = session.payload
        externalProcessorResultPanelController.hide()

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.restoreResultReviewSourceApplicationIfNeeded(
                    bundleIdentifier: session.sourceApplicationBundleID
                )
                let targetSnapshot = self.editableTextTargetInspector.currentSnapshot()
                switch Self.transcriptDeliveryRoute(
                    for: trimmedText,
                    targetInspection: targetSnapshot.inspection
                ) {
                case .emptyResult:
                    self.clearExternalProcessorResultState()
                    self.statusBarController?.setTransientStatus(nil)
                case .injectableTarget:
                    let injectionRecord = try await self.textInjector.injectAndRecord(text: trimmedText)
                    self.clearExternalProcessorResultState()
                    self.statusBarController?.setTransientStatus("Injected")
                    self.model.recordHistoryEntry(
                        text: trimmedText,
                        recordingDurationMilliseconds: session.recordingDurationMilliseconds
                    )
                    self.beginPostInjectionLearning(
                        targetSnapshot: targetSnapshot,
                        sourceApplicationOverride: session.sourceApplicationBundleID,
                        injectionRecord: injectionRecord
                    )
                    self.startRecentInsertionRewriteTracking(
                        rawTranscript: session.sourceText,
                        insertedText: injectionRecord.text,
                        appliedPromptPresetID: nil,
                        targetSnapshot: targetSnapshot,
                        sourceApplicationBundleID: session.sourceApplicationBundleID
                    )
                case .fallbackPanel:
                    self.clearExternalProcessorResultState()
                    if let payload = InputFallbackPanelPayload(text: trimmedText) {
                        self.model.recordHistoryEntry(
                            text: trimmedText,
                            recordingDurationMilliseconds: session.recordingDurationMilliseconds
                        )
                        self.presentInputFallbackPanel(payload)
                    }
                }
            } catch {
                self.externalProcessorResultPanelController.show(payload: currentPayload)
                self.presentTransientError(error.localizedDescription)
            }
        }
    }


}
