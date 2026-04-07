import AppKit
import Testing
@testable import VoicePi

struct SettingsWindowPromptEditorAppearanceTests {
    @Test
    @MainActor
    func promptEditorBodyUsesEditorTypographyAndInsets() {
        let font = SettingsWindowController.promptEditorBodyFont
        let inset = SettingsWindowController.promptEditorBodyTextInset

        #expect(font.pointSize == 13)
        #expect(font.fontDescriptor.symbolicTraits.contains(NSFontDescriptor.SymbolicTraits.monoSpace))
        #expect(inset.width == 14)
        #expect(inset.height == 12)
    }

    @Test
    @MainActor
    func promptEditorBodyContainerUsesReadableLightChrome() {
        let chrome = SettingsWindowController.promptEditorBodyContainerChrome(for: NSAppearance(named: .aqua))

        #expect(
            chrome.background == NSColor(
                calibratedRed: 0xF6 / 255.0,
                green: 0xF3 / 255.0,
                blue: 0xEC / 255.0,
                alpha: 1
            )
        )
        #expect(
            chrome.border == NSColor(
                calibratedWhite: 0,
                alpha: 0.08
            )
        )
        #expect(chrome.cornerRadius == 12)
    }

    @Test
    @MainActor
    func promptEditorBodyContainerUsesReadableDarkChrome() {
        let chrome = SettingsWindowController.promptEditorBodyContainerChrome(for: NSAppearance(named: .darkAqua))

        #expect(
            chrome.background == NSColor(
                calibratedWhite: 0.24,
                alpha: 1
            )
        )
        #expect(
            chrome.border == NSColor(
                calibratedWhite: 1,
                alpha: 0.08
            )
        )
        #expect(chrome.cornerRadius == 12)
    }

    @Test
    @MainActor
    func promptEditorBodyUsesReadableLightPalette() {
        let palette = SettingsWindowController.promptEditorBodyPalette(for: NSAppearance(named: .aqua))

        #expect(palette.text == NSColor.labelColor)
        #expect(
            palette.background == NSColor(
                calibratedRed: 0xFC / 255.0,
                green: 0xFB / 255.0,
                blue: 0xF8 / 255.0,
                alpha: 1
            )
        )
        #expect(palette.insertionPoint == palette.text)
    }

    @Test
    @MainActor
    func promptEditorBodyUsesReadableDarkPalette() {
        let palette = SettingsWindowController.promptEditorBodyPalette(for: NSAppearance(named: .darkAqua))

        #expect(palette.text == NSColor.labelColor)
        #expect(
            palette.background == NSColor(
                calibratedWhite: 0.205,
                alpha: 1
            )
        )
        #expect(palette.insertionPoint == palette.text)
    }
}
