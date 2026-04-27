import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

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
        refreshCancelShortcutMonitorState()
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
        requestInputMonitoringPermissionIfNeededAfterShortcutUpdate(shortcut)
    }

    func statusBarController(_ controller: StatusBarController, didUpdateCancelShortcut shortcut: ActivationShortcut) {
        model.setCancelShortcut(shortcut)
        cancelShortcutAction.shortcut = shortcut
        controller.refreshAll()
        ensureHotkeyMonitorRunning()
        requestInputMonitoringPermissionIfNeededAfterShortcutUpdate(shortcut)
    }

    func statusBarController(_ controller: StatusBarController, didUpdateModeCycleShortcut shortcut: ActivationShortcut) {
        model.setModeCycleShortcut(shortcut)
        modeCycleShortcutAction.shortcut = shortcut
        controller.refreshAll()
        ensureHotkeyMonitorRunning()
        requestInputMonitoringPermissionIfNeededAfterShortcutUpdate(shortcut)
    }

    func statusBarController(_ controller: StatusBarController, didUpdatePromptCycleShortcut shortcut: ActivationShortcut) {
        model.setPromptCycleShortcut(shortcut)
        promptCycleShortcutAction.shortcut = shortcut
        controller.refreshAll()
        ensureHotkeyMonitorRunning()
        requestInputMonitoringPermissionIfNeededAfterShortcutUpdate(shortcut)
    }

    func statusBarController(_ controller: StatusBarController, didUpdateProcessorShortcut shortcut: ActivationShortcut) {
        model.setProcessorShortcut(shortcut)
        processorShortcutAction.shortcut = shortcut
        controller.refreshAll()
        ensureHotkeyMonitorRunning()
        requestInputMonitoringPermissionIfNeededAfterShortcutUpdate(shortcut)
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

    func openSystemSettingsPane(_ rawURL: String) {
        guard let url = URL(string: rawURL) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func offerInputMonitoringSettingsPrompt(source: PermissionPromptSource) {
        offerPermissionSettingsPrompt(for: .inputMonitoring, source: source)
    }

    func offerPermissionSettingsPrompt(
        for destination: PermissionSettingsDestination,
        source: PermissionPromptSource,
        beforeOpen: (() -> Void)? = nil
    ) {
        if Self.permissionSettingsTransitionStyle(for: destination) == .permissionFlow,
           let guidanceDestination = Self.permissionGuidanceFlowDestination(for: destination) {
            if Self.shouldActivateAppForPermissionPrompt(source: source) {
                NSApp.activate(ignoringOtherApps: true)
            }
            beforeOpen?()
            permissionGuidanceFlow.present(for: guidanceDestination)
            return
        }

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
