import AppKit
import ApplicationServices

struct ShortcutRecorderResult {
    let previewShortcut: ActivationShortcut?
    let committedShortcut: ActivationShortcut?
}

struct ShortcutRecorderState {
    private var currentModifiers: NSEvent.ModifierFlags = []
    private var pressedKeyCodes: [UInt16] = []
    private var lastObservedShortcut: ActivationShortcut?

    mutating func handleFlagsChanged(_ flags: NSEvent.ModifierFlags) -> ShortcutRecorderResult {
        currentModifiers = normalizedModifiers(from: flags)

        if pressedKeyCodes.isEmpty {
            if currentModifiers.isEmpty {
                if let lastObservedShortcut, lastObservedShortcut.isModifierOnly {
                    reset()
                    return ShortcutRecorderResult(previewShortcut: nil, committedShortcut: lastObservedShortcut)
                }

                lastObservedShortcut = nil
                return ShortcutRecorderResult(previewShortcut: nil, committedShortcut: nil)
            }

            let shortcut = currentShortcut()
            if shouldPersistObservedShortcut(shortcut) {
                lastObservedShortcut = shortcut
            }
            return ShortcutRecorderResult(previewShortcut: shortcut, committedShortcut: nil)
        }

        let shortcut = currentShortcut()
        lastObservedShortcut = shortcut
        return ShortcutRecorderResult(previewShortcut: shortcut, committedShortcut: nil)
    }

    mutating func handleKeyDown(_ keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> ShortcutRecorderResult {
        currentModifiers = normalizedModifiers(from: modifiers)

        if !pressedKeyCodes.contains(keyCode), pressedKeyCodes.count < 3 {
            pressedKeyCodes.append(keyCode)
        }

        let shortcut = currentShortcut()
        lastObservedShortcut = shortcut.isEmpty ? lastObservedShortcut : shortcut
        return ShortcutRecorderResult(previewShortcut: shortcut.isEmpty ? nil : shortcut, committedShortcut: nil)
    }

    mutating func handleKeyUp(_ keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> ShortcutRecorderResult {
        currentModifiers = normalizedModifiers(from: modifiers)
        pressedKeyCodes.removeAll { $0 == keyCode }

        if pressedKeyCodes.isEmpty {
            let committedShortcut = lastObservedShortcut.flatMap { $0.isModifierOnly ? nil : $0 }
            reset()
            return ShortcutRecorderResult(previewShortcut: nil, committedShortcut: committedShortcut)
        }

        let shortcut = currentShortcut()
        return ShortcutRecorderResult(previewShortcut: shortcut, committedShortcut: nil)
    }

    mutating func reset() {
        currentModifiers = []
        pressedKeyCodes = []
        lastObservedShortcut = nil
    }

    private func currentShortcut() -> ActivationShortcut {
        ActivationShortcut(
            keyCodes: pressedKeyCodes,
            modifierFlagsRawValue: currentModifiers.rawValue
        )
    }

    private func shouldPersistObservedShortcut(_ shortcut: ActivationShortcut) -> Bool {
        guard let lastObservedShortcut else {
            return true
        }

        guard shortcut.isModifierOnly, lastObservedShortcut.isModifierOnly else {
            return true
        }

        return shortcut.modifierFlags.isSuperset(of: lastObservedShortcut.modifierFlags)
    }

    private func normalizedModifiers(from flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.command, .option, .control, .shift, .capsLock, .function])
    }
}

struct ShortcutMonitorResult {
    let didPress: Bool
    let didRelease: Bool
}

struct ShortcutMonitorState {
    var shortcut: ActivationShortcut

    private var currentFlags: CGEventFlags = []
    private var pressedKeyCodes: Set<UInt16> = []
    private var isShortcutActive = false

    init(shortcut: ActivationShortcut) {
        self.shortcut = shortcut
    }

    mutating func handleFlagsChanged(flags: CGEventFlags) -> ShortcutMonitorResult {
        currentFlags = flags
        return updateActivationState()
    }

    mutating func handleKeyDown(_ keyCode: UInt16, flags: CGEventFlags) -> ShortcutMonitorResult {
        currentFlags = flags

        if expectedKeyCodes.contains(keyCode) {
            pressedKeyCodes.insert(keyCode)
        }

        return updateActivationState()
    }

    mutating func handleKeyUp(_ keyCode: UInt16, flags: CGEventFlags) -> ShortcutMonitorResult {
        currentFlags = flags

        if expectedKeyCodes.contains(keyCode) {
            pressedKeyCodes.remove(keyCode)
        }

        return updateActivationState()
    }

    mutating func reset() {
        currentFlags = []
        pressedKeyCodes = []
        isShortcutActive = false
    }

    var expectedKeyCodes: Set<UInt16> {
        Set(shortcut.keyCodes)
    }

    private mutating func updateActivationState() -> ShortcutMonitorResult {
        let matches = matchesCurrentState()

        if matches && !isShortcutActive {
            isShortcutActive = true
            return ShortcutMonitorResult(didPress: true, didRelease: false)
        }

        if !matches && isShortcutActive {
            isShortcutActive = false
            return ShortcutMonitorResult(didPress: false, didRelease: true)
        }

        return ShortcutMonitorResult(didPress: false, didRelease: false)
    }

    private func matchesCurrentState() -> Bool {
        normalizedFlags(currentFlags) == expectedCGFlags() && pressedKeyCodes == expectedKeyCodes
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
}
