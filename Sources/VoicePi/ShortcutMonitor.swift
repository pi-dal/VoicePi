import AppKit
import ApplicationServices
import Carbon.HIToolbox

protocol ShortcutMonitorDelegate: AnyObject {
    func shortcutMonitorDidPress(_ monitor: ShortcutMonitor)
    func shortcutMonitorDidRelease(_ monitor: ShortcutMonitor)
}

enum ShortcutMonitorMode: Equatable {
    case listenAndSuppress
    case listenOnly
    case suppressOnly

    var tapCreateOptions: CGEventTapOptions {
        switch self {
        case .listenOnly:
            return .listenOnly
        case .listenAndSuppress, .suppressOnly:
            return .defaultTap
        }
    }

    var reportsMatchedEvents: Bool {
        switch self {
        case .listenAndSuppress, .listenOnly:
            return true
        case .suppressOnly:
            return false
        }
    }

    var suppressesMatchedEvents: Bool {
        switch self {
        case .listenAndSuppress, .suppressOnly:
            return true
        case .listenOnly:
            return false
        }
    }
}

final class ShortcutMonitor {
    weak var delegate: ShortcutMonitorDelegate?

    let mode: ShortcutMonitorMode

    var shortcut: ActivationShortcut = .default {
        didSet {
            if shortcut.isEmpty {
                shortcut = .default
            }
            monitorState.shortcut = shortcut
            resetTrackingState()
        }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isMonitoring = false
    private var currentFlags: CGEventFlags = []
    private var monitorState = ShortcutMonitorState(shortcut: .default)
    private let tapBootstrapper: ((ShortcutMonitor) -> Bool)?
    private let tapDisabler: ((ShortcutMonitor) -> Void)?
    private let eventMask: CGEventMask =
        (1 << CGEventType.flagsChanged.rawValue) |
        (1 << CGEventType.keyDown.rawValue) |
        (1 << CGEventType.keyUp.rawValue)

    init(
        mode: ShortcutMonitorMode = .listenAndSuppress,
        tapBootstrapper: ((ShortcutMonitor) -> Bool)? = nil,
        tapDisabler: ((ShortcutMonitor) -> Void)? = nil
    ) {
        self.mode = mode
        self.tapBootstrapper = tapBootstrapper
        self.tapDisabler = tapDisabler
    }

    var tapCreateOptions: CGEventTapOptions {
        mode.tapCreateOptions
    }

    var reportsMatchedEvents: Bool {
        mode.reportsMatchedEvents
    }

    var suppressesMatchedEvents: Bool {
        mode.suppressesMatchedEvents
    }

    @discardableResult
    func start() -> Bool {
        guard !isMonitoring else { return true }

        let didStart = tapBootstrapper?(self) ?? installEventTap()
        isMonitoring = didStart
        return didStart
    }

    private func installEventTap() -> Bool {
        guard eventTap == nil else { return true }

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<ShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handleEvent(proxy: proxy, type: type, event: event)
        }

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: tapCreateOptions,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source

        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        guard isMonitoring || eventTap != nil else { return }

        if let tapDisabler {
            tapDisabler(self)
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
        isMonitoring = false
        resetTrackingState()
    }

    deinit {
        stop()
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            currentFlags = event.flags
            return handleFlagsChanged(event)

        case .keyDown:
            currentFlags = event.flags
            return handleKeyDown(event)

        case .keyUp:
            currentFlags = event.flags
            return handleKeyUp(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let result = monitorState.handleFlagsChanged(flags: currentFlags)
        handleMonitorResult(result)

        return shouldSuppressFlagsChangedEvent(event, flags: currentFlags)
            ? nil
            : Unmanaged.passUnretained(event)
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let result = monitorState.handleKeyDown(UInt16(keyCode), flags: currentFlags)
        handleMonitorResult(result)

        return shouldSuppressKeyEvent(keyCode: keyCode, flags: currentFlags)
            ? nil
            : Unmanaged.passUnretained(event)
    }

    private func handleKeyUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let result = monitorState.handleKeyUp(UInt16(keyCode), flags: currentFlags)
        handleMonitorResult(result)

        return shouldSuppressKeyEvent(keyCode: keyCode, flags: currentFlags)
            ? nil
            : Unmanaged.passUnretained(event)
    }

    private func matchesCurrentModifierFlags(_ flags: CGEventFlags) -> Bool {
        normalizedFlags(flags) == expectedCGFlags()
    }

    private func expectedCGFlags() -> CGEventFlags {
        var flags: CGEventFlags = []

        if shortcut.modifierFlags.contains(.command) {
            flags.insert(.maskCommand)
        }
        if shortcut.modifierFlags.contains(.option) {
            flags.insert(.maskAlternate)
        }
        if shortcut.modifierFlags.contains(.control) {
            flags.insert(.maskControl)
        }
        if shortcut.modifierFlags.contains(.shift) {
            flags.insert(.maskShift)
        }
        if shortcut.modifierFlags.contains(.capsLock) {
            flags.insert(.maskAlphaShift)
        }
        if shortcut.modifierFlags.contains(.function) {
            flags.insert(.maskSecondaryFn)
        }

        return flags
    }

    private func normalizedFlags(_ flags: CGEventFlags) -> CGEventFlags {
        var normalized: CGEventFlags = []

        if flags.contains(.maskCommand) {
            normalized.insert(.maskCommand)
        }
        if flags.contains(.maskAlternate) {
            normalized.insert(.maskAlternate)
        }
        if flags.contains(.maskControl) {
            normalized.insert(.maskControl)
        }
        if flags.contains(.maskShift) {
            normalized.insert(.maskShift)
        }
        if flags.contains(.maskAlphaShift) {
            normalized.insert(.maskAlphaShift)
        }
        if flags.contains(.maskSecondaryFn) {
            normalized.insert(.maskSecondaryFn)
        }

        return normalized
    }

    private func shouldSuppressFlagsChangedEvent(_ event: CGEvent, flags: CGEventFlags) -> Bool {
        guard suppressesMatchedEvents else {
            return false
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == CGKeyCode(kVK_Function) && shortcut.modifierFlags.contains(.function) {
            return true
        }

        if keyCode == CGKeyCode(kVK_Option) && shortcut.modifierFlags.contains(.option) {
            return true
        }

        if keyCode == CGKeyCode(kVK_RightOption) && shortcut.modifierFlags.contains(.option) {
            return true
        }

        if keyCode == CGKeyCode(kVK_Command) && shortcut.modifierFlags.contains(.command) {
            return true
        }

        if keyCode == CGKeyCode(kVK_RightCommand) && shortcut.modifierFlags.contains(.command) {
            return true
        }

        if keyCode == CGKeyCode(kVK_Control) && shortcut.modifierFlags.contains(.control) {
            return true
        }

        if keyCode == CGKeyCode(kVK_RightControl) && shortcut.modifierFlags.contains(.control) {
            return true
        }

        if keyCode == CGKeyCode(kVK_Shift) && shortcut.modifierFlags.contains(.shift) {
            return true
        }

        if keyCode == CGKeyCode(kVK_RightShift) && shortcut.modifierFlags.contains(.shift) {
            return true
        }

        if shortcut.isModifierOnly && normalizedFlags(flags) == expectedCGFlags() {
            return true
        }

        return false
    }

    private func shouldSuppressKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard suppressesMatchedEvents else {
            return false
        }

        guard shortcut.keyCodes.contains(UInt16(keyCode)) else {
            return false
        }

        return normalizedFlags(flags) == expectedCGFlags()
    }

    private func handleMonitorResult(_ result: ShortcutMonitorResult) {
        guard reportsMatchedEvents else {
            return
        }

        if result.didPress {
            delegate?.shortcutMonitorDidPress(self)
        }

        if result.didRelease {
            delegate?.shortcutMonitorDidRelease(self)
        }
    }

    private func resetTrackingState() {
        currentFlags = []
        monitorState.reset()
    }
}
