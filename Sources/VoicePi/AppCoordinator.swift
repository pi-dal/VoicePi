import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

@MainActor
final class AppController: NSObject {
    struct HotkeyMonitorPlan: Equatable {
        let strategy: HotkeyMonitorStrategy?
        let statusMessage: String?
    }

    enum HotkeyMonitorStrategy: Equatable {
        case registeredHotkey
        case eventTap(ShortcutMonitorMode)
    }

    enum PermissionSettingsDestination {
        case accessibility
        case microphone
        case speech
        case inputMonitoring
    }

    struct PermissionSettingsPrompt: Equatable {
        let messageText: String
        let informativeText: String
        let settingsURL: String
    }

    struct MediaPermissionPrePrompt: Equatable {
        let messageText: String
        let informativeText: String
        let continueTitle: String
    }

    struct LaunchPermissionPlan: Equatable {
        let requestMediaPermissions: Bool
        let promptAccessibility: Bool
        let requestInputMonitoringPermission: Bool
        let useSystemAccessibilityPrompt: Bool
    }

    enum PermissionPromptSource {
        case accessibilityFollowUp
        case launchFollowUp
        case manualSettingsButton
    }

    enum PermissionSettingsTransitionStyle: Equatable {
        case customPrompt
    }

    enum MediaPermissionTransitionStyle: Equatable {
        case customPrePromptThenSystemRequest
        case customSettingsPrompt
    }

    enum PermissionRefreshStep: Equatable {
        case mediaPermissions
        case accessibility
        case inputMonitoring
    }

    enum InputMonitoringLaunchAction: Equatable {
        case none
        case requestSystemPrompt
        case openSettingsPrompt
    }

    enum PressAction: Equatable {
        case startRecording
        case startSelectionRewrite
        case stopRecording
        case cancelProcessing
        case ignore
    }

    enum ModeCycleInteractionStyle: Equatable {
        case modifierHeldSession
        case holdRepeat
    }

    enum RecordingWorkflowOverride: Equatable {
        case externalProcessorShortcut

        var postProcessingMode: PostProcessingMode {
            switch self {
            case .externalProcessorShortcut:
                return .refinement
            }
        }

        var refinementProvider: RefinementProvider {
            switch self {
            case .externalProcessorShortcut:
                return .externalProcessor
            }
        }
    }

    enum ProcessorShortcutPressAction: Equatable {
        case startProcessorCapture(RecordingWorkflowOverride)
        case stopRecording
        case cancelProcessing
        case ignore
    }

    enum RefiningPresentationMode: Equatable {
        case floatingOverlayAndStatusBar
        case statusBarOnly
    }

    enum RecentInsertionAutoReviewPresentationDecision: Equatable {
        case presentReviewPanel
        case deferToCallToAction
    }

    enum SelectionRewritePresentationDecision: Equatable {
        case presentRecentInsertionReviewPanel
        case presentFreshReviewPanel
    }

    struct ProcessingWorkflowSelection: Equatable {
        let postProcessingMode: PostProcessingMode
        let refinementProvider: RefinementProvider
    }

    enum ResultReviewSourceType: Equatable {
        case recentInsertion
        case selectedText
    }

    enum ResultReviewRegenerateOutcome: Equatable {
        case applyRegeneratedText
        case keepPreviousResult
        case failed
    }

    struct ResultReviewSelectionAnchor: Equatable {
        let targetIdentifier: String?
        let selectedText: String
        let selectedRange: NSRange
        let sourceApplicationBundleID: String?
    }

    struct RefinementReviewSession {
        let sessionID: UUID
        let sourceType: ResultReviewSourceType
        let rawTranscript: String
        let regenerateSourceText: String
        var selectedPromptPresetID: String
        var selectedPromptTitle: String
        var pendingPromptPresetID: String?
        var pendingPromptTitle: String?
        var currentResultText: String
        let selectionAnchor: ResultReviewSelectionAnchor
        let recordingDurationMilliseconds: Int
        let workflow: ProcessingWorkflowSelection
        let workflowOverride: RecordingWorkflowOverride?
        let isAutoOpened: Bool

        init(
            sourceType: ResultReviewSourceType,
            rawTranscript: String,
            regenerateSourceText: String? = nil,
            selectedPromptPresetID: String,
            selectedPromptTitle: String,
            pendingPromptPresetID: String? = nil,
            pendingPromptTitle: String? = nil,
            currentResultText: String,
            selectionAnchor: ResultReviewSelectionAnchor,
            recordingDurationMilliseconds: Int,
            workflow: ProcessingWorkflowSelection,
            workflowOverride: RecordingWorkflowOverride?,
            isAutoOpened: Bool
        ) {
            self.sessionID = UUID()
            self.sourceType = sourceType
            self.rawTranscript = rawTranscript
            let normalizedExplicitSource = ExternalProcessorOutputSanitizer.sanitize(
                regenerateSourceText ?? ""
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedExplicitSource.isEmpty {
                self.regenerateSourceText = normalizedExplicitSource
            } else {
                let normalizedSelectedSource = ExternalProcessorOutputSanitizer.sanitize(
                    selectionAnchor.selectedText
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedRawTranscript = ExternalProcessorOutputSanitizer.sanitize(rawTranscript)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                switch sourceType {
                case .recentInsertion:
                    self.regenerateSourceText = !normalizedSelectedSource.isEmpty
                        ? normalizedSelectedSource
                        : normalizedRawTranscript
                case .selectedText:
                    self.regenerateSourceText = !normalizedRawTranscript.isEmpty
                        ? normalizedRawTranscript
                        : normalizedSelectedSource
                }
            }
            self.selectedPromptPresetID = selectedPromptPresetID
            self.selectedPromptTitle = selectedPromptTitle
            self.pendingPromptPresetID = pendingPromptPresetID
            self.pendingPromptTitle = pendingPromptTitle
            self.currentResultText = currentResultText
            self.selectionAnchor = selectionAnchor
            self.recordingDurationMilliseconds = recordingDurationMilliseconds
            self.workflow = workflow
            self.workflowOverride = workflowOverride
            self.isAutoOpened = isAutoOpened
        }
    }

    struct ExternalProcessorResultSession {
        var payload: ExternalProcessorResultPanelPayload
        let sourceText: String
        let workflowOverride: RecordingWorkflowOverride?
        let sourceApplicationBundleID: String?
        let recordingDurationMilliseconds: Int
    }

    struct ResultReviewPromptSelectionState: Equatable {
        let selectedPromptPresetID: String
        let selectedPromptTitle: String
        let pendingPromptPresetID: String?
        let pendingPromptTitle: String?
    }

    enum PostProcessingFailureAction: Equatable {
        case continueTranscriptDelivery
        case surfaceProcessorFailure
    }

    enum PostProcessingSuccessAction: Equatable {
        case deliverTranscriptNormally
        case presentExternalProcessorResultPanel
    }

    enum RealtimeStopResolution: Equatable {
        case realtimeFinalization
        case batchFallback
        case silentCancel
    }

    enum ReleaseAction: Equatable {
        case ignore
    }

    enum AppUpdateInstallError: LocalizedError {
        case downloadedBundleMissing

        var errorDescription: String? {
            switch self {
            case .downloadedBundleMissing:
                return "VoicePi downloaded the update, but the new app bundle was not ready to install."
            }
        }
    }

    enum ResultReviewInsertionError: LocalizedError {
        case sourceApplicationActivationFailed
        case selectionChanged

        var errorDescription: String? {
            switch self {
            case .sourceApplicationActivationFailed:
                return "VoicePi couldn't return focus to the previous app before pasting."
            case .selectionChanged:
                return "Selection changed. Re-select the text and try again."
            }
        }
    }

    private let model = AppModel()
    private let recordingShortcutAction = ShortcutActionController()
    private let modeCycleShortcutAction = ShortcutActionController()
    private let promptCycleShortcutAction = ShortcutActionController()
    private let processorShortcutAction = ShortcutActionController()
    private let speechRecorder = SpeechRecorder(localeIdentifier: SupportedLanguage.default.localeIdentifier)
    private let floatingPanelController = FloatingPanelController()
    private let inputFallbackPanelController = InputFallbackPanelController()
    private let externalProcessorResultPanelController = ExternalProcessorResultPanelController()
    private let resultReviewPanelController = ResultReviewPanelController()
    private let selectionRegenerateHintController = SelectionRegenerateHintController()
    private let dictionarySuggestionToastController = DictionarySuggestionToastController()
    private let llmRefiner = LLMRefiner()
    private let externalProcessorRefiner = AppControllerExternalProcessorRefiner()
    private let appleTranslateService = AppleTranslateService()
    private let remoteASRClient = RemoteASRClient()
    private let realtimeASRSessionCoordinator = RealtimeASRSessionCoordinator()
    private let textInjector = TextInjector.shared
    private let postInjectionLearningCoordinator = PostInjectionLearningCoordinator()
    private let updateChecker = GitHubReleaseUpdateChecker()
    private let homebrewInstallationDetector = HomebrewInstallationDetector()
    private let appDefaults = UserDefaults.standard
    private let promptDestinationInspector = PromptDestinationInspector()
    private let editableTextTargetInspector: EditableTextTargetInspecting = EditableTextTargetInspector()
    private let recentInsertionRewriteCoordinator = RecentInsertionRewriteCoordinator()
    private let recordingLatencyReporter: any RecordingLatencyReporting = RecordingLatencyCompositeReporter(
        reporters: [
            UnifiedLogRecordingLatencyReporter(),
            RecordingLatencyHistoryReporter()
        ]
    )

    private var statusBarController: StatusBarController?
    private var cancellables: Set<AnyCancellable> = []
    private var isStartingRecording = false
    private var isProcessingRelease = false
    private var processingTask: Task<Void, Never>?
    private var latestTranscript = ""
    private var pendingErrorHideTask: Task<Void, Never>?
    private var accessibilityAuthorizationFollowUpTask: Task<Void, Never>?
    private var inputMonitoringAuthorizationFollowUpTask: Task<Void, Never>?
    private var postInjectionLearningTask: Task<Void, Never>?
    private var postInjectionLearningRunRegistry = PostInjectionLearningRunRegistry()
    private var resultReviewRetryTask: Task<Void, Never>?
    private var modeCycleRepeatTask: Task<Void, Never>?
    private var startupHotkeyBootstrapTask: Task<Void, Never>?
    private var modeCycleSessionActive = false
    private var isAwaitingRealtimeFinalization = false
    private var activeDirectUpdateInstaller: AppUpdater?
    private var installationSource: AppInstallationSource = .unknown
    private var updateExperiencePhase: AppUpdateExperiencePhase = .idle(source: .unknown)
    private var refinementReviewSession: RefinementReviewSession?
    private var externalProcessorResultSession: ExternalProcessorResultSession?
    private var activeRecordingWorkflowOverride: RecordingWorkflowOverride?
    private var activeCapturedSourceSnapshot: CapturedSourceSnapshot?
    private var activeRecordingStartedAt: Date?
    private var activeRecordingLatencyTrace: RecordingLatencyTrace?
    private var activeFloatingRefiningPresentationStartedAt: Date?
    private var externalProcessorResultRetryTask: Task<Void, Never>?
    private var realtimeOverlayUpdateGate = RealtimeOverlayUpdateGate()
    private var realtimeAudioFramePump: RealtimeAudioFramePump?

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

    private static let lastPromptedUpdateVersionKey = "VoicePi.lastPromptedUpdateVersion"

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

    private static func resultReviewTargetProcessIdentifier(
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

    private static func normalizedResultReviewPromptPresetID(_ presetID: String?) -> String? {
        guard let presetID else { return nil }
        let trimmed = presetID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func normalizedResultReviewPromptPresetID(_ presetID: String) -> String {
        normalizedResultReviewPromptPresetID(Optional(presetID)) ?? PromptPreset.builtInDefaultID
    }

    private static func normalizedResultReviewPromptTitle(_ title: String?, fallback: String) -> String {
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

    static func shouldPromptAccessibilityOnLaunch(
        shortcut: ActivationShortcut,
        inputMonitoringState _: AuthorizationState
    ) -> Bool {
        _ = shortcut
        return true
    }

    static func shouldPromptAccessibilityOnLaunch(
        activationShortcut: ActivationShortcut,
        modeCycleShortcut _: ActivationShortcut,
        inputMonitoringState: AuthorizationState
    ) -> Bool {
        shouldPromptAccessibilityOnLaunch(
            shortcut: activationShortcut,
            inputMonitoringState: inputMonitoringState
        )
    }

    static func launchPermissionPlan(
        shortcut: ActivationShortcut,
        inputMonitoringState: AuthorizationState
    ) -> LaunchPermissionPlan {
        launchPermissionPlan(
            activationShortcut: shortcut,
            modeCycleShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
            processorShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
            promptCycleShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
            inputMonitoringState: inputMonitoringState
        )
    }

    static func launchPermissionPlan(
        activationShortcut: ActivationShortcut,
        modeCycleShortcut: ActivationShortcut,
        inputMonitoringState: AuthorizationState
    ) -> LaunchPermissionPlan {
        launchPermissionPlan(
            activationShortcut: activationShortcut,
            modeCycleShortcut: modeCycleShortcut,
            processorShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
            promptCycleShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
            inputMonitoringState: inputMonitoringState
        )
    }

    static func launchPermissionPlan(
        activationShortcut: ActivationShortcut,
        modeCycleShortcut: ActivationShortcut,
        processorShortcut: ActivationShortcut,
        promptCycleShortcut: ActivationShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
        inputMonitoringState: AuthorizationState
    ) -> LaunchPermissionPlan {
        LaunchPermissionPlan(
            requestMediaPermissions: true,
            promptAccessibility: shouldPromptAccessibilityOnLaunch(
                activationShortcut: activationShortcut,
                modeCycleShortcut: modeCycleShortcut,
                inputMonitoringState: inputMonitoringState
            ),
            requestInputMonitoringPermission: shortcutsRequireInputMonitoring(
                activationShortcut: activationShortcut,
                modeCycleShortcut: modeCycleShortcut,
                processorShortcut: processorShortcut,
                promptCycleShortcut: promptCycleShortcut
            ),
            useSystemAccessibilityPrompt: true
        )
    }

    static func shortcutsRequireInputMonitoring(
        activationShortcut: ActivationShortcut,
        modeCycleShortcut: ActivationShortcut
    ) -> Bool {
        shortcutsRequireInputMonitoring(
            activationShortcut: activationShortcut,
            modeCycleShortcut: modeCycleShortcut,
            processorShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
        )
    }

    static func shortcutsRequireInputMonitoring(
        activationShortcut: ActivationShortcut,
        modeCycleShortcut: ActivationShortcut,
        processorShortcut: ActivationShortcut,
        promptCycleShortcut: ActivationShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
    ) -> Bool {
        activationShortcut.requiresInputMonitoring
            || modeCycleShortcut.requiresInputMonitoring
            || processorShortcut.requiresInputMonitoring
            || promptCycleShortcut.requiresInputMonitoring
    }

    static func shouldOfferInputMonitoringSettingsOnLaunch(
        requestGranted: Bool,
        inputMonitoringState: AuthorizationState
    ) -> Bool {
        guard !requestGranted else {
            return false
        }

        switch inputMonitoringState {
        case .denied, .restricted:
            return true
        case .granted, .unknown:
            return false
        }
    }

    static func shouldAwaitInputMonitoringAuthorization(
        requestInputMonitoringPermission: Bool,
        inputMonitoringStateAfterRequest: AuthorizationState
    ) -> Bool {
        requestInputMonitoringPermission &&
        inputMonitoringStateAfterRequest != .granted
    }

    static func inputMonitoringLaunchAction(
        authorizationState: AuthorizationState
    ) -> InputMonitoringLaunchAction {
        switch authorizationState {
        case .granted:
            return .none
        case .unknown:
            return .requestSystemPrompt
        case .denied, .restricted:
            return .openSettingsPrompt
        }
    }

    static func hotkeyMonitorPlan(
        shortcut: ActivationShortcut,
        inputMonitoringState: AuthorizationState,
        accessibilityState: AuthorizationState
    ) -> HotkeyMonitorPlan {
        monitorPlan(
            shortcut: shortcut,
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState,
            registeredHotkeyAccessibilityWarning: shortcutInjectionWarningMessage,
            eventTapAccessibilityWarning: shortcutSuppressionWarningMessage,
            inputMonitoringFailureMessage: shortcutMonitoringFailureMessage
        )
    }

    static func hotkeyMonitorFallbackPlanAfterRegistrationFailure(
        shortcut: ActivationShortcut,
        inputMonitoringState: AuthorizationState,
        accessibilityState: AuthorizationState
    ) -> HotkeyMonitorPlan {
        monitorPlan(
            shortcut: shortcut,
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState,
            registeredHotkeyAccessibilityWarning: shortcutInjectionWarningMessage,
            eventTapAccessibilityWarning: shortcutSuppressionWarningMessage,
            inputMonitoringFailureMessage: shortcutMonitoringFailureMessage,
            preferRegisteredHotkey: false
        )
    }

    static func modeCycleShortcutMonitorPlan(
        shortcut: ActivationShortcut,
        inputMonitoringState: AuthorizationState,
        accessibilityState: AuthorizationState
    ) -> HotkeyMonitorPlan {
        monitorPlan(
            shortcut: shortcut,
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState,
            registeredHotkeyAccessibilityWarning: nil,
            eventTapAccessibilityWarning: modeCycleShortcutSuppressionWarningMessage,
            inputMonitoringFailureMessage: modeCycleShortcutMonitoringFailureMessage
        )
    }

    static func promptCycleShortcutMonitorPlan(
        shortcut: ActivationShortcut,
        inputMonitoringState: AuthorizationState,
        accessibilityState: AuthorizationState
    ) -> HotkeyMonitorPlan {
        monitorPlan(
            shortcut: shortcut,
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState,
            registeredHotkeyAccessibilityWarning: nil,
            eventTapAccessibilityWarning: promptCycleShortcutSuppressionWarningMessage,
            inputMonitoringFailureMessage: promptCycleShortcutMonitoringFailureMessage
        )
    }

    static func processorShortcutMonitorPlan(
        shortcut: ActivationShortcut,
        inputMonitoringState: AuthorizationState,
        accessibilityState: AuthorizationState
    ) -> HotkeyMonitorPlan {
        monitorPlan(
            shortcut: shortcut,
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState,
            registeredHotkeyAccessibilityWarning: nil,
            eventTapAccessibilityWarning: processorShortcutSuppressionWarningMessage,
            inputMonitoringFailureMessage: processorShortcutMonitoringFailureMessage
        )
    }

    private static func monitorPlan(
        shortcut: ActivationShortcut,
        inputMonitoringState: AuthorizationState,
        accessibilityState: AuthorizationState,
        registeredHotkeyAccessibilityWarning: String?,
        eventTapAccessibilityWarning: String?,
        inputMonitoringFailureMessage: String,
        preferRegisteredHotkey: Bool = true
    ) -> HotkeyMonitorPlan {
        guard !shortcut.isEmpty else {
            return HotkeyMonitorPlan(strategy: nil, statusMessage: nil)
        }

        if preferRegisteredHotkey, shortcut.isRegisteredHotkeyCompatible {
            let statusMessage = accessibilityState == .granted ? nil : registeredHotkeyAccessibilityWarning
            return HotkeyMonitorPlan(strategy: .registeredHotkey, statusMessage: statusMessage)
        }

        guard inputMonitoringState == .granted else {
            return HotkeyMonitorPlan(strategy: nil, statusMessage: inputMonitoringFailureMessage)
        }

        if accessibilityState == .granted {
            return HotkeyMonitorPlan(
                strategy: .eventTap(.listenAndSuppress),
                statusMessage: nil
            )
        }

        return HotkeyMonitorPlan(
            strategy: .eventTap(.listenOnly),
            statusMessage: eventTapAccessibilityWarning
        )
    }

    static func permissionRefreshSequence(
        requestMediaPermissions: Bool,
        promptAccessibility: Bool,
        requestInputMonitoringPermission: Bool,
        accessibilityStateAfterPrompt: AuthorizationState
    ) -> [PermissionRefreshStep] {
        var steps: [PermissionRefreshStep] = []

        if requestMediaPermissions {
            steps.append(.mediaPermissions)
        }

        if promptAccessibility {
            steps.append(.accessibility)
        }

        if requestInputMonitoringPermission, accessibilityStateAfterPrompt == .granted {
            steps.append(.inputMonitoring)
        }

        return steps
    }

    static func shouldAwaitAccessibilityAuthorization(
        promptAccessibility: Bool,
        requestInputMonitoringPermission: Bool,
        accessibilityStateAfterPrompt: AuthorizationState
    ) -> Bool {
        promptAccessibility &&
        requestInputMonitoringPermission &&
        accessibilityStateAfterPrompt != .granted
    }

    static func permissionSettingsPrompt(for destination: PermissionSettingsDestination) -> PermissionSettingsPrompt {
        switch destination {
        case .accessibility:
            return PermissionSettingsPrompt(
                messageText: "Accessibility Still Needs Approval",
                informativeText: "VoicePi can continue setup by opening the Accessibility settings page. Open System Settings now?",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        case .microphone:
            return PermissionSettingsPrompt(
                messageText: "Microphone Still Needs Approval",
                informativeText: "VoicePi can continue setup by opening the Microphone settings page. Open System Settings now?",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            )
        case .speech:
            return PermissionSettingsPrompt(
                messageText: "Speech Recognition Still Needs Approval",
                informativeText: "VoicePi can continue setup by opening the Speech Recognition settings page. Open System Settings now?",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
            )
        case .inputMonitoring:
            return PermissionSettingsPrompt(
                messageText: "Input Monitoring Still Needs Approval",
                informativeText: "VoicePi can continue setup by opening the Input Monitoring settings page. Open System Settings now?",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
            )
        }
    }

    static func permissionSettingsTransitionStyle(
        for destination: PermissionSettingsDestination
    ) -> PermissionSettingsTransitionStyle {
        _ = destination
        return .customPrompt
    }

    static func mediaPermissionTransitionStyle(
        for destination: PermissionSettingsDestination,
        authorizationState: AuthorizationState
    ) -> MediaPermissionTransitionStyle {
        switch authorizationState {
        case .unknown:
            return .customPrePromptThenSystemRequest
        case .granted, .denied, .restricted:
            return .customSettingsPrompt
        }
    }

    static func mediaPermissionPrePrompt(for destination: PermissionSettingsDestination) -> MediaPermissionPrePrompt {
        switch destination {
        case .microphone:
            return MediaPermissionPrePrompt(
                messageText: "Microphone Permission",
                informativeText: "VoicePi uses the microphone to capture your dictation. Continue to the macOS permission prompt?",
                continueTitle: "Continue"
            )
        case .speech:
            return MediaPermissionPrePrompt(
                messageText: "Speech Recognition Permission",
                informativeText: "VoicePi uses Speech Recognition for on-device and Apple speech transcription. Continue to the macOS permission prompt?",
                continueTitle: "Continue"
            )
        case .accessibility, .inputMonitoring:
            return MediaPermissionPrePrompt(
                messageText: "Permission Required",
                informativeText: "Continue to the macOS permission prompt?",
                continueTitle: "Continue"
            )
        }
    }

    static func shouldActivateAppForPermissionPrompt(source: PermissionPromptSource) -> Bool {
        switch source {
        case .accessibilityFollowUp, .launchFollowUp:
            return true
        case .manualSettingsButton:
            return false
        }
    }

    func start() {
        floatingPanelController.applyInterfaceTheme(model.interfaceTheme)
        inputFallbackPanelController.applyInterfaceTheme(model.interfaceTheme)
        externalProcessorResultPanelController.applyInterfaceTheme(model.interfaceTheme)
        resultReviewPanelController.applyInterfaceTheme(model.interfaceTheme)
        selectionRegenerateHintController.applyInterfaceTheme(model.interfaceTheme)
        dictionarySuggestionToastController.applyInterfaceTheme(model.interfaceTheme)
        inputFallbackPanelController.onCopySuccess = { [weak self] in
            self?.statusBarController?.setTransientStatus("Copied")
        }
        externalProcessorResultPanelController.onInsertRequested = { [weak self] text in
            Task { @MainActor [weak self] in
                self?.insertExternalProcessorResultText(text)
            }
        }
        externalProcessorResultPanelController.onCopyRequested = { [weak self] _ in
            self?.statusBarController?.setTransientStatus("Copied")
        }
        externalProcessorResultPanelController.onRetryRequested = { [weak self] in
            Task { @MainActor [weak self] in
                self?.retryExternalProcessorResultText()
            }
        }
        externalProcessorResultPanelController.onDismissRequested = { [weak self] in
            self?.dismissExternalProcessorResultPanel()
        }
        resultReviewPanelController.onInsertRequested = { [weak self] text in
            Task { @MainActor [weak self] in
                self?.insertReviewedText(text)
            }
        }
        resultReviewPanelController.onCopyRequested = { [weak self] _ in
            self?.statusBarController?.setTransientStatus("Copied")
        }
        resultReviewPanelController.onPromptSelectionChanged = { [weak self] presetID in
            self?.updateResultReviewPromptSelection(presetID)
        }
        resultReviewPanelController.onRetryRequested = { [weak self] in
            Task { @MainActor [weak self] in
                self?.retryReviewedText()
            }
        }
        resultReviewPanelController.onDismissRequested = { [weak self] in
            self?.dismissResultReviewPanel()
        }
        selectionRegenerateHintController.onPrimaryAction = { [weak self] payload in
            Task { @MainActor [weak self] in
                self?.openRecentInsertionReviewFromHint(payload)
            }
        }
        dictionarySuggestionToastController.onApprove = { [weak self] suggestion in
            guard let self else { return }
            self.model.approveDictionarySuggestion(id: suggestion.id)
            self.statusBarController?.refreshAll()
            self.statusBarController?.setTransientStatus("Approved dictionary suggestion")
        }
        dictionarySuggestionToastController.onReview = { [weak self] _ in
            guard let self else { return }
            self.statusBarController?.showSettingsWindow(section: .dictionary)
            self.statusBarController?.setTransientStatus("Open Dictionary suggestions in Settings")
        }
        dictionarySuggestionToastController.onDismiss = { [weak self] _ in
            self?.statusBarController?.setTransientStatus("Suggestion kept for later review")
        }
        model.$interfaceTheme
            .sink { [weak self] theme in
                self?.floatingPanelController.applyInterfaceTheme(theme)
                self?.inputFallbackPanelController.applyInterfaceTheme(theme)
                self?.externalProcessorResultPanelController.applyInterfaceTheme(theme)
                self?.resultReviewPanelController.applyInterfaceTheme(theme)
                self?.selectionRegenerateHintController.applyInterfaceTheme(theme)
                self?.dictionarySuggestionToastController.applyInterfaceTheme(theme)
            }
            .store(in: &cancellables)

        speechRecorder.delegate = self
        recordingShortcutAction.onPress = { [weak self] in
            Task { @MainActor [weak self] in
                self?.beginRecording()
            }
        }
        recordingShortcutAction.shortcut = model.activationShortcut

        modeCycleShortcutAction.onPress = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleModeCycleShortcutPress()
            }
        }
        modeCycleShortcutAction.shortcut = model.modeCycleShortcut

        promptCycleShortcutAction.onPress = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handlePromptCycleShortcutPress()
            }
        }
        promptCycleShortcutAction.shortcut = model.promptCycleShortcut

        processorShortcutAction.onPress = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleProcessorShortcutPress()
            }
        }
        processorShortcutAction.shortcut = model.processorShortcut

        let statusBarController = StatusBarController(model: model)
        statusBarController.delegate = self
        statusBarController.start()
        self.statusBarController = statusBarController
        applyUpdateExperience(.idle(source: .unknown))
        bootstrapHotkeyMonitoring()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let source = await self.refreshInstallationSource(forceRefresh: true)
            self.applyUpdateExperience(.idle(source: source))
            let launchPermissionPlan = Self.launchPermissionPlan(
                activationShortcut: self.model.activationShortcut,
                modeCycleShortcut: self.model.modeCycleShortcut,
                processorShortcut: self.model.processorShortcut,
                promptCycleShortcut: self.model.promptCycleShortcut,
                inputMonitoringState: self.currentInputMonitoringAuthorizationState()
            )
            await self.refreshPermissionStates(
                promptAccessibility: launchPermissionPlan.promptAccessibility,
                requestMediaPermissions: launchPermissionPlan.requestMediaPermissions,
                requestInputMonitoringPermission: launchPermissionPlan.requestInputMonitoringPermission,
                useSystemAccessibilityPrompt: launchPermissionPlan.useSystemAccessibilityPrompt,
                inputMonitoringPromptSource: .launchFollowUp
            )
            _ = await self.checkForUpdates(trigger: .automatic)
        }
    }

    func stop() {
        accessibilityAuthorizationFollowUpTask?.cancel()
        inputMonitoringAuthorizationFollowUpTask?.cancel()
        pendingErrorHideTask?.cancel()
        postInjectionLearningTask?.cancel()
        resultReviewRetryTask?.cancel()
        postInjectionLearningTask = nil
        postInjectionLearningRunRegistry.clear()
        resultReviewRetryTask = nil
        refinementReviewSession = nil
        dictionarySuggestionToastController.hide()
        selectionRegenerateHintController.hide()
        resultReviewPanelController.hide()
        modeCycleRepeatTask?.cancel()
        startupHotkeyBootstrapTask?.cancel()
        modeCycleRepeatTask = nil
        startupHotkeyBootstrapTask = nil
        recordingShortcutAction.stop()
        modeCycleShortcutAction.stop()
        promptCycleShortcutAction.stop()
        processorShortcutAction.stop()

        if speechRecorder.isRecording {
            Task { @MainActor [weak self] in
                guard let self else { return }
                _ = await self.speechRecorder.stopRecording()
            }
        }

        Task { @MainActor [weak self] in
            await self?.realtimeASRSessionCoordinator.close()
        }
    }

    private func handleLanguageChange(_ language: SupportedLanguage) {
        model.selectedLanguage = language
        speechRecorder.updateLocale(identifier: language.localeIdentifier)
        statusBarController?.refreshAll()
    }

    private func cyclePostProcessingModeFromShortcut() {
        model.cyclePostProcessingMode()
        let autoHideDelay: UInt64? = modeCycleSessionActive ? nil : 1_100_000_000
        floatingPanelController.showModeSwitch(
            modeTitle: model.postProcessingMode.title,
            refinementPromptTitle: model.resolvedPromptPreset().title,
            autoHideDelayNanoseconds: autoHideDelay
        )
        statusBarController?.refreshAll()
        statusBarController?.setTransientStatus("Text processing: \(model.modeDisplayTitle(for: model.postProcessingMode))")
    }

    private func cycleRefinementPromptFromShortcut() {
        guard let cycledPrompt = model.cycleActivePromptSelection() else {
            return
        }

        let destination = promptDestinationInspector.currentDestinationContext()
        let effectivePrompt = model.resolvedPromptPreset(for: .voicePi, destination: destination)
        let effectivePresetID = effectivePrompt.presetID ?? PromptPreset.builtInDefaultID
        let cycledPresetID = cycledPrompt.presetID ?? PromptPreset.builtInDefaultID
        let didStrictBindingOverride = model.promptWorkspace.strictModeEnabled && effectivePresetID != cycledPresetID
        let statusPrefix = didStrictBindingOverride ? "Prompt default" : "Prompt"

        floatingPanelController.showModeSwitch(
            modeTitle: model.postProcessingMode.title,
            refinementPromptTitle: cycledPrompt.title,
            autoHideDelayNanoseconds: 1_100_000_000
        )
        statusBarController?.refreshAll()
        statusBarController?.setTransientStatus("\(statusPrefix): \(cycledPrompt.title)")
    }

    private func bootstrapHotkeyMonitoring() {
        startupHotkeyBootstrapTask?.cancel()
        let initialStatus = ensureHotkeyMonitorRunning()
        guard initialStatus == Self.shortcutRegistrationFailureMessage
            || initialStatus == Self.modeCycleShortcutRegistrationFailureMessage
            || initialStatus == Self.promptCycleShortcutRegistrationFailureMessage
            || initialStatus == Self.processorShortcutRegistrationFailureMessage else {
            return
        }

        startupHotkeyBootstrapTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.startupHotkeyBootstrapTask = nil
            }

            for _ in 0..<Self.startupHotkeyBootstrapMaxAttempts {
                try? await Task.sleep(nanoseconds: Self.startupHotkeyBootstrapRetryNanoseconds)
                guard !Task.isCancelled else { return }

                let status = self.ensureHotkeyMonitorRunning()
                guard status == Self.shortcutRegistrationFailureMessage
                    || status == Self.modeCycleShortcutRegistrationFailureMessage
                    || status == Self.promptCycleShortcutRegistrationFailureMessage
                    || status == Self.processorShortcutRegistrationFailureMessage else {
                    return
                }
            }
        }
    }

    private func handleModeCycleShortcutPress() {
        guard Self.shouldStartModeCycleRepeat(
            shortcut: model.modeCycleShortcut,
            isRecording: speechRecorder.isRecording,
            isStartingRecording: isStartingRecording,
            isProcessingRelease: isProcessingRelease
        ) else { return }

        let interactionStyle = Self.modeCycleInteractionStyle(for: model.modeCycleShortcut)
        if interactionStyle == .modifierHeldSession {
            modeCycleSessionActive = true
        }

        cyclePostProcessingModeFromShortcut()
        switch interactionStyle {
        case .modifierHeldSession:
            startModeCycleShortcutSession()
        case .holdRepeat:
            startModeCycleShortcutRepeat()
        }
    }

    private func handlePromptCycleShortcutPress() {
        guard Self.shouldStartModeCycleRepeat(
            shortcut: model.promptCycleShortcut,
            isRecording: speechRecorder.isRecording,
            isStartingRecording: isStartingRecording,
            isProcessingRelease: isProcessingRelease
        ) else { return }

        cycleRefinementPromptFromShortcut()
    }

    private func startModeCycleShortcutRepeat() {
        modeCycleRepeatTask?.cancel()
        modeCycleRepeatTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: Self.modeCycleRepeatDelayNanoseconds)
            while !Task.isCancelled {
                guard Self.shouldStartModeCycleRepeat(
                    shortcut: self.model.modeCycleShortcut,
                    isRecording: self.speechRecorder.isRecording,
                    isStartingRecording: self.isStartingRecording,
                    isProcessingRelease: self.isProcessingRelease
                ),
                self.model.modeCycleShortcut.isCurrentlyHeld() else {
                    self.modeCycleRepeatTask = nil
                    return
                }

                self.cyclePostProcessingModeFromShortcut()
                try? await Task.sleep(nanoseconds: Self.modeCycleRepeatIntervalNanoseconds)
            }
            self.modeCycleRepeatTask = nil
        }
    }

    private func startModeCycleShortcutSession() {
        modeCycleRepeatTask?.cancel()
        modeCycleRepeatTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard self.model.modeCycleShortcut.areRequiredModifiersHeld() else {
                    self.modeCycleSessionActive = false
                    self.floatingPanelController.showModeSwitch(
                        modeTitle: self.model.postProcessingMode.title,
                        refinementPromptTitle: self.model.resolvedPromptPreset().title,
                        autoHideDelayNanoseconds: 220_000_000
                    )
                    self.modeCycleRepeatTask = nil
                    return
                }

                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            self.modeCycleRepeatTask = nil
        }
    }

    private func handleProcessorShortcutPress() {
        switch Self.processorShortcutPressAction(
            isRecording: speechRecorder.isRecording,
            isStartingRecording: isStartingRecording,
            isProcessingRelease: isProcessingRelease
        ) {
        case .ignore:
            return
        case .stopRecording:
            endRecordingAndInject()
        case .cancelProcessing:
            cancelProcessingAndHideOverlay()
        case .startProcessorCapture(let override):
            beginRecording(workflowOverride: override)
        }
    }

    private func beginRecording(
        workflowOverride: RecordingWorkflowOverride? = nil
    ) {
        if isAwaitingRealtimeFinalization {
            return
        }

        switch Self.pressAction(
            isRecording: speechRecorder.isRecording,
            isStartingRecording: isStartingRecording,
            isProcessingRelease: isProcessingRelease,
            hasConfirmedSelectionForRewrite: hasConfirmedSelectionForRewrite(),
            workflowOverride: workflowOverride
        ) {
        case .ignore:
            return
        case .stopRecording:
            endRecordingAndInject()
            return
        case .cancelProcessing:
            cancelProcessingAndHideOverlay()
            return
        case .startSelectionRewrite:
            beginSelectionRewriteFromCurrentSelection()
            return
        case .startRecording:
            break
        }

        isStartingRecording = true
        activeRecordingWorkflowOverride = workflowOverride
        let captureWorkflow = Self.effectiveProcessingWorkflow(
            postProcessingMode: model.postProcessingMode,
            refinementProvider: model.refinementProvider,
            override: workflowOverride
        )
        activeCapturedSourceSnapshot = Self.capturedSourceSnapshot(
            workflow: captureWorkflow,
            workflowOverride: workflowOverride,
            targetSnapshot: editableTextTargetInspector.currentSnapshot(),
            sourceApplicationBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
        activeRecordingStartedAt = nil
        activeFloatingRefiningPresentationStartedAt = nil
        activeRecordingLatencyTrace = RecordingLatencyTrace()
        realtimeOverlayUpdateGate.reset()
        latestTranscript = ""
        cancelPostInjectionLearning()
        clearExternalProcessorResultState()
        clearResultReviewState()
        statusBarController?.setTransientStatus(nil)
        inputFallbackPanelController.hide()

        Task { @MainActor [weak self] in
            guard let self else { return }

            let permissionsReady = await self.prepareForRecording()
            guard permissionsReady else {
                self.finishActiveRecordingLatency(.cancelled)
                self.clearActiveRecordingWorkflowState()
                self.isStartingRecording = false
                return
            }

            do {
                self.speechRecorder.updateLocale(identifier: self.model.selectedLanguage.localeIdentifier)
                self.floatingPanelController.showRecording(
                    transcript: "",
                    sourcePreviewText: self.activeCapturedSourceSnapshot?.previewText
                )
                self.model.updateOverlayRecording(transcript: "", level: 0)
                self.statusBarController?.setRecording(true)

                if self.model.asrBackend.usesRealtimeStreaming {
                    try await self.startRealtimeRecordingSession()
                } else {
                    try await self.speechRecorder.startRecording(mode: self.model.asrBackend.speechRecorderMode)
                }
            } catch {
                self.statusBarController?.setRecording(false)
                self.floatingPanelController.hide()
                self.model.hideOverlay()
                if case let asrError as RemoteASRStreamingError = error, asrError == .cancelled {
                    self.finishActiveRecordingLatency(.cancelled)
                    self.clearActiveRecordingWorkflowState()
                    self.isStartingRecording = false
                    return
                }
                self.finishActiveRecordingLatency(.failed(error.localizedDescription))
                self.clearActiveRecordingWorkflowState()
                self.presentTransientError(error.localizedDescription)
            }

            self.isStartingRecording = false
        }
    }

    private func endRecordingAndInject() {
        guard !isProcessingRelease else { return }

        if isStartingRecording {
            if model.asrBackend.usesRealtimeStreaming {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.realtimeASRSessionCoordinator.cancelConnecting()
                    self.speechRecorder.cancelImmediately()
                    self.finishActiveRecordingLatency(.cancelled)
                    self.isStartingRecording = false
                    self.clearActiveRecordingWorkflowState()
                    self.statusBarController?.setRecording(false)
                    self.floatingPanelController.hide()
                    self.model.hideOverlay()
                }
                return
            }

            Task { @MainActor [weak self] in
                while let self, self.isStartingRecording {
                    try? await Task.sleep(nanoseconds: 30_000_000)
                }
                self?.endRecordingAndInject()
            }
            return
        }

        guard speechRecorder.isRecording else { return }
        isProcessingRelease = true
        statusBarController?.setRecording(false)

        processingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.processingTask = nil
            }

            self.markActiveRecordingLatency(.stopRequested)
            let localTranscript = await self.speechRecorder.stopRecording()
            let recordingDurationMilliseconds = self.consumeCurrentRecordingDurationMilliseconds()
            guard !Task.isCancelled, self.isProcessingRelease else { return }

            let asrTranscript = await self.resolveTranscriptAfterRecording(localFallback: localTranscript)
            let trimmedASRTranscript = asrTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedASRTranscript.isEmpty {
                self.markActiveRecordingLatency(.transcriptResolved)
            }
            guard !Task.isCancelled, self.isProcessingRelease else { return }

            let captured = trimmedASRTranscript

            guard !captured.isEmpty else {
                self.finishActiveRecordingLatency(.cancelled)
                self.floatingPanelController.hide()
                self.model.hideOverlay()
                self.statusBarController?.setTransientStatus(nil)
                self.isProcessingRelease = false
                self.clearActiveRecordingWorkflowState()
                return
            }

            let workflow = Self.effectiveProcessingWorkflow(
                postProcessingMode: self.model.postProcessingMode,
                refinementProvider: self.model.refinementProvider,
                override: self.activeRecordingWorkflowOverride
            )
            let finalText = await self.refineIfNeeded(
                captured,
                workflow: workflow,
                workflowOverride: self.activeRecordingWorkflowOverride,
                sourceSnapshot: self.activeCapturedSourceSnapshot
            )
            self.markActiveRecordingLatency(.refinementCompleted)
            guard !Task.isCancelled, self.isProcessingRelease else { return }

            let didSucceed = await self.externalProcessorRefiner.didSucceedOnLastInvocation
            let failureAction = Self.postProcessingFailureAction(
                workflowOverride: self.activeRecordingWorkflowOverride,
                didExternalProcessorSucceed: didSucceed
            )
            let successAction = Self.postProcessingSuccessAction(
                workflowOverride: self.activeRecordingWorkflowOverride,
                didExternalProcessorSucceed: didSucceed
            )

            if successAction == .presentExternalProcessorResultPanel {
                await self.ensureFloatingRefiningOverlayRemainsVisibleIfNeeded()
                self.presentExternalProcessorResultPanel(
                    text: finalText,
                    sourceText: captured,
                    workflowOverride: self.activeRecordingWorkflowOverride,
                    sourceApplicationBundleID: self.activeCapturedSourceSnapshot?.sourceApplicationBundleID,
                    recordingDurationMilliseconds: recordingDurationMilliseconds
                )
                self.finishActiveRecordingLatency(.success)
            } else if failureAction == .surfaceProcessorFailure {
                await self.ensureFloatingRefiningOverlayRemainsVisibleIfNeeded()
                let processorFailureMessage = await self.externalProcessorRefiner.lastFailureMessageOnLastInvocation
                let trimmedFailureMessage = processorFailureMessage?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let failureMessage = trimmedFailureMessage.isEmpty
                    ? "Processor shortcut requires a working external processor. Check Processors settings."
                    : trimmedFailureMessage
                self.presentTransientError(failureMessage)
                self.finishActiveRecordingLatency(.failed(failureMessage))
                self.floatingPanelController.hide()
            } else {
                let targetSnapshot = self.editableTextTargetInspector.currentSnapshot()
                switch Self.transcriptDeliveryRoute(
                    for: finalText,
                    targetInspection: targetSnapshot.inspection
                ) {
                case .emptyResult:
                    await self.ensureFloatingRefiningOverlayRemainsVisibleIfNeeded()
                    self.recentInsertionRewriteCoordinator.cancelTracking()
                    self.statusBarController?.setTransientStatus(nil)
                    self.finishActiveRecordingLatency(.cancelled)
                    self.floatingPanelController.hide()
                case .injectableTarget:
                    await self.ensureFloatingRefiningOverlayRemainsVisibleIfNeeded()
                    do {
                        let injectionRecord = try await self.textInjector.injectAndRecord(text: finalText)
                        self.markActiveRecordingLatency(.injectionCompleted)
                        self.statusBarController?.setTransientStatus("Injected")
                        self.model.recordHistoryEntry(
                            text: finalText,
                            recordingDurationMilliseconds: recordingDurationMilliseconds
                        )
                        self.beginPostInjectionLearning(
                            targetSnapshot: targetSnapshot,
                            injectionRecord: injectionRecord
                        )
                        let resolvedPrompt = self.resolvedRefinementPrompt(for: workflow)
                        self.startRecentInsertionRewriteTracking(
                            rawTranscript: captured,
                            insertedText: injectionRecord.text,
                            appliedPromptPresetID: resolvedPrompt?.presetID,
                            targetSnapshot: targetSnapshot,
                            sourceApplicationBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                        )
                        self.finishActiveRecordingLatency(.success)
                    } catch {
                        self.finishActiveRecordingLatency(.failed(error.localizedDescription))
                        self.presentTransientError(error.localizedDescription)
                    }
                    self.floatingPanelController.hide()
                case .fallbackPanel:
                    await self.ensureFloatingRefiningOverlayRemainsVisibleIfNeeded()
                    self.recentInsertionRewriteCoordinator.cancelTracking()
                    if let payload = InputFallbackPanelPayload(text: finalText) {
                        self.model.recordHistoryEntry(
                            text: finalText,
                            recordingDurationMilliseconds: recordingDurationMilliseconds
                        )
                        self.presentInputFallbackPanel(payload)
                        self.finishActiveRecordingLatency(.success)
                    } else {
                        self.finishActiveRecordingLatency(.cancelled)
                    }
                }
            }

            self.model.hideOverlay()
            self.isProcessingRelease = false
            self.clearActiveRecordingWorkflowState()
        }
    }

    private func cancelProcessingAndHideOverlay() {
        guard isProcessingRelease else { return }

        processingTask?.cancel()
        processingTask = nil
        cancelPostInjectionLearning()
        clearResultReviewState()
        isProcessingRelease = false
        finishActiveRecordingLatency(.cancelled)
        clearActiveRecordingWorkflowState()
        latestTranscript = ""
        statusBarController?.setRecording(false)
        statusBarController?.setTransientStatus(nil)
        floatingPanelController.hide()
        model.hideOverlay()
    }

    private func clearActiveRecordingWorkflowState() {
        activeRecordingWorkflowOverride = nil
        activeCapturedSourceSnapshot = nil
        activeRecordingLatencyTrace = nil
        activeFloatingRefiningPresentationStartedAt = nil
        realtimeOverlayUpdateGate.reset()
        realtimeAudioFramePump = nil
    }

    private func presentInputFallbackPanel(_ payload: InputFallbackPanelPayload) {
        floatingPanelController.hide(immediately: true) { [weak self] in
            guard let self else { return }
            self.inputFallbackPanelController.show(payload: payload)
        }
    }

    private func presentExternalProcessorResultPanel(
        text: String,
        sourceText: String,
        workflowOverride: RecordingWorkflowOverride?,
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
        externalProcessorResultSession = ExternalProcessorResultSession(
            payload: payload,
            sourceText: sourceText,
            workflowOverride: workflowOverride,
            sourceApplicationBundleID: sourceApplicationBundleID,
            recordingDurationMilliseconds: max(0, recordingDurationMilliseconds)
        )
        selectionRegenerateHintController.hide()
        resultReviewPanelController.hide()
        floatingPanelController.hide(immediately: true)
        model.hideOverlay()
        statusBarController?.setTransientStatus(nil)
        inputFallbackPanelController.hide()
        externalProcessorResultPanelController.show(payload: payload)
    }

    private func presentResultReviewPanel(
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
        let sanitizedOriginalText = ExternalProcessorOutputSanitizer.sanitize(originalText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedOriginalText.isEmpty else {
            presentTransientError("Original text is unavailable for review.")
            return
        }

        let selectedPromptPresetID = Self.normalizedResultReviewPromptPresetID(
            selectedPromptPresetIDOverride
        ) ?? resolvedRefinementPrompt(for: workflow)?.presetID ?? PromptPreset.builtInDefaultID
        let fallbackPromptTitle = resolvedRefinementPrompt(for: workflow)?.title
            ?? PromptPreset.builtInDefault.title
        let selectedPromptTitle = Self.normalizedResultReviewPromptTitle(
            selectedPromptTitleOverride,
            fallback: fallbackPromptTitle
        )
        let session = RefinementReviewSession(
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
        selectionRegenerateHintController.hide()
        clearExternalProcessorResultState()
        floatingPanelController.hide(immediately: true)
        model.hideOverlay()
        statusBarController?.setTransientStatus(nil)
        inputFallbackPanelController.hide()
        resultReviewPanelController.show(payload: payload)
    }

    private func clearExternalProcessorResultState() {
        externalProcessorResultRetryTask?.cancel()
        externalProcessorResultRetryTask = nil
        externalProcessorResultSession = nil
        externalProcessorResultPanelController.hide()
    }

    private func dismissExternalProcessorResultPanel() {
        clearExternalProcessorResultState()
    }

    private func updateResultReviewPromptSelection(_ presetID: String) {
        guard var session = refinementReviewSession else { return }

        let resolvedPrompt = model.resolvedPromptPresetForExplicitPresetID(presetID)
        let updatedSelection = Self.updatedResultReviewPromptSelection(
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

    private func resultReviewPromptOptions() -> [ResultReviewPanelPromptOption] {
        model.orderedPromptCyclePresets().map {
            .init(presetID: $0.id, title: $0.resolvedTitle)
        }
    }

    private func resultReviewPayload(
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

    private func clearResultReviewState() {
        resultReviewRetryTask?.cancel()
        resultReviewRetryTask = nil
        refinementReviewSession = nil
        selectionRegenerateHintController.hide()
        resultReviewPanelController.hide()
    }

    private func dismissResultReviewPanel() {
        clearResultReviewState()
    }

    private func retryReviewedText(
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

    private func insertReviewedText(_ text: String) {
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

    private func retryExternalProcessorResultText() {
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

    private func insertExternalProcessorResultText(_ text: String) {
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

    private func rewriteSelectionAnchor(
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

    private func normalizedSnapshotSelectedText(
        _ snapshot: EditableTextTargetSnapshot
    ) -> String? {
        let normalizedText = ExternalProcessorOutputSanitizer.sanitize(snapshot.selectedText ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }
        return normalizedText
    }

    private func hasConfirmedSelectionForRewrite() -> Bool {
        let snapshot = editableTextTargetInspector.currentSnapshot()
        return rewriteSelectionAnchor(
            from: snapshot,
            sourceApplicationBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        ) != nil
    }

    private func beginSelectionRewriteFromCurrentSelection() {
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

    private func cancelPostInjectionLearning() {
        postInjectionLearningTask?.cancel()
        postInjectionLearningTask = nil
        postInjectionLearningRunRegistry.clear()
        dictionarySuggestionToastController.hide()
        selectionRegenerateHintController.hide()
    }

    private func beginPostInjectionLearning(
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

    private func captureDictionarySuggestions(
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

    private func startRecentInsertionRewriteTracking(
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

    private func presentRecentInsertionReviewPanel(
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

    private func refreshSelectionRegenerateHint(from snapshot: EditableTextTargetSnapshot) {
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

    private func openRecentInsertionReviewFromHint(_ payload: SelectionRegenerateHintPayload) {
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

    private func restoreResultReviewSourceApplicationIfNeeded(
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

    private func restoreAndValidateResultReviewSelection(
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

    private func selectionMatchesAnchor(
        _ snapshot: EditableTextTargetSnapshot,
        selectionAnchor: ResultReviewSelectionAnchor
    ) -> Bool {
        Self.resultReviewSelectionMatchesAnchor(snapshot, selectionAnchor: selectionAnchor)
    }

    private func resolveTranscriptAfterRecording(localFallback: String) async -> String {
        if model.asrBackend.usesRealtimeStreaming {
            let realtimeStatus = await realtimeASRSessionCoordinator.statusSnapshot()
            let resolution = Self.realtimeStopResolution(
                backend: model.asrBackend,
                isRealtimeStreamingReady: realtimeStatus.isRealtimeStreamingReady,
                degradedToBatchFallback: realtimeStatus.degradedToBatchFallback,
                hasRecordedAudio: realtimeStatus.hasCapturedAudio,
                localFallback: localFallback
            )

            switch resolution {
            case .silentCancel:
                await realtimeASRSessionCoordinator.close()
                return ""
            case .batchFallback:
                await realtimeASRSessionCoordinator.close()
                return await resolveBatchTranscriptAfterRecording(localFallback: localFallback)
            case .realtimeFinalization:
                isAwaitingRealtimeFinalization = true
                defer { isAwaitingRealtimeFinalization = false }

                do {
                    let transcript = try await realtimeASRSessionCoordinator.stopAndResolveFinal()
                    return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch let error as RemoteASRStreamingError where error == .cancelled {
                    return ""
                } catch {
                    await realtimeASRSessionCoordinator.close()
                    return await resolveBatchTranscriptAfterRecording(localFallback: localFallback)
                }
            }
        }

        return await resolveBatchTranscriptAfterRecording(localFallback: localFallback)
    }

    private func resolveBatchTranscriptAfterRecording(localFallback: String) async -> String {
        return await AppWorkflowSupport.resolveTranscriptAfterRecording(
            backend: model.asrBackend,
            localFallback: localFallback,
            audioURL: speechRecorder.latestAudioFileURL,
            language: model.selectedLanguage,
            configuration: model.remoteASRConfiguration,
            remoteASR: remoteASRClient,
            onPresentation: { [weak self] presentation in
                guard let self else { return }
                switch presentation {
                case .transcribing(let overlayTranscript, let statusText):
                    self.floatingPanelController.showRefining(
                        transcript: "Transcribing…",
                        sourcePreviewText: self.activeCapturedSourceSnapshot?.previewText
                    )
                    self.model.updateOverlayRefining(transcript: overlayTranscript)
                    self.statusBarController?.setTransientStatus(statusText)
                case .refining(let overlayTranscript, let statusText):
                    self.floatingPanelController.showRefining(
                        transcript: localFallback,
                        sourcePreviewText: self.activeCapturedSourceSnapshot?.previewText
                    )
                    self.model.updateOverlayRefining(transcript: overlayTranscript)
                    self.statusBarController?.setTransientStatus(statusText)
                }
            },
            onError: { [weak self] message in
                self?.presentTransientError(message)
            }
        )
    }

    private func startRealtimeRecordingSession() async throws {
        let realtimeCoordinator = realtimeASRSessionCoordinator
        let framePump = RealtimeAudioFramePump(
            maximumPendingBytes: RealtimeASRSessionCoordinator.preconnectBufferByteLimit,
            handler: { frame in
                await realtimeCoordinator.handleCapturedFrame(frame)
            },
            overflowHandler: {
                await realtimeCoordinator.handleCaptureBackpressureLimitExceeded()
            }
        )
        realtimeAudioFramePump = framePump
        let callbacks = RealtimeASRSessionCoordinator.Callbacks(
            onPartial: { [weak self] text in
                self?.updateRealtimeOverlayTranscript(text)
            },
            onFinal: { [weak self] text in
                self?.updateRealtimeOverlayTranscript(text)
            },
            onTerminalError: { [weak self] message in
                self?.handleRealtimeTerminalError(message)
            }
        )

        do {
            try await realtimeASRSessionCoordinator.start(
                configuration: model.remoteASRConfiguration,
                backend: model.asrBackend,
                language: model.selectedLanguage,
                callbacks: callbacks
            )
            try await speechRecorder.startRecording(
                mode: .captureOnly,
                onCapturedAudioFrame: { frame in
                    framePump.submit(frame)
                }
            )
        } catch {
            realtimeAudioFramePump = nil
            speechRecorder.cancelImmediately()
            await realtimeASRSessionCoordinator.close()
            throw error
        }
    }

    private func updateRealtimeOverlayTranscript(_ text: String) {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            markActiveRecordingLatency(.firstPartialReceived)
        }
        publishRecordingOverlayUpdate(
            transcript: text,
            level: model.overlayState.level
        )
    }

    private func publishRecordingOverlayUpdate(
        transcript: String,
        level: CGFloat,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        switch realtimeOverlayUpdateGate.consume(
            transcript: transcript,
            level: level,
            now: now
        ) {
        case .none:
            break
        case .levelOnly(let publishedLevel):
            model.updateOverlayRecordingLevel(publishedLevel)
            floatingPanelController.updateAudioLevel(publishedLevel)
        case .transcriptAndLevel(let publishedTranscript, let publishedLevel):
            latestTranscript = publishedTranscript
            model.updateOverlayRecording(
                transcript: publishedTranscript,
                level: publishedLevel
            )
            floatingPanelController.updateLive(
                transcript: publishedTranscript,
                level: publishedLevel
            )
        }
    }

    private func handleRealtimeTerminalError(_ message: String) {
        guard !isAwaitingRealtimeFinalization else { return }
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if speechRecorder.isRecording {
            speechRecorder.cancelImmediately()
        }
        activeRecordingStartedAt = nil

        isStartingRecording = false
        finishActiveRecordingLatency(.failed(message))
        clearActiveRecordingWorkflowState()
        statusBarController?.setRecording(false)
        floatingPanelController.hide()
        model.hideOverlay()
        presentTransientError(message)
    }

    private func consumeCurrentRecordingDurationMilliseconds() -> Int {
        defer {
            activeRecordingStartedAt = nil
        }
        guard let activeRecordingStartedAt else { return 0 }

        let elapsed = max(0, Date().timeIntervalSince(activeRecordingStartedAt))
        return Int((elapsed * 1000).rounded())
    }

    private func markActiveRecordingLatency(_ milestone: RecordingLatencyTrace.Milestone) {
        activeRecordingLatencyTrace?.markNow(milestone)
    }

    private func finishActiveRecordingLatency(_ outcome: RecordingLatencyTrace.Outcome) {
        guard let activeRecordingLatencyTrace else { return }

        let report = activeRecordingLatencyTrace.report(
            outcome: outcome,
            finishedAt: RecordingLatencyTrace.currentTimestamp()
        )
        recordingLatencyReporter.report(report)
        self.activeRecordingLatencyTrace = nil
    }

    private func resolvedRefinementPrompt(
        for workflow: ProcessingWorkflowSelection,
        promptPresetOverrideID: String? = nil,
        workflowOverride: RecordingWorkflowOverride? = nil
    ) -> ResolvedPromptPreset? {
        guard workflow.postProcessingMode == .refinement else {
            return nil
        }

        if let promptPresetOverrideID {
            let normalizedPromptID = promptPresetOverrideID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedPromptID.isEmpty {
                return model.resolvedPromptPresetForExplicitPresetID(normalizedPromptID)
            }
        }

        guard Self.shouldResolveAutomaticRefinementPrompt(
            workflowOverride: workflowOverride,
            promptPresetOverrideID: promptPresetOverrideID
        ) else {
            return nil
        }

        let destination = promptDestinationInspector.currentDestinationContext()
        return model.resolvedPromptPreset(for: .voicePi, destination: destination)
    }

    private func refineIfNeeded(
        _ text: String,
        workflow: ProcessingWorkflowSelection? = nil,
        workflowOverride: RecordingWorkflowOverride? = nil,
        promptPresetOverrideID: String? = nil,
        sourceSnapshot: CapturedSourceSnapshot? = nil,
        refiningPresentationMode: RefiningPresentationMode = .floatingOverlayAndStatusBar
    ) async -> String {
        let effectiveWorkflow = workflow ?? Self.effectiveProcessingWorkflow(
            postProcessingMode: model.postProcessingMode,
            refinementProvider: model.refinementProvider,
            override: workflowOverride ?? activeRecordingWorkflowOverride
        )
        let resolvedPrompt = resolvedRefinementPrompt(
            for: effectiveWorkflow,
            promptPresetOverrideID: promptPresetOverrideID,
            workflowOverride: workflowOverride ?? activeRecordingWorkflowOverride
        )
        if effectiveWorkflow.refinementProvider == .externalProcessor {
            await externalProcessorRefiner.resetLastInvocation()
        }

        return await AppWorkflowSupport.postProcessIfNeeded(
            text,
            mode: effectiveWorkflow.postProcessingMode,
            refinementProvider: effectiveWorkflow.refinementProvider,
            externalProcessor: model.selectedExternalProcessorEntry(),
            externalProcessorRefiner: externalProcessorRefiner,
            translationProvider: model.effectiveTranslationProvider(
                appleTranslateSupported: AppleTranslateService.isSupported
            ),
            sourceLanguage: model.selectedLanguage,
            targetLanguage: model.targetLanguage,
            configuration: model.llmConfiguration,
            refinementPromptTitle: resolvedPrompt?.title,
            resolvedRefinementPrompt: resolvedPrompt?.middleSection,
            sourceSnapshot: sourceSnapshot,
            dictionaryEntries: model.enabledDictionaryEntries,
            refiner: llmRefiner,
            translator: appleTranslateService,
            onPresentation: { [weak self] presentation in
                guard let self else { return }
                switch presentation {
                case .transcribing:
                    break
                case .refining(let overlayTranscript, let statusText):
                    if refiningPresentationMode == .floatingOverlayAndStatusBar {
                        self.activeFloatingRefiningPresentationStartedAt = Date()
                        self.floatingPanelController.showRefining(
                            transcript: overlayTranscript,
                            sourcePreviewText: sourceSnapshot?.previewText
                        )
                        self.model.updateOverlayRefining(transcript: overlayTranscript)
                    }
                    self.statusBarController?.setTransientStatus(statusText)
                }
            },
            onError: { [weak self] message in
                self?.presentTransientError(message)
            }
        )
    }

    private func ensureFloatingRefiningOverlayRemainsVisibleIfNeeded() async {
        guard activeRecordingWorkflowOverride == .externalProcessorShortcut else {
            return
        }

        let delay = Self.pendingFloatingRefiningHideDelayNanoseconds(
            presentationStartedAt: activeFloatingRefiningPresentationStartedAt
        )
        guard delay > 0 else {
            return
        }

        try? await Task.sleep(nanoseconds: delay)
    }

    private func prepareForRecording() async -> Bool {
        let accessibilityGranted = currentAccessibilityAuthorizationState(prompt: false) == .granted
        let microphoneGranted = await requestMicrophonePermissionIfNeeded()
        let speechGranted = await requestSpeechPermissionIfNeededIfNeededForBackend()

        updateAuthorizationStates(
            microphoneState: currentMicrophoneAuthorizationState(),
            speechState: currentSpeechAuthorizationState(),
            accessibilityState: currentAccessibilityAuthorizationState(prompt: false),
            inputMonitoringState: currentInputMonitoringAuthorizationState()
        )

        if let message = AppWorkflowSupport.preparationFailureMessage(
            permissions: .init(
                accessibilityGranted: accessibilityGranted,
                microphoneGranted: microphoneGranted,
                speechGranted: speechGranted
            ),
            backend: model.asrBackend,
            remoteConfigurationReady: model.remoteASRConfiguration.isConfigured
        ) {
            presentTransientError(message)
            return false
        }

        return true
    }

    private func refreshPermissionStates(
        promptAccessibility: Bool,
        requestMediaPermissions: Bool = false,
        requestInputMonitoringPermission: Bool = false,
        useSystemAccessibilityPrompt: Bool = false,
        inputMonitoringPromptSource: PermissionPromptSource = .manualSettingsButton
    ) async {
        if requestMediaPermissions {
            _ = await requestMicrophonePermissionIfNeeded()
            _ = await requestSpeechPermissionIfNeededIfNeededForBackend()
        }

        let accessibilityStateAfterPrompt: AuthorizationState
        if promptAccessibility {
            let currentAccessibilityState = currentAccessibilityAuthorizationState(prompt: false)
            if currentAccessibilityState != .granted, useSystemAccessibilityPrompt {
                _ = currentAccessibilityAuthorizationState(prompt: true)
            } else if currentAccessibilityState != .granted {
                offerPermissionSettingsPrompt(for: .accessibility, source: .manualSettingsButton)
            }
            accessibilityStateAfterPrompt = currentAccessibilityAuthorizationState(prompt: false)
        } else {
            accessibilityStateAfterPrompt = currentAccessibilityAuthorizationState(prompt: false)
        }

        if Self.shouldAwaitAccessibilityAuthorization(
            promptAccessibility: promptAccessibility,
            requestInputMonitoringPermission: requestInputMonitoringPermission,
            accessibilityStateAfterPrompt: accessibilityStateAfterPrompt
        ) {
            scheduleAccessibilityAuthorizationFollowUp()
        } else {
            accessibilityAuthorizationFollowUpTask?.cancel()
            accessibilityAuthorizationFollowUpTask = nil
        }

        if Self.permissionRefreshSequence(
            requestMediaPermissions: requestMediaPermissions,
            promptAccessibility: promptAccessibility,
            requestInputMonitoringPermission: requestInputMonitoringPermission,
            accessibilityStateAfterPrompt: accessibilityStateAfterPrompt
        ).contains(.inputMonitoring) {
            let inputMonitoringState = currentInputMonitoringAuthorizationState()
            switch Self.inputMonitoringLaunchAction(authorizationState: inputMonitoringState) {
            case .none:
                inputMonitoringAuthorizationFollowUpTask?.cancel()
                inputMonitoringAuthorizationFollowUpTask = nil
            case .requestSystemPrompt:
                if Self.shouldActivateAppForPermissionPrompt(source: inputMonitoringPromptSource) {
                    NSApp.activate(ignoringOtherApps: true)
                }
                let requestGranted = InputMonitoringAccess.requestIfNeeded()
                let refreshedInputMonitoringState = currentInputMonitoringAuthorizationState()
                if Self.shouldAwaitInputMonitoringAuthorization(
                    requestInputMonitoringPermission: requestInputMonitoringPermission,
                    inputMonitoringStateAfterRequest: refreshedInputMonitoringState
                ) {
                    scheduleInputMonitoringAuthorizationFollowUp()
                } else {
                    inputMonitoringAuthorizationFollowUpTask?.cancel()
                    inputMonitoringAuthorizationFollowUpTask = nil
                }
                if Self.shouldOfferInputMonitoringSettingsOnLaunch(
                    requestGranted: requestGranted,
                    inputMonitoringState: refreshedInputMonitoringState
                ) {
                    offerInputMonitoringSettingsPrompt(source: inputMonitoringPromptSource)
                }
            case .openSettingsPrompt:
                offerInputMonitoringSettingsPrompt(source: inputMonitoringPromptSource)
                if Self.shouldAwaitInputMonitoringAuthorization(
                    requestInputMonitoringPermission: requestInputMonitoringPermission,
                    inputMonitoringStateAfterRequest: inputMonitoringState
                ) {
                    scheduleInputMonitoringAuthorizationFollowUp()
                }
            }
        } else {
            inputMonitoringAuthorizationFollowUpTask?.cancel()
            inputMonitoringAuthorizationFollowUpTask = nil
        }

        updateAuthorizationStates(
            microphoneState: currentMicrophoneAuthorizationState(),
            speechState: currentSpeechAuthorizationState(),
            accessibilityState: accessibilityStateAfterPrompt,
            inputMonitoringState: currentInputMonitoringAuthorizationState()
        )

        statusBarController?.refreshAll()
        ensureHotkeyMonitorRunning()
    }

    private func scheduleAccessibilityAuthorizationFollowUp() {
        accessibilityAuthorizationFollowUpTask?.cancel()
        accessibilityAuthorizationFollowUpTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.accessibilityAuthorizationFollowUpTask = nil
            }

            let deadline = Date().addingTimeInterval(120)
            while !Task.isCancelled {
                let accessibilityState = self.currentAccessibilityAuthorizationState(prompt: false)
                if accessibilityState == .granted {
                    await self.refreshPermissionStates(
                        promptAccessibility: false,
                        requestInputMonitoringPermission: self.currentShortcutsRequireInputMonitoring(),
                        inputMonitoringPromptSource: .accessibilityFollowUp
                    )
                    return
                }

                if Date() >= deadline {
                    await self.refreshPermissionStates(promptAccessibility: false)
                    return
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func scheduleInputMonitoringAuthorizationFollowUp() {
        inputMonitoringAuthorizationFollowUpTask?.cancel()
        inputMonitoringAuthorizationFollowUpTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.inputMonitoringAuthorizationFollowUpTask = nil
            }

            let deadline = Date().addingTimeInterval(120)
            while !Task.isCancelled {
                let inputMonitoringState = self.currentInputMonitoringAuthorizationState()
                if inputMonitoringState == .granted {
                    await self.refreshPermissionStates(promptAccessibility: false)
                    return
                }

                if Date() >= deadline {
                    await self.refreshPermissionStates(promptAccessibility: false)
                    return
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    @discardableResult
    private func ensureHotkeyMonitorRunning() -> String? {
        let inputMonitoringState = currentInputMonitoringAuthorizationState()
        let accessibilityState = currentAccessibilityAuthorizationState(prompt: false)
        let activationPlan = Self.hotkeyMonitorPlan(
            shortcut: model.activationShortcut,
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState
        )
        let cyclePlan = Self.modeCycleShortcutMonitorPlan(
            shortcut: model.modeCycleShortcut,
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState
        )
        let promptCyclePlan = Self.promptCycleShortcutMonitorPlan(
            shortcut: model.promptCycleShortcut,
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState
        )
        let processorPlan = Self.processorShortcutMonitorPlan(
            shortcut: model.processorShortcut,
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState
        )

        let activationStatus = applyHotkeyMonitorPlan(
            activationPlan,
            actionController: recordingShortcutAction,
            registrationFailureMessage: Self.shortcutRegistrationFailureMessage,
            monitoringFailureMessage: Self.shortcutMonitoringFailureMessage,
            fallbackPlanAfterRegistrationFailure: inputMonitoringState == .granted
                ? Self.hotkeyMonitorFallbackPlanAfterRegistrationFailure(
                    shortcut: model.activationShortcut,
                    inputMonitoringState: inputMonitoringState,
                    accessibilityState: accessibilityState
                )
                : nil
        )
        let cycleStatus = applyHotkeyMonitorPlan(
            cyclePlan,
            actionController: modeCycleShortcutAction,
            registrationFailureMessage: Self.modeCycleShortcutRegistrationFailureMessage,
            monitoringFailureMessage: Self.modeCycleShortcutMonitoringFailureMessage
        )
        let promptCycleStatus = applyHotkeyMonitorPlan(
            promptCyclePlan,
            actionController: promptCycleShortcutAction,
            registrationFailureMessage: Self.promptCycleShortcutRegistrationFailureMessage,
            monitoringFailureMessage: Self.promptCycleShortcutMonitoringFailureMessage
        )
        let processorStatus = applyHotkeyMonitorPlan(
            processorPlan,
            actionController: processorShortcutAction,
            registrationFailureMessage: Self.processorShortcutRegistrationFailureMessage,
            monitoringFailureMessage: Self.processorShortcutMonitoringFailureMessage
        )

        let statusMessage = activationStatus ?? cycleStatus ?? promptCycleStatus ?? processorStatus
        if let statusMessage, statusBarController != nil {
            statusBarController?.setTransientStatus(statusMessage)
        } else if statusBarController != nil, model.errorState == nil {
            statusBarController?.setTransientStatus(nil)
        }
        return statusMessage
    }

    private func applyHotkeyMonitorPlan(
        _ plan: HotkeyMonitorPlan,
        actionController: ShortcutActionController,
        registrationFailureMessage: String,
        monitoringFailureMessage: String,
        fallbackPlanAfterRegistrationFailure: HotkeyMonitorPlan? = nil
    ) -> String? {
        let status = actionController.apply(
            plan,
            registrationFailureMessage: registrationFailureMessage,
            monitoringFailureMessage: monitoringFailureMessage
        )

        guard status == registrationFailureMessage,
              let fallbackPlanAfterRegistrationFailure else {
            return status
        }

        return actionController.apply(
            fallbackPlanAfterRegistrationFailure,
            registrationFailureMessage: registrationFailureMessage,
            monitoringFailureMessage: monitoringFailureMessage
        )
    }

    private func currentMicrophoneAuthorizationState() -> AuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .notDetermined:
            return .unknown
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }

    private func currentShortcutsRequireInputMonitoring() -> Bool {
        Self.shortcutsRequireInputMonitoring(
            activationShortcut: model.activationShortcut,
            modeCycleShortcut: model.modeCycleShortcut,
            processorShortcut: model.processorShortcut,
            promptCycleShortcut: model.promptCycleShortcut
        )
    }

    private func currentSpeechAuthorizationState() -> AuthorizationState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .notDetermined:
            return .unknown
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }

    private func currentAccessibilityAuthorizationState(prompt: Bool) -> AuthorizationState {
        requestAccessibilityPermission(prompt: prompt) ? .granted : .denied
    }

    private func currentInputMonitoringAuthorizationState() -> AuthorizationState {
        InputMonitoringAccess.authorizationState()
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        let authorizationState = currentMicrophoneAuthorizationState()
        switch authorizationState {
        case .granted:
            return true
        case .unknown:
            let transitionStyle = Self.mediaPermissionTransitionStyle(
                for: .microphone,
                authorizationState: authorizationState
            )
            switch transitionStyle {
            case .customPrePromptThenSystemRequest:
                guard offerMediaPermissionPrePrompt(for: .microphone) else {
                    return false
                }
                return await AVCaptureDevice.requestAccess(for: .audio)
            case .customSettingsPrompt:
                offerPermissionSettingsPrompt(for: .microphone, source: .manualSettingsButton)
                return false
            }
        case .denied, .restricted:
            offerPermissionSettingsPrompt(for: .microphone, source: .manualSettingsButton)
            return false
        @unknown default:
            return false
        }
    }

    private func requestSpeechPermissionIfNeededIfNeededForBackend() async -> Bool {
        guard model.asrBackend == .appleSpeech else {
            return currentSpeechAuthorizationState() != .denied && currentSpeechAuthorizationState() != .restricted
        }

        let authorizationState = currentSpeechAuthorizationState()
        switch authorizationState {
        case .granted:
            return true
        case .unknown:
            let transitionStyle = Self.mediaPermissionTransitionStyle(
                for: .speech,
                authorizationState: authorizationState
            )
            switch transitionStyle {
            case .customPrePromptThenSystemRequest:
                guard offerMediaPermissionPrePrompt(for: .speech) else {
                    return false
                }
                return await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { status in
                        continuation.resume(returning: status == .authorized)
                    }
                }
            case .customSettingsPrompt:
                offerPermissionSettingsPrompt(for: .speech, source: .manualSettingsButton)
                return false
            }
        case .denied, .restricted:
            offerPermissionSettingsPrompt(for: .speech, source: .manualSettingsButton)
            return false
        @unknown default:
            return false
        }
    }

    private func requestAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func offerMediaPermissionPrePrompt(for destination: PermissionSettingsDestination) -> Bool {
        let prompt = Self.mediaPermissionPrePrompt(for: destination)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = prompt.messageText
        alert.informativeText = prompt.informativeText
        alert.addButton(withTitle: prompt.continueTitle)
        alert.addButton(withTitle: "Not Now")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func updateAuthorizationStates(
        microphoneState: AuthorizationState,
        speechState: AuthorizationState,
        accessibilityState: AuthorizationState,
        inputMonitoringState: AuthorizationState
    ) {
        model.setMicrophoneAuthorization(microphoneState)
        model.setSpeechAuthorization(speechState)
        model.setAccessibilityAuthorization(accessibilityState)
        model.setInputMonitoringAuthorization(inputMonitoringState)
    }

    private func presentTransientError(_ message: String) {
        pendingErrorHideTask?.cancel()
        model.presentError(message)
        statusBarController?.setTransientStatus(message)
        NSSound.beep()

        pendingErrorHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self else { return }
            self.model.clearError()
            self.statusBarController?.setTransientStatus(nil)
        }
    }

    private func testLLMConfiguration(_ configuration: LLMConfiguration) async -> Result<String, Error> {
        let refinerConfiguration = LLMRefinerConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model,
            refinementPrompt: configuration.refinementPrompt
        )

        do {
            let response = try await llmRefiner.testConnection(configuration: refinerConfiguration)
            return .success(response)
        } catch {
            return .failure(error)
        }
    }

    private func testRemoteASRConfiguration(
        _ configuration: RemoteASRConfiguration,
        backend: ASRBackend
    ) async -> Result<String, Error> {
        do {
            try configuration.validate(for: backend)
            let response = try await remoteASRClient.testConnection(backend: backend, with: configuration)
            return .success(response)
        } catch {
            return .failure(error)
        }
    }

    private func currentAppVersion() -> String {
        SettingsPresentation.aboutPresentation(infoDictionary: Bundle.main.infoDictionary).version
    }

    private func checkForUpdates(trigger: UpdateCheckTrigger) async -> String {
        let source = await refreshInstallationSource()
        applyUpdateExperience(.checking(source: source))

        do {
            let result = try await updateChecker.checkForUpdates(currentVersion: currentAppVersion())
            let statusText = AppUpdateCopy.statusText(for: result)

            switch result {
            case .updateAvailable(let release):
                let delivery = Self.updateDelivery(for: source)
                let phase = AppUpdateExperiencePhase.updateAvailable(
                    release: release,
                    delivery: delivery,
                    source: source
                )
                applyUpdateExperience(
                    phase,
                    presentPanel: Self.shouldPresentUpdatePrompt(
                        trigger: trigger,
                        availableVersion: release.version,
                        lastPromptedVersion: appDefaults.string(forKey: Self.lastPromptedUpdateVersionKey)
                    )
                )
                if Self.shouldPresentUpdatePrompt(
                    trigger: trigger,
                    availableVersion: release.version,
                    lastPromptedVersion: appDefaults.string(forKey: Self.lastPromptedUpdateVersionKey)
                ) {
                    appDefaults.set(release.version, forKey: Self.lastPromptedUpdateVersionKey)
                }
            case .upToDate(let currentVersion):
                applyUpdateExperience(
                    .upToDate(currentVersion: currentVersion, source: source),
                    presentPanel: Self.shouldPresentManualUpdateResultDialog(trigger: trigger, result: result)
                )
            }

            return statusText
        } catch {
            let message = "Update check failed: \(error.localizedDescription)"
            if trigger == .manual {
                applyUpdateExperience(
                    .failed(
                        message: message,
                        delivery: Self.updateDelivery(for: source),
                        source: source,
                        release: currentUpdateRelease()
                    ),
                    presentPanel: true
                )
            } else {
                applyUpdateExperience(.idle(source: source))
            }

            switch trigger {
            case .automatic:
                return "Automatic update check unavailable."
            case .manual:
                return message
            }
        }
    }

    private func installDirectUpdate(for release: AppUpdateRelease) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let source = self.installationSource

            do {
                self.applyUpdateExperience(
                    .downloading(release: release, source: source, progress: 0),
                    presentPanel: true
                )
                try await self.installDirectUpdate(release: release, source: source)
            } catch {
                self.applyUpdateExperience(
                    .failed(
                        message: "Automatic install failed: \(error.localizedDescription)",
                        delivery: .inAppInstaller,
                        source: source,
                        release: release
                    ),
                    presentPanel: true
                )
            }
        }
    }

    private func installDirectUpdate(release: AppUpdateRelease, source: AppInstallationSource) async throws {
        let updater = AppUpdater(
            owner: "pi-dal",
            repo: "VoicePi",
            releasePrefix: "VoicePi",
            interval: 365 * 24 * 60 * 60,
            provider: VoicePiAppUpdateReleaseProvider()
        )
        activeDirectUpdateInstaller = updater
        let stateObserver = updater.$state.sink { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleUpdaterState(state, release: release, source: source)
            }
        }

        defer {
            stateObserver.cancel()
            activeDirectUpdateInstaller = nil
        }

        try await updater.checkThrowing()

        let downloadedBundle = try await downloadedBundle(from: updater)
        applyUpdateExperience(.installing(release: release, source: source), presentPanel: true)
        try updater.installThrowing(downloadedBundle)
    }

    private func downloadedBundle(from updater: AppUpdater) async throws -> Bundle {
        for _ in 0..<Self.directUpdateDownloadPollMaxAttempts {
            let currentState = await MainActor.run(body: { updater.state })
            if case .downloaded(_, _, let bundle) = currentState {
                return bundle
            }

            try await Task.sleep(nanoseconds: Self.directUpdateDownloadPollIntervalNanoseconds)
        }

        throw AppUpdateInstallError.downloadedBundleMissing
    }

    private func refreshInstallationSource(forceRefresh: Bool = false) async -> AppInstallationSource {
        if forceRefresh || installationSource == .unknown {
            installationSource = await homebrewInstallationDetector.detectInstallationSource()
        }
        return installationSource
    }

    private func applyUpdateExperience(_ phase: AppUpdateExperiencePhase, presentPanel: Bool = false) {
        updateExperiencePhase = phase

        let handler = makeUpdateExperienceActionHandler(for: phase)
        let card = AppUpdateExperience.cardPresentation(for: phase)
        statusBarController?.setAboutUpdateExperience(
            card,
            primaryAction: { handler(card.primaryAction.role) },
            secondaryAction: card.secondaryAction.map { secondary in
                { handler(secondary.role) }
            }
        )
        statusBarController?.setTransientStatus(transientStatusText(for: phase))

        if presentPanel, let panel = AppUpdateExperience.panelPresentation(for: phase) {
            statusBarController?.presentUpdatePanel(panel, actionHandler: handler)
        } else if case .idle = phase {
            statusBarController?.dismissUpdatePanel()
        }
    }

    private func makeUpdateExperienceActionHandler(
        for phase: AppUpdateExperiencePhase
    ) -> (AppUpdateActionRole) -> Void {
        { [weak self] role in
            guard let self else { return }

            switch role {
            case .check:
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    _ = await self.checkForUpdates(trigger: .manual)
                }
            case .install:
                if case .updateAvailable(let release, let delivery, _) = phase, delivery == .inAppInstaller {
                    self.installDirectUpdate(for: release)
                }
            case .openRelease:
                if let release = self.release(from: phase) {
                    NSWorkspace.shared.open(release.releasePageURL)
                    self.statusBarController?.setTransientStatus("Opened VoicePi release page")
                }
            case .copyHomebrew:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(HomebrewUpdateInstructions.combinedCommands, forType: .string)
                self.statusBarController?.setTransientStatus("Copied Homebrew update commands")
            case .openHomebrewGuide:
                if let url = URL(string: HomebrewUpdateInstructions.readmeInstallURL) {
                    NSWorkspace.shared.open(url)
                    self.statusBarController?.setTransientStatus("Opened Homebrew install guide")
                }
            case .retry:
                if case let .failed(_, delivery, _, release) = phase,
                   delivery == .inAppInstaller,
                   let release {
                    self.installDirectUpdate(for: release)
                } else {
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        _ = await self.checkForUpdates(trigger: .manual)
                    }
                }
            case .dismiss, .acknowledge:
                self.statusBarController?.dismissUpdatePanel()
            }
        }
    }

    private func release(from phase: AppUpdateExperiencePhase) -> AppUpdateRelease? {
        switch phase {
        case .updateAvailable(let release, _, _):
            return release
        case .downloading(let release, _, _):
            return release
        case .installing(let release, _):
            return release
        case .failed(_, _, _, let release):
            return release
        case .idle, .checking, .upToDate:
            return nil
        }
    }

    private func currentUpdateRelease() -> AppUpdateRelease? {
        release(from: updateExperiencePhase)
    }

    private func transientStatusText(for phase: AppUpdateExperiencePhase) -> String? {
        switch phase {
        case .idle:
            return nil
        case .checking:
            return "Checking GitHub Releases…"
        case .updateAvailable(let release, _, _):
            return "Update available: VoicePi \(release.version)"
        case .downloading(let release, _, _):
            return "Downloading VoicePi \(release.version)…"
        case .installing:
            return "Installing VoicePi update…"
        case .upToDate(let currentVersion, _):
            return "VoicePi \(currentVersion) is up to date."
        case .failed(let message, _, _, _):
            return message
        }
    }

    private func handleUpdaterState(
        _ state: AppUpdater.UpdateState,
        release: AppUpdateRelease,
        source: AppInstallationSource
    ) {
        switch state {
        case .downloading(_, _, let fraction):
            applyUpdateExperience(
                .downloading(release: release, source: source, progress: fraction),
                presentPanel: true
            )
        case .downloaded:
            applyUpdateExperience(.installing(release: release, source: source), presentPanel: true)
        case .none, .newVersionDetected:
            break
        }
    }

}

extension AppController: ShortcutMonitorDelegate {
    nonisolated func shortcutMonitorDidPress() {
        Task { @MainActor [weak self] in
            self?.beginRecording()
        }
    }

    nonisolated func shortcutMonitorDidRelease() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            switch Self.releaseAction(
                shortcut: self.model.activationShortcut,
                isRecording: self.speechRecorder.isRecording,
                isStartingRecording: self.isStartingRecording,
                isProcessingRelease: self.isProcessingRelease
            ) {
            case .ignore:
                return
            }
        }
    }
}

extension AppController: SpeechRecorderDelegate {
    func speechRecorderDidStart(_ recorder: SpeechRecorder) {
        activeRecordingStartedAt = Date()
        markActiveRecordingLatency(.recordingStarted)
    }

    func speechRecorder(_ recorder: SpeechRecorder, didUpdateTranscript transcript: String, isFinal: Bool) {
        if !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            markActiveRecordingLatency(.firstPartialReceived)
        }
        publishRecordingOverlayUpdate(
            transcript: transcript,
            level: model.overlayState.level
        )
    }

    func speechRecorder(_ recorder: SpeechRecorder, didUpdateMetering normalizedLevel: CGFloat) {
        publishRecordingOverlayUpdate(
            transcript: latestTranscript,
            level: normalizedLevel
        )
    }

    func speechRecorder(_ recorder: SpeechRecorder, didFail error: Error) {
        latestTranscript = recorder.latestTranscript
        if !isProcessingRelease {
            activeRecordingStartedAt = nil
        }
        if !isProcessingRelease {
            finishActiveRecordingLatency(.failed(error.localizedDescription))
            statusBarController?.setRecording(false)
            presentTransientError(error.localizedDescription)
        }
    }

    func speechRecorderDidStop(_ recorder: SpeechRecorder, finalTranscript: String, audioFileURL: URL?) {
        latestTranscript = finalTranscript
    }
}

extension AppController: StatusBarControllerDelegate {
    func statusBarControllerDidRequestStartRecording(_ controller: StatusBarController) {
        beginRecording()
    }

    func statusBarControllerDidRequestStopRecording(_ controller: StatusBarController) {
        endRecordingAndInject()
    }

    func statusBarController(_ controller: StatusBarController, didSelect language: SupportedLanguage) {
        handleLanguageChange(language)
    }

    func statusBarController(_ controller: StatusBarController, didUpdateActivationShortcut shortcut: ActivationShortcut) {
        model.setActivationShortcut(shortcut)
        recordingShortcutAction.shortcut = shortcut
        controller.refreshAll()
        ensureHotkeyMonitorRunning()
    }

    func statusBarController(_ controller: StatusBarController, didUpdateModeCycleShortcut shortcut: ActivationShortcut) {
        model.setModeCycleShortcut(shortcut)
        modeCycleShortcutAction.shortcut = shortcut
        controller.refreshAll()
        ensureHotkeyMonitorRunning()
    }

    func statusBarController(_ controller: StatusBarController, didUpdatePromptCycleShortcut shortcut: ActivationShortcut) {
        model.setPromptCycleShortcut(shortcut)
        promptCycleShortcutAction.shortcut = shortcut
        controller.refreshAll()
        ensureHotkeyMonitorRunning()
    }

    func statusBarController(_ controller: StatusBarController, didUpdateProcessorShortcut shortcut: ActivationShortcut) {
        model.setProcessorShortcut(shortcut)
        processorShortcutAction.shortcut = shortcut
        controller.refreshAll()
        ensureHotkeyMonitorRunning()
    }

    func statusBarController(_ controller: StatusBarController, didSave configuration: LLMConfiguration) {
        model.saveLLMConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model,
            enableThinking: .some(configuration.enableThinking)
        )
        controller.refreshAll()
    }

    func statusBarController(_ controller: StatusBarController, didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration) {
        model.saveRemoteASRConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model,
            prompt: configuration.prompt,
            volcengineAppID: configuration.volcengineAppID
        )
        controller.refreshAll()
    }

    func statusBarController(_ controller: StatusBarController, didSelectASRBackend backend: ASRBackend) {
        model.setASRBackend(backend)
        controller.refreshAll()
    }

    func statusBarController(_ controller: StatusBarController, didRequestTest configuration: LLMConfiguration) async -> Result<String, Error> {
        await testLLMConfiguration(configuration)
    }

    func statusBarController(_ controller: StatusBarController, didRequestRemoteASRTest configuration: RemoteASRConfiguration) async -> Result<String, Error> {
        await testRemoteASRConfiguration(configuration, backend: model.asrBackend)
    }

    func statusBarControllerDidRequestOpenAccessibilitySettings(_ controller: StatusBarController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshPermissionStates(
                promptAccessibility: true,
                requestInputMonitoringPermission: self.currentShortcutsRequireInputMonitoring(),
                inputMonitoringPromptSource: .accessibilityFollowUp
            )
        }
    }

    func statusBarControllerDidRequestOpenMicrophoneSettings(_ controller: StatusBarController) {
        switch Self.mediaPermissionTransitionStyle(
            for: .microphone,
            authorizationState: currentMicrophoneAuthorizationState()
        ) {
        case .customPrePromptThenSystemRequest:
            Task { @MainActor [weak self] in
                _ = await self?.requestMicrophonePermissionIfNeeded()
                await self?.refreshPermissionStates(promptAccessibility: false)
            }
        case .customSettingsPrompt:
            offerPermissionSettingsPrompt(for: .microphone, source: .manualSettingsButton)
        }
    }

    func statusBarControllerDidRequestOpenSpeechSettings(_ controller: StatusBarController) {
        switch Self.mediaPermissionTransitionStyle(
            for: .speech,
            authorizationState: currentSpeechAuthorizationState()
        ) {
        case .customPrePromptThenSystemRequest:
            Task { @MainActor [weak self] in
                _ = await self?.requestSpeechPermissionIfNeededIfNeededForBackend()
                await self?.refreshPermissionStates(promptAccessibility: false)
            }
        case .customSettingsPrompt:
            offerPermissionSettingsPrompt(for: .speech, source: .manualSettingsButton)
        }
    }

    func statusBarControllerDidRequestOpenInputMonitoringSettings(_ controller: StatusBarController) {
        offerPermissionSettingsPrompt(for: .inputMonitoring, source: .manualSettingsButton)
    }

    func statusBarControllerDidRequestRefreshPermissions(_ controller: StatusBarController) async {
        await refreshPermissionStates(promptAccessibility: false)
    }

    func statusBarControllerDidRequestPromptAccessibilityPermission(_ controller: StatusBarController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshPermissionStates(
                promptAccessibility: true,
                requestInputMonitoringPermission: self.currentShortcutsRequireInputMonitoring(),
                inputMonitoringPromptSource: .accessibilityFollowUp
            )
        }
    }

    func statusBarControllerDidRequestQuit(_ controller: StatusBarController) {
        NSApp.terminate(nil)
    }

    func statusBarControllerDidRequestCheckForUpdates(_ controller: StatusBarController) async -> String {
        await checkForUpdates(trigger: .manual)
    }

    private func openSystemSettingsPane(_ rawURL: String) {
        guard let url = URL(string: rawURL) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func offerInputMonitoringSettingsPrompt(source: PermissionPromptSource) {
        offerPermissionSettingsPrompt(for: .inputMonitoring, source: source)
    }

    private func offerPermissionSettingsPrompt(
        for destination: PermissionSettingsDestination,
        source: PermissionPromptSource,
        beforeOpen: (() -> Void)? = nil
    ) {
        let prompt = Self.permissionSettingsPrompt(for: destination)
        if Self.shouldActivateAppForPermissionPrompt(source: source) {
            NSApp.activate(ignoringOtherApps: true)
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = prompt.messageText
        alert.informativeText = prompt.informativeText
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")

        if alert.runModal() == .alertFirstButtonReturn {
            beforeOpen?()
            openSystemSettingsPane(prompt.settingsURL)
        }
    }
}

private actor AppControllerExternalProcessorRefiner: ExternalProcessorRefining {
    private var lastInvocationSucceeded = false
    private var lastFailureMessage: String?

    var didSucceedOnLastInvocation: Bool {
        return lastInvocationSucceeded
    }

    var lastFailureMessageOnLastInvocation: String? {
        return lastFailureMessage
    }

    func resetLastInvocation() {
        lastInvocationSucceeded = false
        lastFailureMessage = nil
    }

    func refine(
        text: String,
        prompt: String,
        processor: ExternalProcessorEntry
    ) async throws -> String {
        let additionalArguments = processor.additionalArguments
            .map(\.value)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        switch processor.kind {
        case .almaCLI:
            do {
                let invocation = try AlmaCLIInvocationBuilder().build(
                    executablePath: processor.executablePath,
                    prompt: prompt,
                    additionalArguments: additionalArguments
                )
                let rawOutput = try await ExternalProcessorRunner().run(
                    invocation: invocation,
                    stdin: text
                )
                let refinedText = try ExternalProcessorOutputValidator.validate(
                    rawOutput,
                    againstInput: text
                )
                lastInvocationSucceeded = true
                lastFailureMessage = nil
                return refinedText
            } catch {
                lastInvocationSucceeded = false
                lastFailureMessage = error.localizedDescription
                throw error
            }
        }
    }
}
