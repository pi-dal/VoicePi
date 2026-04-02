import Testing
@testable import VoicePi

struct AppControllerInteractionTests {
    @Test
    @MainActor
    func hotkeyMonitorPlanUsesSingleCombinedMonitorWhenBothPermissionsAreGranted() {
        #expect(
            AppController.hotkeyMonitorPlan(
                inputMonitoringState: .granted,
                accessibilityState: .granted
            ) == AppController.HotkeyMonitorPlan(
                primaryMonitorMode: .listenAndSuppress,
                statusMessage: nil
            )
        )
    }

    @Test
    @MainActor
    func hotkeyMonitorPlanFallsBackToListenOnlyWhenAccessibilityIsMissing() {
        #expect(
            AppController.hotkeyMonitorPlan(
                inputMonitoringState: .granted,
                accessibilityState: .denied
            ) == AppController.HotkeyMonitorPlan(
                primaryMonitorMode: .listenOnly,
                statusMessage: "Shortcut listening is active, but Accessibility is still required to suppress the shortcut and inject pasted text."
            )
        )
    }

    @Test
    @MainActor
    func pressStartsRecordingWhenIdle() {
        #expect(
            AppController.pressAction(
                isRecording: false,
                isStartingRecording: false,
                isProcessingRelease: false
            ) == .startRecording
        )
    }

    @Test
    @MainActor
    func pressCancelsProcessingWhenOverlayIsStillProcessing() {
        #expect(
            AppController.pressAction(
                isRecording: false,
                isStartingRecording: false,
                isProcessingRelease: true
            ) == .cancelProcessing
        )
    }

    @Test
    @MainActor
    func pressIsIgnoredWhileRecordingIsStarting() {
        #expect(
            AppController.pressAction(
                isRecording: false,
                isStartingRecording: true,
                isProcessingRelease: false
            ) == .ignore
        )
    }

    @Test
    @MainActor
    func releaseIsIgnoredWhileActivelyRecording() {
        #expect(
            AppController.releaseAction(
                isRecording: true,
                isStartingRecording: false,
                isProcessingRelease: false
            ) == .ignore
        )
    }

    @Test
    @MainActor
    func secondPressStopsAnActiveRecording() {
        #expect(
            AppController.pressAction(
                isRecording: true,
                isStartingRecording: false,
                isProcessingRelease: false
            ) == .stopRecording
        )
    }

    @Test
    @MainActor
    func shortcutMonitoringFailureMessageCallsOutInputMonitoringRequirement() {
        #expect(
            AppController.shortcutMonitoringFailureMessage
                == "Global shortcut monitoring is unavailable. Input Monitoring is required to listen for the shortcut, and Accessibility is required to suppress and inject events."
        )
    }

    @Test
    @MainActor
    func launchPromptsAccessibilityBeforeInputMonitoringStateIsResolved() {
        #expect(AppController.shouldPromptAccessibilityOnLaunch(inputMonitoringState: .unknown))
        #expect(AppController.shouldPromptAccessibilityOnLaunch(inputMonitoringState: .denied))
        #expect(AppController.shouldPromptAccessibilityOnLaunch(inputMonitoringState: .granted))
    }

    @Test
    @MainActor
    func permissionRefreshSequenceSkipsInputMonitoringUntilAccessibilityIsGranted() {
        #expect(
            AppController.permissionRefreshSequence(
                requestMediaPermissions: true,
                promptAccessibility: true,
                requestInputMonitoringPermission: true,
                accessibilityStateAfterPrompt: .denied
            ) == [.mediaPermissions, .accessibility]
        )
        #expect(
            AppController.permissionRefreshSequence(
                requestMediaPermissions: true,
                promptAccessibility: true,
                requestInputMonitoringPermission: true,
                accessibilityStateAfterPrompt: .granted
            ) == [.mediaPermissions, .accessibility, .inputMonitoring]
        )
    }

    @Test
    @MainActor
    func accessibilityPromptStartsFollowUpWhileWaitingToAdvanceToInputMonitoring() {
        #expect(
            AppController.shouldAwaitAccessibilityAuthorization(
                promptAccessibility: true,
                requestInputMonitoringPermission: true,
                accessibilityStateAfterPrompt: .denied
            )
        )
        #expect(
            !AppController.shouldAwaitAccessibilityAuthorization(
                promptAccessibility: true,
                requestInputMonitoringPermission: true,
                accessibilityStateAfterPrompt: .granted
            )
        )
        #expect(
            !AppController.shouldAwaitAccessibilityAuthorization(
                promptAccessibility: false,
                requestInputMonitoringPermission: true,
                accessibilityStateAfterPrompt: .denied
            )
        )
    }

    @Test
    @MainActor
    func permissionSettingsPromptsUseConsistentCopyAndDestinations() {
        #expect(
            AppController.permissionSettingsPrompt(for: .accessibility) == .init(
                messageText: "Accessibility Still Needs Approval",
                informativeText: "VoicePi can continue setup by opening the Accessibility settings page. Open System Settings now?",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        )
        #expect(
            AppController.permissionSettingsPrompt(for: .inputMonitoring) == .init(
                messageText: "Input Monitoring Still Needs Approval",
                informativeText: "VoicePi can continue setup by opening the Input Monitoring settings page. Open System Settings now?",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
            )
        )
    }

    @Test
    @MainActor
    func followUpPermissionPromptsBringVoicePiToFront() {
        #expect(AppController.shouldActivateAppForPermissionPrompt(source: .accessibilityFollowUp))
        #expect(AppController.shouldActivateAppForPermissionPrompt(source: .launchFollowUp))
        #expect(!AppController.shouldActivateAppForPermissionPrompt(source: .manualSettingsButton))
    }

    @Test
    @MainActor
    func permissionSettingsTransitionsPreferCustomSettingsPrompts() {
        #expect(AppController.permissionSettingsTransitionStyle(for: .accessibility) == .customPrompt)
        #expect(AppController.permissionSettingsTransitionStyle(for: .inputMonitoring) == .customPrompt)
    }

    @Test
    @MainActor
    func firstRunMediaPermissionsUseCustomPrePromptsBeforeSystemSheets() {
        #expect(
            AppController.mediaPermissionTransitionStyle(
                for: .microphone,
                authorizationState: .unknown
            ) == .customPrePromptThenSystemRequest
        )
        #expect(
            AppController.mediaPermissionTransitionStyle(
                for: .speech,
                authorizationState: .unknown
            ) == .customPrePromptThenSystemRequest
        )
        #expect(
            AppController.mediaPermissionTransitionStyle(
                for: .microphone,
                authorizationState: .denied
            ) == .customSettingsPrompt
        )
    }

    @Test
    @MainActor
    func mediaPermissionPrePromptsUseGuidedCopy() {
        #expect(
            AppController.mediaPermissionPrePrompt(for: .microphone) == .init(
                messageText: "Microphone Permission",
                informativeText: "VoicePi uses the microphone to capture your dictation. Continue to the macOS permission prompt?",
                continueTitle: "Continue"
            )
        )
        #expect(
            AppController.mediaPermissionPrePrompt(for: .speech) == .init(
                messageText: "Speech Recognition Permission",
                informativeText: "VoicePi uses Speech Recognition for on-device and Apple speech transcription. Continue to the macOS permission prompt?",
                continueTitle: "Continue"
            )
        )
    }

    @Test
    @MainActor
    func launchOpensInputMonitoringSettingsWhenRequestDoesNotGrantAccess() {
        #expect(
            AppController.shouldOfferInputMonitoringSettingsOnLaunch(
                requestGranted: false,
                inputMonitoringState: .unknown
            )
        )
        #expect(
            AppController.shouldOfferInputMonitoringSettingsOnLaunch(
                requestGranted: false,
                inputMonitoringState: .denied
            )
        )
        #expect(
            !AppController.shouldOfferInputMonitoringSettingsOnLaunch(
                requestGranted: true,
                inputMonitoringState: .granted
            )
        )
    }

    @Test
    @MainActor
    func hotkeyMonitorPlanRequiresInputMonitoringForListeningAndAccessibilityForSuppression() {
        #expect(
            AppController.hotkeyMonitorPlan(
                inputMonitoringState: .denied,
                accessibilityState: .granted
            ) == AppController.HotkeyMonitorPlan(
                primaryMonitorMode: nil,
                statusMessage: "Global shortcut monitoring is unavailable. Input Monitoring is required to listen for the shortcut, and Accessibility is required to suppress and inject events."
            )
        )
    }
}
