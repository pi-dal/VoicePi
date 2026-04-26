import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

extension AppController {
    static let shortcutMonitoringFailureMessage =
        "Global shortcut monitoring is unavailable. Input Monitoring is required to listen for the shortcut, and Accessibility is required to suppress and inject events."

    static let shortcutSuppressionWarningMessage =
        "Shortcut listening is active, but Accessibility is still required to suppress the shortcut and inject pasted text."

    static let shortcutInjectionWarningMessage =
        "Shortcut listening is active, but Accessibility is still required to inject pasted text."

    static let shortcutRegistrationFailureMessage =
        "Global shortcut registration is unavailable. Choose a different shortcut."

    static let modeCycleShortcutMonitoringFailureMessage =
        "Mode-switch shortcut listening is unavailable. Input Monitoring is required to listen for this shortcut."

    static let modeCycleShortcutSuppressionWarningMessage =
        "Mode-switch shortcut listening is active, but Accessibility is still required to suppress the shortcut before it reaches the frontmost app."

    static let modeCycleShortcutRegistrationFailureMessage =
        "Mode-switch shortcut registration is unavailable. Choose a different shortcut."

    static let promptCycleShortcutMonitoringFailureMessage =
        "Prompt-cycle shortcut listening is unavailable. Input Monitoring is required to listen for this shortcut."

    static let promptCycleShortcutSuppressionWarningMessage =
        "Prompt-cycle shortcut listening is active, but Accessibility is still required to suppress the shortcut before it reaches the frontmost app."

    static let promptCycleShortcutRegistrationFailureMessage =
        "Prompt-cycle shortcut registration is unavailable. Choose a different shortcut."

    static let processorShortcutMonitoringFailureMessage =
        "Processor shortcut listening is unavailable. Input Monitoring is required to listen for this shortcut."

    static let processorShortcutSuppressionWarningMessage =
        "Processor shortcut listening is active, but Accessibility is still required to suppress the shortcut before it reaches the frontmost app."

    static let processorShortcutRegistrationFailureMessage =
        "Processor shortcut registration is unavailable. Choose a different shortcut."

    static let startupHotkeyBootstrapRetryNanoseconds: UInt64 = 500_000_000
    static let startupHotkeyBootstrapMaxAttempts = 6
    static let modeCycleRepeatDelayNanoseconds: UInt64 = 350_000_000
    static let modeCycleRepeatIntervalNanoseconds: UInt64 = 170_000_000
    static let minimumFloatingRefiningVisibilityNanoseconds: UInt64 = 320_000_000
    static let directUpdateDownloadPollMaxAttempts = 20
    static let directUpdateDownloadPollIntervalNanoseconds: UInt64 = 100_000_000

    static let lastPromptedUpdateVersionKey = "VoicePi.lastPromptedUpdateVersion"
    static let escapeCancelShortcut = ActivationShortcut(keyCodes: [53], modifierFlagsRawValue: 0)


    static func pressAction(
        isRecording: Bool,
        isStartingRecording: Bool,
        isProcessingRelease: Bool,
        hasConfirmedSelectionForRewrite: Bool = false,
        workflowOverride: RecordingWorkflowOverride? = nil
    ) -> PressAction {
        if isProcessingRelease {
            return .cancelProcessing
        }

        if isRecording {
            return .stopRecording
        }

        if isStartingRecording {
            return .ignore
        }

        if workflowOverride == .externalProcessorShortcut {
            return .startRecording
        }

        if hasConfirmedSelectionForRewrite {
            return .startSelectionRewrite
        }

        return .startRecording
    }

    static func releaseAction(
        shortcut: ActivationShortcut,
        isRecording: Bool,
        isStartingRecording: Bool,
        isProcessingRelease: Bool
    ) -> ReleaseAction {
        _ = shortcut
        _ = isRecording
        _ = isStartingRecording
        _ = isProcessingRelease
        return .ignore
    }

    static func shouldPresentUpdatePrompt(
        trigger: UpdateCheckTrigger,
        availableVersion: String,
        lastPromptedVersion: String?
    ) -> Bool {
        switch trigger {
        case .manual:
            return true
        case .automatic:
            return lastPromptedVersion != availableVersion
        }
    }

    static func shouldPresentManualUpdateResultDialog(
        trigger: UpdateCheckTrigger,
        result: AppUpdateCheckResult
    ) -> Bool {
        switch trigger {
        case .manual:
            return true
        case .automatic:
            return false
        }
    }

    static func updateDelivery(for installationSource: AppInstallationSource) -> AppUpdateDelivery {
        switch installationSource {
        case .homebrewManaged:
            return .homebrew
        case .directDownload, .unknown:
            return .inAppInstaller
        }
    }

    static func shouldStartModeCycleRepeat(
        shortcut: ActivationShortcut,
        isRecording: Bool,
        isStartingRecording: Bool,
        isProcessingRelease: Bool
    ) -> Bool {
        !shortcut.isEmpty &&
        !isRecording &&
        !isStartingRecording &&
        !isProcessingRelease
    }

    static func modeCycleInteractionStyle(for shortcut: ActivationShortcut) -> ModeCycleInteractionStyle {
        if shortcut.primaryKeyCode != nil, !shortcut.modifierFlags.isEmpty {
            return .modifierHeldSession
        }

        return .holdRepeat
    }

    static func processorShortcutPressAction(
        isRecording: Bool,
        isStartingRecording: Bool,
        isProcessingRelease: Bool
    ) -> ProcessorShortcutPressAction {
        if isProcessingRelease {
            return .ignore
        }

        if isRecording {
            return .stopRecording
        }

        if isStartingRecording {
            return .ignore
        }

        return .startProcessorCapture(.externalProcessorShortcut)
    }

    static func escapeCancelMonitorPlan(
        inputMonitoringState: AuthorizationState,
        accessibilityState: AuthorizationState
    ) -> HotkeyMonitorPlan {
        guard accessibilityState == .granted, inputMonitoringState == .granted else {
            return HotkeyMonitorPlan(strategy: nil, statusMessage: nil)
        }

        return HotkeyMonitorPlan(
            strategy: .eventTap(.listenAndSuppress),
            statusMessage: nil
        )
    }

    static func commandPeriodCancelMonitorPlan() -> HotkeyMonitorPlan {
        HotkeyMonitorPlan(
            strategy: .registeredHotkey,
            statusMessage: nil
        )
    }

    static func cancelShortcutMonitorPlan(
        shortcut: ActivationShortcut,
        inputMonitoringState: AuthorizationState,
        accessibilityState: AuthorizationState
    ) -> HotkeyMonitorPlan {
        if shortcut.keyCodes == Self.escapeCancelShortcut.keyCodes,
           shortcut.modifierFlagsRawValue == Self.escapeCancelShortcut.modifierFlagsRawValue {
            return escapeCancelMonitorPlan(
                inputMonitoringState: inputMonitoringState,
                accessibilityState: accessibilityState
            )
        }

        return monitorPlan(
            shortcut: shortcut,
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState,
            registeredHotkeyAccessibilityWarning: nil,
            eventTapAccessibilityWarning: Self.shortcutSuppressionWarningMessage,
            inputMonitoringFailureMessage: Self.shortcutMonitoringFailureMessage
        )
    }

    static func escapeCancelAction(
        isStartingRecording: Bool,
        isRecording: Bool,
        isProcessingRelease: Bool
    ) -> EscapeCancelAction {
        if isStartingRecording {
            return .cancelStartup
        }

        if isRecording {
            return .cancelRecording
        }

        if isProcessingRelease {
            return .cancelProcessing
        }

        return .ignore
    }

    static func effectiveProcessingWorkflow(
        postProcessingMode: PostProcessingMode,
        refinementProvider: RefinementProvider,
        override: RecordingWorkflowOverride?
    ) -> ProcessingWorkflowSelection {
        if let override {
            return ProcessingWorkflowSelection(
                postProcessingMode: override.postProcessingMode,
                refinementProvider: override.refinementProvider
            )
        }

        return ProcessingWorkflowSelection(
            postProcessingMode: postProcessingMode,
            refinementProvider: refinementProvider
        )
    }

    static func postProcessingFailureAction(
        workflowOverride: RecordingWorkflowOverride?,
        didExternalProcessorSucceed: Bool
    ) -> PostProcessingFailureAction {
        guard let workflowOverride else {
            return .continueTranscriptDelivery
        }

        switch workflowOverride {
        case .externalProcessorShortcut:
            return didExternalProcessorSucceed ? .continueTranscriptDelivery : .surfaceProcessorFailure
        }
    }

    static func postProcessingSuccessAction(
        workflowOverride: RecordingWorkflowOverride?,
        didExternalProcessorSucceed: Bool
    ) -> PostProcessingSuccessAction {
        guard workflowOverride == .externalProcessorShortcut, didExternalProcessorSucceed else {
            return .deliverTranscriptNormally
        }

        return .presentExternalProcessorResultPanel
    }

    static func capturedSourceSnapshot(
        workflow: ProcessingWorkflowSelection,
        workflowOverride: RecordingWorkflowOverride?,
        targetSnapshot: EditableTextTargetSnapshot,
        sourceApplicationBundleID: String?
    ) -> CapturedSourceSnapshot? {
        guard workflowOverride == .externalProcessorShortcut
            || (
                workflow.postProcessingMode == .refinement
                && workflow.refinementProvider == .externalProcessor
            ) else {
            return nil
        }
        return ExternalProcessorSourceSnapshotSupport.capture(
            from: targetSnapshot,
            sourceApplicationBundleID: sourceApplicationBundleID
        )
    }

    static func resolvedCapturedSourceSnapshot(
        existingSnapshot: CapturedSourceSnapshot?,
        workflow: ProcessingWorkflowSelection,
        workflowOverride: RecordingWorkflowOverride?,
        targetSnapshot: EditableTextTargetSnapshot,
        sourceApplicationBundleID: String?,
        fallbackSelectedText: String?
    ) -> CapturedSourceSnapshot? {
        if let existingSnapshot {
            return existingSnapshot
        }

        guard workflowOverride == .externalProcessorShortcut
            || (
                workflow.postProcessingMode == .refinement
                && workflow.refinementProvider == .externalProcessor
            ) else {
            return nil
        }

        guard let normalizedText = ExternalProcessorSourceSnapshotSupport.normalizedSourceText(
            fallbackSelectedText ?? ""
        ) else {
            return nil
        }

        return CapturedSourceSnapshot(
            text: normalizedText,
            previewText: ExternalProcessorSourceSnapshotSupport.previewText(from: normalizedText),
            sourceApplicationBundleID: sourceApplicationBundleID?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            targetIdentifier: targetSnapshot.targetIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func shouldResolveAutomaticRefinementPrompt(
        workflowOverride: RecordingWorkflowOverride?,
        promptPresetOverrideID: String?
    ) -> Bool {
        let normalizedPromptID = promptPresetOverrideID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedPromptID, !normalizedPromptID.isEmpty {
            return true
        }

        return workflowOverride != .externalProcessorShortcut
    }

    static func transcriptDeliveryRoute(
        for text: String,
        targetInspection: EditableTextTargetInspection
    ) -> TranscriptDelivery.Route {
        TranscriptDelivery.route(for: text, targetInspection: targetInspection)
    }

    static func shouldPresentResultReviewPanel(
        refinementProvider: RefinementProvider,
        postProcessingMode: PostProcessingMode
    ) -> Bool {
        _ = refinementProvider
        return postProcessingMode == .refinement
    }

    static func refiningPresentationModeForRegenerate() -> RefiningPresentationMode {
        .statusBarOnly
    }

    static func refiningPresentationModeForNormalWorkflow() -> RefiningPresentationMode {
        .floatingOverlayAndStatusBar
    }

    @MainActor
    static func pendingFloatingRefiningHideDelayNanoseconds(
        presentationStartedAt: Date?,
        now: Date = Date(),
        minimumVisibilityNanoseconds: UInt64 = 320_000_000
    ) -> UInt64 {
        guard let presentationStartedAt else {
            return 0
        }

        let elapsedNanoseconds = max(
            0,
            Int64((now.timeIntervalSince(presentationStartedAt) * 1_000_000_000).rounded())
        )
        let minimumVisibilityNanoseconds = Int64(minimumVisibilityNanoseconds)
        guard elapsedNanoseconds < minimumVisibilityNanoseconds else {
            return 0
        }

        return UInt64(minimumVisibilityNanoseconds - elapsedNanoseconds)
    }

    static func recentInsertionAutoReviewPresentationDecision(
        selectedRange: NSRange,
        textValue: String?
    ) -> RecentInsertionAutoReviewPresentationDecision {
        guard let textValue, !textValue.isEmpty else {
            return .presentReviewPanel
        }

        let fullRange = NSRange(location: 0, length: textValue.utf16.count)
        return NSEqualRanges(selectedRange, fullRange) ? .deferToCallToAction : .presentReviewPanel
    }

    static func selectionRewritePresentationDecision(
        hasRecentInsertionMatch: Bool
    ) -> SelectionRewritePresentationDecision {
        hasRecentInsertionMatch
            ? .presentRecentInsertionReviewPanel
            : .presentFreshReviewPanel
    }

    static func resultReviewSourceText(for session: RefinementReviewSession) -> String {
        let normalizedSessionSource = ExternalProcessorOutputSanitizer.sanitize(session.regenerateSourceText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSessionSource.isEmpty {
            return normalizedSessionSource
        }

        let normalizedSelectionText = ExternalProcessorOutputSanitizer.sanitize(
            session.selectionAnchor.selectedText
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSelectionText.isEmpty {
            return normalizedSelectionText
        }

        return ExternalProcessorOutputSanitizer.sanitize(session.rawTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func didRefinementReviewRegenerateSucceed(
        refinementProvider: RefinementProvider,
        sourceText: String,
        previousResultText: String? = nil,
        regeneratedText: String,
        didExternalProcessorSucceed: Bool
    ) -> Bool {
        resultReviewRegenerateOutcome(
            refinementProvider: refinementProvider,
            sourceText: sourceText,
            previousResultText: previousResultText,
            regeneratedText: regeneratedText,
            didExternalProcessorSucceed: didExternalProcessorSucceed
        ) != .failed
    }

    static func resultReviewRegenerateOutcome(
        refinementProvider: RefinementProvider,
        sourceText: String,
        previousResultText: String? = nil,
        regeneratedText: String,
        didExternalProcessorSucceed: Bool
    ) -> ResultReviewRegenerateOutcome {
        let sanitizedRegeneratedText = ExternalProcessorOutputSanitizer.sanitize(regeneratedText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedRegeneratedText.isEmpty else {
            return .failed
        }

        switch refinementProvider {
        case .externalProcessor:
            return didExternalProcessorSucceed ? .applyRegeneratedText : .failed
        case .llm:
            let normalizedSourceText = ExternalProcessorOutputSanitizer.sanitize(sourceText)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard sanitizedRegeneratedText == normalizedSourceText else {
                return .applyRegeneratedText
            }
            let normalizedPreviousResultText = ExternalProcessorOutputSanitizer.sanitize(
                previousResultText ?? ""
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedPreviousResultText.isEmpty,
                  normalizedPreviousResultText != normalizedSourceText else {
                return .applyRegeneratedText
            }
            return .keepPreviousResult
        }
    }

    static func updatedResultReviewPromptSelection(
        selectedPromptPresetID: String,
        selectedPromptTitle: String,
        pendingPromptPresetID: String?,
        pendingPromptTitle: String?,
        requestedPromptPresetID: String,
        requestedPromptTitle: String
    ) -> ResultReviewPromptSelectionState {
        let normalizedSelectedPromptPresetID = normalizedResultReviewPromptPresetID(selectedPromptPresetID)
        let normalizedSelectedPromptTitle = normalizedResultReviewPromptTitle(
            selectedPromptTitle,
            fallback: PromptPreset.builtInDefault.title
        )
        let normalizedPendingPromptPresetID = normalizedResultReviewPromptPresetID(
            pendingPromptPresetID
        )
        let normalizedPendingPromptTitle = normalizedResultReviewPromptTitle(
            pendingPromptTitle,
            fallback: normalizedSelectedPromptTitle
        )
        let normalizedRequestedPromptPresetID = normalizedResultReviewPromptPresetID(requestedPromptPresetID)
        let normalizedRequestedPromptTitle = normalizedResultReviewPromptTitle(
            requestedPromptTitle,
            fallback: normalizedSelectedPromptTitle
        )

        if normalizedRequestedPromptPresetID == normalizedSelectedPromptPresetID {
            return ResultReviewPromptSelectionState(
                selectedPromptPresetID: normalizedSelectedPromptPresetID,
                selectedPromptTitle: normalizedSelectedPromptTitle,
                pendingPromptPresetID: nil,
                pendingPromptTitle: nil
            )
        }

        if normalizedRequestedPromptPresetID == normalizedPendingPromptPresetID {
            return ResultReviewPromptSelectionState(
                selectedPromptPresetID: normalizedSelectedPromptPresetID,
                selectedPromptTitle: normalizedSelectedPromptTitle,
                pendingPromptPresetID: normalizedPendingPromptPresetID,
                pendingPromptTitle: normalizedPendingPromptTitle
            )
        }

        return ResultReviewPromptSelectionState(
            selectedPromptPresetID: normalizedSelectedPromptPresetID,
            selectedPromptTitle: normalizedSelectedPromptTitle,
            pendingPromptPresetID: normalizedRequestedPromptPresetID,
            pendingPromptTitle: normalizedRequestedPromptTitle
        )
    }

    static func committedResultReviewPromptSelectionAfterRegenerateSuccess(
        selectedPromptPresetID: String,
        selectedPromptTitle: String,
        pendingPromptPresetID: String?,
        pendingPromptTitle: String?
    ) -> ResultReviewPromptSelectionState {
        let normalizedSelectedPromptPresetID = normalizedResultReviewPromptPresetID(selectedPromptPresetID)
        let normalizedSelectedPromptTitle = normalizedResultReviewPromptTitle(
            selectedPromptTitle,
            fallback: PromptPreset.builtInDefault.title
        )
        let normalizedPendingPromptPresetID = normalizedResultReviewPromptPresetID(
            pendingPromptPresetID
        )

        guard let normalizedPendingPromptPresetID else {
            return ResultReviewPromptSelectionState(
                selectedPromptPresetID: normalizedSelectedPromptPresetID,
                selectedPromptTitle: normalizedSelectedPromptTitle,
                pendingPromptPresetID: nil,
                pendingPromptTitle: nil
            )
        }

        return ResultReviewPromptSelectionState(
            selectedPromptPresetID: normalizedPendingPromptPresetID,
            selectedPromptTitle: normalizedResultReviewPromptTitle(
                pendingPromptTitle,
                fallback: normalizedSelectedPromptTitle
            ),
            pendingPromptPresetID: nil,
            pendingPromptTitle: nil
        )
    }

    static func canPresentResultReviewPanel(
        refinementProvider: RefinementProvider,
        postProcessingMode: PostProcessingMode,
        llmConfigurationIsConfigured: Bool,
        didExternalProcessorSucceed: Bool,
        processedText: String
    ) -> Bool {
        guard shouldPresentResultReviewPanel(
            refinementProvider: refinementProvider,
            postProcessingMode: postProcessingMode
        ) else {
            return false
        }

        let sanitizedOutput = ExternalProcessorOutputSanitizer.sanitize(processedText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedOutput.isEmpty else { return false }

        guard canEnterRefinementReviewFlow(
            refinementProvider: refinementProvider,
            llmConfigurationIsConfigured: llmConfigurationIsConfigured
        ) else {
            return false
        }

        switch refinementProvider {
        case .externalProcessor:
            return didExternalProcessorSucceed
        case .llm:
            return true
        }
    }

    static func canEnterRefinementReviewFlow(
        refinementProvider: RefinementProvider,
        llmConfigurationIsConfigured: Bool
    ) -> Bool {
        switch refinementProvider {
        case .externalProcessor:
            return true
        case .llm:
            return llmConfigurationIsConfigured
        }
    }

    static func resultReviewInsertionTargetSnapshot(
        capturedTargetSnapshot: EditableTextTargetSnapshot?,
        currentTargetSnapshot: EditableTextTargetSnapshot
    ) -> EditableTextTargetSnapshot {
        capturedTargetSnapshot ?? currentTargetSnapshot
    }

    static func resultReviewInsertionSourceApplicationBundleID(
        capturedSourceApplicationBundleID: String?,
        currentFrontmostApplicationBundleID: String?,
        targetIdentifier: String? = nil,
        voicePiBundleID: String? = Bundle.main.bundleIdentifier
    ) -> String? {
        let capturedBundleID = capturedSourceApplicationBundleID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let capturedBundleID, !capturedBundleID.isEmpty {
            return capturedBundleID
        }

        let currentBundleID = currentFrontmostApplicationBundleID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedVoicePiBundleID = voicePiBundleID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let currentBundleID, !currentBundleID.isEmpty, currentBundleID != normalizedVoicePiBundleID {
            return currentBundleID
        }

        if let targetProcessIdentifier = resultReviewTargetProcessIdentifier(targetIdentifier),
           let targetApplication = NSRunningApplication(processIdentifier: targetProcessIdentifier),
           !targetApplication.isTerminated {
            let targetBundleID = targetApplication.bundleIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let targetBundleID, !targetBundleID.isEmpty {
                return targetBundleID
            }
        }

        return nil
    }

    static func resultReviewSelectionMatchesAnchor(
        _ snapshot: EditableTextTargetSnapshot,
        selectionAnchor: ResultReviewSelectionAnchor
    ) -> Bool {
        guard snapshot.inspection == .editable else {
            return false
        }

        if let anchorTargetIdentifier = selectionAnchor.targetIdentifier {
            guard snapshot.targetIdentifier == anchorTargetIdentifier else {
                return false
            }
        }

        let normalizedAnchorText = ExternalProcessorOutputSanitizer.sanitize(selectionAnchor.selectedText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAnchorText.isEmpty else {
            return false
        }

        let normalizedSelectedText = ExternalProcessorOutputSanitizer.sanitize(snapshot.selectedText ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSelectedText.isEmpty else {
            // Some editors expose selection range but not selected text after focus switches.
            guard let currentSelectedRange = snapshot.selectedTextRange else {
                return false
            }
            return currentSelectedRange == selectionAnchor.selectedRange
        }

        return normalizedSelectedText == normalizedAnchorText
    }

    static func resultReviewTargetProcessIdentifier(
        _ targetIdentifier: String?
    ) -> pid_t? {
        guard let targetIdentifier else { return nil }
        let trimmedTargetIdentifier = targetIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTargetIdentifier.isEmpty else { return nil }
        guard let processComponent = trimmedTargetIdentifier
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .first else {
            return nil
        }
        guard let processID = Int32(processComponent), processID > 0 else {
            return nil
        }
        return pid_t(processID)
    }

    static func normalizedResultReviewPromptPresetID(_ presetID: String?) -> String? {
        guard let presetID else { return nil }
        let trimmed = presetID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func normalizedResultReviewPromptPresetID(_ presetID: String) -> String {
        normalizedResultReviewPromptPresetID(Optional(presetID)) ?? PromptPreset.builtInDefaultID
    }

    static func normalizedResultReviewPromptTitle(_ title: String?, fallback: String) -> String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return fallback
        }
        return trimmed
    }

    static func realtimeStopResolution(
        backend: ASRBackend,
        isRealtimeStreamingReady: Bool,
        degradedToBatchFallback: Bool,
        hasRecordedAudio: Bool,
        localFallback: String
    ) -> RealtimeStopResolution {
        guard backend.usesRealtimeStreaming else {
            return .batchFallback
        }

        if degradedToBatchFallback {
            return hasRecordedAudio || !localFallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .batchFallback
                : .silentCancel
        }

        if isRealtimeStreamingReady {
            return .realtimeFinalization
        }

        return hasRecordedAudio || !localFallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .batchFallback
            : .silentCancel
    }

}
