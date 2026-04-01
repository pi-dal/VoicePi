import AppKit
import ApplicationServices
import Foundation
import Testing
@testable import VoicePi

struct ShortcutChordTests {
    @Test
    func legacySingleKeyShortcutPayloadStillDecodes() throws {
        let payload = #"{"keyCode":0,"modifierFlagsRawValue":0}"#.data(using: .utf8)!
        let shortcut = try JSONDecoder().decode(ActivationShortcut.self, from: payload)

        #expect(shortcut.displayString == "A")
        #expect(shortcut.menuTitle == "A")
    }

    @Test
    func multiKeyShortcutPayloadDecodesAllKeysForDisplay() throws {
        let command = NSEvent.ModifierFlags.command.intersection(.deviceIndependentFlagsMask).rawValue
        let payload = #"{"keyCodes":[0,1],"modifierFlagsRawValue":\#(command)}"#.data(using: .utf8)!
        let shortcut = try JSONDecoder().decode(ActivationShortcut.self, from: payload)

        #expect(shortcut.displayString == "⌘ + A + S")
        #expect(shortcut.menuTitle == "Command + A + S")
    }

    @Test
    func recorderStateCommitsFullChordOnFinalKeyRelease() {
        var state = ShortcutRecorderState()
        let command = NSEvent.ModifierFlags.command

        let initial = state.handleFlagsChanged(command)
        #expect(initial.previewShortcut?.displayString == "⌘")
        #expect(initial.committedShortcut == nil)

        let firstKey = state.handleKeyDown(0, modifiers: command)
        #expect(firstKey.previewShortcut?.displayString == "⌘ + A")
        #expect(firstKey.committedShortcut == nil)

        let secondKey = state.handleKeyDown(1, modifiers: command)
        #expect(secondKey.previewShortcut?.displayString == "⌘ + A + S")
        #expect(secondKey.committedShortcut == nil)

        let firstRelease = state.handleKeyUp(0, modifiers: command)
        #expect(firstRelease.committedShortcut == nil)

        let secondRelease = state.handleKeyUp(1, modifiers: command)
        #expect(secondRelease.committedShortcut?.menuTitle == "Command + A + S")
    }

    @Test
    func recorderStateCommitsModifierOnlyShortcutWhenModifiersAreReleased() {
        var state = ShortcutRecorderState()
        let modifiers: NSEvent.ModifierFlags = [.option, .function]

        let preview = state.handleFlagsChanged(modifiers)
        #expect(preview.previewShortcut?.menuTitle == "Option + Fn")
        #expect(preview.committedShortcut == nil)

        let release = state.handleFlagsChanged([])
        #expect(release.committedShortcut?.menuTitle == "Option + Fn")
    }

    @Test
    func recorderStatePreservesFullModifierOnlyShortcutAcrossStaggeredRelease() {
        var state = ShortcutRecorderState()
        let both: NSEvent.ModifierFlags = [.option, .function]

        let preview = state.handleFlagsChanged(both)
        #expect(preview.previewShortcut?.menuTitle == "Option + Fn")

        let fnReleasedFirst = state.handleFlagsChanged([.option])
        #expect(fnReleasedFirst.previewShortcut?.menuTitle == "Option")
        #expect(fnReleasedFirst.committedShortcut == nil)

        let finalRelease = state.handleFlagsChanged([])
        #expect(finalRelease.committedShortcut?.menuTitle == "Option + Fn")
    }

    @Test
    func monitorStateActivatesOnlyWhenAllChordKeysAreHeld() {
        let command = NSEvent.ModifierFlags.command.intersection(.deviceIndependentFlagsMask).rawValue
        let shortcut = ActivationShortcut(keyCodes: [0, 1], modifierFlagsRawValue: command)
        var state = ShortcutMonitorState(shortcut: shortcut)

        let firstKey = state.handleKeyDown(0, flags: CGEventFlags([.maskCommand]))
        #expect(firstKey.didPress == false)
        #expect(firstKey.didRelease == false)

        let secondKey = state.handleKeyDown(1, flags: CGEventFlags([.maskCommand]))
        #expect(secondKey.didPress == true)
        #expect(secondKey.didRelease == false)

        let release = state.handleKeyUp(0, flags: CGEventFlags([.maskCommand]))
        #expect(release.didPress == false)
        #expect(release.didRelease == true)
    }

    @Test
    func monitorStateActivatesForModifierOnlyOptionFnShortcut() {
        let modifiers = NSEvent.ModifierFlags([.option, .function]).intersection(.deviceIndependentFlagsMask).rawValue
        let shortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: modifiers)
        var state = ShortcutMonitorState(shortcut: shortcut)

        let press = state.handleFlagsChanged(flags: CGEventFlags([.maskAlternate, .maskSecondaryFn]))
        #expect(press.didPress == true)
        #expect(press.didRelease == false)

        let release = state.handleFlagsChanged(flags: [])
        #expect(release.didPress == false)
        #expect(release.didRelease == true)
    }
}
