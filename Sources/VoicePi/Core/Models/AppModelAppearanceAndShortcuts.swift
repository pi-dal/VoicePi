import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import Foundation

enum InterfaceTheme: String, Codable, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

struct ActivationShortcut: Codable, Equatable {
    var keyCodes: [UInt16]
    var modifierFlagsRawValue: UInt

    enum CodingKeys: String, CodingKey {
        case keyCodes
        case keyCode
        case modifierFlagsRawValue
    }

    init(
        keyCodes: [UInt16] = [],
        modifierFlagsRawValue: UInt = 0
    ) {
        self.keyCodes = Array(keyCodes.prefix(3))
        self.modifierFlagsRawValue = modifierFlagsRawValue
    }

    init(
        keyCode: UInt16? = nil,
        modifierFlagsRawValue: UInt = 0
    ) {
        self.init(
            keyCodes: keyCode.map { [$0] } ?? [],
            modifierFlagsRawValue: modifierFlagsRawValue
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let decodedKeyCodes = try container.decodeIfPresent([UInt16].self, forKey: .keyCodes) {
            self.keyCodes = Array(decodedKeyCodes.prefix(3))
        } else if let decodedKeyCode = try container.decodeIfPresent(UInt16.self, forKey: .keyCode) {
            self.keyCodes = [decodedKeyCode]
        } else {
            self.keyCodes = []
        }

        self.modifierFlagsRawValue = try container.decode(UInt.self, forKey: .modifierFlagsRawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCodes, forKey: .keyCodes)
        try container.encode(modifierFlagsRawValue, forKey: .modifierFlagsRawValue)
    }

    static let legacyDefault = ActivationShortcut(
        keyCodes: [],
        modifierFlagsRawValue: NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
    )

    static let `default` = ActivationShortcut(
        keyCodes: [35],
        modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
    )

    var keyCode: UInt16? {
        keyCodes.count == 1 ? keyCodes[0] : nil
    }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue).intersection(.deviceIndependentFlagsMask)
    }

    var isEmpty: Bool {
        keyCodes.isEmpty && modifierFlags.isEmpty
    }

    var isModifierOnly: Bool {
        keyCodes.isEmpty && !modifierFlags.isEmpty
    }

    var isRegisteredHotkeyCompatible: Bool {
        keyCodes.count == 1 &&
        !modifierFlags.isEmpty &&
        modifierFlags.isSubset(of: [.command, .option, .control, .shift])
    }

    var requiresInputMonitoring: Bool {
        !isEmpty && !isRegisteredHotkeyCompatible
    }

    var isBareLetterShortcut: Bool {
        modifierFlags.isEmpty &&
        keyCodes.count == 1 &&
        Self.letterKeyCodes.contains(keyCodes[0])
    }

    func isCurrentlyHeld(
        keyStateProvider: (CGKeyCode) -> Bool = {
            CGEventSource.keyState(.combinedSessionState, key: $0)
        }
    ) -> Bool {
        let expectedKeyCodesHeld = keyCodes.allSatisfy { keyStateProvider(CGKeyCode($0)) }
        guard expectedKeyCodesHeld else { return false }

        if modifierFlags.contains(.command),
           !Self.commandModifierKeyCodes.contains(where: keyStateProvider) {
            return false
        }
        if modifierFlags.contains(.option),
           !Self.optionModifierKeyCodes.contains(where: keyStateProvider) {
            return false
        }
        if modifierFlags.contains(.control),
           !Self.controlModifierKeyCodes.contains(where: keyStateProvider) {
            return false
        }
        if modifierFlags.contains(.shift),
           !Self.shiftModifierKeyCodes.contains(where: keyStateProvider) {
            return false
        }
        if modifierFlags.contains(.function),
           !Self.functionModifierKeyCodes.contains(where: keyStateProvider) {
            return false
        }

        return !isEmpty
    }

    var primaryKeyCode: UInt16? {
        keyCodes.count == 1 ? keyCodes[0] : nil
    }

    func areRequiredModifiersHeld(
        keyStateProvider: (CGKeyCode) -> Bool = {
            CGEventSource.keyState(.combinedSessionState, key: $0)
        }
    ) -> Bool {
        if modifierFlags.contains(.command),
           !Self.commandModifierKeyCodes.contains(where: keyStateProvider) {
            return false
        }
        if modifierFlags.contains(.option),
           !Self.optionModifierKeyCodes.contains(where: keyStateProvider) {
            return false
        }
        if modifierFlags.contains(.control),
           !Self.controlModifierKeyCodes.contains(where: keyStateProvider) {
            return false
        }
        if modifierFlags.contains(.shift),
           !Self.shiftModifierKeyCodes.contains(where: keyStateProvider) {
            return false
        }
        if modifierFlags.contains(.function),
           !Self.functionModifierKeyCodes.contains(where: keyStateProvider) {
            return false
        }

        return !modifierFlags.isEmpty
    }

    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0

        if modifierFlags.contains(.command) {
            flags |= UInt32(cmdKey)
        }
        if modifierFlags.contains(.option) {
            flags |= UInt32(optionKey)
        }
        if modifierFlags.contains(.control) {
            flags |= UInt32(controlKey)
        }
        if modifierFlags.contains(.shift) {
            flags |= UInt32(shiftKey)
        }

        return flags
    }

    var displayString: String {
        let modifierText = modifierGlyphs(for: modifierFlags)
        let keyTexts = keyCodes.compactMap(displayKeyName(for:))

        if modifierText.isEmpty && keyTexts.isEmpty {
            return "Not Set"
        }

        if keyTexts.isEmpty {
            return modifierText
        }

        if modifierText.isEmpty {
            return keyTexts.joined(separator: " + ")
        }

        return ([modifierText] + keyTexts).joined(separator: " + ")
    }

    var menuTitle: String {
        let parts = menuModifierNames(for: modifierFlags) + keyCodes.compactMap(menuKeyName(for:))
        return parts.isEmpty ? "Not Set" : parts.joined(separator: " + ")
    }

    private static let letterKeyCodes: Set<UInt16> = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
        11, 12, 13, 14, 15, 16, 17,
        31, 32, 34, 35, 37, 38, 40,
        45, 46
    ]
    private static let commandModifierKeyCodes: [CGKeyCode] = [CGKeyCode(kVK_Command), CGKeyCode(kVK_RightCommand)]
    private static let optionModifierKeyCodes: [CGKeyCode] = [CGKeyCode(kVK_Option), CGKeyCode(kVK_RightOption)]
    private static let controlModifierKeyCodes: [CGKeyCode] = [CGKeyCode(kVK_Control), CGKeyCode(kVK_RightControl)]
    private static let shiftModifierKeyCodes: [CGKeyCode] = [CGKeyCode(kVK_Shift), CGKeyCode(kVK_RightShift)]
    private static let functionModifierKeyCodes: [CGKeyCode] = [CGKeyCode(kVK_Function)]

    private func modifierGlyphs(for flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []

        if flags.contains(.command) {
            parts.append("⌘")
        }
        if flags.contains(.option) {
            parts.append("⌥")
        }
        if flags.contains(.control) {
            parts.append("⌃")
        }
        if flags.contains(.shift) {
            parts.append("⇧")
        }
        if flags.contains(.capsLock) {
            parts.append("⇪")
        }
        if flags.contains(.function) {
            parts.append("fn")
        }

        return parts.joined()
    }

    private func menuModifierNames(for flags: NSEvent.ModifierFlags) -> [String] {
        var parts: [String] = []

        if flags.contains(.command) {
            parts.append("Command")
        }
        if flags.contains(.option) {
            parts.append("Option")
        }
        if flags.contains(.control) {
            parts.append("Control")
        }
        if flags.contains(.shift) {
            parts.append("Shift")
        }
        if flags.contains(.capsLock) {
            parts.append("Caps Lock")
        }
        if flags.contains(.function) {
            parts.append("Fn")
        }

        return parts
    }

    private func displayKeyName(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 36:
            return "↩"
        case 48:
            return "⇥"
        case 49:
            return "Space"
        case 51:
            return "⌫"
        case 53:
            return "⎋"
        case 123:
            return "←"
        case 124:
            return "→"
        case 125:
            return "↓"
        case 126:
            return "↑"
        default:
            return menuKeyName(for: keyCode)
        }
    }

    private func menuKeyName(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 0:
            return "A"
        case 1:
            return "S"
        case 2:
            return "D"
        case 3:
            return "F"
        case 4:
            return "H"
        case 5:
            return "G"
        case 6:
            return "Z"
        case 7:
            return "X"
        case 8:
            return "C"
        case 9:
            return "V"
        case 11:
            return "B"
        case 12:
            return "Q"
        case 13:
            return "W"
        case 14:
            return "E"
        case 15:
            return "R"
        case 16:
            return "Y"
        case 17:
            return "T"
        case 18:
            return "1"
        case 19:
            return "2"
        case 20:
            return "3"
        case 21:
            return "4"
        case 22:
            return "6"
        case 23:
            return "5"
        case 24:
            return "="
        case 25:
            return "9"
        case 26:
            return "7"
        case 27:
            return "-"
        case 28:
            return "8"
        case 29:
            return "0"
        case 30:
            return "]"
        case 31:
            return "O"
        case 32:
            return "U"
        case 33:
            return "["
        case 34:
            return "I"
        case 35:
            return "P"
        case 36:
            return "Return"
        case 37:
            return "L"
        case 38:
            return "J"
        case 39:
            return "'"
        case 40:
            return "K"
        case 41:
            return ";"
        case 42:
            return "\\"
        case 43:
            return ","
        case 44:
            return "/"
        case 45:
            return "N"
        case 46:
            return "M"
        case 47:
            return "."
        case 48:
            return "Tab"
        case 49:
            return "Space"
        case 50:
            return "`"
        case 51:
            return "Delete"
        case 53:
            return "Escape"
        case 65:
            return "."
        case 67:
            return "*"
        case 69:
            return "+"
        case 71:
            return "Clear"
        case 75:
            return "/"
        case 76:
            return "Enter"
        case 78:
            return "-"
        case 81:
            return "="
        case 82:
            return "0"
        case 83:
            return "1"
        case 84:
            return "2"
        case 85:
            return "3"
        case 86:
            return "4"
        case 87:
            return "5"
        case 88:
            return "6"
        case 89:
            return "7"
        case 91:
            return "8"
        case 92:
            return "9"
        case 96:
            return "F5"
        case 97:
            return "F6"
        case 98:
            return "F7"
        case 99:
            return "F3"
        case 100:
            return "F8"
        case 101:
            return "F9"
        case 103:
            return "F11"
        case 105:
            return "F13"
        case 106:
            return "F16"
        case 107:
            return "F14"
        case 109:
            return "F10"
        case 111:
            return "F12"
        case 113:
            return "F15"
        case 114:
            return "Help"
        case 115:
            return "Home"
        case 116:
            return "Page Up"
        case 117:
            return "Forward Delete"
        case 118:
            return "F4"
        case 119:
            return "End"
        case 120:
            return "F2"
        case 121:
            return "Page Down"
        case 122:
            return "F1"
        case 123:
            return "Left Arrow"
        case 124:
            return "Right Arrow"
        case 125:
            return "Down Arrow"
        case 126:
            return "Up Arrow"
        default:
            return nil
        }
    }
}

