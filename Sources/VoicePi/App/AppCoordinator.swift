import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

@MainActor
final class AppController: NSObject {
    let model = AppModel()
    let recordingShortcutAction = ShortcutActionController()
    let modeCycleShortcutAction = ShortcutActionController()
    let promptCycleShortcutAction = ShortcutActionController()
    let processorShortcutAction = ShortcutActionController()
    let cancelShortcutAction = ShortcutActionController()
    let speechRecorder = SpeechRecorder(localeIdentifier: SupportedLanguage.default.localeIdentifier)
    let floatingPanelController = FloatingPanelController()
    let inputFallbackPanelController = InputFallbackPanelController()
    let externalProcessorResultPanelController = ExternalProcessorResultPanelController()
    let resultReviewPanelController = ResultReviewPanelController()
    let selectionRegenerateHintController = SelectionRegenerateHintController()
    let dictionarySuggestionToastController = DictionarySuggestionToastController()
    let llmRefiner = LLMRefiner()
    let externalProcessorRefiner = AppControllerExternalProcessorRefiner()
    let appleTranslateService = AppleTranslateService()
    let remoteASRClient = RemoteASRClient()
    let realtimeASRSessionCoordinator = RealtimeASRSessionCoordinator()
    let textInjector = TextInjector.shared
    let postInjectionLearningCoordinator = PostInjectionLearningCoordinator()
    let updateChecker = GitHubReleaseUpdateChecker()
    let homebrewInstallationDetector = HomebrewInstallationDetector()
    let permissionGuidanceFlow = PermissionGuidanceFlow()
    let appDefaults = UserDefaults.standard
    let promptDestinationInspector = PromptDestinationInspector()
    let editableTextTargetInspector: EditableTextTargetInspecting = EditableTextTargetInspector()
    let recentInsertionRewriteCoordinator = RecentInsertionRewriteCoordinator()
    let recordingLatencyReporter: any RecordingLatencyReporting = RecordingLatencyCompositeReporter(
        reporters: [
            UnifiedLogRecordingLatencyReporter(),
            RecordingLatencyHistoryReporter()
        ]
    )

    var statusBarController: StatusBarController?
    var cancellables: Set<AnyCancellable> = []
    var isStartingRecording = false {
        didSet {
            refreshCancelShortcutMonitorState()
        }
    }
    var isProcessingRelease = false {
        didSet {
            refreshCancelShortcutMonitorState()
        }
    }
    var processingTask: Task<Void, Never>?
    var recordingStartupTask: Task<Void, Never>?
    var latestTranscript = ""
    var pendingErrorHideTask: Task<Void, Never>?
    var accessibilityAuthorizationFollowUpTask: Task<Void, Never>?
    var inputMonitoringAuthorizationFollowUpTask: Task<Void, Never>?
    var postInjectionLearningTask: Task<Void, Never>?
    var postInjectionLearningRunRegistry = PostInjectionLearningRunRegistry()
    var resultReviewRetryTask: Task<Void, Never>?
    var modeCycleRepeatTask: Task<Void, Never>?
    var startupHotkeyBootstrapTask: Task<Void, Never>?
    var modeCycleSessionActive = false
    var isAwaitingRealtimeFinalization = false
    var activeDirectUpdateInstaller: AppUpdater?
    var installationSource: AppInstallationSource = .unknown
    var updateExperiencePhase: AppUpdateExperiencePhase = .idle(source: .unknown)
    var refinementReviewSession: RefinementReviewSession?
    var externalProcessorResultSession: ExternalProcessorResultSession?
    var activeRecordingWorkflowOverride: RecordingWorkflowOverride?
    var activeCapturedSourceSnapshot: CapturedSourceSnapshot?
    var activeRecordingStartedAt: Date?
    var activeRecordingLatencyTrace: RecordingLatencyTrace?
    var activeFloatingRefiningPresentationStartedAt: Date?
    var externalProcessorResultRetryTask: Task<Void, Never>?
    var realtimeOverlayUpdateGate = RealtimeOverlayUpdateGate()
    var realtimeAudioFramePump: RealtimeAudioFramePump?


    func start() {
        let debugSettingsCapture = Self.debugSettingsCaptureConfiguration()
        if let debugInterfaceTheme = debugSettingsCapture?.interfaceTheme {
            model.interfaceTheme = debugInterfaceTheme
        }

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

        cancelShortcutAction.onPress = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleCancelShortcutPress()
            }
        }
        cancelShortcutAction.shortcut = model.cancelShortcut

        let statusBarController = StatusBarController(model: model)
        statusBarController.delegate = self
        statusBarController.start()
        self.statusBarController = statusBarController
        if let debugSettingsCapture {
            statusBarController.showSettingsWindow(
                section: debugSettingsCapture.section,
                scrollToBottom: debugSettingsCapture.scrollPosition == .bottom
            )
        }
        applyUpdateExperience(.idle(source: .unknown))
        bootstrapHotkeyMonitoring()

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard debugSettingsCapture == nil else { return }
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
        cancelShortcutAction.stop()
        recordingStartupTask?.cancel()

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


}
