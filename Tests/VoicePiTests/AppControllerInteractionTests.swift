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
    func launchOpensInputMonitoringSettingsWhenRequestDoesNotGrantAccess() {
        #expect(
            AppController.shouldOpenInputMonitoringSettingsOnLaunch(
                requestGranted: false,
                inputMonitoringState: .unknown
            )
        )
        #expect(
            AppController.shouldOpenInputMonitoringSettingsOnLaunch(
                requestGranted: false,
                inputMonitoringState: .denied
            )
        )
        #expect(
            !AppController.shouldOpenInputMonitoringSettingsOnLaunch(
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
