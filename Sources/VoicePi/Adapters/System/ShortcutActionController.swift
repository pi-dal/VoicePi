import Foundation

@MainActor
final class ShortcutActionController {
    weak var delegate: ShortcutMonitorDelegate? {
        didSet {
            listenOnlyMonitor.delegate = delegate
            combinedMonitor.delegate = delegate
            registeredHotkeyMonitor.delegate = delegate
        }
    }

    var onPress: (() -> Void)? {
        didSet {
            listenOnlyMonitor.onPress = onPress
            combinedMonitor.onPress = onPress
            registeredHotkeyMonitor.onPress = onPress
        }
    }

    var onRelease: (() -> Void)? {
        didSet {
            listenOnlyMonitor.onRelease = onRelease
            combinedMonitor.onRelease = onRelease
            registeredHotkeyMonitor.onRelease = onRelease
        }
    }

    var shortcut: ActivationShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0) {
        didSet {
            listenOnlyMonitor.shortcut = shortcut
            combinedMonitor.shortcut = shortcut
            registeredHotkeyMonitor.shortcut = shortcut
        }
    }

    private let listenOnlyMonitor = ShortcutMonitor(mode: .listenOnly)
    private let combinedMonitor = ShortcutMonitor(mode: .listenAndSuppress)
    private let registeredHotkeyMonitor = RegisteredHotkeyMonitor()

    func stop() {
        registeredHotkeyMonitor.stop()
        listenOnlyMonitor.stop()
        combinedMonitor.stop()
    }

    func apply(
        _ plan: AppController.HotkeyMonitorPlan,
        registrationFailureMessage: String,
        monitoringFailureMessage: String
    ) -> String? {
        guard let strategy = plan.strategy else {
            stop()
            return plan.statusMessage
        }

        switch strategy {
        case .registeredHotkey:
            listenOnlyMonitor.stop()
            combinedMonitor.stop()
            guard registeredHotkeyMonitor.start() else {
                return registrationFailureMessage
            }
        case .eventTap(.listenOnly):
            registeredHotkeyMonitor.stop()
            combinedMonitor.stop()
            guard listenOnlyMonitor.start() else {
                return monitoringFailureMessage
            }
        case .eventTap(.listenAndSuppress):
            registeredHotkeyMonitor.stop()
            listenOnlyMonitor.stop()
            guard combinedMonitor.start() else {
                return monitoringFailureMessage
            }
        case .eventTap(.suppressOnly):
            stop()
            return monitoringFailureMessage
        }

        return plan.statusMessage
    }
}
