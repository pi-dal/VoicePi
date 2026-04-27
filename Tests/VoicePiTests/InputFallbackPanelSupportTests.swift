import AppKit
import Testing
@testable import VoicePi

struct InputFallbackPanelSupportTests {
    @Test
    func shortTextStaysCollapsedWithoutExpandControl() throws {
        let payload = try #require(InputFallbackPanelPayload(text: "short note"))
        let state = InputFallbackPanelPresentationState(payload: payload)

        #expect(state.isExpanded == false)
        #expect(state.displayText == "short note")
        #expect(state.toggleTitle == nil)
        #expect(state.copyText == "short note")
    }

    @Test
    func longTextStartsCollapsedAndCanExpand() throws {
        let longText = String(repeating: "voicepi fallback text ", count: 12)
        let payload = try #require(InputFallbackPanelPayload(text: longText))
        let collapsedState = InputFallbackPanelPresentationState(payload: payload)
        let expandedState = collapsedState.toggled()

        #expect(payload.canExpand)
        #expect(collapsedState.isExpanded == false)
        #expect(collapsedState.displayText != payload.fullText)
        #expect(collapsedState.toggleTitle == "Show Full Text")
        #expect(expandedState.isExpanded)
        #expect(expandedState.displayText == payload.fullText)
        #expect(expandedState.toggleTitle == "Hide Full Text")
    }

    @Test
    func summaryTextIsShorterThanFullTextForLongPayloads() throws {
        let longText = String(repeating: "copy me later ", count: 15)
        let payload = try #require(InputFallbackPanelPayload(text: longText))

        #expect(payload.summaryText.count < payload.fullText.count)
    }

    @Test
    func paletteSupportsLightAndDarkModes() {
        let lightPalette = InputFallbackPanelPalette(
            appearance: NSAppearance(named: .aqua) ?? NSAppearance(named: .vibrantLight) ?? NSAppearance()
        )
        let darkPalette = InputFallbackPanelPalette(
            appearance: NSAppearance(named: .darkAqua) ?? NSAppearance(named: .vibrantDark) ?? NSAppearance()
        )

        #expect(lightPalette.backgroundColor != darkPalette.backgroundColor)
        #expect(lightPalette.textColor != darkPalette.textColor)
        #expect(lightPalette.primaryButtonBackgroundColor != darkPalette.primaryButtonBackgroundColor)
    }

    @Test
    func paletteReusesSettingsThemeBackgroundChrome() throws {
        let lightAppearance = try #require(NSAppearance(named: .aqua))
        let darkAppearance = try #require(NSAppearance(named: .darkAqua))

        let lightPalette = InputFallbackPanelPalette(appearance: lightAppearance)
        let darkPalette = InputFallbackPanelPalette(appearance: darkAppearance)
        let lightChrome = SettingsWindowTheme.surfaceChrome(for: lightAppearance, style: .card)
        let darkChrome = SettingsWindowTheme.surfaceChrome(for: darkAppearance, style: .card)

        #expect(lightPalette.backgroundColor == lightChrome.background)
        #expect(darkPalette.backgroundColor == darkChrome.background)
        #expect(lightPalette.borderColor == lightChrome.border)
        #expect(darkPalette.borderColor == darkChrome.border)
    }
}
