import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

extension AppController: ShortcutMonitorDelegate {
    nonisolated func shortcutMonitorDidPress() {
        Task { @MainActor [weak self] in
            self?.beginRecording()
        }
    }

    nonisolated func shortcutMonitorDidRelease() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            switch Self.releaseAction(
                shortcut: self.model.activationShortcut,
                isRecording: self.speechRecorder.isRecording,
                isStartingRecording: self.isStartingRecording,
                isProcessingRelease: self.isProcessingRelease
            ) {
            case .ignore:
                return
            }
        }
    }
}
