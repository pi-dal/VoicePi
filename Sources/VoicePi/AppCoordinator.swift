import AppKit
import AVFoundation
import ApplicationServices
import Foundation
import Speech

@MainActor
final class AppController: NSObject {
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
    private let shortcutMonitor = ShortcutMonitor()
    private let speechRecorder = SpeechRecorder(localeIdentifier: SupportedLanguage.default.localeIdentifier)
    private let floatingPanelController = FloatingPanelController()
    private let llmRefiner = LLMRefiner()
    private let appleTranslateService = AppleTranslateService()
    private let remoteASRClient = RemoteASRClient()
    private let textInjector = TextInjector.shared

    private var statusBarController: StatusBarController?
    private var isStartingRecording = false
    private var isProcessingRelease = false
    private var processingTask: Task<Void, Never>?
    private var latestTranscript = ""
    private var pendingErrorHideTask: Task<Void, Never>?
    private var hasAttemptedInputMonitoringRequest = false

    static let shortcutMonitoringFailureMessage =
        "Global shortcut monitoring is unavailable. Input Monitoring is required to listen for the shortcut, and Accessibility is required to suppress and inject events."

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

    static func shouldPromptAccessibilityOnLaunch(inputMonitoringState: AuthorizationState) -> Bool {
        inputMonitoringState == .granted
    }

    func start() {
        speechRecorder.delegate = self
        shortcutMonitor.delegate = self
        shortcutMonitor.shortcut = model.activationShortcut

        let statusBarController = StatusBarController(model: model)
        statusBarController.delegate = self
        statusBarController.start()
        self.statusBarController = statusBarController

        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = self.requestInputMonitoringPermissionIfNeeded()
            let inputMonitoringState = self.currentInputMonitoringAuthorizationState()
            await self.refreshPermissionStates(
                promptAccessibility: Self.shouldPromptAccessibilityOnLaunch(inputMonitoringState: inputMonitoringState),
                requestMediaPermissions: true
            )
        }
    }

    func stop() {
        pendingErrorHideTask?.cancel()
        shortcutMonitor.stop()

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
        let accessibilityGranted = requestAccessibilityPermission(prompt: true)
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
        requestInputMonitoringPermission: Bool = false
    ) async {
        if requestMediaPermissions {
            _ = await requestMicrophonePermissionIfNeeded()
            _ = await requestSpeechPermissionIfNeededIfNeededForBackend()
        }

        if requestInputMonitoringPermission {
            _ = requestInputMonitoringPermissionIfNeeded()
        }

        updateAuthorizationStates(
            microphoneState: currentMicrophoneAuthorizationState(),
            speechState: currentSpeechAuthorizationState(),
            accessibilityState: currentAccessibilityAuthorizationState(prompt: promptAccessibility),
            inputMonitoringState: currentInputMonitoringAuthorizationState()
        )

        statusBarController?.refreshAll()
        ensureHotkeyMonitorRunning()
    }

    private func ensureHotkeyMonitorRunning() {
        let accessibilityGranted = currentAccessibilityAuthorizationState(prompt: false) == .granted
        let inputMonitoringGranted = currentInputMonitoringAuthorizationState() == .granted

        guard accessibilityGranted, inputMonitoringGranted else {
            shortcutMonitor.stop()
            if statusBarController != nil {
                statusBarController?.setTransientStatus(Self.shortcutMonitoringFailureMessage)
            }
            return
        }

        guard shortcutMonitor.start() else {
            statusBarController?.setTransientStatus(Self.shortcutMonitoringFailureMessage)
            return
        }

        if statusBarController != nil, model.errorState == nil {
            statusBarController?.setTransientStatus(nil)
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
        let state = InputMonitoringAccess.authorizationState()
        if state == .unknown, hasAttemptedInputMonitoringRequest {
            return .denied
        }
        return state
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestSpeechPermissionIfNeededIfNeededForBackend() async -> Bool {
        guard model.asrBackend == .appleSpeech else {
            return currentSpeechAuthorizationState() == .granted || currentSpeechAuthorizationState() == .unknown
        }

        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func requestInputMonitoringPermissionIfNeeded() -> Bool {
        hasAttemptedInputMonitoringRequest = true
        return InputMonitoringAccess.requestIfNeeded()
    }

    private func requestMicrophonePermissionFromSettings() async {
        _ = await requestMicrophonePermissionIfNeeded()
        await refreshPermissionStates(promptAccessibility: false)
    }

    private func requestSpeechPermissionFromSettings() async {
        _ = await requestSpeechPermissionIfNeededIfNeededForBackend()
        await refreshPermissionStates(promptAccessibility: false)
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
    nonisolated func shortcutMonitorDidPress(_ monitor: ShortcutMonitor) {
        Task { @MainActor [weak self] in
            self?.beginRecording()
        }
    }

    nonisolated func shortcutMonitorDidRelease(_ monitor: ShortcutMonitor) {
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
        shortcutMonitor.shortcut = shortcut
        controller.refreshAll()
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
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func statusBarControllerDidRequestOpenMicrophoneSettings(_ controller: StatusBarController) {
        Task { @MainActor [weak self] in
            await self?.requestMicrophonePermissionFromSettings()
        }
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    func statusBarControllerDidRequestOpenSpeechSettings(_ controller: StatusBarController) {
        Task { @MainActor [weak self] in
            await self?.requestSpeechPermissionFromSettings()
        }
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
    }

    func statusBarControllerDidRequestOpenInputMonitoringSettings(_ controller: StatusBarController) {
        if currentInputMonitoringAuthorizationState() == .unknown {
            _ = requestInputMonitoringPermissionIfNeeded()

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                await self?.refreshPermissionStates(promptAccessibility: false)
            }

            if currentInputMonitoringAuthorizationState() == .granted {
                return
            }
        }

        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func statusBarControllerDidRequestRefreshPermissions(_ controller: StatusBarController) async {
        await refreshPermissionStates(promptAccessibility: false)
    }

    func statusBarControllerDidRequestPromptAccessibilityPermission(_ controller: StatusBarController) {
        _ = requestAccessibilityPermission(prompt: true)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await self?.refreshPermissionStates(promptAccessibility: false)
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
}
