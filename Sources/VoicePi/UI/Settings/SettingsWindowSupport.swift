import AppKit

enum SettingsWindowChrome {
    static let title = "VoicePi Settings"
    static let subtitle = "Quick controls for permissions, dictation, dictionary, and processor settings."
    static let defaultSize = NSSize(width: 820, height: 600)
    static let minimumSize = NSSize(width: 720, height: 600)
}
enum SettingsWindowSurfaceStyle {
    case card
    case header
    case pill
    case row
}

enum SettingsWindowButtonRole {
    case primary
    case secondary
    case navigation
}

struct SettingsWindowThemePalette: Equatable {
    let pageBackground: NSColor
    let accent: NSColor
    let accentGlow: NSColor
    let titleText: NSColor
    let subtitleText: NSColor
}

struct SettingsWindowSurfaceChrome: Equatable {
    let background: NSColor
    let border: NSColor
    let shadowColor: NSColor
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let cornerRadius: CGFloat
}

struct SettingsWindowButtonChrome: Equatable {
    let fill: NSColor
    let border: NSColor
    let text: NSColor
    let shadowColor: NSColor
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let cornerRadius: CGFloat
}

enum SettingsWindowTheme {
    static func isDark(_ appearance: NSAppearance?) -> Bool {
        appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func palette(for appearance: NSAppearance?) -> SettingsWindowThemePalette {
        if isDark(appearance) {
            return .init(
                pageBackground: NSColor(
                    calibratedRed: 0x16 / 255.0,
                    green: 0x1A / 255.0,
                    blue: 0x1C / 255.0,
                    alpha: 1
                ),
                accent: NSColor(
                    calibratedRed: 0x76 / 255.0,
                    green: 0xE7 / 255.0,
                    blue: 0x89 / 255.0,
                    alpha: 1
                ),
                accentGlow: NSColor(
                    calibratedRed: 0x4A / 255.0,
                    green: 0xF2 / 255.0,
                    blue: 0x72 / 255.0,
                    alpha: 1
                ),
                titleText: NSColor(
                    calibratedRed: 0xEE / 255.0,
                    green: 0xF4 / 255.0,
                    blue: 0xEF / 255.0,
                    alpha: 1
                ),
                subtitleText: NSColor(
                    calibratedRed: 0xB7 / 255.0,
                    green: 0xC0 / 255.0,
                    blue: 0xB9 / 255.0,
                    alpha: 1
                )
            )
        }

        return .init(
            pageBackground: NSColor(
                calibratedRed: 0xF6 / 255.0,
                green: 0xF0 / 255.0,
                blue: 0xE8 / 255.0,
                alpha: 1
            ),
            accent: NSColor(
                calibratedRed: 0x3E / 255.0,
                green: 0x64 / 255.0,
                blue: 0x4A / 255.0,
                alpha: 1
            ),
            accentGlow: NSColor(
                calibratedRed: 0x4A / 255.0,
                green: 0xF2 / 255.0,
                blue: 0x72 / 255.0,
                alpha: 1
            ),
            titleText: NSColor(
                calibratedRed: 0x1D / 255.0,
                green: 0x2C / 255.0,
                blue: 0x24 / 255.0,
                alpha: 1
            ),
            subtitleText: NSColor(
                calibratedRed: 0x63 / 255.0,
                green: 0x68 / 255.0,
                blue: 0x60 / 255.0,
                alpha: 1
            )
        )
    }

    static func surfaceChrome(
        for appearance: NSAppearance?,
        style: SettingsWindowSurfaceStyle
    ) -> SettingsWindowSurfaceChrome {
        if isDark(appearance) {
            switch style {
            case .card:
                return .init(
                    background: NSColor(
                        calibratedRed: 0x1B / 255.0,
                        green: 0x1F / 255.0,
                        blue: 0x21 / 255.0,
                        alpha: 0.90
                    ),
                    border: NSColor(calibratedWhite: 1, alpha: 0.040),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0.05,
                    shadowRadius: 8,
                    shadowOffset: CGSize(width: 0, height: -2),
                    cornerRadius: 14
                )
            case .header:
                return .init(
                    background: NSColor(
                        calibratedRed: 0x18 / 255.0,
                        green: 0x1C / 255.0,
                        blue: 0x1E / 255.0,
                        alpha: 0.98
                    ),
                    border: NSColor(calibratedWhite: 1, alpha: 0.045),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0,
                    shadowRadius: 0,
                    shadowOffset: .zero,
                    cornerRadius: 0
                )
            case .pill:
                return .init(
                    background: NSColor(
                        calibratedRed: 0x30 / 255.0,
                        green: 0x35 / 255.0,
                        blue: 0x37 / 255.0,
                        alpha: 0.86
                    ),
                    border: NSColor(calibratedWhite: 1, alpha: 0.032),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0,
                    shadowRadius: 0,
                    shadowOffset: .zero,
                    cornerRadius: 11
                )
            case .row:
                return .init(
                    background: NSColor(
                        calibratedRed: 0x22 / 255.0,
                        green: 0x27 / 255.0,
                        blue: 0x29 / 255.0,
                        alpha: 0.86
                    ),
                    border: NSColor(calibratedWhite: 1, alpha: 0.035),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0,
                    shadowRadius: 0,
                    shadowOffset: .zero,
                    cornerRadius: 12
                )
            }
        }

        switch style {
        case .card:
            return .init(
                background: NSColor(
                    calibratedRed: 0xFC / 255.0,
                    green: 0xF8 / 255.0,
                    blue: 0xF1 / 255.0,
                    alpha: 0.94
                ),
                border: NSColor(calibratedWhite: 0, alpha: 0.035),
                shadowColor: NSColor.black,
                shadowOpacity: 0.045,
                shadowRadius: 10,
                shadowOffset: CGSize(width: 0, height: -2),
                cornerRadius: 14
            )
        case .header:
            return .init(
                background: NSColor(
                    calibratedRed: 0xF7 / 255.0,
                    green: 0xF2 / 255.0,
                    blue: 0xEA / 255.0,
                    alpha: 0.985
                ),
                border: NSColor(calibratedWhite: 0, alpha: 0.045),
                shadowColor: NSColor.black,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowOffset: .zero,
                cornerRadius: 0
            )
        case .pill:
            return .init(
                background: NSColor(
                    calibratedRed: 0xF2 / 255.0,
                    green: 0xEC / 255.0,
                    blue: 0xE4 / 255.0,
                    alpha: 0.95
                ),
                border: NSColor(calibratedWhite: 0, alpha: 0.03),
                shadowColor: NSColor.black,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowOffset: .zero,
                cornerRadius: 11
            )
        case .row:
            return .init(
                background: NSColor(
                    calibratedRed: 0xFB / 255.0,
                    green: 0xF7 / 255.0,
                    blue: 0xF0 / 255.0,
                    alpha: 0.90
                ),
                border: NSColor(calibratedWhite: 0, alpha: 0.03),
                shadowColor: NSColor.black,
                shadowOpacity: 0.015,
                shadowRadius: 3,
                shadowOffset: CGSize(width: 0, height: -1),
                cornerRadius: 12
            )
        }
    }

    static func buttonChrome(
        for appearance: NSAppearance?,
        role: SettingsWindowButtonRole,
        isSelected: Bool,
        isHovered: Bool,
        isHighlighted: Bool
    ) -> SettingsWindowButtonChrome {
        let palette = palette(for: appearance)
        let darkMode = isDark(appearance)

        switch role {
        case .primary:
            if darkMode {
                return .init(
                    fill: NSColor(
                        calibratedRed: 0x2F / 255.0,
                        green: 0x69 / 255.0,
                        blue: 0x39 / 255.0,
                        alpha: isHighlighted ? 1.0 : 0.96
                    ),
                    border: NSColor(
                        calibratedRed: 0x74 / 255.0,
                        green: 0xD7 / 255.0,
                        blue: 0x83 / 255.0,
                        alpha: 0.18
                    ),
                    text: NSColor(
                        calibratedRed: 0xF4 / 255.0,
                        green: 0xF8 / 255.0,
                        blue: 0xF4 / 255.0,
                        alpha: 1
                    ),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0.12,
                    shadowRadius: 8,
                    shadowOffset: CGSize(width: 0, height: -2),
                    cornerRadius: 12
                )
            }

            return .init(
                fill: palette.accent.withAlphaComponent(isHighlighted ? 0.94 : 0.90),
                border: palette.accent.withAlphaComponent(0.10),
                text: NSColor(
                    calibratedRed: 0xFB / 255.0,
                    green: 0xF8 / 255.0,
                    blue: 0xF1 / 255.0,
                    alpha: 1
                ),
                shadowColor: NSColor.black,
                shadowOpacity: 0.10,
                shadowRadius: 8,
                shadowOffset: CGSize(width: 0, height: -2),
                cornerRadius: 12
            )
        case .secondary:
            if darkMode {
                return .init(
                    fill: NSColor.white.withAlphaComponent(isHighlighted ? 0.070 : 0.045),
                    border: NSColor(calibratedWhite: 1, alpha: 0.055),
                    text: NSColor(
                        calibratedRed: 0xE6 / 255.0,
                        green: 0xEC / 255.0,
                        blue: 0xE7 / 255.0,
                        alpha: 1
                    ),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0,
                    shadowRadius: 0,
                    shadowOffset: .zero,
                    cornerRadius: 12
                )
            }

            return .init(
                fill: NSColor.white.withAlphaComponent(isHighlighted ? 0.56 : 0.40),
                border: NSColor(calibratedWhite: 0, alpha: 0.045),
                text: NSColor(
                    calibratedRed: 0x2A / 255.0,
                    green: 0x35 / 255.0,
                    blue: 0x2E / 255.0,
                    alpha: 1
                ),
                shadowColor: NSColor.black,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowOffset: .zero,
                cornerRadius: 12
            )
        case .navigation:
            let showsHoverChrome = isHovered || isHighlighted

            if darkMode {
                return .init(
                    fill: isSelected
                        ? NSColor.white.withAlphaComponent(0.020)
                        : (showsHoverChrome
                            ? NSColor.white.withAlphaComponent(0.018)
                            : .clear),
                    border: .clear,
                    text: isSelected
                        ? palette.accent
                        : NSColor(
                            calibratedRed: 0xB7 / 255.0,
                            green: 0xC0 / 255.0,
                            blue: 0xB9 / 255.0,
                            alpha: 1
                        ),
                    shadowColor: palette.accentGlow,
                    shadowOpacity: 0,
                    shadowRadius: 0,
                    shadowOffset: .zero,
                    cornerRadius: 0
                )
            }

            return .init(
                fill: isSelected
                    ? NSColor.black.withAlphaComponent(0.015)
                    : (showsHoverChrome
                        ? NSColor.black.withAlphaComponent(0.02)
                        : .clear),
                border: .clear,
                text: isSelected
                    ? palette.accent
                    : NSColor(
                        calibratedRed: 0x62 / 255.0,
                        green: 0x66 / 255.0,
                        blue: 0x61 / 255.0,
                        alpha: 1
                    ),
                shadowColor: NSColor.black,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowOffset: .zero,
                cornerRadius: 0
            )
        }
    }

    static func homeShortcutIconColor(for appearance: NSAppearance?) -> NSColor {
        let palette = palette(for: appearance)
        return isDark(appearance) ? palette.subtitleText : palette.accent
    }

    static func homeShortcutTitleColor(for appearance: NSAppearance?) -> NSColor {
        if isDark(appearance) {
            return NSColor(
                calibratedRed: 0xF1 / 255.0,
                green: 0xF5 / 255.0,
                blue: 0xF2 / 255.0,
                alpha: 1
            )
        }

        return NSColor(
            calibratedRed: 0x25 / 255.0,
            green: 0x2D / 255.0,
            blue: 0x28 / 255.0,
            alpha: 1
        )
    }

    static func homeReadinessTitleColor(for appearance: NSAppearance?, isError: Bool) -> NSColor {
        if isError {
            return isDark(appearance)
                ? NSColor(
                    calibratedRed: 0xFF / 255.0,
                    green: 0xC4 / 255.0,
                    blue: 0x6B / 255.0,
                    alpha: 1
                )
                : NSColor(
                    calibratedRed: 0xC9 / 255.0,
                    green: 0x6A / 255.0,
                    blue: 0x10 / 255.0,
                    alpha: 1
                )
        }

        return isDark(appearance)
            ? homeShortcutTitleColor(for: appearance)
            : palette(for: appearance).titleText
    }

    static func featureEyebrowTextColor(for appearance: NSAppearance?) -> NSColor {
        let palette = palette(for: appearance)
        return isDark(appearance) ? palette.subtitleText : palette.accent
    }

    static func processorEnabledTextColor(for appearance: NSAppearance?) -> NSColor {
        let palette = palette(for: appearance)
        return isDark(appearance) ? palette.titleText : palette.accent
    }
}
