import AppKit

enum OverlayButtonRole {
    case primary
    case secondary
    case subtle
}

enum OverlayButtonStyler {
    static func configureBase(
        _ button: NSButton,
        action: Selector,
        target: AnyObject?,
        font: NSFont = .systemFont(ofSize: 12.5, weight: .medium)
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = target
        button.action = action
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryPushIn)
        button.font = font
        button.wantsLayer = true
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        if let cell = button.cell as? NSButtonCell {
            cell.lineBreakMode = .byTruncatingTail
        }
    }

    static func style(
        _ button: NSButton,
        role: OverlayButtonRole,
        appearance: NSAppearance,
        cornerRadius: CGFloat = 14
    ) {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let palette = paletteForRole(role, isDark: isDark)
        button.layer?.backgroundColor = palette.background.cgColor
        button.layer?.borderColor = palette.border.cgColor
        button.layer?.borderWidth = 1
        button.layer?.cornerRadius = cornerRadius
        button.contentTintColor = palette.foreground
    }

    private static func paletteForRole(
        _ role: OverlayButtonRole,
        isDark: Bool
    ) -> (background: NSColor, border: NSColor, foreground: NSColor) {
        if isDark {
            switch role {
            case .primary:
                return (
                    background: NSColor(calibratedWhite: 1.0, alpha: 0.20),
                    border: NSColor(calibratedWhite: 1.0, alpha: 0.18),
                    foreground: NSColor.white.withAlphaComponent(0.98)
                )
            case .secondary:
                return (
                    background: NSColor(calibratedWhite: 1.0, alpha: 0.12),
                    border: NSColor(calibratedWhite: 1.0, alpha: 0.14),
                    foreground: NSColor.white.withAlphaComponent(0.90)
                )
            case .subtle:
                return (
                    background: NSColor(calibratedWhite: 1.0, alpha: 0.06),
                    border: NSColor(calibratedWhite: 1.0, alpha: 0.10),
                    foreground: NSColor.white.withAlphaComponent(0.78)
                )
            }
        }

        switch role {
        case .primary:
            return (
                background: NSColor(calibratedWhite: 1.0, alpha: 0.72),
                border: NSColor(calibratedWhite: 1.0, alpha: 0.78),
                foreground: NSColor(calibratedWhite: 0.10, alpha: 1.0)
            )
        case .secondary:
            return (
                background: NSColor(calibratedWhite: 1.0, alpha: 0.46),
                border: NSColor(calibratedWhite: 1.0, alpha: 0.52),
                foreground: NSColor(calibratedWhite: 0.16, alpha: 0.95)
            )
        case .subtle:
            return (
                background: NSColor(calibratedWhite: 1.0, alpha: 0.24),
                border: NSColor(calibratedWhite: 1.0, alpha: 0.30),
                foreground: NSColor(calibratedWhite: 0.20, alpha: 0.78)
            )
        }
    }
}
