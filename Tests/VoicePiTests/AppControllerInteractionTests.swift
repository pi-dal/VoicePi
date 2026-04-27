import Testing
@testable import VoicePi
import AppKit

struct AppControllerInteractionTests {
    @Test
    @MainActor
    func debugSettingsCaptureConfigurationParsesSectionAliasesAndThemeOverride() {
        #expect(
            AppController.debugSettingsCaptureConfiguration(from: [
                "VOICEPI_DEBUG_SETTINGS_SECTION": "text",
                "VOICEPI_DEBUG_INTERFACE_THEME": "dark"
            ]) == AppController.DebugSettingsCaptureConfiguration(
                section: .llm,
                interfaceTheme: .dark,
                scrollPosition: .top
            )
        )
        #expect(
            AppController.debugSettingsCaptureConfiguration(from: [
                "VOICEPI_DEBUG_SETTINGS_SECTION": "processors",
                "VOICEPI_DEBUG_INTERFACE_THEME": "light",
                "VOICEPI_DEBUG_SETTINGS_SCROLL": "bottom"
            ]) == AppController.DebugSettingsCaptureConfiguration(
                section: .externalProcessors,
                interfaceTheme: .light,
                scrollPosition: .bottom
            )
        )
        #expect(
            AppController.debugSettingsCaptureConfiguration(from: [
                "VOICEPI_DEBUG_SETTINGS_SECTION": "provider"
            ]) == AppController.DebugSettingsCaptureConfiguration(
                section: .provider,
                interfaceTheme: nil,
                scrollPosition: .top
            )
        )
    }

    @Test
    @MainActor
    func debugSettingsCaptureConfigurationReturnsNilWithoutRecognizedSection() {
        #expect(AppController.debugSettingsCaptureConfiguration(from: [:]) == nil)
        #expect(
            AppController.debugSettingsCaptureConfiguration(from: [
                "VOICEPI_DEBUG_SETTINGS_SECTION": "unknown",
                "VOICEPI_DEBUG_INTERFACE_THEME": "dark"
            ]) == nil
        )
        #expect(
            AppController.debugSettingsCaptureConfiguration(from: [
                "VOICEPI_DEBUG_SETTINGS_SECTION": "text",
                "VOICEPI_DEBUG_SETTINGS_SCROLL": "invalid"
            ]) == AppController.DebugSettingsCaptureConfiguration(
                section: .llm,
                interfaceTheme: nil,
                scrollPosition: .top
            )
        )
    }

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
    func escapeCancelMonitorPlanUsesCombinedEventTapWhenBothPermissionsAreGranted() {
        #expect(
            AppController.escapeCancelMonitorPlan(
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
    func escapeCancelMonitorPlanStaysDisabledWhenAccessibilityIsMissing() {
        #expect(
            AppController.escapeCancelMonitorPlan(
                inputMonitoringState: .granted,
                accessibilityState: .denied
            ) == AppController.HotkeyMonitorPlan(
                strategy: nil,
                statusMessage: nil
            )
        )
    }

    @Test
    @MainActor
    func commandPeriodCancelMonitorPlanUsesRegisteredHotkeyWithoutExtraPermissions() {
        #expect(
            AppController.commandPeriodCancelMonitorPlan() == AppController.HotkeyMonitorPlan(
                strategy: .registeredHotkey,
                statusMessage: nil
            )
        )
    }

    @Test
    @MainActor
    func cancelShortcutMonitorPlanPrefersRegisteredHotkeyForStandardShortcut() {
        #expect(
            AppController.cancelShortcutMonitorPlan(
                shortcut: ActivationShortcut(
                    keyCodes: [47],
                    modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
                ),
                inputMonitoringState: .unknown,
                accessibilityState: .unknown
            ) == AppController.HotkeyMonitorPlan(
                strategy: .registeredHotkey,
                statusMessage: nil
            )
        )
    }

    @Test
    @MainActor
    func cancelShortcutMonitorPlanRequiresAdvancedPathForEscape() {
        #expect(
            AppController.cancelShortcutMonitorPlan(
                shortcut: ActivationShortcut(keyCodes: [53], modifierFlagsRawValue: 0),
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
    func escapeCancelActionCancelsStartupBeforeOtherStates() {
        #expect(
            AppController.escapeCancelAction(
                isStartingRecording: true,
                isRecording: true,
                isProcessingRelease: true
            ) == .cancelStartup
        )
    }

    @Test
    @MainActor
    func escapeCancelActionCancelsRecordingWhenCaptureIsActive() {
        #expect(
            AppController.escapeCancelAction(
                isStartingRecording: false,
                isRecording: true,
                isProcessingRelease: false
            ) == .cancelRecording
        )
    }

    @Test
    @MainActor
    func escapeCancelActionCancelsProcessingWhenOverlayIsBusy() {
        #expect(
            AppController.escapeCancelAction(
                isStartingRecording: false,
                isRecording: false,
                isProcessingRelease: true
            ) == .cancelProcessing
        )
    }

    @Test
    @MainActor
    func escapeCancelActionIsIgnoredWhenVoicePiIsIdle() {
        #expect(
            AppController.escapeCancelAction(
                isStartingRecording: false,
                isRecording: false,
                isProcessingRelease: false
            ) == .ignore
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
    func pressStartsSelectionRewriteWhenIdleAndSelectionIsConfirmed() {
        #expect(
            AppController.pressAction(
                isRecording: false,
                isStartingRecording: false,
                isProcessingRelease: false,
                hasConfirmedSelectionForRewrite: true
            ) == .startSelectionRewrite
        )
    }

    @Test
    @MainActor
    func externalProcessorShortcutBypassesSelectionRewriteWhenSelectionIsConfirmed() {
        #expect(
            AppController.pressAction(
                isRecording: false,
                isStartingRecording: false,
                isProcessingRelease: false,
                hasConfirmedSelectionForRewrite: true,
                workflowOverride: .externalProcessorShortcut
            ) == .startRecording
        )
    }

    @Test
    @MainActor
    func pressStillStopsRecordingBeforeSelectionRewriteWhenRecordingIsActive() {
        #expect(
            AppController.pressAction(
                isRecording: true,
                isStartingRecording: false,
                isProcessingRelease: false,
                hasConfirmedSelectionForRewrite: true
            ) == .stopRecording
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
    func refinementReviewPanelSupportsBothLLMAndExternalProcessorModes() {
        #expect(
            AppController.shouldPresentResultReviewPanel(
                refinementProvider: .externalProcessor,
                postProcessingMode: .refinement
            )
        )
        #expect(
            AppController.shouldPresentResultReviewPanel(
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
        #expect(
            !AppController.shouldPresentResultReviewPanel(
                refinementProvider: .llm,
                postProcessingMode: .translation
            )
        )
    }

    @Test
    @MainActor
    func resultReviewPromptSelectionDefersPromptCommitUntilRegenerateSuccess() {
        let updated = AppController.updatedResultReviewPromptSelection(
            selectedPromptPresetID: PromptPreset.builtInDefaultID,
            selectedPromptTitle: PromptPreset.builtInDefault.title,
            pendingPromptPresetID: nil,
            pendingPromptTitle: nil,
            requestedPromptPresetID: "user.meeting",
            requestedPromptTitle: "Meeting Notes"
        )

        #expect(updated.selectedPromptPresetID == PromptPreset.builtInDefaultID)
        #expect(updated.selectedPromptTitle == PromptPreset.builtInDefault.title)
        #expect(updated.pendingPromptPresetID == "user.meeting")
        #expect(updated.pendingPromptTitle == "Meeting Notes")
    }

    @Test
    @MainActor
    func resultReviewPromptSelectionCommitsPendingPromptAfterSuccessfulRegenerate() {
        let committed = AppController.committedResultReviewPromptSelectionAfterRegenerateSuccess(
            selectedPromptPresetID: PromptPreset.builtInDefaultID,
            selectedPromptTitle: PromptPreset.builtInDefault.title,
            pendingPromptPresetID: "user.meeting",
            pendingPromptTitle: "Meeting Notes"
        )

        #expect(committed.selectedPromptPresetID == "user.meeting")
        #expect(committed.selectedPromptTitle == "Meeting Notes")
        #expect(committed.pendingPromptPresetID == nil)
        #expect(committed.pendingPromptTitle == nil)
    }

    @Test
    @MainActor
    func unconfiguredLLMRefinementDoesNotPresentResultReviewPanel() {
        #expect(
            !AppController.canPresentResultReviewPanel(
                refinementProvider: .llm,
                postProcessingMode: .refinement,
                llmConfigurationIsConfigured: false,
                didExternalProcessorSucceed: false,
                processedText: "unchanged transcript"
            )
        )
    }

    @Test
    @MainActor
    func configuredLLMRefinementCanPresentResultReviewPanelWithNonEmptyResult() {
        #expect(
            AppController.canPresentResultReviewPanel(
                refinementProvider: .llm,
                postProcessingMode: .refinement,
                llmConfigurationIsConfigured: true,
                didExternalProcessorSucceed: false,
                processedText: "refined answer"
            )
        )
    }

    @Test
    @MainActor
    func unconfiguredLLMCannotEnterRefinementReviewFlow() {
        #expect(
            !AppController.canEnterRefinementReviewFlow(
                refinementProvider: .llm,
                llmConfigurationIsConfigured: false
            )
        )
    }

    @Test
    @MainActor
    func configuredLLMAndExternalProcessorCanEnterRefinementReviewFlow() {
        #expect(
            AppController.canEnterRefinementReviewFlow(
                refinementProvider: .llm,
                llmConfigurationIsConfigured: true
            )
        )
        #expect(
            AppController.canEnterRefinementReviewFlow(
                refinementProvider: .externalProcessor,
                llmConfigurationIsConfigured: false
            )
        )
    }

    @Test
    @MainActor
    func resultReviewRegenerateUsesStatusBarOnlyRefiningPresentation() {
        #expect(
            AppController.refiningPresentationModeForRegenerate() == .statusBarOnly
        )
    }

    @Test
    @MainActor
    func llmReviewRegenerateAllowsSourceEchoAsNoopWhenPreviousRewriteExists() {
        #expect(
            AppController.resultReviewRegenerateOutcome(
                refinementProvider: .llm,
                sourceText: "Original transcript",
                previousResultText: "Polished result",
                regeneratedText: "Original transcript",
                didExternalProcessorSucceed: false
            ) == .keepPreviousResult
        )
        #expect(
            AppController.didRefinementReviewRegenerateSucceed(
                refinementProvider: .llm,
                sourceText: "Original transcript",
                previousResultText: "Polished result",
                regeneratedText: "Original transcript",
                didExternalProcessorSucceed: false
            )
        )
        #expect(
            AppController.didRefinementReviewRegenerateSucceed(
                refinementProvider: .llm,
                sourceText: "Original transcript",
                previousResultText: "Polished result",
                regeneratedText: "Polished result",
                didExternalProcessorSucceed: false
            )
        )
        #expect(
            AppController.didRefinementReviewRegenerateSucceed(
                refinementProvider: .llm,
                sourceText: "Original transcript",
                previousResultText: "Polished result",
                regeneratedText: "Sharpened rewrite",
                didExternalProcessorSucceed: false
            )
        )
    }

    @Test
    @MainActor
    func resultReviewInsertFallsBackToTargetProcessBundleIDWhenSourceBundleIsMissing() {
        let currentProcessID = ProcessInfo.processInfo.processIdentifier
        let targetIdentifier = "\(currentProcessID):AXTextArea"

        let resolvedBundleID = AppController.resultReviewInsertionSourceApplicationBundleID(
            capturedSourceApplicationBundleID: nil,
            currentFrontmostApplicationBundleID: nil,
            targetIdentifier: targetIdentifier
        )

        #expect(resolvedBundleID == NSRunningApplication.current.bundleIdentifier)
    }

    @Test
    @MainActor
    func resultReviewInsertDoesNotFallbackToVoicePiBundleIDWhenNoSourceAppIsKnown() {
        let resolvedBundleID = AppController.resultReviewInsertionSourceApplicationBundleID(
            capturedSourceApplicationBundleID: nil,
            currentFrontmostApplicationBundleID: "com.pi-dal.VoicePi",
            targetIdentifier: nil,
            voicePiBundleID: "com.pi-dal.VoicePi"
        )

        #expect(resolvedBundleID == nil)
    }

    @Test
    @MainActor
    func resultReviewSelectionMatchAllowsRangeValidationWhenSelectedTextIsUnavailable() {
        let selectionAnchor = AppController.ResultReviewSelectionAnchor(
            targetIdentifier: "target-1",
            selectedText: "Original selected text",
            selectedRange: NSRange(location: 5, length: 8),
            sourceApplicationBundleID: "com.apple.TextEdit"
        )
        let snapshot = EditableTextTargetSnapshot(
            inspection: .editable,
            targetIdentifier: "target-1",
            textValue: "prefix Original selected text suffix",
            selectedText: nil,
            selectedTextRange: NSRange(location: 5, length: 8),
            selectedTextBoundsInScreen: nil,
            canSetSelectedTextRange: true
        )

        #expect(
            AppController.resultReviewSelectionMatchesAnchor(
                snapshot,
                selectionAnchor: selectionAnchor
            )
        )
    }

    @Test
    @MainActor
    func resultReviewSelectionMatchAllowsTextValidationWhenSelectedRangeIsUnavailable() {
        let selectionAnchor = AppController.ResultReviewSelectionAnchor(
            targetIdentifier: "target-1",
            selectedText: "Original selected text",
            selectedRange: NSRange(location: 5, length: 8),
            sourceApplicationBundleID: "com.apple.TextEdit"
        )
        let snapshot = EditableTextTargetSnapshot(
            inspection: .editable,
            targetIdentifier: "target-1",
            textValue: "prefix Original selected text suffix",
            selectedText: "Original selected text",
            selectedTextRange: nil,
            selectedTextBoundsInScreen: nil,
            canSetSelectedTextRange: true
        )

        #expect(
            AppController.resultReviewSelectionMatchesAnchor(
                snapshot,
                selectionAnchor: selectionAnchor
            )
        )
    }

    @Test
    @MainActor
    func recentInsertionRegenerateUsesSelectionTextAsSource() {
        let selectionText = "Selected paragraph in editor"
        let session = AppController.RefinementReviewSession(
            sourceType: .recentInsertion,
            rawTranscript: "Original dictated transcript",
            selectedPromptPresetID: PromptPreset.builtInDefaultID,
            selectedPromptTitle: PromptPreset.builtInDefault.title,
            currentResultText: selectionText,
            selectionAnchor: AppController.ResultReviewSelectionAnchor(
                targetIdentifier: "target-1",
                selectedText: selectionText,
                selectedRange: NSRange(location: 0, length: selectionText.utf16.count),
                sourceApplicationBundleID: "com.apple.TextEdit"
            ),
            recordingDurationMilliseconds: 900,
            workflow: AppController.ProcessingWorkflowSelection(
                postProcessingMode: .refinement,
                refinementProvider: .llm
            ),
            workflowOverride: nil,
            isAutoOpened: false
        )

        #expect(AppController.resultReviewSourceText(for: session) == selectionText)
    }

    @Test
    @MainActor
    func reviewSourceStaysStableAcrossMultipleRegenerates() {
        let initialSourceText = "Initial selected source text"
        var session = AppController.RefinementReviewSession(
            sourceType: .recentInsertion,
            rawTranscript: "Raw transcript",
            selectedPromptPresetID: PromptPreset.builtInDefaultID,
            selectedPromptTitle: PromptPreset.builtInDefault.title,
            currentResultText: "First regenerate result",
            selectionAnchor: AppController.ResultReviewSelectionAnchor(
                targetIdentifier: "target-1",
                selectedText: initialSourceText,
                selectedRange: NSRange(location: 0, length: initialSourceText.utf16.count),
                sourceApplicationBundleID: "com.apple.TextEdit"
            ),
            recordingDurationMilliseconds: 500,
            workflow: AppController.ProcessingWorkflowSelection(
                postProcessingMode: .refinement,
                refinementProvider: .llm
            ),
            workflowOverride: nil,
            isAutoOpened: false
        )

        #expect(AppController.resultReviewSourceText(for: session) == initialSourceText)
        session.currentResultText = "Second regenerate result"
        #expect(AppController.resultReviewSourceText(for: session) == initialSourceText)
        session.currentResultText = "Third regenerate result"
        #expect(AppController.resultReviewSourceText(for: session) == initialSourceText)
    }

    @Test
    @MainActor
    func selectedTextRegenerateKeepsRawTranscriptAsSource() {
        let selectedText = "Direct selection source"
        let session = AppController.RefinementReviewSession(
            sourceType: .selectedText,
            rawTranscript: selectedText,
            selectedPromptPresetID: PromptPreset.builtInDefaultID,
            selectedPromptTitle: PromptPreset.builtInDefault.title,
            currentResultText: selectedText,
            selectionAnchor: AppController.ResultReviewSelectionAnchor(
                targetIdentifier: "target-2",
                selectedText: "Stale selection",
                selectedRange: NSRange(location: 0, length: 5),
                sourceApplicationBundleID: "com.apple.Notes"
            ),
            recordingDurationMilliseconds: 900,
            workflow: AppController.ProcessingWorkflowSelection(
                postProcessingMode: .refinement,
                refinementProvider: .llm
            ),
            workflowOverride: nil,
            isAutoOpened: false
        )

        #expect(AppController.resultReviewSourceText(for: session) == selectedText)
    }

    @Test
    @MainActor
    func selectedTextReviewSessionCapturesSourceSnapshotForExternalProcessorPrompt() throws {
        let selectedText = "Quoted webpage text"
        let session = AppController.RefinementReviewSession(
            sourceType: .selectedText,
            rawTranscript: selectedText,
            selectedPromptPresetID: PromptPreset.builtInDefaultID,
            selectedPromptTitle: PromptPreset.builtInDefault.title,
            currentResultText: selectedText,
            selectionAnchor: AppController.ResultReviewSelectionAnchor(
                targetIdentifier: "target-3",
                selectedText: selectedText,
                selectedRange: NSRange(location: 0, length: selectedText.utf16.count),
                sourceApplicationBundleID: "com.apple.Safari"
            ),
            recordingDurationMilliseconds: 900,
            workflow: AppController.ProcessingWorkflowSelection(
                postProcessingMode: .refinement,
                refinementProvider: .externalProcessor
            ),
            workflowOverride: nil,
            isAutoOpened: false
        )

        let sourceSnapshot = try #require(session.sourceSnapshot)
        #expect(sourceSnapshot.text == selectedText)
        #expect(sourceSnapshot.previewText == selectedText)
        #expect(sourceSnapshot.sourceApplicationBundleID == "com.apple.Safari")
        #expect(sourceSnapshot.targetIdentifier == "target-3")
    }

    @Test
    @MainActor
    func selectedTextRewriteWithoutRecentInsertionMatchOpensReviewPanelWithoutAutoRegenerate() {
        #expect(
            AppController.selectionRewritePresentationDecision(hasRecentInsertionMatch: false)
                == .presentFreshReviewPanel
        )
    }

    @Test
    @MainActor
    func selectedTextRewriteWithRecentInsertionMatchReusesExistingReviewFlow() {
        #expect(
            AppController.selectionRewritePresentationDecision(hasRecentInsertionMatch: true)
                == .presentRecentInsertionReviewPanel
        )
    }

    @Test
    @MainActor
    func normalRefinementUsesFloatingOverlayRefiningPresentation() {
        #expect(
            AppController.refiningPresentationModeForNormalWorkflow() == .floatingOverlayAndStatusBar
        )
    }

    @Test
    @MainActor
    func recentInsertionFullDocumentSelectionDefersPanelForCallToActionFlow() {
        #expect(
            AppController.recentInsertionAutoReviewPresentationDecision(
                selectedRange: NSRange(location: 0, length: 11),
                textValue: "hello world"
            ) == .deferToCallToAction
        )
    }

    @Test
    @MainActor
    func recentInsertionPartialSelectionStillAllowsDirectPanelPresentation() {
        #expect(
            AppController.recentInsertionAutoReviewPresentationDecision(
                selectedRange: NSRange(location: 1, length: 5),
                textValue: "hello world"
            ) == .presentReviewPanel
        )
    }

    @Test
    @MainActor
    func recentInsertionDecisionFallsBackToDirectPanelWhenTextContextMissing() {
        #expect(
            AppController.recentInsertionAutoReviewPresentationDecision(
                selectedRange: NSRange(location: 0, length: 11),
                textValue: nil
            ) == .presentReviewPanel
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
    func capturedSourceSnapshotExistsForAnyExternalProcessorWorkflow() throws {
        let targetSnapshot = EditableTextTargetSnapshot(
            inspection: .editable,
            targetIdentifier: "target-1",
            textValue: "Full document text",
            selectedText: "Reference paragraph",
            selectedTextRange: NSRange(location: 0, length: 19)
        )
        let externalProcessorWorkflow = AppController.ProcessingWorkflowSelection(
            postProcessingMode: .refinement,
            refinementProvider: .externalProcessor
        )
        let llmWorkflow = AppController.ProcessingWorkflowSelection(
            postProcessingMode: .refinement,
            refinementProvider: .llm
        )

        #expect(
            AppController.capturedSourceSnapshot(
                workflow: llmWorkflow,
                workflowOverride: nil,
                targetSnapshot: targetSnapshot,
                sourceApplicationBundleID: "com.apple.TextEdit"
            ) == nil
        )

        let captured = try #require(
            AppController.capturedSourceSnapshot(
                workflow: externalProcessorWorkflow,
                workflowOverride: nil,
                targetSnapshot: targetSnapshot,
                sourceApplicationBundleID: "com.apple.TextEdit"
            )
        )
        #expect(captured.text == "Reference paragraph")

        let shortcutCaptured = try #require(
            AppController.capturedSourceSnapshot(
                workflow: llmWorkflow,
                workflowOverride: .externalProcessorShortcut,
                targetSnapshot: targetSnapshot,
                sourceApplicationBundleID: "com.apple.TextEdit"
            )
        )
        #expect(shortcutCaptured.text == "Reference paragraph")
    }

    @Test
    @MainActor
    func resolvedCapturedSourceSnapshotUsesFallbackSelectionTextWhenAXSelectionIsMissing() throws {
        let targetSnapshot = EditableTextTargetSnapshot(
            inspection: .notEditable,
            targetIdentifier: "target-clipboard",
            textValue: nil,
            selectedText: nil,
            selectedTextRange: nil
        )
        let workflow = AppController.ProcessingWorkflowSelection(
            postProcessingMode: .refinement,
            refinementProvider: .externalProcessor
        )

        let captured = try #require(
            AppController.resolvedCapturedSourceSnapshot(
                existingSnapshot: nil,
                workflow: workflow,
                workflowOverride: nil,
                targetSnapshot: targetSnapshot,
                sourceApplicationBundleID: "com.apple.Safari",
                fallbackSelectedText: " Clipboard quoted webpage text "
            )
        )

        #expect(captured.text == "Clipboard quoted webpage text")
        #expect(captured.previewText == "Clipboard quoted webpage text")
        #expect(captured.sourceApplicationBundleID == "com.apple.Safari")
        #expect(captured.targetIdentifier == "target-clipboard")
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
    func externalProcessorShortcutDisablesAutomaticPromptResolutionWithoutExplicitOverride() {
        #expect(
            !AppController.shouldResolveAutomaticRefinementPrompt(
                workflowOverride: .externalProcessorShortcut,
                promptPresetOverrideID: nil
            )
        )
        #expect(
            AppController.shouldResolveAutomaticRefinementPrompt(
                workflowOverride: .externalProcessorShortcut,
                promptPresetOverrideID: "custom-prompt"
            )
        )
        #expect(
            AppController.shouldResolveAutomaticRefinementPrompt(
                workflowOverride: nil,
                promptPresetOverrideID: nil
            )
        )
    }

    @Test
    @MainActor
    func externalProcessorShortcutSuccessUsesDedicatedResultPanelAction() {
        #expect(
            AppController.postProcessingSuccessAction(
                workflowOverride: .externalProcessorShortcut,
                didExternalProcessorSucceed: true
            ) == .presentExternalProcessorResultPanel
        )
        #expect(
            AppController.postProcessingSuccessAction(
                workflowOverride: .externalProcessorShortcut,
                didExternalProcessorSucceed: false
            ) == .deliverTranscriptNormally
        )
        #expect(
            AppController.postProcessingSuccessAction(
                workflowOverride: nil,
                didExternalProcessorSucceed: true
            ) == .deliverTranscriptNormally
        )
    }

    @Test
    @MainActor
    func floatingRefiningOverlayDelayWaitsForMinimumVisibleDuration() {
        let now = Date()
        let recentPresentation = now.addingTimeInterval(-0.08)
        let expiredPresentation = now.addingTimeInterval(-0.6)

        #expect(
            AppController.pendingFloatingRefiningHideDelayNanoseconds(
                presentationStartedAt: recentPresentation,
                now: now
            ) > 0
        )
        #expect(
            AppController.pendingFloatingRefiningHideDelayNanoseconds(
                presentationStartedAt: expiredPresentation,
                now: now
            ) == 0
        )
        #expect(
            AppController.pendingFloatingRefiningHideDelayNanoseconds(
                presentationStartedAt: nil,
                now: now
            ) == 0
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
                useSystemAccessibilityPrompt: false
            )
        )
    }

    @Test
    @MainActor
    func launchPermissionPlanDoesNotRequestInputMonitoringForAdvancedActivationShortcut() {
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
                requestInputMonitoringPermission: false,
                useSystemAccessibilityPrompt: false
            )
        )
    }

    @Test
    @MainActor
    func launchPermissionPlanDoesNotRequestInputMonitoringForAdvancedModeCycleShortcut() {
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
                requestInputMonitoringPermission: false,
                useSystemAccessibilityPrompt: false
            )
        )
    }

    @Test
    @MainActor
    func launchPermissionPlanDoesNotRequestInputMonitoringForAdvancedProcessorShortcut() {
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
                promptCycleShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
                inputMonitoringState: .unknown
            ) == .init(
                requestMediaPermissions: true,
                promptAccessibility: true,
                requestInputMonitoringPermission: false,
                useSystemAccessibilityPrompt: false
            )
        )
    }

    @Test
    @MainActor
    func launchPermissionPlanDoesNotRequestInputMonitoringForAdvancedPromptCycleShortcut() {
        let activationShortcut = ActivationShortcut(
            keyCodes: [49],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
        )
        let promptCycleShortcut = ActivationShortcut(
            keyCodes: [],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(
            AppController.launchPermissionPlan(
                activationShortcut: activationShortcut,
                modeCycleShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
                processorShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
                promptCycleShortcut: promptCycleShortcut,
                inputMonitoringState: .unknown
            ) == .init(
                requestMediaPermissions: true,
                promptAccessibility: true,
                requestInputMonitoringPermission: false,
                useSystemAccessibilityPrompt: false
            )
        )
    }

    @Test
    @MainActor
    func shortcutUpdateRequestsInputMonitoringOnlyForUpdatedAdvancedShortcutWhenStillMissing() {
        let advancedShortcut = ActivationShortcut(
            keyCodes: [],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
        )
        let standardShortcut = ActivationShortcut(
            keyCodes: [49],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(
            AppController.shouldRequestInputMonitoringAfterShortcutUpdate(
                updatedShortcut: advancedShortcut,
                inputMonitoringState: .unknown
            )
        )
        #expect(
            AppController.shouldRequestInputMonitoringAfterShortcutUpdate(
                updatedShortcut: advancedShortcut,
                inputMonitoringState: .denied
            )
        )
        #expect(
            !AppController.shouldRequestInputMonitoringAfterShortcutUpdate(
                updatedShortcut: standardShortcut,
                inputMonitoringState: .unknown
            )
        )
        #expect(
            !AppController.shouldRequestInputMonitoringAfterShortcutUpdate(
                updatedShortcut: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0),
                inputMonitoringState: .unknown
            )
        )
        #expect(
            !AppController.shouldRequestInputMonitoringAfterShortcutUpdate(
                updatedShortcut: advancedShortcut,
                inputMonitoringState: .granted
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
    func customAccessibilityFlowDefersRemainingLaunchPermissionPrompts() {
        #expect(
            AppController.shouldDeferRemainingPermissionPromptsAfterAccessibilityLaunch(
                promptAccessibility: true,
                useSystemAccessibilityPrompt: false,
                accessibilityStateAfterPrompt: .denied
            )
        )
        #expect(
            !AppController.shouldDeferRemainingPermissionPromptsAfterAccessibilityLaunch(
                promptAccessibility: true,
                useSystemAccessibilityPrompt: true,
                accessibilityStateAfterPrompt: .denied
            )
        )
        #expect(
            !AppController.shouldDeferRemainingPermissionPromptsAfterAccessibilityLaunch(
                promptAccessibility: true,
                useSystemAccessibilityPrompt: false,
                accessibilityStateAfterPrompt: .granted
            )
        )
        #expect(
            !AppController.shouldDeferRemainingPermissionPromptsAfterAccessibilityLaunch(
                promptAccessibility: false,
                useSystemAccessibilityPrompt: false,
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
    func accessibilityPermissionPromptUsesScenarioSource() {
        #expect(
            AppController.accessibilityPermissionPromptSource(from: .launchFollowUp) == .launchFollowUp
        )
        #expect(
            AppController.accessibilityPermissionPromptSource(from: .accessibilityFollowUp) == .accessibilityFollowUp
        )
        #expect(
            AppController.accessibilityPermissionPromptSource(from: .manualSettingsButton) == .manualSettingsButton
        )
    }

    @Test
    @MainActor
    func permissionSettingsTransitionsPreferCustomSettingsPrompts() {
        #expect(AppController.permissionSettingsTransitionStyle(for: .accessibility) == .permissionFlow)
        #expect(AppController.permissionSettingsTransitionStyle(for: .inputMonitoring) == .permissionFlow)
        #expect(AppController.permissionSettingsTransitionStyle(for: .microphone) == .customPrompt)
        #expect(AppController.permissionSettingsTransitionStyle(for: .speech) == .customPrompt)
    }

    @Test
    @MainActor
    func permissionFlowOnlyCoversAccessibilityAndInputMonitoring() {
        #expect(AppController.permissionGuidanceFlowDestination(for: .accessibility) == .accessibility)
        #expect(AppController.permissionGuidanceFlowDestination(for: .inputMonitoring) == .inputMonitoring)
        #expect(AppController.permissionGuidanceFlowDestination(for: .microphone) == nil)
        #expect(AppController.permissionGuidanceFlowDestination(for: .speech) == nil)
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
