import Testing
@testable import VoicePi

struct ShortcutMonitorTests {
    @Test
    @MainActor
    func listenAndSuppressMonitorUsesDefaultTapAndReportsMatches() {
        let monitor = ShortcutMonitor(mode: .listenAndSuppress)

        #expect(monitor.mode == .listenAndSuppress)
        #expect(monitor.tapCreateOptions == .defaultTap)
        #expect(monitor.reportsMatchedEvents)
        #expect(monitor.suppressesMatchedEvents)
    }

    @Test
    @MainActor
    func listenOnlyMonitorUsesListenOnlyTapAndReportsMatches() {
        let monitor = ShortcutMonitor(mode: .listenOnly)

        #expect(monitor.mode == .listenOnly)
        #expect(monitor.tapCreateOptions == .listenOnly)
        #expect(monitor.reportsMatchedEvents)
        #expect(!monitor.suppressesMatchedEvents)
    }

    @Test
    @MainActor
    func suppressOnlyMonitorUsesDefaultTapAndOnlySuppresses() {
        let monitor = ShortcutMonitor(mode: .suppressOnly)

        #expect(monitor.mode == .suppressOnly)
        #expect(monitor.tapCreateOptions == .defaultTap)
        #expect(!monitor.reportsMatchedEvents)
        #expect(monitor.suppressesMatchedEvents)
    }

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
