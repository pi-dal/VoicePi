import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

@MainActor
extension AppController {
    func resolveTranscriptAfterRecording(localFallback: String) async -> String {
        if model.asrBackend.usesRealtimeStreaming {
            let realtimeStatus = await realtimeASRSessionCoordinator.statusSnapshot()
            let resolution = Self.realtimeStopResolution(
                backend: model.asrBackend,
                isRealtimeStreamingReady: realtimeStatus.isRealtimeStreamingReady,
                degradedToBatchFallback: realtimeStatus.degradedToBatchFallback,
                hasRecordedAudio: realtimeStatus.hasCapturedAudio,
                localFallback: localFallback
            )

            switch resolution {
            case .silentCancel:
                await realtimeASRSessionCoordinator.close()
                return ""
            case .batchFallback:
                await realtimeASRSessionCoordinator.close()
                return await resolveBatchTranscriptAfterRecording(localFallback: localFallback)
            case .realtimeFinalization:
                isAwaitingRealtimeFinalization = true
                defer { isAwaitingRealtimeFinalization = false }

                do {
                    let transcript = try await realtimeASRSessionCoordinator.stopAndResolveFinal()
                    return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch let error as RemoteASRStreamingError where error == .cancelled {
                    return ""
                } catch {
                    await realtimeASRSessionCoordinator.close()
                    return await resolveBatchTranscriptAfterRecording(localFallback: localFallback)
                }
            }
        }

        return await resolveBatchTranscriptAfterRecording(localFallback: localFallback)
    }

    func resolveBatchTranscriptAfterRecording(localFallback: String) async -> String {
        return await AppWorkflowSupport.resolveTranscriptAfterRecording(
            backend: model.asrBackend,
            localFallback: localFallback,
            audioURL: speechRecorder.latestAudioFileURL,
            language: model.selectedLanguage,
            configuration: model.remoteASRConfiguration,
            remoteASR: remoteASRClient,
            onPresentation: { [weak self] presentation in
                guard let self else { return }
                switch presentation {
                case .transcribing(let overlayTranscript, let statusText):
                    self.floatingPanelController.showRefining(
                        transcript: "Transcribing…",
                        sourcePreviewText: self.activeCapturedSourceSnapshot?.previewText
                    )
                    self.model.updateOverlayRefining(transcript: overlayTranscript)
                    self.statusBarController?.setTransientStatus(statusText)
                case .refining(let overlayTranscript, let statusText):
                    self.floatingPanelController.showRefining(
                        transcript: localFallback,
                        sourcePreviewText: self.activeCapturedSourceSnapshot?.previewText
                    )
                    self.model.updateOverlayRefining(transcript: overlayTranscript)
                    self.statusBarController?.setTransientStatus(statusText)
                }
            },
            onError: { [weak self] message in
                self?.presentTransientError(message)
            }
        )
    }

    func startRealtimeRecordingSession() async throws {
        let realtimeCoordinator = realtimeASRSessionCoordinator
        let framePump = RealtimeAudioFramePump(
            maximumPendingBytes: RealtimeASRSessionCoordinator.preconnectBufferByteLimit,
            handler: { frame in
                await realtimeCoordinator.handleCapturedFrame(frame)
            },
            overflowHandler: {
                await realtimeCoordinator.handleCaptureBackpressureLimitExceeded()
            }
        )
        realtimeAudioFramePump = framePump
        let callbacks = RealtimeASRSessionCoordinator.Callbacks(
            onPartial: { [weak self] text in
                self?.updateRealtimeOverlayTranscript(text)
            },
            onFinal: { [weak self] text in
                self?.updateRealtimeOverlayTranscript(text)
            },
            onTerminalError: { [weak self] message in
                self?.handleRealtimeTerminalError(message)
            }
        )

        do {
            try await realtimeASRSessionCoordinator.start(
                configuration: model.remoteASRConfiguration,
                backend: model.asrBackend,
                language: model.selectedLanguage,
                callbacks: callbacks
            )
            try await speechRecorder.startRecording(
                mode: .captureOnly,
                onCapturedAudioFrame: { frame in
                    framePump.submit(frame)
                }
            )
        } catch {
            realtimeAudioFramePump = nil
            speechRecorder.cancelImmediately()
            await realtimeASRSessionCoordinator.close()
            throw error
        }
    }

    func updateRealtimeOverlayTranscript(_ text: String) {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            markActiveRecordingLatency(.firstPartialReceived)
        }
        publishRecordingOverlayUpdate(
            transcript: text,
            level: model.overlayState.level
        )
    }

    func publishRecordingOverlayUpdate(
        transcript: String,
        level: CGFloat,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        switch realtimeOverlayUpdateGate.consume(
            transcript: transcript,
            level: level,
            now: now
        ) {
        case .none:
            break
        case .levelOnly(let publishedLevel):
            model.updateOverlayRecordingLevel(publishedLevel)
            floatingPanelController.updateAudioLevel(publishedLevel)
        case .transcriptAndLevel(let publishedTranscript, let publishedLevel):
            latestTranscript = publishedTranscript
            model.updateOverlayRecording(
                transcript: publishedTranscript,
                level: publishedLevel
            )
            floatingPanelController.updateLive(
                transcript: publishedTranscript,
                level: publishedLevel
            )
        }
    }

    func handleRealtimeTerminalError(_ message: String) {
        guard !isAwaitingRealtimeFinalization else { return }
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if speechRecorder.isRecording {
            speechRecorder.cancelImmediately()
        }
        activeRecordingStartedAt = nil

        isStartingRecording = false
        finishActiveRecordingLatency(.failed(message))
        clearActiveRecordingWorkflowState()
        statusBarController?.setRecording(false)
        floatingPanelController.hide()
        model.hideOverlay()
        presentTransientError(message)
    }

    func consumeCurrentRecordingDurationMilliseconds() -> Int {
        defer {
            activeRecordingStartedAt = nil
        }
        guard let activeRecordingStartedAt else { return 0 }

        let elapsed = max(0, Date().timeIntervalSince(activeRecordingStartedAt))
        return Int((elapsed * 1000).rounded())
    }

    func markActiveRecordingLatency(_ milestone: RecordingLatencyTrace.Milestone) {
        activeRecordingLatencyTrace?.markNow(milestone)
    }

    func finishActiveRecordingLatency(_ outcome: RecordingLatencyTrace.Outcome) {
        guard let activeRecordingLatencyTrace else { return }

        let report = activeRecordingLatencyTrace.report(
            outcome: outcome,
            finishedAt: RecordingLatencyTrace.currentTimestamp()
        )
        recordingLatencyReporter.report(report)
        self.activeRecordingLatencyTrace = nil
    }

    func resolvedRefinementPrompt(
        for workflow: ProcessingWorkflowSelection,
        promptPresetOverrideID: String? = nil,
        workflowOverride: RecordingWorkflowOverride? = nil
    ) -> ResolvedPromptPreset? {
        guard workflow.postProcessingMode == .refinement else {
            return nil
        }

        if let promptPresetOverrideID {
            let normalizedPromptID = promptPresetOverrideID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedPromptID.isEmpty {
                return model.resolvedPromptPresetForExplicitPresetID(normalizedPromptID)
            }
        }

        guard Self.shouldResolveAutomaticRefinementPrompt(
            workflowOverride: workflowOverride,
            promptPresetOverrideID: promptPresetOverrideID
        ) else {
            return nil
        }

        let destination = promptDestinationInspector.currentDestinationContext()
        return model.resolvedPromptPreset(for: .voicePi, destination: destination)
    }

    func refineIfNeeded(
        _ text: String,
        workflow: ProcessingWorkflowSelection? = nil,
        workflowOverride: RecordingWorkflowOverride? = nil,
        promptPresetOverrideID: String? = nil,
        sourceSnapshot: CapturedSourceSnapshot? = nil,
        refiningPresentationMode: RefiningPresentationMode = .floatingOverlayAndStatusBar
    ) async -> String {
        let effectiveWorkflow = workflow ?? Self.effectiveProcessingWorkflow(
            postProcessingMode: model.postProcessingMode,
            refinementProvider: model.refinementProvider,
            override: workflowOverride ?? activeRecordingWorkflowOverride
        )
        let resolvedPrompt = resolvedRefinementPrompt(
            for: effectiveWorkflow,
            promptPresetOverrideID: promptPresetOverrideID,
            workflowOverride: workflowOverride ?? activeRecordingWorkflowOverride
        )
        if effectiveWorkflow.refinementProvider == .externalProcessor {
            await externalProcessorRefiner.resetLastInvocation()
        }

        return await AppWorkflowSupport.postProcessIfNeeded(
            text,
            mode: effectiveWorkflow.postProcessingMode,
            refinementProvider: effectiveWorkflow.refinementProvider,
            externalProcessor: model.selectedExternalProcessorEntry(),
            externalProcessorRefiner: externalProcessorRefiner,
            translationProvider: model.effectiveTranslationProvider(
                appleTranslateSupported: AppleTranslateService.isSupported
            ),
            sourceLanguage: model.selectedLanguage,
            targetLanguage: model.targetLanguage,
            configuration: model.llmConfiguration,
            refinementPromptTitle: resolvedPrompt?.title,
            resolvedRefinementPrompt: resolvedPrompt?.middleSection,
            sourceSnapshot: sourceSnapshot,
            dictionaryEntries: model.enabledDictionaryEntries,
            refiner: llmRefiner,
            translator: appleTranslateService,
            onPresentation: { [weak self] presentation in
                guard let self else { return }
                switch presentation {
                case .transcribing:
                    break
                case .refining(let overlayTranscript, let statusText):
                    if refiningPresentationMode == .floatingOverlayAndStatusBar {
                        self.activeFloatingRefiningPresentationStartedAt = Date()
                        self.floatingPanelController.showRefining(
                            transcript: overlayTranscript,
                            sourcePreviewText: sourceSnapshot?.previewText
                        )
                        self.model.updateOverlayRefining(transcript: overlayTranscript)
                    }
                    self.statusBarController?.setTransientStatus(statusText)
                }
            },
            onError: { [weak self] message in
                self?.presentTransientError(message)
            }
        )
    }

    func ensureFloatingRefiningOverlayRemainsVisibleIfNeeded() async {
        guard activeRecordingWorkflowOverride == .externalProcessorShortcut else {
            return
        }

        let delay = Self.pendingFloatingRefiningHideDelayNanoseconds(
            presentationStartedAt: activeFloatingRefiningPresentationStartedAt
        )
        guard delay > 0 else {
            return
        }

        try? await Task.sleep(nanoseconds: delay)
    }

}
