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
        case stopRecording
        case cancelProcessing
        case ignore
    }

    enum ModeCycleInteractionStyle: Equatable {
        case modifierHeldSession
        case holdRepeat
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

    private let model = AppModel()
    private let recordingShortcutAction = ShortcutActionController()
    private let modeCycleShortcutAction = ShortcutActionController()
    private let speechRecorder = SpeechRecorder(localeIdentifier: SupportedLanguage.default.localeIdentifier)
    private let floatingPanelController = FloatingPanelController()
    private let llmRefiner = LLMRefiner()
    private let appleTranslateService = AppleTranslateService()
    private let remoteASRClient = RemoteASRClient()
    private let textInjector = TextInjector.shared
    private let updateChecker = GitHubReleaseUpdateChecker()
    private let homebrewInstallationDetector = HomebrewInstallationDetector()
    private let appDefaults = UserDefaults.standard
    private let promptDestinationInspector = PromptDestinationInspector()

    private var statusBarController: StatusBarController?
    private var cancellables: Set<AnyCancellable> = []
    private var isStartingRecording = false
    private var isProcessingRelease = false
    private var processingTask: Task<Void, Never>?
    private var latestTranscript = ""
    private var pendingErrorHideTask: Task<Void, Never>?
    private var accessibilityAuthorizationFollowUpTask: Task<Void, Never>?
    private var inputMonitoringAuthorizationFollowUpTask: Task<Void, Never>?
    private var modeCycleRepeatTask: Task<Void, Never>?
    private var startupHotkeyBootstrapTask: Task<Void, Never>?
    private var modeCycleSessionActive = false
    private var activeDirectUpdateInstaller: AppUpdater?
    private var installationSource: AppInstallationSource = .unknown
    private var updateExperiencePhase: AppUpdateExperiencePhase = .idle(source: .unknown)

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

    static let startupHotkeyBootstrapRetryNanoseconds: UInt64 = 500_000_000
    static let startupHotkeyBootstrapMaxAttempts = 6
    static let modeCycleRepeatDelayNanoseconds: UInt64 = 350_000_000
    static let modeCycleRepeatIntervalNanoseconds: UInt64 = 170_000_000

    private static let lastPromptedUpdateVersionKey = "VoicePi.lastPromptedUpdateVersion"

    static func pressAction(
        isRecording: Bool,
        isStartingRecording: Bool,
        isProcessingRelease: Bool
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
            inputMonitoringState: inputMonitoringState
        )
    }

    static func launchPermissionPlan(
        activationShortcut: ActivationShortcut,
        modeCycleShortcut: ActivationShortcut,
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
                modeCycleShortcut: modeCycleShortcut
            ),
            useSystemAccessibilityPrompt: true
        )
    }

    static func shortcutsRequireInputMonitoring(
        activationShortcut: ActivationShortcut,
        modeCycleShortcut: ActivationShortcut
    ) -> Bool {
        activationShortcut.requiresInputMonitoring || modeCycleShortcut.requiresInputMonitoring
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
        model.$interfaceTheme
            .sink { [weak self] theme in
                self?.floatingPanelController.applyInterfaceTheme(theme)
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
        modeCycleRepeatTask?.cancel()
        startupHotkeyBootstrapTask?.cancel()
        modeCycleRepeatTask = nil
        startupHotkeyBootstrapTask = nil
        recordingShortcutAction.stop()
        modeCycleShortcutAction.stop()

        if speechRecorder.isRecording {
            Task { @MainActor [weak self] in
                guard let self else { return }
                _ = await self.speechRecorder.stopRecording()
            }
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

    private func bootstrapHotkeyMonitoring() {
        startupHotkeyBootstrapTask?.cancel()
        let initialStatus = ensureHotkeyMonitorRunning()
        guard initialStatus == Self.shortcutRegistrationFailureMessage
            || initialStatus == Self.modeCycleShortcutRegistrationFailureMessage else {
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
                    || status == Self.modeCycleShortcutRegistrationFailureMessage else {
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

    private func beginRecording() {
        switch Self.pressAction(
            isRecording: speechRecorder.isRecording,
            isStartingRecording: isStartingRecording,
            isProcessingRelease: isProcessingRelease
        ) {
        case .ignore:
            return
        case .stopRecording:
            endRecordingAndInject()
            return
        case .cancelProcessing:
            cancelProcessingAndHideOverlay()
            return
        case .startRecording:
            break
        }

        isStartingRecording = true
        latestTranscript = ""
        statusBarController?.setTransientStatus(nil)

        Task { @MainActor [weak self] in
            guard let self else { return }

            let permissionsReady = await self.prepareForRecording()
            guard permissionsReady else {
                self.isStartingRecording = false
                return
            }

            do {
                self.speechRecorder.updateLocale(identifier: self.model.selectedLanguage.localeIdentifier)
                self.floatingPanelController.showRecording(transcript: "")
                self.model.updateOverlayRecording(transcript: "", level: 0)
                self.statusBarController?.setRecording(true)
                try await self.speechRecorder.startRecording(mode: self.model.asrBackend.speechRecorderMode)
            } catch {
                self.statusBarController?.setRecording(false)
                self.floatingPanelController.hide()
                self.presentTransientError(error.localizedDescription)
            }

            self.isStartingRecording = false
        }
    }

    private func endRecordingAndInject() {
        guard !isProcessingRelease else { return }

        if isStartingRecording {
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

            let localTranscript = await self.speechRecorder.stopRecording()
            guard !Task.isCancelled, self.isProcessingRelease else { return }

            let asrTranscript = await self.resolveTranscriptAfterRecording(localFallback: localTranscript)
            guard !Task.isCancelled, self.isProcessingRelease else { return }

            let captured = asrTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !captured.isEmpty else {
                self.floatingPanelController.hide()
                self.model.hideOverlay()
                self.statusBarController?.setTransientStatus(nil)
                self.isProcessingRelease = false
                return
            }

            let finalText = await self.refineIfNeeded(captured)
            guard !Task.isCancelled, self.isProcessingRelease else { return }

            do {
                try await self.textInjector.inject(text: finalText)
                self.statusBarController?.setTransientStatus("Injected")
            } catch {
                self.presentTransientError(error.localizedDescription)
            }

            self.floatingPanelController.hide()
            self.model.hideOverlay()
            self.isProcessingRelease = false
        }
    }

    private func cancelProcessingAndHideOverlay() {
        guard isProcessingRelease else { return }

        processingTask?.cancel()
        processingTask = nil
        isProcessingRelease = false
        latestTranscript = ""
        statusBarController?.setRecording(false)
        statusBarController?.setTransientStatus(nil)
        floatingPanelController.hide()
        model.hideOverlay()
    }

    private func resolveTranscriptAfterRecording(localFallback: String) async -> String {
        await AppWorkflowSupport.resolveTranscriptAfterRecording(
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
                    self.floatingPanelController.showRefining(transcript: "Transcribing…")
                    self.model.updateOverlayRefining(transcript: overlayTranscript)
                    self.statusBarController?.setTransientStatus(statusText)
                case .refining(let overlayTranscript, let statusText):
                    self.floatingPanelController.showRefining(transcript: localFallback)
                    self.model.updateOverlayRefining(transcript: overlayTranscript)
                    self.statusBarController?.setTransientStatus(statusText)
                }
            },
            onError: { [weak self] message in
                self?.presentTransientError(message)
            }
        )
    }

    private func refineIfNeeded(_ text: String) async -> String {
        let destination = promptDestinationInspector.currentDestinationContext()

        return await AppWorkflowSupport.postProcessIfNeeded(
            text,
            mode: model.postProcessingMode,
            translationProvider: model.effectiveTranslationProvider(
                appleTranslateSupported: AppleTranslateService.isSupported
            ),
            sourceLanguage: model.selectedLanguage,
            targetLanguage: model.targetLanguage,
            configuration: model.llmConfiguration,
            resolvedRefinementPrompt: model.postProcessingMode == .refinement
                ? model.resolvedRefinementPrompt(for: .voicePi, destination: destination)
                : nil,
            refiner: llmRefiner,
            translator: appleTranslateService,
            onPresentation: { [weak self] presentation in
                guard let self else { return }
                switch presentation {
                case .transcribing:
                    break
                case .refining(let overlayTranscript, let statusText):
                    self.floatingPanelController.showRefining(transcript: text)
                    self.model.updateOverlayRefining(transcript: overlayTranscript)
                    self.statusBarController?.setTransientStatus(statusText)
                }
            },
            onError: { [weak self] message in
                self?.presentTransientError(message)
            }
        )
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

        let statusMessage = activationStatus ?? cycleStatus
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
            modeCycleShortcut: model.modeCycleShortcut
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

    private func testRemoteASRConfiguration(_ configuration: RemoteASRConfiguration) async -> Result<String, Error> {
        do {
            try configuration.validate()
            let response = try await remoteASRClient.testConnection(with: configuration)
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
        for _ in 0..<20 {
            let currentState = await MainActor.run(body: { updater.state })
            if case .downloaded(_, _, let bundle) = currentState {
                return bundle
            }

            try await Task.sleep(nanoseconds: 100_000_000)
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
                switch phase {
                case .failed(_, let delivery, _, let release) where delivery == .inAppInstaller && release != nil:
                    self.installDirectUpdate(for: release!)
                default:
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
    func speechRecorderDidStart(_ recorder: SpeechRecorder) {}

    func speechRecorder(_ recorder: SpeechRecorder, didUpdateTranscript transcript: String, isFinal: Bool) {
        latestTranscript = transcript
        let level = model.overlayState.level
        model.updateOverlayRecording(transcript: transcript, level: level)
        floatingPanelController.updateLive(transcript: transcript, level: level)
    }

    func speechRecorder(_ recorder: SpeechRecorder, didUpdateMetering normalizedLevel: CGFloat) {
        let transcript = latestTranscript
        model.updateOverlayRecording(transcript: transcript, level: normalizedLevel)
        floatingPanelController.updateLive(transcript: transcript, level: normalizedLevel)
    }

    func speechRecorder(_ recorder: SpeechRecorder, didFail error: Error) {
        latestTranscript = recorder.latestTranscript
        if !isProcessingRelease {
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

    func statusBarController(_ controller: StatusBarController, didSave configuration: LLMConfiguration) {
        model.saveLLMConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model
        )
        controller.refreshAll()
    }

    func statusBarController(_ controller: StatusBarController, didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration) {
        model.saveRemoteASRConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model,
            prompt: configuration.prompt
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
        await testRemoteASRConfiguration(configuration)
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
