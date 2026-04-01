import Testing
@testable import VoicePi

struct ShortcutMonitorTests {
    @Test
    @MainActor
    func startCanRecoverAfterInitialTapCreationFailure() {
        var attempts = 0

        let monitor = ShortcutMonitor(
            tapBootstrapper: { _ in
                attempts += 1
                return attempts > 1
            },
            tapDisabler: { _ in }
        )

        #expect(monitor.isMonitoring == false)
        #expect(monitor.start() == false)
        #expect(monitor.isMonitoring == false)

        #expect(monitor.start() == true)
        #expect(monitor.isMonitoring == true)
    }
}
