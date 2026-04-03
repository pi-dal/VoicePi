import AppKit
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

    enum ReleaseAction: Equatable {
        case ignore
    }

    private let model = AppModel()
    private let shortcutListener = ShortcutMonitor(mode: .listenOnly)
    private let shortcutCombinedMonitor = ShortcutMonitor(mode: .listenAndSuppress)
    private let registeredHotkeyMonitor = RegisteredHotkeyMonitor()
    private let speechRecorder = SpeechRecorder(localeIdentifier: SupportedLanguage.default.localeIdentifier)
    private let floatingPanelController = FloatingPanelController()
    private let llmRefiner = LLMRefiner()
    private let appleTranslateService = AppleTranslateService()
    private let remoteASRClient = RemoteASRClient()
    private let textInjector = TextInjector.shared

    private var statusBarController: StatusBarController?
    private var cancellables: Set<AnyCancellable> = []
    private var isStartingRecording = false
    private var isProcessingRelease = false
    private var processingTask: Task<Void, Never>?
    private var latestTranscript = ""
    private var pendingErrorHideTask: Task<Void, Never>?
    private var accessibilityAuthorizationFollowUpTask: Task<Void, Never>?
    private var inputMonitoringAuthorizationFollowUpTask: Task<Void, Never>?

    static let shortcutMonitoringFailureMessage =
        "Global shortcut monitoring is unavailable. Input Monitoring is required to listen for the shortcut, and Accessibility is required to suppress and inject events."

    static let shortcutSuppressionWarningMessage =
        "Shortcut listening is active, but Accessibility is still required to suppress the shortcut and inject pasted text."

    static let shortcutInjectionWarningMessage =
        "Shortcut listening is active, but Accessibility is still required to inject pasted text."

    static let shortcutRegistrationFailureMessage =
        "Global shortcut registration is unavailable. Choose a different shortcut."

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
        isRecording: Bool,
        isStartingRecording: Bool,
        isProcessingRelease: Bool
    ) -> ReleaseAction {
        .ignore
    }

    static func shouldPromptAccessibilityOnLaunch(
        shortcut: ActivationShortcut,
        inputMonitoringState _: AuthorizationState
    ) -> Bool {
        _ = shortcut
        return true
    }

    static func launchPermissionPlan(
        shortcut: ActivationShortcut,
        inputMonitoringState: AuthorizationState
    ) -> LaunchPermissionPlan {
        LaunchPermissionPlan(
            requestMediaPermissions: true,
            promptAccessibility: shouldPromptAccessibilityOnLaunch(
                shortcut: shortcut,
                inputMonitoringState: inputMonitoringState
            ),
            requestInputMonitoringPermission: shortcut.requiresInputMonitoring,
            useSystemAccessibilityPrompt: true
        )
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
        if shortcut.isRegisteredHotkeyCompatible {
            return HotkeyMonitorPlan(
                strategy: .registeredHotkey,
                statusMessage: accessibilityState == .granted ? nil : shortcutInjectionWarningMessage
            )
        }

        guard inputMonitoringState == .granted else {
            return HotkeyMonitorPlan(
                strategy: nil,
                statusMessage: shortcutMonitoringFailureMessage
            )
        }

        if accessibilityState == .granted {
            return HotkeyMonitorPlan(
                strategy: .eventTap(.listenAndSuppress),
                statusMessage: nil
            )
        }

        return HotkeyMonitorPlan(
            strategy: .eventTap(.listenOnly),
            statusMessage: shortcutSuppressionWarningMessage
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
        shortcutListener.delegate = self
        shortcutCombinedMonitor.delegate = self
        registeredHotkeyMonitor.delegate = self
        shortcutListener.shortcut = model.activationShortcut
        shortcutCombinedMonitor.shortcut = model.activationShortcut
        registeredHotkeyMonitor.shortcut = model.activationShortcut

        let statusBarController = StatusBarController(model: model)
        statusBarController.delegate = self
        statusBarController.start()
        self.statusBarController = statusBarController

        Task { @MainActor [weak self] in
            guard let self else { return }
            let launchPermissionPlan = Self.launchPermissionPlan(
                shortcut: self.model.activationShortcut,
                inputMonitoringState: self.currentInputMonitoringAuthorizationState()
            )
            await self.refreshPermissionStates(
                promptAccessibility: launchPermissionPlan.promptAccessibility,
                requestMediaPermissions: launchPermissionPlan.requestMediaPermissions,
                requestInputMonitoringPermission: launchPermissionPlan.requestInputMonitoringPermission,
                useSystemAccessibilityPrompt: launchPermissionPlan.useSystemAccessibilityPrompt,
                inputMonitoringPromptSource: .launchFollowUp
            )
        }
    }

    func stop() {
        accessibilityAuthorizationFollowUpTask?.cancel()
        inputMonitoringAuthorizationFollowUpTask?.cancel()
        pendingErrorHideTask?.cancel()
        registeredHotkeyMonitor.stop()
        shortcutListener.stop()
        shortcutCombinedMonitor.stop()

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
        await AppWorkflowSupport.postProcessIfNeeded(
            text,
            mode: model.postProcessingMode,
            translationProvider: model.effectiveTranslationProvider(
                appleTranslateSupported: AppleTranslateService.isSupported
            ),
            sourceLanguage: model.selectedLanguage,
            targetLanguage: model.targetLanguage,
            configuration: model.llmConfiguration,
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
            scheduleAccessibilityAuthorizationFollowUp(requestInputMonitoringPermission: requestInputMonitoringPermission)
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

    private func scheduleAccessibilityAuthorizationFollowUp(requestInputMonitoringPermission: Bool) {
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
                        requestInputMonitoringPermission: requestInputMonitoringPermission,
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

    private func ensureHotkeyMonitorRunning() {
        let plan = Self.hotkeyMonitorPlan(
            shortcut: model.activationShortcut,
            inputMonitoringState: currentInputMonitoringAuthorizationState(),
            accessibilityState: currentAccessibilityAuthorizationState(prompt: false)
        )

        guard let strategy = plan.strategy else {
            registeredHotkeyMonitor.stop()
            shortcutListener.stop()
            shortcutCombinedMonitor.stop()
            if let statusMessage = plan.statusMessage, statusBarController != nil {
                statusBarController?.setTransientStatus(statusMessage)
            }
            return
        }

        switch strategy {
        case .registeredHotkey:
            shortcutListener.stop()
            shortcutCombinedMonitor.stop()
            guard registeredHotkeyMonitor.start() else {
                statusBarController?.setTransientStatus(Self.shortcutRegistrationFailureMessage)
                return
            }
        case .eventTap(.listenOnly):
            registeredHotkeyMonitor.stop()
            shortcutCombinedMonitor.stop()
            guard shortcutListener.start() else {
                statusBarController?.setTransientStatus(Self.shortcutMonitoringFailureMessage)
                return
            }
        case .eventTap(.listenAndSuppress):
            registeredHotkeyMonitor.stop()
            shortcutListener.stop()
            guard shortcutCombinedMonitor.start() else {
                statusBarController?.setTransientStatus(Self.shortcutMonitoringFailureMessage)
                return
            }
        case .eventTap(.suppressOnly):
            registeredHotkeyMonitor.stop()
            shortcutListener.stop()
            shortcutCombinedMonitor.stop()
            statusBarController?.setTransientStatus(Self.shortcutMonitoringFailureMessage)
            return
        }

        if statusBarController != nil, model.errorState == nil {
            statusBarController?.setTransientStatus(plan.statusMessage)
        }
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
            model: configuration.model
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
        shortcutListener.shortcut = shortcut
        shortcutCombinedMonitor.shortcut = shortcut
        registeredHotkeyMonitor.shortcut = shortcut
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
            await self?.refreshPermissionStates(
                promptAccessibility: true,
                requestInputMonitoringPermission: true,
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
            await self?.refreshPermissionStates(
                promptAccessibility: true,
                requestInputMonitoringPermission: true,
                inputMonitoringPromptSource: .accessibilityFollowUp
            )
        }
    }

    func statusBarControllerDidRequestQuit(_ controller: StatusBarController) {
        NSApp.terminate(nil)
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
