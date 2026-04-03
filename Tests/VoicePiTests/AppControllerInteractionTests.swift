import Testing
@testable import VoicePi
import AppKit

struct AppControllerInteractionTests {
    @Test
    @MainActor
    func hotkeyMonitorPlanUsesSingleCombinedMonitorWhenBothPermissionsAreGranted() {
        #expect(
            AppController.hotkeyMonitorPlan(
                shortcut: ActivationShortcut(
                    keyCodes: [],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                inputMonitoringState: .granted,
                accessibilityState: .granted
            ) == AppController.HotkeyMonitorPlan(
                strategy: .eventTap(.listenAndSuppress),
                statusMessage: nil
            )
        )
    }

    @Test
    @MainActor
    func hotkeyMonitorPlanFallsBackToListenOnlyWhenAccessibilityIsMissing() {
        #expect(
            AppController.hotkeyMonitorPlan(
                shortcut: ActivationShortcut(
                    keyCodes: [],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                inputMonitoringState: .granted,
                accessibilityState: .denied
            ) == AppController.HotkeyMonitorPlan(
                strategy: .eventTap(.listenOnly),
                statusMessage: "Shortcut listening is active, but Accessibility is still required to suppress the shortcut and inject pasted text."
            )
        )
    }

    @Test
    @MainActor
    func standardShortcutUsesRegisteredHotkeyWithoutInputMonitoring() {
        #expect(
            AppController.hotkeyMonitorPlan(
                shortcut: ActivationShortcut(
                    keyCodes: [49],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                inputMonitoringState: .denied,
                accessibilityState: .granted
            ) == AppController.HotkeyMonitorPlan(
                strategy: .registeredHotkey,
                statusMessage: nil
            )
        )
    }

    @Test
    @MainActor
    func standardShortcutOnlyWarnsAboutAccessibilityForPasteInjection() {
        #expect(
            AppController.hotkeyMonitorPlan(
                shortcut: ActivationShortcut(
                    keyCodes: [49],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                inputMonitoringState: .denied,
                accessibilityState: .denied
            ) == AppController.HotkeyMonitorPlan(
                strategy: .registeredHotkey,
                statusMessage: "Shortcut listening is active, but Accessibility is still required to inject pasted text."
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
    func launchPromptsShortcutPermissionsForAdvancedShortcutDefaults() {
        let advancedShortcut = ActivationShortcut(
            keyCodes: [],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(AppController.shouldPromptAccessibilityOnLaunch(shortcut: advancedShortcut, inputMonitoringState: .unknown))
        #expect(AppController.shouldPromptAccessibilityOnLaunch(shortcut: advancedShortcut, inputMonitoringState: .denied))
        #expect(AppController.shouldPromptAccessibilityOnLaunch(shortcut: advancedShortcut, inputMonitoringState: .granted))
    }

    @Test
    @MainActor
    func launchPromptsAccessibilityForStandardShortcuts() {
        let standardShortcut = ActivationShortcut(
            keyCodes: [49],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(AppController.shouldPromptAccessibilityOnLaunch(shortcut: standardShortcut, inputMonitoringState: .unknown))
        #expect(AppController.shouldPromptAccessibilityOnLaunch(shortcut: standardShortcut, inputMonitoringState: .denied))
        #expect(AppController.shouldPromptAccessibilityOnLaunch(shortcut: standardShortcut, inputMonitoringState: .granted))
    }

    @Test
    @MainActor
    func launchPermissionPlanRequestsMediaAndAccessibilityForStandardShortcuts() {
        let standardShortcut = ActivationShortcut(
            keyCodes: [49],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(
            AppController.launchPermissionPlan(
                shortcut: standardShortcut,
                inputMonitoringState: .unknown
            ) == .init(
                requestMediaPermissions: true,
                promptAccessibility: true,
                requestInputMonitoringPermission: false,
                useSystemAccessibilityPrompt: true
            )
        )
    }

    @Test
    @MainActor
    func launchPermissionPlanRequestsInputMonitoringOnlyForAdvancedShortcuts() {
        let advancedShortcut = ActivationShortcut(
            keyCodes: [],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(
            AppController.launchPermissionPlan(
                shortcut: advancedShortcut,
                inputMonitoringState: .unknown
            ) == .init(
                requestMediaPermissions: true,
                promptAccessibility: true,
                requestInputMonitoringPermission: true,
                useSystemAccessibilityPrompt: true
            )
        )
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
    func launchOpensInputMonitoringSettingsOnlyWhenInputMonitoringIsDeniedAfterRequest() {
        #expect(
            !AppController.shouldOfferInputMonitoringSettingsOnLaunch(
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
            AppController.shouldOfferInputMonitoringSettingsOnLaunch(
                requestGranted: false,
                inputMonitoringState: .restricted
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
    func inputMonitoringPromptStartsFollowUpWhileWaitingForGrant() {
        #expect(
            AppController.shouldAwaitInputMonitoringAuthorization(
                requestInputMonitoringPermission: true,
                inputMonitoringStateAfterRequest: .unknown
            )
        )
        #expect(
            AppController.shouldAwaitInputMonitoringAuthorization(
                requestInputMonitoringPermission: true,
                inputMonitoringStateAfterRequest: .denied
            )
        )
        #expect(
            !AppController.shouldAwaitInputMonitoringAuthorization(
                requestInputMonitoringPermission: true,
                inputMonitoringStateAfterRequest: .granted
            )
        )
        #expect(
            !AppController.shouldAwaitInputMonitoringAuthorization(
                requestInputMonitoringPermission: false,
                inputMonitoringStateAfterRequest: .unknown
            )
        )
    }

    @Test
    @MainActor
    func inputMonitoringLaunchActionRequestsSystemPromptForUnknownState() {
        #expect(
            AppController.inputMonitoringLaunchAction(
                authorizationState: .unknown
            ) == .requestSystemPrompt
        )
    }

    @Test
    @MainActor
    func inputMonitoringLaunchActionOpensSettingsForDeniedState() {
        #expect(
            AppController.inputMonitoringLaunchAction(
                authorizationState: .denied
            ) == .openSettingsPrompt
        )
    }

    @Test
    @MainActor
    func inputMonitoringLaunchActionDoesNothingWhenAlreadyGranted() {
        #expect(
            AppController.inputMonitoringLaunchAction(
                authorizationState: .granted
            ) == .none
        )
    }

    @Test
    @MainActor
    func hotkeyMonitorPlanRequiresInputMonitoringForListeningAndAccessibilityForSuppression() {
        #expect(
            AppController.hotkeyMonitorPlan(
                shortcut: ActivationShortcut(
                    keyCodes: [],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                inputMonitoringState: .denied,
                accessibilityState: .granted
            ) == AppController.HotkeyMonitorPlan(
                strategy: nil,
                statusMessage: "Global shortcut monitoring is unavailable. Input Monitoring is required to listen for the shortcut, and Accessibility is required to suppress and inject events."
            )
        )
    }
}
