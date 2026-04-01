import Testing
@testable import VoicePi

struct StatusBarIconTests {
    @Test
    @MainActor
    func menuBarUsesBundledAppIconForIdleState() {
        #expect(StatusBarController.statusBarIconResourceName(isRecording: false) == "AppIcon")
    }

    @Test
    @MainActor
    func menuBarUsesBundledAppIconForRecordingState() {
        #expect(StatusBarController.statusBarIconResourceName(isRecording: true) == "AppIcon")
    }
}
