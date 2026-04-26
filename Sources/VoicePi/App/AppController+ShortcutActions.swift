import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

@MainActor
extension AppController {
    func handleLanguageChange(_ language: SupportedLanguage) {
        model.selectedLanguage = language
        speechRecorder.updateLocale(identifier: language.localeIdentifier)
        statusBarController?.refreshAll()
    }

    func cyclePostProcessingModeFromShortcut() {
        model.cyclePostProcessingMode()
        let autoHideDelay: UInt64? = modeCycleSessionActive ? nil : 1_100_000_000
        floatingPanelController.showModeSwitch(
            modeTitle: model.postProcessingMode.title,
            refinementPromptTitle: model.resolvedPromptPreset().title,
            autoHideDelayNanoseconds: autoHideDelay
        )
        statusBarController?.refreshAll()
        statusBarController?.setTransientStatus("Text processing: \(model.modeDisplayTitle(for: model.postProcessingMode))")
    }

    func cycleRefinementPromptFromShortcut() {
        guard let cycledPrompt = model.cycleActivePromptSelection() else {
            return
        }

        let destination = promptDestinationInspector.currentDestinationContext()
        let effectivePrompt = model.resolvedPromptPreset(for: .voicePi, destination: destination)
        let effectivePresetID = effectivePrompt.presetID ?? PromptPreset.builtInDefaultID
        let cycledPresetID = cycledPrompt.presetID ?? PromptPreset.builtInDefaultID
        let didStrictBindingOverride = model.promptWorkspace.strictModeEnabled && effectivePresetID != cycledPresetID
        let statusPrefix = didStrictBindingOverride ? "Prompt default" : "Prompt"

        floatingPanelController.showModeSwitch(
            modeTitle: model.postProcessingMode.title,
            refinementPromptTitle: cycledPrompt.title,
            autoHideDelayNanoseconds: 1_100_000_000
        )
        statusBarController?.refreshAll()
        statusBarController?.setTransientStatus("\(statusPrefix): \(cycledPrompt.title)")
    }

    func bootstrapHotkeyMonitoring() {
        startupHotkeyBootstrapTask?.cancel()
        let initialStatus = ensureHotkeyMonitorRunning()
        guard initialStatus == Self.shortcutRegistrationFailureMessage
            || initialStatus == Self.modeCycleShortcutRegistrationFailureMessage
            || initialStatus == Self.promptCycleShortcutRegistrationFailureMessage
            || initialStatus == Self.processorShortcutRegistrationFailureMessage else {
            return
        }

        startupHotkeyBootstrapTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.startupHotkeyBootstrapTask = nil
            }

            for _ in 0..<Self.startupHotkeyBootstrapMaxAttempts {
                try? await Task.sleep(nanoseconds: Self.startupHotkeyBootstrapRetryNanoseconds)
                guard !Task.isCancelled else { return }

                let status = self.ensureHotkeyMonitorRunning()
                guard status == Self.shortcutRegistrationFailureMessage
                    || status == Self.modeCycleShortcutRegistrationFailureMessage
                    || status == Self.promptCycleShortcutRegistrationFailureMessage
                    || status == Self.processorShortcutRegistrationFailureMessage else {
                    return
                }
            }
        }
    }

    func handleModeCycleShortcutPress() {
        guard Self.shouldStartModeCycleRepeat(
            shortcut: model.modeCycleShortcut,
            isRecording: speechRecorder.isRecording,
            isStartingRecording: isStartingRecording,
            isProcessingRelease: isProcessingRelease
        ) else { return }

        let interactionStyle = Self.modeCycleInteractionStyle(for: model.modeCycleShortcut)
        if interactionStyle == .modifierHeldSession {
            modeCycleSessionActive = true
        }

        cyclePostProcessingModeFromShortcut()
        switch interactionStyle {
        case .modifierHeldSession:
            startModeCycleShortcutSession()
        case .holdRepeat:
            startModeCycleShortcutRepeat()
        }
    }

    func handlePromptCycleShortcutPress() {
        guard Self.shouldStartModeCycleRepeat(
            shortcut: model.promptCycleShortcut,
            isRecording: speechRecorder.isRecording,
            isStartingRecording: isStartingRecording,
            isProcessingRelease: isProcessingRelease
        ) else { return }

        cycleRefinementPromptFromShortcut()
    }

    func startModeCycleShortcutRepeat() {
        modeCycleRepeatTask?.cancel()
        modeCycleRepeatTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: Self.modeCycleRepeatDelayNanoseconds)
            while !Task.isCancelled {
                guard Self.shouldStartModeCycleRepeat(
                    shortcut: self.model.modeCycleShortcut,
                    isRecording: self.speechRecorder.isRecording,
                    isStartingRecording: self.isStartingRecording,
                    isProcessingRelease: self.isProcessingRelease
                ),
                self.model.modeCycleShortcut.isCurrentlyHeld() else {
                    self.modeCycleRepeatTask = nil
                    return
                }

                self.cyclePostProcessingModeFromShortcut()
                try? await Task.sleep(nanoseconds: Self.modeCycleRepeatIntervalNanoseconds)
            }
            self.modeCycleRepeatTask = nil
        }
    }

    func startModeCycleShortcutSession() {
        modeCycleRepeatTask?.cancel()
        modeCycleRepeatTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard self.model.modeCycleShortcut.areRequiredModifiersHeld() else {
                    self.modeCycleSessionActive = false
                    self.floatingPanelController.showModeSwitch(
                        modeTitle: self.model.postProcessingMode.title,
                        refinementPromptTitle: self.model.resolvedPromptPreset().title,
                        autoHideDelayNanoseconds: 220_000_000
                    )
                    self.modeCycleRepeatTask = nil
                    return
                }

                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            self.modeCycleRepeatTask = nil
        }
    }

    func handleProcessorShortcutPress() {
        switch Self.processorShortcutPressAction(
            isRecording: speechRecorder.isRecording,
            isStartingRecording: isStartingRecording,
            isProcessingRelease: isProcessingRelease
        ) {
        case .ignore:
            return
        case .stopRecording:
            endRecordingAndInject()
        case .cancelProcessing:
            cancelProcessingAndHideOverlay()
        case .startProcessorCapture(let override):
            beginRecording(workflowOverride: override)
        }
    }

    func handleCancelShortcutPress() {
        switch Self.escapeCancelAction(
            isStartingRecording: isStartingRecording,
            isRecording: speechRecorder.isRecording,
            isProcessingRelease: isProcessingRelease
        ) {
        case .cancelStartup, .cancelRecording:
            cancelCurrentRecordingAndHideOverlay()
        case .cancelProcessing:
            cancelProcessingAndHideOverlay()
        case .ignore:
            return
        }
    }

}
