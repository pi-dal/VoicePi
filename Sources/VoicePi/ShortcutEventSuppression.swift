import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum ShortcutEventSuppression {
    static func shouldSuppressFlagsChangedEvent(
        suppressesMatchedEvents: Bool,
        shortcut: ActivationShortcut,
        keyCode: CGKeyCode,
        flags: CGEventFlags
    ) -> Bool {
        guard suppressesMatchedEvents else {
            return false
        }

        guard shortcutIncludesModifierKey(shortcut, keyCode: keyCode) else {
            return false
        }

        return normalizedFlags(flags) == expectedFlags(for: shortcut)
    }

    static func expectedFlags(for shortcut: ActivationShortcut) -> CGEventFlags {
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

    static func normalizedFlags(_ flags: CGEventFlags) -> CGEventFlags {
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

    private static func shortcutIncludesModifierKey(_ shortcut: ActivationShortcut, keyCode: CGKeyCode) -> Bool {
        if keyCode == CGKeyCode(kVK_Function) {
            return shortcut.modifierFlags.contains(.function)
        }
        if keyCode == CGKeyCode(kVK_Option) || keyCode == CGKeyCode(kVK_RightOption) {
            return shortcut.modifierFlags.contains(.option)
        }
        if keyCode == CGKeyCode(kVK_Command) || keyCode == CGKeyCode(kVK_RightCommand) {
            return shortcut.modifierFlags.contains(.command)
        }
        if keyCode == CGKeyCode(kVK_Control) || keyCode == CGKeyCode(kVK_RightControl) {
            return shortcut.modifierFlags.contains(.control)
        }
        if keyCode == CGKeyCode(kVK_Shift) || keyCode == CGKeyCode(kVK_RightShift) {
            return shortcut.modifierFlags.contains(.shift)
        }

        return false
    }
}
