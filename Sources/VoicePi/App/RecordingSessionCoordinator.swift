import AppKit
import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class RecordingSessionCoordinator {
    weak var appController: AppController?

    private var speechRecorder: SpeechRecorder? {
        appController?.speechRecorder
    }

    private var floatingPanelController: FloatingPanelController? {
        appController?.floatingPanelController
    }

    private var statusBarController: StatusBarController? {
        appController?.statusBarController
    }

    private var model: AppModel? {
        appController?.model
    }

    init() {}

    func configure(with appController: AppController) {
        self.appController = appController
    }

    var isRecording: Bool {
        speechRecorder?.isRecording ?? false
    }

    var isStartingRecording: Bool {
        get { appController?.isStartingRecording ?? false }
        set {
            guard let appController else { return }
            appController.isStartingRecording = newValue
        }
    }

    var activeCapturedSourceSnapshot: CapturedSourceSnapshot? {
        get { appController?.activeCapturedSourceSnapshot }
        set {
            guard let appController else { return }
            appController.activeCapturedSourceSnapshot = newValue
        }
    }

    var activeRecordingWorkflowOverride: AppController.RecordingWorkflowOverride? {
        get { appController?.activeRecordingWorkflowOverride }
        set {
            guard let appController else { return }
            appController.activeRecordingWorkflowOverride = newValue
        }
    }

    var activeRecordingStartedAt: Date? {
        get { appController?.activeRecordingStartedAt }
        set {
            guard let appController else { return }
            appController.activeRecordingStartedAt = newValue
        }
    }

    var activeRecordingLatencyTrace: RecordingLatencyTrace? {
        get { appController?.activeRecordingLatencyTrace }
        set {
            guard let appController else { return }
            appController.activeRecordingLatencyTrace = newValue
        }
    }

    var isAwaitingRealtimeFinalization: Bool {
        get { appController?.isAwaitingRealtimeFinalization ?? false }
        set {
            guard let appController else { return }
            appController.isAwaitingRealtimeFinalization = newValue
        }
    }

    var latestTranscript: String {
        get { appController?.latestTranscript ?? "" }
        set {
            guard let appController else { return }
            appController.latestTranscript = newValue
        }
    }

    var recordingStartupTask: Task<Void, Never>? {
        get { appController?.recordingStartupTask }
        set {
            guard let appController else { return }
            appController.recordingStartupTask = newValue
        }
    }

    var activeFloatingRefiningPresentationStartedAt: Date? {
        get { appController?.activeFloatingRefiningPresentationStartedAt }
        set {
            guard let appController else { return }
            appController.activeFloatingRefiningPresentationStartedAt = newValue
        }
    }

    var realtimeAudioFramePump: RealtimeAudioFramePump? {
        get { appController?.realtimeAudioFramePump }
        set {
            guard let appController else { return }
            appController.realtimeAudioFramePump = newValue
        }
    }

    func clearActiveRecordingWorkflowState() {
        activeRecordingWorkflowOverride = nil
        activeCapturedSourceSnapshot = nil
        activeRecordingLatencyTrace = nil
        activeFloatingRefiningPresentationStartedAt = nil
        appController?.realtimeOverlayUpdateGate.reset()
        realtimeAudioFramePump = nil
    }

    func cancelRecording() {
        guard isStartingRecording || isRecording else { return }

        recordingStartupTask?.cancel()
        recordingStartupTask = nil
        latestTranscript = ""
        speechRecorder?.cancelImmediately()

        Task { @MainActor [weak self] in
            await self?.appController?.realtimeASRSessionCoordinator.close()
        }

        activeRecordingStartedAt = nil
        appController?.finishActiveRecordingLatency(.cancelled)
        clearActiveRecordingWorkflowState()
        isStartingRecording = false
        statusBarController?.setRecording(false)
        statusBarController?.setTransientStatus(nil)
        floatingPanelController?.hide()
        model?.hideOverlay()
        appController?.refreshCancelShortcutMonitorState()
    }

    func cancelProcessing() {
        guard appController?.isProcessingRelease ?? false else { return }

        appController?.processingTask?.cancel()
        appController?.processingTask = nil
        appController?.cancelPostInjectionLearning()
        appController?.clearResultReviewState()
        appController?.isProcessingRelease = false
        appController?.finishActiveRecordingLatency(.cancelled)
        clearActiveRecordingWorkflowState()
        latestTranscript = ""
        statusBarController?.setRecording(false)
        statusBarController?.setTransientStatus(nil)
        floatingPanelController?.hide()
        model?.hideOverlay()
    }
}
