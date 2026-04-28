import AppKit
import Foundation

@MainActor
struct SiteScreenshotExporter {
    struct Asset: Equatable {
        let filename: String
        let size: NSSize
    }

    private enum ThemeVariant: CaseIterable {
        case sunny
        case moon

        var interfaceTheme: InterfaceTheme {
            switch self {
            case .sunny:
                return .light
            case .moon:
                return .dark
            }
        }

        var suffix: String {
            switch self {
            case .sunny:
                return "sunny"
            case .moon:
                return "moon"
            }
        }

        var title: String {
            switch self {
            case .sunny:
                return "Sunny Mode"
            case .moon:
                return "Moonlight Mode"
            }
        }
    }

    func exportGalleryAssets(to directoryURL: URL) throws -> [Asset] {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var manifest: [Asset] = []
        for theme in ThemeVariant.allCases {
            let modeSwitchImage = try renderModeSwitch(for: theme)
            let recordingImage = try renderRecordingOverlay(for: theme)
            let settingsImage = try renderSettingsOverview(for: theme)

            manifest.append(try writePNG(modeSwitchImage, named: "mode-switch-\(theme.suffix).png", to: directoryURL))
            manifest.append(try writePNG(recordingImage, named: "recording-\(theme.suffix).png", to: directoryURL))
            manifest.append(try writePNG(settingsImage, named: "settings-home-\(theme.suffix).png", to: directoryURL))
        }

        return manifest
    }

    private func renderModeSwitch(for theme: ThemeVariant) throws -> NSImage {
        let controller = FloatingPanelContentViewController()
        controller.loadViewIfNeeded()
        controller.view.appearance = theme.interfaceTheme.appearance
        controller.setPhase(.modeSwitch)
        controller.updateModeSwitchTitle(
            PostProcessingMode.refinement.title,
            refinementPromptTitle: "Meeting Notes"
        )

        let rendered = try renderView(controller.view, size: panelSize(for: controller))
        return drawImage(rendered, into: NSSize(width: 944, height: 272), backgroundColor: .clear)
    }

    private func renderRecordingOverlay(for theme: ThemeVariant) throws -> NSImage {
        let controller = FloatingPanelContentViewController()
        controller.loadViewIfNeeded()
        controller.view.appearance = theme.interfaceTheme.appearance
        controller.setPhase(.recording)
        controller.updateTranscript("…back into the active app.")
        controller.updateAudioLevel(0.44)

        let rendered = try renderView(controller.view, size: panelSize(for: controller))
        return drawImage(rendered, into: NSSize(width: 560, height: 112), backgroundColor: .clear)
    }

    private func renderSettingsOverview(for theme: ThemeVariant) throws -> NSImage {
        let palette = SettingsWindowTheme.palette(for: theme.interfaceTheme.appearance)
        let homeWindow = try renderSettingsWindow(section: .home, theme: theme)
        let permissionsWindow = try renderSettingsWindow(section: .permissions, theme: theme)
        let textWindow = try renderSettingsWindow(section: .llm, theme: theme)
        let aboutWindow = try renderSettingsWindow(section: .about, theme: theme)

        let canvasSize = NSSize(width: 3000, height: 2000)
        let image = NSImage(size: canvasSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        palette.pageBackground.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

        drawAtmosphere(
            in: canvasSize,
            accent: palette.accent,
            secondary: palette.subtitleText.withAlphaComponent(theme == .sunny ? 0.14 : 0.10)
        )

        drawThemeBadge(
            title: theme.title,
            accent: palette.accent,
            textColor: palette.titleText,
            canvasSize: canvasSize
        )

        drawWindow(homeWindow, in: NSRect(x: 160, y: 570, width: 1220, height: 910))
        drawWindow(permissionsWindow, in: NSRect(x: 1510, y: 260, width: 720, height: 538))
        drawWindow(textWindow, in: NSRect(x: 1480, y: 900, width: 820, height: 614))
        drawWindow(aboutWindow, in: NSRect(x: 2130, y: 1080, width: 670, height: 502))

        return image
    }

    private func renderSettingsWindow(section: SettingsSection, theme: ThemeVariant) throws -> NSImage {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.SiteScreenshotExporter.\(theme.suffix).\(section.rawValue).\(UUID().uuidString)"
        )!
        let configRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicepi-site-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: configRootURL, withIntermediateDirectories: true)
        let model = AppModel(defaults: defaults, configRootURL: configRootURL)
        model.interfaceTheme = theme.interfaceTheme
        model.microphoneAuthorization = .granted
        model.speechAuthorization = .granted
        model.accessibilityAuthorization = .granted
        model.inputMonitoringAuthorization = .granted

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.show(section: section)
        guard let window = controller.window else {
            throw ExportError.windowUnavailable
        }

        window.appearance = theme.interfaceTheme.appearance
        let rootView = window.contentView?.superview ?? window.contentView
        guard let rootView else {
            throw ExportError.windowUnavailable
        }

        rootView.layoutSubtreeIfNeeded()
        return try renderView(rootView, size: rootView.bounds.size)
    }

    private func panelSize(for controller: FloatingPanelContentViewController) -> NSSize {
        NSSize(width: controller.preferredPanelWidth, height: controller.preferredPanelHeight)
    }

    private func renderView(_ view: NSView, size: NSSize) throws -> NSImage {
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()

        let pixelWidth = max(Int(size.width.rounded()), 1)
        let pixelHeight = max(Int(size.height.rounded()), 1)
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ExportError.bitmapUnavailable
        }

        view.cacheDisplay(in: view.bounds, to: representation)
        representation.size = NSSize(width: pixelWidth, height: pixelHeight)

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        return image
    }

    private func drawImage(_ image: NSImage, into canvasSize: NSSize, backgroundColor: NSColor) -> NSImage {
        let canvas = NSImage(size: canvasSize)
        canvas.lockFocus()
        defer { canvas.unlockFocus() }

        if backgroundColor.alphaComponent > 0 {
            backgroundColor.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()
        }

        let sourceSize = image.size
        let scale = min(canvasSize.width / sourceSize.width, canvasSize.height / sourceSize.height)
        let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let drawRect = NSRect(
            x: round((canvasSize.width - drawSize.width) / 2),
            y: round((canvasSize.height - drawSize.height) / 2),
            width: round(drawSize.width),
            height: round(drawSize.height)
        )
        image.draw(in: drawRect)
        return canvas
    }

    private func drawAtmosphere(in canvasSize: NSSize, accent: NSColor, secondary: NSColor) {
        let upperGlow = NSBezierPath(ovalIn: NSRect(x: 1780, y: 150, width: 860, height: 860))
        accent.withAlphaComponent(0.11).setFill()
        upperGlow.fill()

        let lowerGlow = NSBezierPath(ovalIn: NSRect(x: 60, y: 920, width: 1120, height: 720))
        secondary.setFill()
        lowerGlow.fill()

        let halo = NSBezierPath(ovalIn: NSRect(x: 2100, y: 1040, width: 620, height: 620))
        accent.withAlphaComponent(0.07).setFill()
        halo.fill()
    }

    private func drawThemeBadge(title: String, accent: NSColor, textColor: NSColor, canvasSize: NSSize) {
        let badgeRect = NSRect(x: 1220, y: 140, width: 560, height: 78)
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 39, yRadius: 39)
        accent.withAlphaComponent(0.16).setFill()
        badgePath.fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 34, weight: .semibold),
            .foregroundColor: textColor.withAlphaComponent(0.92),
            .paragraphStyle: paragraph
        ]
        let textRect = badgeRect.offsetBy(dx: 0, dy: 18)
        title.draw(in: textRect, withAttributes: attributes)
    }

    private func drawWindow(_ image: NSImage, in rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 34
        shadow.shadowOffset = NSSize(width: 0, height: -16)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.set()
        image.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func writePNG(_ image: NSImage, named filename: String, to directoryURL: URL) throws -> Asset {
        let fileURL = directoryURL.appendingPathComponent(filename)
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: max(Int(image.size.width.rounded()), 1),
                pixelsHigh: max(Int(image.size.height.rounded()), 1),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            throw ExportError.pngEncodingFailed
        }

        bitmap.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ExportError.pngEncodingFailed
        }
        try pngData.write(to: fileURL)
        return Asset(filename: filename, size: image.size)
    }

    private enum ExportError: Error {
        case bitmapUnavailable
        case pngEncodingFailed
        case windowUnavailable
    }
}
