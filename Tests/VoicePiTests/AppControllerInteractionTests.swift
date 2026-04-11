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
    func currentShortcutsDoNotRequireInputMonitoringWhenBothUseRegisteredHotkeysOrAreUnset() {
        #expect(
            !AppController.shortcutsRequireInputMonitoring(
                activationShortcut: ActivationShortcut(
                    keyCodes: [35],
                    modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
                ),
                modeCycleShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
            )
        )
        #expect(
            !AppController.shortcutsRequireInputMonitoring(
                activationShortcut: ActivationShortcut(
                    keyCodes: [49],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                modeCycleShortcut: ActivationShortcut(
                    keyCodes: [17],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .shift]).intersection(.deviceIndependentFlagsMask).rawValue
                )
            )
        )
    }

    @Test
    @MainActor
    func currentShortcutsRequireInputMonitoringWhenEitherShortcutIsAdvanced() {
        #expect(
            AppController.shortcutsRequireInputMonitoring(
                activationShortcut: ActivationShortcut(
                    keyCodes: [],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                modeCycleShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
            )
        )
        #expect(
            AppController.shortcutsRequireInputMonitoring(
                activationShortcut: ActivationShortcut(
                    keyCodes: [35],
                    modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
                ),
                modeCycleShortcut: ActivationShortcut(
                    keyCodes: [0, 1],
                    modifierFlagsRawValue: NSEvent.ModifierFlags.command.intersection(.deviceIndependentFlagsMask).rawValue
                )
            )
        )
    }

    @Test
    @MainActor
    func currentShortcutsRequireInputMonitoringWhenProcessorShortcutIsAdvanced() {
        #expect(
            AppController.shortcutsRequireInputMonitoring(
                activationShortcut: ActivationShortcut(
                    keyCodes: [35],
                    modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
                ),
                modeCycleShortcut: ActivationShortcut(
                    keyCodes: [17],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .shift]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                processorShortcut: ActivationShortcut(
                    keyCodes: [],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
                )
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
    func standardShortcutPrefersEventTapWhenInputMonitoringIsGranted() {
        #expect(
            AppController.hotkeyMonitorPlan(
                shortcut: ActivationShortcut(
                    keyCodes: [49],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                inputMonitoringState: .granted,
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
    func hotkeyFallbackPlanAfterRegistrationFailureUsesEventTapWhenInputMonitoringGranted() {
        #expect(
            AppController.hotkeyMonitorFallbackPlanAfterRegistrationFailure(
                shortcut: ActivationShortcut(
                    keyCodes: [49],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
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
                shortcut: ActivationShortcut(
                    keyCodes: [49],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                isRecording: true,
                isStartingRecording: false,
                isProcessingRelease: false
            ) == .ignore
        )
    }

    @Test
    @MainActor
    func modifierOnlyShortcutReleaseIsIgnored() {
        #expect(
            AppController.releaseAction(
                shortcut: ActivationShortcut(
                    keyCodes: [],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
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
    func realtimeStopResolutionUsesRealtimeFinalizationWhenStreamingIsReady() {
        #expect(
            AppController.realtimeStopResolution(
                backend: .remoteAliyunASR,
                isRealtimeStreamingReady: true,
                degradedToBatchFallback: false,
                hasRecordedAudio: true,
                localFallback: ""
            ) == .realtimeFinalization
        )
    }

    @Test
    @MainActor
    func realtimeStopResolutionUsesBatchFallbackWhenStreamingIsNotReadyAndAudioExists() {
        #expect(
            AppController.realtimeStopResolution(
                backend: .remoteVolcengineASR,
                isRealtimeStreamingReady: false,
                degradedToBatchFallback: false,
                hasRecordedAudio: true,
                localFallback: ""
            ) == .batchFallback
        )
    }

    @Test
    @MainActor
    func realtimeStopResolutionCancelsSilentlyWhenStreamingIsNotReadyAndNoAudioExists() {
        #expect(
            AppController.realtimeStopResolution(
                backend: .remoteAliyunASR,
                isRealtimeStreamingReady: false,
                degradedToBatchFallback: false,
                hasRecordedAudio: false,
                localFallback: "   "
            ) == .silentCancel
        )
    }

    @Test
    @MainActor
    func realtimeStopResolutionUsesBatchFallbackWhenRealtimeSessionHasDegraded() {
        #expect(
            AppController.realtimeStopResolution(
                backend: .remoteAliyunASR,
                isRealtimeStreamingReady: true,
                degradedToBatchFallback: true,
                hasRecordedAudio: true,
                localFallback: ""
            ) == .batchFallback
        )
    }

    @Test
    @MainActor
    func transcriptDeliveryRouteUsesInjectionForEditableTarget() {
        #expect(
            AppController.transcriptDeliveryRoute(
                for: "hello world",
                targetInspection: .editable
            ) == .injectableTarget
        )
    }

    @Test
    @MainActor
    func transcriptDeliveryRouteUsesFallbackForMissingInputTarget() {
        #expect(
            AppController.transcriptDeliveryRoute(
                for: "hello world",
                targetInspection: .notEditable
            ) == .fallbackPanel
        )
    }

    @Test
    @MainActor
    func externalProcessorRefinementUsesResultReviewPanelWhileStandardModesDoNot() {
        #expect(
            AppController.shouldPresentResultReviewPanel(
                refinementProvider: .externalProcessor,
                postProcessingMode: .refinement
            )
        )
        #expect(
            !AppController.shouldPresentResultReviewPanel(
                refinementProvider: .llm,
                postProcessingMode: .refinement
            )
        )
        #expect(
            !AppController.shouldPresentResultReviewPanel(
                refinementProvider: .externalProcessor,
                postProcessingMode: .disabled
            )
        )
    }

    @Test
    @MainActor
    func resultReviewInsertPrefersCapturedEditableTargetSnapshotOverLivePanelSnapshot() {
        let capturedSnapshot = EditableTextTargetSnapshot(
            inspection: .editable,
            targetIdentifier: "target-1",
            textValue: "Original draft"
        )
        let livePanelSnapshot = EditableTextTargetSnapshot(
            inspection: .notEditable,
            targetIdentifier: "voicepi-panel",
            textValue: nil
        )

        #expect(
            AppController.resultReviewInsertionTargetSnapshot(
                capturedTargetSnapshot: capturedSnapshot,
                currentTargetSnapshot: livePanelSnapshot
            ) == capturedSnapshot
        )
    }

    @Test
    @MainActor
    func resultReviewInsertFallsBackToLiveSnapshotWhenNoCapturedTargetExists() {
        let liveSnapshot = EditableTextTargetSnapshot(
            inspection: .editable,
            targetIdentifier: "target-2",
            textValue: "Live text"
        )

        #expect(
            AppController.resultReviewInsertionTargetSnapshot(
                capturedTargetSnapshot: nil,
                currentTargetSnapshot: liveSnapshot
            ) == liveSnapshot
        )
    }

    @Test
    @MainActor
    func resultReviewInsertPrefersCapturedSourceApplicationWhenVoicePiIsFrontmost() {
        #expect(
            AppController.resultReviewInsertionSourceApplicationBundleID(
                capturedSourceApplicationBundleID: "com.apple.TextEdit",
                currentFrontmostApplicationBundleID: "com.pi-dal.VoicePi"
            ) == "com.apple.TextEdit"
        )
    }

    @Test
    @MainActor
    func resultReviewInsertFallsBackToCurrentSourceApplicationWhenNothingWasCaptured() {
        #expect(
            AppController.resultReviewInsertionSourceApplicationBundleID(
                capturedSourceApplicationBundleID: nil,
                currentFrontmostApplicationBundleID: "com.apple.Safari"
            ) == "com.apple.Safari"
        )
    }

    @Test
    @MainActor
    func processorShortcutStartsDedicatedProcessorCaptureWhenIdle() {
        #expect(
            AppController.processorShortcutPressAction(
                isRecording: false,
                isStartingRecording: false,
                isProcessingRelease: false
            ) == .startProcessorCapture(.externalProcessorShortcut)
        )
    }

    @Test
    @MainActor
    func processorShortcutIsIgnoredWhileProcessingRelease() {
        #expect(
            AppController.processorShortcutPressAction(
                isRecording: false,
                isStartingRecording: false,
                isProcessingRelease: true
            ) == .ignore
        )
    }

    @Test
    @MainActor
    func processorShortcutForcesExternalProcessorRefinementWorkflow() {
        let selection = AppController.effectiveProcessingWorkflow(
            postProcessingMode: .translation,
            refinementProvider: .llm,
            override: .externalProcessorShortcut
        )

        #expect(
            selection == .init(
                postProcessingMode: .refinement,
                refinementProvider: .externalProcessor
            )
        )
    }

    @Test
    @MainActor
    func processorShortcutDoesNotSilentlyDeliverRawTranscriptWhenProcessorFails() {
        #expect(
            AppController.postProcessingFailureAction(
                workflowOverride: .externalProcessorShortcut,
                didExternalProcessorSucceed: false
            ) == .surfaceProcessorFailure
        )
    }

    @Test
    @MainActor
    func standardWorkflowStillDeliversTranscriptWhenNoProcessorOverrideExists() {
        #expect(
            AppController.postProcessingFailureAction(
                workflowOverride: nil,
                didExternalProcessorSucceed: false
            ) == .continueTranscriptDelivery
        )
    }

    @Test
    @MainActor
    func modeCycleRepeatStartsOnlyWhenShortcutIsConfiguredAndAppIsIdle() {
        #expect(
            AppController.shouldStartModeCycleRepeat(
                shortcut: ActivationShortcut(
                    keyCodes: [37],
                    modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
                ),
                isRecording: false,
                isStartingRecording: false,
                isProcessingRelease: false
            )
        )
        #expect(
            !AppController.shouldStartModeCycleRepeat(
                shortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
                isRecording: false,
                isStartingRecording: false,
                isProcessingRelease: false
            )
        )
        #expect(
            !AppController.shouldStartModeCycleRepeat(
                shortcut: ActivationShortcut(
                    keyCodes: [37],
                    modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
                ),
                isRecording: true,
                isStartingRecording: false,
                isProcessingRelease: false
            )
        )
    }

    @Test
    @MainActor
    func modeCycleRepeatScheduleUsesHoldDelayThenFastIntervals() {
        #expect(AppController.modeCycleRepeatDelayNanoseconds == 350_000_000)
        #expect(AppController.modeCycleRepeatIntervalNanoseconds == 170_000_000)
    }

    @Test
    @MainActor
    func standardModeCycleShortcutUsesModifierHeldSessionInteraction() {
        #expect(
            AppController.modeCycleInteractionStyle(
                for: ActivationShortcut(
                    keyCodes: [37],
                    modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
                )
            ) == .modifierHeldSession
        )
        #expect(
            AppController.modeCycleInteractionStyle(
                for: ActivationShortcut(
                    keyCodes: [],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
                )
            ) == .holdRepeat
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
    func launchPermissionPlanAlsoRequestsInputMonitoringWhenModeCycleShortcutIsAdvanced() {
        let activationShortcut = ActivationShortcut(
            keyCodes: [49],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
        )
        let cycleShortcut = ActivationShortcut(
            keyCodes: [],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(
            AppController.launchPermissionPlan(
                activationShortcut: activationShortcut,
                modeCycleShortcut: cycleShortcut,
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
    func launchPermissionPlanAlsoRequestsInputMonitoringWhenProcessorShortcutIsAdvanced() {
        let activationShortcut = ActivationShortcut(
            keyCodes: [49],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
        )
        let processorShortcut = ActivationShortcut(
            keyCodes: [],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(
            AppController.launchPermissionPlan(
                activationShortcut: activationShortcut,
                modeCycleShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
                processorShortcut: processorShortcut,
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

    @Test
    @MainActor
    func modeCycleShortcutCanListenWithoutAccessibilityButWarnsThatSuppressionIsUnavailable() {
        #expect(
            AppController.modeCycleShortcutMonitorPlan(
                shortcut: ActivationShortcut(
                    keyCodes: [],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                inputMonitoringState: .granted,
                accessibilityState: .denied
            ) == AppController.HotkeyMonitorPlan(
                strategy: .eventTap(.listenOnly),
                statusMessage: "Mode-switch shortcut listening is active, but Accessibility is still required to suppress the shortcut before it reaches the frontmost app."
            )
        )
    }

    @Test
    @MainActor
    func processorShortcutCanListenWithoutAccessibilityButWarnsThatSuppressionIsUnavailable() {
        #expect(
            AppController.processorShortcutMonitorPlan(
                shortcut: ActivationShortcut(
                    keyCodes: [],
                    modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
                ),
                inputMonitoringState: .granted,
                accessibilityState: .denied
            ) == AppController.HotkeyMonitorPlan(
                strategy: .eventTap(.listenOnly),
                statusMessage: "Processor shortcut listening is active, but Accessibility is still required to suppress the shortcut before it reaches the frontmost app."
            )
        )
    }

    @Test
    @MainActor
    func automaticUpdatePromptOnlyAppearsOncePerVersion() {
        #expect(
            AppController.shouldPresentUpdatePrompt(
                trigger: .automatic,
                availableVersion: "1.4.0",
                lastPromptedVersion: nil
            )
        )
        #expect(
            !AppController.shouldPresentUpdatePrompt(
                trigger: .automatic,
                availableVersion: "1.4.0",
                lastPromptedVersion: "1.4.0"
            )
        )
        #expect(
            AppController.shouldPresentUpdatePrompt(
                trigger: .automatic,
                availableVersion: "1.4.1",
                lastPromptedVersion: "1.4.0"
            )
        )
    }

    @Test
    @MainActor
    func manualUpdateCheckAlwaysAllowsPromptForAvailableVersion() {
        #expect(
            AppController.shouldPresentUpdatePrompt(
                trigger: .manual,
                availableVersion: "1.4.0",
                lastPromptedVersion: "1.4.0"
            )
        )
    }

    @Test
    @MainActor
    func manualUpdateCheckShowsDialogWhenAlreadyUpToDate() {
        #expect(
            AppController.shouldPresentManualUpdateResultDialog(
                trigger: .manual,
                result: .upToDate(currentVersion: "1.4.0")
            )
        )
        #expect(
            !AppController.shouldPresentManualUpdateResultDialog(
                trigger: .automatic,
                result: .upToDate(currentVersion: "1.4.0")
            )
        )
    }
}
