import AppKit
import Foundation

struct InputFallbackPanelPayload: Equatable {
    static let summaryCharacterLimit = 96

    let fullText: String
    let summaryText: String
    let canExpand: Bool

    init?(text: String, summaryCharacterLimit: Int = InputFallbackPanelPayload.summaryCharacterLimit) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        fullText = trimmed

        if trimmed.count > summaryCharacterLimit {
            let endIndex = trimmed.index(trimmed.startIndex, offsetBy: summaryCharacterLimit)
            summaryText = String(trimmed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
            canExpand = true
        } else {
            summaryText = trimmed
            canExpand = false
        }
    }
}

struct InputFallbackPanelPresentationState: Equatable {
    let payload: InputFallbackPanelPayload
    let isExpanded: Bool

    init(payload: InputFallbackPanelPayload, isExpanded: Bool = false) {
        self.payload = payload
        self.isExpanded = isExpanded && payload.canExpand
    }

    var displayText: String {
        isExpanded ? payload.fullText : payload.summaryText
    }

    var toggleTitle: String? {
        guard payload.canExpand else {
            return nil
        }

        return isExpanded ? "Hide Full Text" : "Show Full Text"
    }

    var copyText: String {
        payload.fullText
    }

    func toggled() -> InputFallbackPanelPresentationState {
        InputFallbackPanelPresentationState(payload: payload, isExpanded: !isExpanded)
    }
}

struct InputFallbackPanelPalette {
    let backgroundColor: NSColor
    let borderColor: NSColor
    let titleColor: NSColor
    let textColor: NSColor
    let secondaryTextColor: NSColor
    let primaryButtonBackgroundColor: NSColor
    let primaryButtonBorderColor: NSColor
    let primaryButtonTextColor: NSColor
    let secondaryButtonBackgroundColor: NSColor
    let secondaryButtonBorderColor: NSColor
    let secondaryButtonTextColor: NSColor
    let toggleColor: NSColor

    init(appearance: NSAppearance) {
        let cardChrome = PanelTheme.surfaceChrome(for: appearance, style: .card)
        let primaryChrome = PanelTheme.buttonChrome(for: appearance, role: .primary)
        let secondaryChrome = PanelTheme.buttonChrome(for: appearance, role: .secondary)

        backgroundColor = cardChrome.background
        borderColor = cardChrome.border
        titleColor = PanelTheme.titleText(for: appearance)
        textColor = PanelTheme.titleText(for: appearance)
        secondaryTextColor = PanelTheme.subtitleText(for: appearance)
        primaryButtonBackgroundColor = primaryChrome.fill
        primaryButtonBorderColor = primaryChrome.border
        primaryButtonTextColor = primaryChrome.text
        secondaryButtonBackgroundColor = secondaryChrome.fill
        secondaryButtonBorderColor = secondaryChrome.border
        secondaryButtonTextColor = secondaryChrome.text
        toggleColor = PanelTheme.subtitleText(for: appearance)
    }
}
