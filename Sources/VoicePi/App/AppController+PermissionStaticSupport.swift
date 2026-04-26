import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

extension AppController {
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
            cancelShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
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
            cancelShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
            promptCycleShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
            inputMonitoringState: inputMonitoringState
        )
    }

    static func launchPermissionPlan(
        activationShortcut: ActivationShortcut,
        modeCycleShortcut: ActivationShortcut,
        processorShortcut: ActivationShortcut,
        cancelShortcut: ActivationShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
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
                cancelShortcut: cancelShortcut,
                promptCycleShortcut: promptCycleShortcut
            ),
            useSystemAccessibilityPrompt: false
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
        cancelShortcut: ActivationShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
        promptCycleShortcut: ActivationShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
    ) -> Bool {
        activationShortcut.requiresInputMonitoring
            || modeCycleShortcut.requiresInputMonitoring
            || processorShortcut.requiresInputMonitoring
            || cancelShortcut.requiresInputMonitoring
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

    static func monitorPlan(
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

    static func shouldDeferRemainingPermissionPromptsAfterAccessibilityLaunch(
        promptAccessibility: Bool,
        useSystemAccessibilityPrompt: Bool,
        accessibilityStateAfterPrompt: AuthorizationState
    ) -> Bool {
        promptAccessibility &&
        !useSystemAccessibilityPrompt &&
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
        switch destination {
        case .accessibility, .inputMonitoring:
            return .permissionFlow
        case .microphone, .speech:
            return .customPrompt
        }
    }

    static func permissionGuidanceFlowDestination(
        for destination: PermissionSettingsDestination
    ) -> PermissionGuidanceFlowDestination? {
        switch destination {
        case .accessibility:
            return .accessibility
        case .inputMonitoring:
            return .inputMonitoring
        case .microphone, .speech:
            return nil
        }
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

    static func accessibilityPermissionPromptSource(
        from source: PermissionPromptSource
    ) -> PermissionPromptSource {
        source
    }

}
