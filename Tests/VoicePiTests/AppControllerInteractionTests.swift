import Testing
@testable import VoicePi

struct AppControllerInteractionTests {
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
}
