import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

@MainActor
extension AppController {
    func beginRecording(
        workflowOverride: RecordingWorkflowOverride? = nil
    ) {
        if isAwaitingRealtimeFinalization {
            return
        }

        switch Self.pressAction(
            isRecording: speechRecorder.isRecording,
            isStartingRecording: isStartingRecording,
            isProcessingRelease: isProcessingRelease,
            hasConfirmedSelectionForRewrite: hasConfirmedSelectionForRewrite(),
            workflowOverride: workflowOverride
        ) {
        case .ignore:
            return
        case .stopRecording:
            endRecordingAndInject()
            return
        case .cancelProcessing:
            cancelProcessingAndHideOverlay()
            return
        case .startSelectionRewrite:
            beginSelectionRewriteFromCurrentSelection()
            return
        case .startRecording:
            break
        }

        isStartingRecording = true
        activeRecordingWorkflowOverride = workflowOverride
        let captureWorkflow = Self.effectiveProcessingWorkflow(
            postProcessingMode: model.postProcessingMode,
            refinementProvider: model.refinementProvider,
            override: workflowOverride
        )
        activeCapturedSourceSnapshot = Self.capturedSourceSnapshot(
            workflow: captureWorkflow,
            workflowOverride: workflowOverride,
            targetSnapshot: editableTextTargetInspector.currentSnapshot(),
            sourceApplicationBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
        activeRecordingStartedAt = nil
        activeFloatingRefiningPresentationStartedAt = nil
        activeRecordingLatencyTrace = RecordingLatencyTrace()
        realtimeOverlayUpdateGate.reset()
        latestTranscript = ""
        cancelPostInjectionLearning()
        clearExternalProcessorResultState()
        clearResultReviewState()
        statusBarController?.setTransientStatus(nil)
        inputFallbackPanelController.hide()

        recordingStartupTask?.cancel()
        recordingStartupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.recordingStartupTask = nil
            }

            let permissionsReady = await self.prepareForRecording()
            guard !Task.isCancelled else {
                return
            }
            guard permissionsReady else {
                self.finishActiveRecordingLatency(.cancelled)
                self.clearActiveRecordingWorkflowState()
                self.isStartingRecording = false
                return
            }

            await self.hydrateCapturedSourceSnapshotFromClipboardIfNeeded(
                workflow: captureWorkflow,
                workflowOverride: workflowOverride
            )
            guard !Task.isCancelled else {
                return
            }

            do {
                self.speechRecorder.updateLocale(identifier: self.model.selectedLanguage.localeIdentifier)
                self.floatingPanelController.showRecording(
                    transcript: "",
                    sourcePreviewText: self.activeCapturedSourceSnapshot?.previewText
                )
                self.model.updateOverlayRecording(transcript: "", level: 0)
                self.statusBarController?.setRecording(true)

                if self.model.asrBackend.usesRealtimeStreaming {
                    try await self.startRealtimeRecordingSession()
                } else {
                    try await self.speechRecorder.startRecording(mode: self.model.asrBackend.speechRecorderMode)
                }
                guard !Task.isCancelled else {
                    return
                }
            } catch {
                self.statusBarController?.setRecording(false)
                self.floatingPanelController.hide()
                self.model.hideOverlay()
                if case let asrError as RemoteASRStreamingError = error, asrError == .cancelled {
                    self.finishActiveRecordingLatency(.cancelled)
                    self.clearActiveRecordingWorkflowState()
                    self.isStartingRecording = false
                    return
                }
                self.finishActiveRecordingLatency(.failed(error.localizedDescription))
                self.clearActiveRecordingWorkflowState()
                self.presentTransientError(error.localizedDescription)
            }

            self.isStartingRecording = false
        }
    }

    func hydrateCapturedSourceSnapshotFromClipboardIfNeeded(
        workflow: ProcessingWorkflowSelection,
        workflowOverride: RecordingWorkflowOverride?
    ) async {
        guard activeCapturedSourceSnapshot == nil else {
            return
        }

        let sourceApplicationBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let fallbackSelectedText = await Self.captureSelectedTextFromClipboardFallback(
            workflow: workflow,
            workflowOverride: workflowOverride,
            sourceApplicationBundleID: sourceApplicationBundleID
        )
        guard let fallbackSelectedText else {
            return
        }

        activeCapturedSourceSnapshot = Self.resolvedCapturedSourceSnapshot(
            existingSnapshot: activeCapturedSourceSnapshot,
            workflow: workflow,
            workflowOverride: workflowOverride,
            targetSnapshot: editableTextTargetInspector.currentSnapshot(),
            sourceApplicationBundleID: sourceApplicationBundleID,
            fallbackSelectedText: fallbackSelectedText
        )
    }

    static func captureSelectedTextFromClipboardFallback(
        workflow: ProcessingWorkflowSelection,
        workflowOverride: RecordingWorkflowOverride?,
        sourceApplicationBundleID: String?
    ) async -> String? {
        guard workflowOverride == .externalProcessorShortcut
            || (
                workflow.postProcessingMode == .refinement
                && workflow.refinementProvider == .externalProcessor
            ) else {
            return nil
        }

        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           sourceApplicationBundleID == bundleIdentifier {
            return nil
        }

        let pasteboard = NSPasteboard.general
        let originalItems = capturePasteboardItems(from: pasteboard)
        let originalChangeCount = pasteboard.changeCount

        do {
            try await Task.sleep(for: .milliseconds(35))
            try await simulateCommandCopy(keyPressInterval: .milliseconds(8))

            let deadline = Date().addingTimeInterval(0.22)
            while pasteboard.changeCount == originalChangeCount, Date() < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }

            let copiedText = pasteboard.changeCount == originalChangeCount
                ? nil
                : pasteboard.string(forType: .string)
            restorePasteboardItems(originalItems, to: pasteboard)
            return ExternalProcessorSourceSnapshotSupport.normalizedSourceText(copiedText ?? "")
        } catch {
            restorePasteboardItems(originalItems, to: pasteboard)
            return nil
        }
    }

    static func capturePasteboardItems(from pasteboard: NSPasteboard) -> [NSPasteboardItem]? {
        pasteboard.pasteboardItems?.compactMap { item in
            let copy = NSPasteboardItem()
            var copiedAnyType = false

            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                    copiedAnyType = true
                } else if let string = item.string(forType: type) {
                    copy.setString(string, forType: type)
                    copiedAnyType = true
                } else if let propertyList = item.propertyList(forType: type) {
                    copy.setPropertyList(propertyList, forType: type)
                    copiedAnyType = true
                }
            }

            return copiedAnyType ? copy : nil
        }
    }

    static func restorePasteboardItems(
        _ items: [NSPasteboardItem]?,
        to pasteboard: NSPasteboard
    ) {
        pasteboard.clearContents()
        guard let items, !items.isEmpty else { return }
        _ = pasteboard.writeObjects(items)
    }

    static func simulateCommandCopy(keyPressInterval: Duration) async throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw TextInjectorError.eventSourceUnavailable
        }

        let keyCode: CGKeyCode = 8 // ANSI C
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            throw TextInjectorError.eventSourceUnavailable
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        try await Task.sleep(for: keyPressInterval)
        keyUp.post(tap: .cghidEventTap)
    }

    func endRecordingAndInject() {
        guard !isProcessingRelease else { return }

        if isStartingRecording {
            if model.asrBackend.usesRealtimeStreaming {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.realtimeASRSessionCoordinator.cancelConnecting()
                    self.speechRecorder.cancelImmediately()
                    self.finishActiveRecordingLatency(.cancelled)
                    self.isStartingRecording = false
                    self.clearActiveRecordingWorkflowState()
                    self.statusBarController?.setRecording(false)
                    self.floatingPanelController.hide()
                    self.model.hideOverlay()
                }
                return
            }

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

            self.markActiveRecordingLatency(.stopRequested)
            let localTranscript = await self.speechRecorder.stopRecording()
            let recordingDurationMilliseconds = self.consumeCurrentRecordingDurationMilliseconds()
            guard !Task.isCancelled, self.isProcessingRelease else { return }

            let asrTranscript = await self.resolveTranscriptAfterRecording(localFallback: localTranscript)
            let trimmedASRTranscript = asrTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedASRTranscript.isEmpty {
                self.markActiveRecordingLatency(.transcriptResolved)
            }
            guard !Task.isCancelled, self.isProcessingRelease else { return }

            let captured = trimmedASRTranscript

            guard !captured.isEmpty else {
                self.finishActiveRecordingLatency(.cancelled)
                self.floatingPanelController.hide()
                self.model.hideOverlay()
                self.statusBarController?.setTransientStatus(nil)
                self.isProcessingRelease = false
                self.clearActiveRecordingWorkflowState()
                return
            }

            let workflow = Self.effectiveProcessingWorkflow(
                postProcessingMode: self.model.postProcessingMode,
                refinementProvider: self.model.refinementProvider,
                override: self.activeRecordingWorkflowOverride
            )
            let finalText = await self.refineIfNeeded(
                captured,
                workflow: workflow,
                workflowOverride: self.activeRecordingWorkflowOverride,
                sourceSnapshot: self.activeCapturedSourceSnapshot
            )
            self.markActiveRecordingLatency(.refinementCompleted)
            guard !Task.isCancelled, self.isProcessingRelease else { return }

            let didSucceed = await self.externalProcessorRefiner.didSucceedOnLastInvocation
            let failureAction = Self.postProcessingFailureAction(
                workflowOverride: self.activeRecordingWorkflowOverride,
                didExternalProcessorSucceed: didSucceed
            )
            let successAction = Self.postProcessingSuccessAction(
                workflowOverride: self.activeRecordingWorkflowOverride,
                didExternalProcessorSucceed: didSucceed
            )

            if successAction == .presentExternalProcessorResultPanel {
                await self.ensureFloatingRefiningOverlayRemainsVisibleIfNeeded()
                self.presentExternalProcessorResultPanel(
                    text: finalText,
                    sourceText: captured,
                    workflowOverride: self.activeRecordingWorkflowOverride,
                    sourceApplicationBundleID: self.activeCapturedSourceSnapshot?.sourceApplicationBundleID,
                    recordingDurationMilliseconds: recordingDurationMilliseconds
                )
                self.finishActiveRecordingLatency(.success)
            } else if failureAction == .surfaceProcessorFailure {
                await self.ensureFloatingRefiningOverlayRemainsVisibleIfNeeded()
                let processorFailureMessage = await self.externalProcessorRefiner.lastFailureMessageOnLastInvocation
                let trimmedFailureMessage = processorFailureMessage?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let failureMessage = trimmedFailureMessage.isEmpty
                    ? "Processor shortcut requires a working external processor. Check Processors settings."
                    : trimmedFailureMessage
                self.presentTransientError(failureMessage)
                self.finishActiveRecordingLatency(.failed(failureMessage))
                self.floatingPanelController.hide()
            } else {
                let targetSnapshot = self.editableTextTargetInspector.currentSnapshot()
                switch Self.transcriptDeliveryRoute(
                    for: finalText,
                    targetInspection: targetSnapshot.inspection
                ) {
                case .emptyResult:
                    await self.ensureFloatingRefiningOverlayRemainsVisibleIfNeeded()
                    self.recentInsertionRewriteCoordinator.cancelTracking()
                    self.statusBarController?.setTransientStatus(nil)
                    self.finishActiveRecordingLatency(.cancelled)
                    self.floatingPanelController.hide()
                case .injectableTarget:
                    await self.ensureFloatingRefiningOverlayRemainsVisibleIfNeeded()
                    do {
                        let injectionRecord = try await self.textInjector.injectAndRecord(text: finalText)
                        self.markActiveRecordingLatency(.injectionCompleted)
                        self.statusBarController?.setTransientStatus("Injected")
                        self.model.recordHistoryEntry(
                            text: finalText,
                            recordingDurationMilliseconds: recordingDurationMilliseconds
                        )
                        self.beginPostInjectionLearning(
                            targetSnapshot: targetSnapshot,
                            injectionRecord: injectionRecord
                        )
                        let resolvedPrompt = self.resolvedRefinementPrompt(for: workflow)
                        self.startRecentInsertionRewriteTracking(
                            rawTranscript: captured,
                            insertedText: injectionRecord.text,
                            appliedPromptPresetID: resolvedPrompt?.presetID,
                            targetSnapshot: targetSnapshot,
                            sourceApplicationBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                        )
                        self.finishActiveRecordingLatency(.success)
                    } catch {
                        self.finishActiveRecordingLatency(.failed(error.localizedDescription))
                        self.presentTransientError(error.localizedDescription)
                    }
                    self.floatingPanelController.hide()
                case .fallbackPanel:
                    await self.ensureFloatingRefiningOverlayRemainsVisibleIfNeeded()
                    self.recentInsertionRewriteCoordinator.cancelTracking()
                    if let payload = InputFallbackPanelPayload(text: finalText) {
                        self.model.recordHistoryEntry(
                            text: finalText,
                            recordingDurationMilliseconds: recordingDurationMilliseconds
                        )
                        self.presentInputFallbackPanel(payload)
                        self.finishActiveRecordingLatency(.success)
                    } else {
                        self.finishActiveRecordingLatency(.cancelled)
                    }
                }
            }

            self.model.hideOverlay()
            self.isProcessingRelease = false
            self.clearActiveRecordingWorkflowState()
        }
    }


}
