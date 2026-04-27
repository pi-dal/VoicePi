import AppKit

final class PanelSurfaceView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum PanelTheme {
    static func pageBackground(for appearance: NSAppearance?) -> NSColor {
        SettingsWindowTheme.palette(for: appearance).pageBackground
    }

    static func overlayBackground(
        for appearance: NSAppearance?,
        alpha: CGFloat = 0.96
    ) -> NSColor {
        pageBackground(for: appearance).withAlphaComponent(alpha)
    }

    static func surfaceChrome(
        for appearance: NSAppearance?,
        style: SettingsWindowSurfaceStyle
    ) -> SettingsWindowSurfaceChrome {
        SettingsWindowTheme.surfaceChrome(for: appearance, style: style)
    }

    static func buttonChrome(
        for appearance: NSAppearance?,
        role: SettingsWindowButtonRole,
        isHovered: Bool = false,
        isHighlighted: Bool = false
    ) -> SettingsWindowButtonChrome {
        SettingsWindowTheme.buttonChrome(
            for: appearance,
            role: role,
            isSelected: false,
            isHovered: isHovered,
            isHighlighted: isHighlighted
        )
    }

    static func titleText(for appearance: NSAppearance?) -> NSColor {
        SettingsWindowTheme.palette(for: appearance).titleText
    }

    static func subtitleText(for appearance: NSAppearance?) -> NSColor {
        SettingsWindowTheme.palette(for: appearance).subtitleText
    }

    static func accent(for appearance: NSAppearance?) -> NSColor {
        SettingsWindowTheme.palette(for: appearance).accent
    }
}
