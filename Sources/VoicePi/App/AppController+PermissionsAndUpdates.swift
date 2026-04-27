import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

@MainActor
extension AppController {
    func prepareForRecording() async -> Bool {
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

    func refreshPermissionStates(
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
                offerPermissionSettingsPrompt(
                    for: .accessibility,
                    source: Self.accessibilityPermissionPromptSource(from: inputMonitoringPromptSource)
                )
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

        if Self.shouldDeferRemainingPermissionPromptsAfterAccessibilityLaunch(
            promptAccessibility: promptAccessibility,
            useSystemAccessibilityPrompt: useSystemAccessibilityPrompt,
            accessibilityStateAfterPrompt: accessibilityStateAfterPrompt
        ) {
            updateAuthorizationStates(
                microphoneState: currentMicrophoneAuthorizationState(),
                speechState: currentSpeechAuthorizationState(),
                accessibilityState: accessibilityStateAfterPrompt,
                inputMonitoringState: currentInputMonitoringAuthorizationState()
            )
            ensureHotkeyMonitorRunning()
            return
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

    func scheduleAccessibilityAuthorizationFollowUp() {
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

    func scheduleInputMonitoringAuthorizationFollowUp() {
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
    func ensureHotkeyMonitorRunning() -> String? {
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
        refreshCancelShortcutMonitorState(
            inputMonitoringState: inputMonitoringState,
            accessibilityState: accessibilityState
        )
        return statusMessage
    }

    func refreshCancelShortcutMonitorState(
        inputMonitoringState: AuthorizationState? = nil,
        accessibilityState: AuthorizationState? = nil
    ) {
        guard isStartingRecording || speechRecorder.isRecording || isProcessingRelease else {
            cancelShortcutAction.stop()
            return
        }

        let resolvedInputMonitoringState = inputMonitoringState ?? currentInputMonitoringAuthorizationState()
        let resolvedAccessibilityState = accessibilityState ?? currentAccessibilityAuthorizationState(prompt: false)
        let plan = Self.cancelShortcutMonitorPlan(
            shortcut: model.cancelShortcut,
            inputMonitoringState: resolvedInputMonitoringState,
            accessibilityState: resolvedAccessibilityState
        )

        let fallbackPlanAfterRegistrationFailure = model.cancelShortcut.isRegisteredHotkeyCompatible
            ? Self.hotkeyMonitorFallbackPlanAfterRegistrationFailure(
                shortcut: model.cancelShortcut,
                inputMonitoringState: resolvedInputMonitoringState,
                accessibilityState: resolvedAccessibilityState
            )
            : nil

        _ = applyHotkeyMonitorPlan(
            plan,
            actionController: cancelShortcutAction,
            registrationFailureMessage: "Cancel shortcut registration is unavailable.",
            monitoringFailureMessage: "Cancel shortcut monitoring is unavailable.",
            fallbackPlanAfterRegistrationFailure: fallbackPlanAfterRegistrationFailure
        )
    }

    func applyHotkeyMonitorPlan(
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

    func currentMicrophoneAuthorizationState() -> AuthorizationState {
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

    func currentShortcutsRequireInputMonitoring() -> Bool {
        Self.shortcutsRequireInputMonitoring(
            activationShortcut: model.activationShortcut,
            modeCycleShortcut: model.modeCycleShortcut,
            processorShortcut: model.processorShortcut,
            cancelShortcut: model.cancelShortcut,
            promptCycleShortcut: model.promptCycleShortcut
        )
    }

    func currentSpeechAuthorizationState() -> AuthorizationState {
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

    func currentAccessibilityAuthorizationState(prompt: Bool) -> AuthorizationState {
        requestAccessibilityPermission(prompt: prompt) ? .granted : .denied
    }

    func currentInputMonitoringAuthorizationState() -> AuthorizationState {
        InputMonitoringAccess.authorizationState()
    }

    func requestInputMonitoringPermissionIfNeededAfterShortcutUpdate(_ shortcut: ActivationShortcut) {
        let inputMonitoringState = currentInputMonitoringAuthorizationState()
        guard Self.shouldRequestInputMonitoringAfterShortcutUpdate(
            updatedShortcut: shortcut,
            inputMonitoringState: inputMonitoringState
        ) else {
            return
        }

        let shouldPromptAccessibility = currentAccessibilityAuthorizationState(prompt: false) != .granted
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshPermissionStates(
                promptAccessibility: shouldPromptAccessibility,
                requestInputMonitoringPermission: true,
                inputMonitoringPromptSource: .manualSettingsButton
            )
        }
    }

    func requestMicrophonePermissionIfNeeded() async -> Bool {
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

    func requestSpeechPermissionIfNeededIfNeededForBackend() async -> Bool {
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

    func requestAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func offerMediaPermissionPrePrompt(for destination: PermissionSettingsDestination) -> Bool {
        let prompt = Self.mediaPermissionPrePrompt(for: destination)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = prompt.messageText
        alert.informativeText = prompt.informativeText
        alert.addButton(withTitle: prompt.continueTitle)
        alert.addButton(withTitle: "Not Now")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func updateAuthorizationStates(
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

    func presentTransientError(_ message: String) {
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

}
