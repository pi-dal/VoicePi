import Testing
@testable import VoicePi
import AppKit
import ApplicationServices
import Carbon.HIToolbox

struct ShortcutMonitorTests {
    @Test
    @MainActor
    func shortcutActionControllerInvokesOnPressWithoutDelegate() {
        let controller = ShortcutActionController()
        var didPress = false
        controller.shortcut = ActivationShortcut(
            keyCodes: [49],
            modifierFlagsRawValue: NSEvent.ModifierFlags.command.intersection(.deviceIndependentFlagsMask).rawValue
        )
        controller.onPress = {
            didPress = true
        }

        let monitor = RegisteredHotkeyMonitor()
        monitor.onPress = controller.onPress
        monitor.onPress?()

        #expect(didPress)
    }

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
    @MainActor
    func monitorsPreserveExplicitlyEmptyShortcuts() {
        let empty = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
        let eventTapMonitor = ShortcutMonitor()
        let registeredMonitor = RegisteredHotkeyMonitor()

        eventTapMonitor.shortcut = empty
        registeredMonitor.shortcut = empty

        #expect(eventTapMonitor.shortcut.isEmpty)
        #expect(registeredMonitor.shortcut.isEmpty)
    }

    @Test
    @MainActor
    func registeredHotkeyMonitorsUseDistinctIdentifiers() {
        let first = RegisteredHotkeyMonitor()
        let second = RegisteredHotkeyMonitor()

        #expect(first.hotKeyIdentifier != second.hotKeyIdentifier)
    }

    @Test
    func registeredHotkeyMonitorOnlyConsumesMatchingEvents() {
        #expect(
            RegisteredHotkeyMonitor.eventDispatchStatus(shouldHandleEvent: true) == noErr
        )
        #expect(
            RegisteredHotkeyMonitor.eventDispatchStatus(shouldHandleEvent: false) == eventNotHandledErr
        )
    }

    @Test
    @MainActor
    func registeredHotkeyMonitorDeduplicatesRepeatedPressUntilRelease() {
        let monitor = RegisteredHotkeyMonitor()
        var pressCount = 0
        var releaseCount = 0
        monitor.onPress = {
            pressCount += 1
        }
        monitor.onRelease = {
            releaseCount += 1
        }

        #expect(monitor.processHotKeyEventKind(UInt32(kEventHotKeyPressed)))
        #expect(monitor.processHotKeyEventKind(UInt32(kEventHotKeyPressed)))
        #expect(monitor.processHotKeyEventKind(UInt32(kEventHotKeyReleased)))
        #expect(monitor.processHotKeyEventKind(UInt32(kEventHotKeyReleased)))

        #expect(pressCount == 1)
        #expect(releaseCount == 1)

        #expect(monitor.processHotKeyEventKind(UInt32(kEventHotKeyPressed)))
        #expect(pressCount == 2)
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

    @Test
    func shortcutHoldEvaluationRequiresAllKeysAndModifiersToRemainPressed() {
        let shortcut = ActivationShortcut(
            keyCodes: [37],
            modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
        )

        let heldKeys: Set<CGKeyCode> = [CGKeyCode(37), CGKeyCode(kVK_Control)]
        #expect(shortcut.isCurrentlyHeld(keyStateProvider: { heldKeys.contains($0) }))

        let missingLetter: Set<CGKeyCode> = [CGKeyCode(kVK_Control)]
        #expect(!shortcut.isCurrentlyHeld(keyStateProvider: { missingLetter.contains($0) }))

        let missingModifier: Set<CGKeyCode> = [CGKeyCode(37)]
        #expect(!shortcut.isCurrentlyHeld(keyStateProvider: { missingModifier.contains($0) }))
    }

    @Test
    func modeCycleSessionAdvancesOnRepeatedPrimaryKeyPressesWhileModifierRemainsHeld() {
        let shortcut = ActivationShortcut(
            keyCodes: [37],
            modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
        )
        var state = ModeCycleSessionState(shortcut: shortcut)

        let initialHold = state.update(isPrimaryKeyPressed: true, areRequiredModifiersHeld: true)
        #expect(initialHold.shouldAdvance == false)
        #expect(initialHold.shouldContinue == true)

        let releasedPrimary = state.update(isPrimaryKeyPressed: false, areRequiredModifiersHeld: true)
        #expect(releasedPrimary.shouldAdvance == false)
        #expect(releasedPrimary.shouldContinue == true)

        let repeatedPress = state.update(isPrimaryKeyPressed: true, areRequiredModifiersHeld: true)
        #expect(repeatedPress.shouldAdvance == true)
        #expect(repeatedPress.shouldContinue == true)
    }

    @Test
    func modeCycleSessionStopsWhenRequiredModifiersAreReleased() {
        let shortcut = ActivationShortcut(
            keyCodes: [37],
            modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
        )
        var state = ModeCycleSessionState(shortcut: shortcut)

        let update = state.update(isPrimaryKeyPressed: false, areRequiredModifiersHeld: false)
        #expect(update.shouldAdvance == false)
        #expect(update.shouldContinue == false)
    }
}
