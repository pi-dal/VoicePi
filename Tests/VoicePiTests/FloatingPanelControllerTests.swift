import AppKit
import Testing
@testable import VoicePi

struct FloatingPanelControllerTests {
    @Test
    func refiningBannerStaysCompactForShortStatusText() {
        let width = FloatingPanelSupport.bannerPreferredWidth(
            for: .refining,
            transcript: FloatingPanelSupport.displayedTranscript(for: .refining, transcript: "")
        )

        #expect(width >= 260)
        #expect(width < 320)
    }

    @Test
    func refiningBannerExpandsForLongStatusText() {
        let shortWidth = FloatingPanelSupport.bannerPreferredWidth(
            for: .refining,
            transcript: "Refining..."
        )
        let longWidth = FloatingPanelSupport.bannerPreferredWidth(
            for: .refining,
            transcript: "Refining with Customer Success Follow-up Email"
        )

        #expect(longWidth > shortWidth)
    }

    @Test
    func displayedTranscriptUsesPhaseSpecificFallbackCopy() {
        #expect(FloatingPanelSupport.displayedTranscript(for: .recording, transcript: "   ") == "正在聆听…")
        #expect(FloatingPanelSupport.displayedTranscript(for: .refining, transcript: "\n") == "Refining...")
        #expect(FloatingPanelSupport.displayedTranscript(for: .modeSwitch, transcript: "Translate") == "Translate")
    }

    @Test
    func sourcePreviewIsSuppressedInFloatingBanner() {
        #expect(FloatingPanelSupport.displayedSourcePreview("  selected source  ") == nil)
        #expect(FloatingPanelSupport.displayedSourcePreview(" \n\t ") == nil)
    }

    @Test
    func bannerHeightIgnoresSourcePreview() {
        #expect(FloatingPanelSupport.bannerPreferredHeight(sourcePreview: nil) == 56)
        #expect(FloatingPanelSupport.bannerPreferredHeight(sourcePreview: "reference text") == 56)
    }

    @Test
    func transcriptPresentationStateSkipsLayoutWorkForRepeatedDisplayedText() {
        var state = FloatingPanelTranscriptPresentationState()

        let first = state.prepareUpdate(for: .recording, transcript: "hello")
        let second = state.prepareUpdate(for: .recording, transcript: "hello")

        #expect(first.requiresLayoutRecalculation)
        #expect(!second.requiresLayoutRecalculation)
        #expect(second.displayedText == "hello")
    }

    @Test
    func transcriptPresentationStateTreatsRecordingPlaceholderAsStableText() {
        var state = FloatingPanelTranscriptPresentationState()

        let first = state.prepareUpdate(for: .recording, transcript: "   ")
        let second = state.prepareUpdate(for: .recording, transcript: "\n")

        #expect(first.displayedText == "正在聆听…")
        #expect(!second.requiresLayoutRecalculation)
    }

    @Test
    func transcriptPresentationStateInvalidatesLayoutWhenPhaseChanges() {
        var state = FloatingPanelTranscriptPresentationState()

        _ = state.prepareUpdate(for: .recording, transcript: "hello")
        let refining = state.prepareDisplayedText("hello", for: .refining)

        #expect(refining.requiresLayoutRecalculation)
        #expect(refining.displayedText == "hello")
    }

    @Test
    func recordingPaletteReusesSettingsThemeBackgroundChrome() throws {
        let lightAppearance = try #require(NSAppearance(named: .aqua))
        let darkAppearance = try #require(NSAppearance(named: .darkAqua))

        let lightPalette = FloatingPanelPalette(appearance: lightAppearance, phase: .recording)
        let darkPalette = FloatingPanelPalette(appearance: darkAppearance, phase: .recording)
        let lightChrome = SettingsWindowTheme.surfaceChrome(for: lightAppearance, style: .row)
        let darkChrome = SettingsWindowTheme.surfaceChrome(for: darkAppearance, style: .row)

        #expect(lightPalette.backgroundColor == lightChrome.background)
        #expect(darkPalette.backgroundColor == darkChrome.background)
        #expect(lightPalette.borderColor == lightChrome.border)
        #expect(darkPalette.borderColor == darkChrome.border)
    }

    @Test
    @MainActor
    func recordingBannerRendersSameWarmSurfaceAsSettings() throws {
        let appearance = try #require(NSAppearance(named: .aqua))
        let controller = FloatingPanelContentViewController()

        controller.loadViewIfNeeded()
        controller.view.appearance = appearance
        controller.view.frame = NSRect(
            x: 0,
            y: 0,
            width: FloatingPanelSupport.compactBannerWidth,
            height: FloatingPanelSupport.compactBannerHeight
        )
        controller.setPhase(.recording)
        controller.updateTranscript("")
        controller.view.layoutSubtreeIfNeeded()

        let referenceView = ThemedSurfaceView(style: .row)
        referenceView.appearance = appearance
        referenceView.frame = controller.view.bounds
        referenceView.layoutSubtreeIfNeeded()

        let samplePoint = NSPoint(x: controller.view.bounds.width - 12, y: 12)
        let actualColor = try #require(sampleRenderedColor(in: controller.view, at: samplePoint))
        let expectedColor = try #require(sampleRenderedColor(in: referenceView, at: samplePoint))

        #expect(actualColor.isApproximatelyEqual(to: expectedColor, tolerance: 0.01))
    }

    @Test
    func modeSwitchPaletteUsesSettingsSurfaceChrome() throws {
        let lightAppearance = try #require(NSAppearance(named: .aqua))
        let darkAppearance = try #require(NSAppearance(named: .darkAqua))

        let lightPalette = FloatingPanelPalette(appearance: lightAppearance, phase: .modeSwitch)
        let darkPalette = FloatingPanelPalette(appearance: darkAppearance, phase: .modeSwitch)
        let lightChrome = SettingsWindowTheme.surfaceChrome(for: lightAppearance, style: .card)
        let darkChrome = SettingsWindowTheme.surfaceChrome(for: darkAppearance, style: .card)

        #expect(lightPalette.backgroundColor == lightChrome.background)
        #expect(darkPalette.backgroundColor == darkChrome.background)
    }
}

@MainActor
private func sampleRenderedColor(in view: NSView, at point: NSPoint) -> NSColor? {
    view.layoutSubtreeIfNeeded()
    guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        return nil
    }

    view.cacheDisplay(in: view.bounds, to: representation)
    let sampleX = min(max(Int(point.x.rounded(.down)), 0), representation.pixelsWide - 1)
    let sampleY = min(max(Int(point.y.rounded(.down)), 0), representation.pixelsHigh - 1)
    return representation.colorAt(x: sampleX, y: sampleY)?.usingColorSpace(.deviceRGB)
}

private extension NSColor {
    func isApproximatelyEqual(to other: NSColor, tolerance: CGFloat = 0.002) -> Bool {
        guard
            let lhs = usingColorSpace(.deviceRGB),
            let rhs = other.usingColorSpace(.deviceRGB)
        else {
            return false
        }

        return abs(lhs.redComponent - rhs.redComponent) <= tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) <= tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) <= tolerance
            && abs(lhs.alphaComponent - rhs.alphaComponent) <= tolerance
    }
}
