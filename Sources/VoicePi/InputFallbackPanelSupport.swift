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
    let material: NSVisualEffectView.Material
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
        let isDarkTheme = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        material = .underWindowBackground

        if isDarkTheme {
            backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 0.96)
            borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
            titleColor = NSColor.white.withAlphaComponent(0.96)
            textColor = NSColor.white.withAlphaComponent(0.92)
            secondaryTextColor = NSColor.white.withAlphaComponent(0.70)
            primaryButtonBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.20)
            primaryButtonBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.16)
            primaryButtonTextColor = NSColor.white.withAlphaComponent(0.98)
            secondaryButtonBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.06)
            secondaryButtonBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
            secondaryButtonTextColor = NSColor.white.withAlphaComponent(0.80)
            toggleColor = NSColor.white.withAlphaComponent(0.78)
        } else {
            backgroundColor = NSColor(calibratedRed: 0xF5 / 255.0, green: 0xF3 / 255.0, blue: 0xED / 255.0, alpha: 0.96)
            borderColor = NSColor(calibratedWhite: 0.0, alpha: 0.08)
            titleColor = NSColor(calibratedWhite: 0.16, alpha: 1)
            textColor = NSColor(calibratedWhite: 0.16, alpha: 1)
            secondaryTextColor = NSColor(calibratedWhite: 0.16, alpha: 0.66)
            primaryButtonBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.58)
            primaryButtonBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.62)
            primaryButtonTextColor = NSColor(calibratedWhite: 0.10, alpha: 1)
            secondaryButtonBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.22)
            secondaryButtonBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.30)
            secondaryButtonTextColor = NSColor(calibratedWhite: 0.22, alpha: 0.82)
            toggleColor = NSColor(calibratedWhite: 0.18, alpha: 0.82)
        }
    }
}
