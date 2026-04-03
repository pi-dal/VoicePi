import Testing
@testable import VoicePi
import AppKit
import ApplicationServices
import Carbon.HIToolbox

struct ShortcutMonitorTests {
    @Test
    func standardShortcutIsRegisteredHotkeyCompatible() {
        let shortcut = ActivationShortcut(
            keyCodes: [49],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(shortcut.isRegisteredHotkeyCompatible)
        #expect(!shortcut.requiresInputMonitoring)
    }

    @Test
    func modifierOnlyShortcutRequiresInputMonitoring() {
        let shortcut = ActivationShortcut(
            keyCodes: [],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(!shortcut.isRegisteredHotkeyCompatible)
        #expect(shortcut.requiresInputMonitoring)
    }

    @Test
    func multiKeyShortcutRequiresInputMonitoring() {
        let shortcut = ActivationShortcut(
            keyCodes: [0, 1],
            modifierFlagsRawValue: NSEvent.ModifierFlags.command.intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(!shortcut.isRegisteredHotkeyCompatible)
        #expect(shortcut.requiresInputMonitoring)
    }

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

    @Test
    @MainActor
    func registeredHotkeyMonitorCanRecoverAfterInitialRegistrationFailure() {
        var attempts = 0

        let monitor = RegisteredHotkeyMonitor(
            hotKeyBootstrapper: { _ in
                attempts += 1
                return attempts > 1
            },
            hotKeyDisabler: { _ in }
        )

        #expect(monitor.isMonitoring == false)
        #expect(monitor.start() == false)
        #expect(monitor.isMonitoring == false)

        #expect(monitor.start() == true)
        #expect(monitor.isMonitoring == true)
    }

    @Test
    func multiModifierShortcutDoesNotSuppressPartialModifierPress() {
        let shortcut = ActivationShortcut(
            keyCodes: [],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(
            ShortcutEventSuppression.shouldSuppressFlagsChangedEvent(
                suppressesMatchedEvents: true,
                shortcut: shortcut,
                keyCode: CGKeyCode(kVK_Option),
                flags: CGEventFlags([.maskAlternate])
            ) == false
        )
    }

    @Test
    func multiModifierShortcutSuppressesWhenFullModifierChordMatches() {
        let shortcut = ActivationShortcut(
            keyCodes: [],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
        )

        #expect(
            ShortcutEventSuppression.shouldSuppressFlagsChangedEvent(
                suppressesMatchedEvents: true,
                shortcut: shortcut,
                keyCode: CGKeyCode(kVK_Function),
                flags: CGEventFlags([.maskAlternate, .maskSecondaryFn])
            )
        )
    }
}
