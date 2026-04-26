import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

@MainActor
extension AppController {
    func rewriteSelectionAnchor(
        from snapshot: EditableTextTargetSnapshot,
        sourceApplicationBundleID: String?
    ) -> ResultReviewSelectionAnchor? {
        guard snapshot.inspection == .editable else { return nil }
        guard let selectedTextRange = snapshot.selectedTextRange, selectedTextRange.length > 0 else {
            return nil
        }
        guard let selectedText = normalizedSnapshotSelectedText(snapshot) else {
            return nil
        }

        return ResultReviewSelectionAnchor(
            targetIdentifier: snapshot.targetIdentifier,
            selectedText: selectedText,
            selectedRange: selectedTextRange,
            sourceApplicationBundleID: sourceApplicationBundleID
        )
    }

    func normalizedSnapshotSelectedText(
        _ snapshot: EditableTextTargetSnapshot
    ) -> String? {
        let normalizedText = ExternalProcessorOutputSanitizer.sanitize(snapshot.selectedText ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }
        return normalizedText
    }

    func hasConfirmedSelectionForRewrite() -> Bool {
        let snapshot = editableTextTargetInspector.currentSnapshot()
        return rewriteSelectionAnchor(
            from: snapshot,
            sourceApplicationBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        ) != nil
    }

    func beginSelectionRewriteFromCurrentSelection() {
        guard !isProcessingRelease else { return }
        selectionRegenerateHintController.hide()

        let sourceApplicationBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let snapshot = editableTextTargetInspector.currentSnapshot()
        guard let selectionAnchor = rewriteSelectionAnchor(
            from: snapshot,
            sourceApplicationBundleID: sourceApplicationBundleID
        ) else {
            presentTransientError("No selected text available for rewrite.")
            return
        }

        let workflow = ProcessingWorkflowSelection(
            postProcessingMode: .refinement,
            refinementProvider: model.refinementProvider
        )
        if !Self.canEnterRefinementReviewFlow(
            refinementProvider: workflow.refinementProvider,
            llmConfigurationIsConfigured: model.llmConfiguration.isConfigured
        ) {
            presentTransientError("LLM refinement is not configured yet.")
            return
        }

        let recentSession = recentInsertionRewriteCoordinator.matchingSession(
            for: snapshot,
            now: Date()
        )
        switch Self.selectionRewritePresentationDecision(
            hasRecentInsertionMatch: recentSession != nil
        ) {
        case .presentRecentInsertionReviewPanel:
            guard let recentSession else { return }
            presentRecentInsertionReviewPanel(
                recentSession,
                snapshot: snapshot,
                isAutoOpened: false
            )
        case .presentFreshReviewPanel:
            let sourceText = selectionAnchor.selectedText
            presentResultReviewPanel(
                sourceType: .selectedText,
                resultText: sourceText,
                originalText: sourceText,
                workflow: workflow,
                workflowOverride: nil,
                selectionAnchor: selectionAnchor,
                isRegenerating: false,
                isAutoOpened: false
            )
        }
    }

    func cancelPostInjectionLearning() {
        postInjectionLearningTask?.cancel()
        postInjectionLearningTask = nil
        postInjectionLearningRunRegistry.clear()
        dictionarySuggestionToastController.hide()
        selectionRegenerateHintController.hide()
    }

    func beginPostInjectionLearning(
        targetSnapshot: EditableTextTargetSnapshot,
        sourceApplicationOverride: String? = nil,
        injectionRecord: TextInjectionRecord
    ) {
        cancelPostInjectionLearning()

        let sourceApplication = sourceApplicationOverride ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let session = PostInjectionLearningSession(
            insertedText: injectionRecord.text,
            targetIdentifier: targetSnapshot.targetIdentifier,
            sourceApplication: sourceApplication,
            startedAt: injectionRecord.injectedAt
        )
        let inspector = editableTextTargetInspector
        let learningCoordinator = postInjectionLearningCoordinator
        let loopPolicy = PostInjectionLearningLoopPolicy.default
        postInjectionLearningRunRegistry.start(session.id)

        postInjectionLearningTask = Task { @MainActor [weak self, inspector, learningCoordinator, loopPolicy] in
            guard let self else { return }
            guard !Task.isCancelled else { return }
            await learningCoordinator.startTracking(session)
            while !Task.isCancelled, await learningCoordinator.isTracking {
                let snapshot = inspector.currentSnapshot()
                self.refreshSelectionRegenerateHint(from: snapshot)

                if let suggestion = await learningCoordinator.processSnapshot(
                    snapshot,
                    now: Date()
                ) {
                    let queued = self.model.enqueueDictionarySuggestion(suggestion)
                    self.statusBarController?.refreshAll()
                    guard queued else {
                        try? await Task.sleep(for: loopPolicy.suggestionCooldownInterval)
                        continue
                    }

                    self.dictionarySuggestionToastController.show(
                        payload: DictionarySuggestionToastPayload(
                            sessionID: session.id,
                            suggestion: suggestion,
                            summaryText: "Saved to suggestions: \(suggestion.proposedCanonical)"
                        )
                    )
                    self.statusBarController?.setTransientStatus("Dictionary suggestion captured")
                    try? await Task.sleep(for: loopPolicy.suggestionCooldownInterval)
                    continue
                }

                try? await Task.sleep(for: loopPolicy.idlePollingInterval)
            }

            let finalSuggestions = await learningCoordinator.finishTracking(
                inspector.currentSnapshot(),
                now: Date()
            )
            self.captureDictionarySuggestions(finalSuggestions, sessionID: session.id)
            guard self.postInjectionLearningRunRegistry.finish(session.id) else { return }
            self.postInjectionLearningTask = nil
            self.selectionRegenerateHintController.hide()
        }
    }

    func captureDictionarySuggestions(
        _ suggestions: [DictionarySuggestion],
        sessionID: UUID
    ) {
        guard !suggestions.isEmpty else { return }

        var queuedSuggestions: [DictionarySuggestion] = []
        for suggestion in suggestions {
            if model.enqueueDictionarySuggestion(suggestion) {
                queuedSuggestions.append(suggestion)
            }
        }

        statusBarController?.refreshAll()
        guard let latestSuggestion = queuedSuggestions.last else { return }

        let summaryText: String
        if queuedSuggestions.count == 1 {
            summaryText = "Saved to suggestions: \(latestSuggestion.proposedCanonical)"
        } else {
            summaryText = "Saved \(queuedSuggestions.count) dictionary suggestions"
        }

        dictionarySuggestionToastController.show(
            payload: DictionarySuggestionToastPayload(
                sessionID: sessionID,
                suggestion: latestSuggestion,
                summaryText: summaryText
            )
        )
        statusBarController?.setTransientStatus("Dictionary suggestion captured")
    }

    func startRecentInsertionRewriteTracking(
        rawTranscript: String,
        insertedText: String,
        appliedPromptPresetID: String?,
        targetSnapshot: EditableTextTargetSnapshot,
        sourceApplicationBundleID: String?
    ) {
        let session = RecentInsertionRewriteSession(
            rawTranscript: rawTranscript,
            insertedText: insertedText,
            appliedPromptPresetID: appliedPromptPresetID,
            targetIdentifier: targetSnapshot.targetIdentifier,
            sourceApplicationBundleID: sourceApplicationBundleID,
            injectedAt: Date()
        )
        recentInsertionRewriteCoordinator.startTracking(session)
    }

    func presentRecentInsertionReviewPanel(
        _ recentSession: RecentInsertionRewriteSession,
        snapshot: EditableTextTargetSnapshot,
        isAutoOpened: Bool
    ) {
        let sourceApplicationBundleID = Self.resultReviewInsertionSourceApplicationBundleID(
            capturedSourceApplicationBundleID: recentSession.sourceApplicationBundleID,
            currentFrontmostApplicationBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            targetIdentifier: snapshot.targetIdentifier
        )
        guard let selectionAnchor = rewriteSelectionAnchor(
            from: snapshot,
            sourceApplicationBundleID: sourceApplicationBundleID
        ) else {
            presentTransientError("No selected text available for rewrite.")
            return
        }
        let workflow = ProcessingWorkflowSelection(
            postProcessingMode: .refinement,
            refinementProvider: model.refinementProvider
        )
        guard Self.canEnterRefinementReviewFlow(
            refinementProvider: workflow.refinementProvider,
            llmConfigurationIsConfigured: model.llmConfiguration.isConfigured
        ) else {
            presentTransientError("LLM refinement is not configured yet.")
            return
        }
        let resolvedPrompt = model.resolvedPromptPresetForExplicitPresetID(
            recentSession.appliedPromptPresetID
        )
        presentResultReviewPanel(
            sourceType: .recentInsertion,
            resultText: recentSession.insertedText,
            originalText: recentSession.rawTranscript,
            workflow: workflow,
            workflowOverride: nil,
            selectionAnchor: selectionAnchor,
            selectedPromptPresetIDOverride: resolvedPrompt.presetID,
            selectedPromptTitleOverride: resolvedPrompt.title,
            isAutoOpened: isAutoOpened
        )
    }

    func refreshSelectionRegenerateHint(from snapshot: EditableTextTargetSnapshot) {
        guard !isProcessingRelease else {
            selectionRegenerateHintController.hide()
            return
        }
        guard refinementReviewSession == nil else {
            selectionRegenerateHintController.hide()
            return
        }
        guard Self.canEnterRefinementReviewFlow(
            refinementProvider: model.refinementProvider,
            llmConfigurationIsConfigured: model.llmConfiguration.isConfigured
        ) else {
            selectionRegenerateHintController.hide()
            return
        }

        let now = Date()
        if let currentPayload = selectionRegenerateHintController.currentPayload {
            if let matchingSession = recentInsertionRewriteCoordinator.matchingSession(
                for: snapshot,
                now: now
            ),
               matchingSession.id == currentPayload.sessionID {
                if let selectedRange = snapshot.selectedTextRange,
                   Self.recentInsertionAutoReviewPresentationDecision(
                    selectedRange: selectedRange,
                    textValue: snapshot.textValue
                   ) == .presentReviewPanel {
                    selectionRegenerateHintController.hide()
                    presentRecentInsertionReviewPanel(
                        matchingSession,
                        snapshot: snapshot,
                        isAutoOpened: true
                    )
                    return
                }
                let refreshedPayload = SelectionRegenerateHintPayload(
                    sessionID: matchingSession.id,
                    selectedText: matchingSession.insertedText,
                    anchorRectInScreen: snapshot.selectedTextBoundsInScreen
                )
                if currentPayload != refreshedPayload {
                    selectionRegenerateHintController.show(payload: refreshedPayload)
                }
                return
            }
            selectionRegenerateHintController.hide()
        }

        guard let recentSession = recentInsertionRewriteCoordinator.processSnapshotForAutoOpen(
            snapshot,
            now: now,
            reviewPanelVisible: resultReviewPanelController.window?.isVisible == true
        ) else {
            return
        }

        if let selectedRange = snapshot.selectedTextRange,
           Self.recentInsertionAutoReviewPresentationDecision(
            selectedRange: selectedRange,
            textValue: snapshot.textValue
           ) == .presentReviewPanel {
            presentRecentInsertionReviewPanel(
                recentSession,
                snapshot: snapshot,
                isAutoOpened: true
            )
            return
        }

        selectionRegenerateHintController.show(
            payload: SelectionRegenerateHintPayload(
                sessionID: recentSession.id,
                selectedText: recentSession.insertedText,
                anchorRectInScreen: snapshot.selectedTextBoundsInScreen
            )
        )
    }

    func openRecentInsertionReviewFromHint(_ payload: SelectionRegenerateHintPayload) {
        selectionRegenerateHintController.hide()
        guard !isProcessingRelease else { return }

        let snapshot = editableTextTargetInspector.currentSnapshot()
        guard let recentSession = recentInsertionRewriteCoordinator.matchingSession(
            for: snapshot,
            now: Date()
        ),
        recentSession.id == payload.sessionID else {
            presentTransientError("Selection changed. Re-select the text and try again.")
            return
        }

        presentRecentInsertionReviewPanel(
            recentSession,
            snapshot: snapshot,
            isAutoOpened: false
        )
    }

    func restoreResultReviewSourceApplicationIfNeeded(
        bundleIdentifier: String?
    ) async throws {
        let trimmedBundleIdentifier = bundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedBundleIdentifier, !trimmedBundleIdentifier.isEmpty else {
            return
        }

        let voicePiBundleID = Bundle.main.bundleIdentifier
        if trimmedBundleIdentifier == voicePiBundleID {
            return
        }

        guard let sourceApplication = NSRunningApplication
            .runningApplications(withBundleIdentifier: trimmedBundleIdentifier)
            .first(where: { !$0.isTerminated }) else {
            throw ResultReviewInsertionError.sourceApplicationActivationFailed
        }

        guard !sourceApplication.isTerminated else {
            throw ResultReviewInsertionError.sourceApplicationActivationFailed
        }

        guard sourceApplication.activate(options: []) else {
            throw ResultReviewInsertionError.sourceApplicationActivationFailed
        }

        try await Task.sleep(for: .milliseconds(120))
    }

    func restoreAndValidateResultReviewSelection(
        _ selectionAnchor: ResultReviewSelectionAnchor
    ) throws {
        let normalizedAnchorText = ExternalProcessorOutputSanitizer.sanitize(selectionAnchor.selectedText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAnchorText.isEmpty else {
            throw ResultReviewInsertionError.selectionChanged
        }

        let currentSnapshot = editableTextTargetInspector.currentSnapshot()
        if selectionMatchesAnchor(currentSnapshot, selectionAnchor: selectionAnchor) {
            return
        }

        guard currentSnapshot.canSetSelectedTextRange else {
            throw ResultReviewInsertionError.selectionChanged
        }

        guard editableTextTargetInspector.restoreSelectionRange(
            targetIdentifier: selectionAnchor.targetIdentifier,
            range: selectionAnchor.selectedRange
        ) else {
            throw ResultReviewInsertionError.selectionChanged
        }

        let restoredSnapshot = editableTextTargetInspector.currentSnapshot()
        guard selectionMatchesAnchor(restoredSnapshot, selectionAnchor: selectionAnchor) else {
            throw ResultReviewInsertionError.selectionChanged
        }
    }

    func selectionMatchesAnchor(
        _ snapshot: EditableTextTargetSnapshot,
        selectionAnchor: ResultReviewSelectionAnchor
    ) -> Bool {
        Self.resultReviewSelectionMatchesAnchor(snapshot, selectionAnchor: selectionAnchor)
    }

}
