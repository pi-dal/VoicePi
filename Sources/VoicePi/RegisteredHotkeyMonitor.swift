import Carbon.HIToolbox
import Foundation

final class RegisteredHotkeyMonitor {
    weak var delegate: ShortcutMonitorDelegate?
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    let hotKeyIdentifier: UInt32

    var shortcut: ActivationShortcut = .default {
        didSet {
            guard oldValue != shortcut else { return }

            if isMonitoring {
                stop()
                _ = start()
            }
        }
    }

    private(set) var isMonitoring = false

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let hotKeyBootstrapper: ((RegisteredHotkeyMonitor) -> Bool)?
    private let hotKeyDisabler: ((RegisteredHotkeyMonitor) -> Void)?

    private static let signature: OSType = 0x5650484B // "VPHK"
    private static var nextIdentifier: UInt32 = 1

    init(
        hotKeyIdentifier: UInt32 = RegisteredHotkeyMonitor.allocateHotKeyIdentifier(),
        hotKeyBootstrapper: ((RegisteredHotkeyMonitor) -> Bool)? = nil,
        hotKeyDisabler: ((RegisteredHotkeyMonitor) -> Void)? = nil
    ) {
        self.hotKeyIdentifier = hotKeyIdentifier
        self.hotKeyBootstrapper = hotKeyBootstrapper
        self.hotKeyDisabler = hotKeyDisabler
    }

    @discardableResult
    func start() -> Bool {
        guard !isMonitoring else { return true }

        let didStart = hotKeyBootstrapper?(self) ?? installHotKey()
        isMonitoring = didStart
        return didStart
    }

    func stop() {
        guard isMonitoring || hotKeyRef != nil || handlerRef != nil else { return }

        if let hotKeyDisabler {
            hotKeyDisabler(self)
        } else {
            uninstallHotKey()
        }

        isMonitoring = false
    }

    deinit {
        stop()
    }

    private func installHotKey() -> Bool {
        guard hotKeyRef == nil, handlerRef == nil else { return true }
        guard shortcut.isRegisteredHotkeyCompatible, let keyCode = shortcut.keyCode else {
            return false
        }

        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userInfo in
                guard let event, let userInfo else {
                    return noErr
                }

                let monitor = Unmanaged<RegisteredHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handleHotKeyEvent(event)
            },
            eventTypes.count,
            &eventTypes,
            userInfo,
            &handlerRef
        )

        guard handlerStatus == noErr else {
            handlerRef = nil
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: hotKeyIdentifier)
        let registrationStatus = RegisterEventHotKey(
            UInt32(keyCode),
            shortcut.carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registrationStatus == noErr else {
            if let handlerRef {
                RemoveEventHandler(handlerRef)
                self.handlerRef = nil
            }
            return false
        }

        return true
    }

    private func uninstallHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard
            status == noErr,
            hotKeyID.signature == Self.signature,
            hotKeyID.id == hotKeyIdentifier
        else {
            return noErr
        }

        switch GetEventKind(event) {
        case UInt32(kEventHotKeyPressed):
            delegate?.shortcutMonitorDidPress()
            onPress?()
        case UInt32(kEventHotKeyReleased):
            delegate?.shortcutMonitorDidRelease()
            onRelease?()
        default:
            break
        }

        return noErr
    }

    private static func allocateHotKeyIdentifier() -> UInt32 {
        let identifier = nextIdentifier
        nextIdentifier += 1
        return identifier
    }
}
