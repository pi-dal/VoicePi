import AppKit
import Testing
@testable import VoicePi

struct FloatingPanelControllerTests {
    @Test
    @MainActor
    func floatingPanelUsesMainSurfaceInLightAppearance() {
        let controller = FloatingPanelController()
        controller.window?.appearance = NSAppearance(named: .aqua)

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let blurView = findSubview(in: window?.contentView, ofType: NSVisualEffectView.self)
        let label = findLabel(in: window?.contentView)
        let expectedBackground = NSColor(
            calibratedRed: 0xF5 / 255.0,
            green: 0xF3 / 255.0,
            blue: 0xED / 255.0,
            alpha: 0.96
        )
        let expectedTextColor = NSColor(calibratedWhite: 0.16, alpha: 1)

        #expect(blurView?.material == .underWindowBackground)
        #expect(color(from: blurView?.layer?.backgroundColor)?.isApproximatelyEqual(to: expectedBackground) == true)
        #expect(blurView?.layer?.borderWidth == 1)
        #expect(label?.textColor?.isApproximatelyEqual(to: expectedTextColor) == true)
    }

    @Test
    @MainActor
    func floatingPanelUsesMainSurfaceInDarkAppearance() {
        let controller = FloatingPanelController()
        controller.window?.appearance = NSAppearance(named: .darkAqua)

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let blurView = findSubview(in: window?.contentView, ofType: NSVisualEffectView.self)
        let label = findLabel(in: window?.contentView)
        let expectedBackground = NSColor(calibratedWhite: 0.16, alpha: 0.96)
        let expectedTextColor = NSColor.white.withAlphaComponent(0.96)

        #expect(blurView?.material == .underWindowBackground)
        #expect(color(from: blurView?.layer?.backgroundColor)?.isApproximatelyEqual(to: expectedBackground) == true)
        #expect(blurView?.layer?.borderWidth == 1)
        #expect(label?.textColor?.isApproximatelyEqual(to: expectedTextColor) == true)
    }

    @Test
    @MainActor
    func floatingPanelTransitionsFromListeningPlaceholderToReadableTranscriptInLightAppearance() {
        let controller = FloatingPanelController()
        controller.window?.appearance = NSAppearance(named: .aqua)
        controller.showRecording(transcript: "")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        controller.updateLive(transcript: "Hello from VoicePi", level: 0.25)

        let label = findLabel(in: window?.contentView)
        let expectedTextColor = NSColor(calibratedWhite: 0.16, alpha: 1)

        #expect(label?.stringValue == "Hello from VoicePi")
        #expect(label?.textColor?.isApproximatelyEqual(to: expectedTextColor) == true)
    }

    @Test
    @MainActor
    func floatingPanelAppliesRequestedInterfaceThemeToWindow() {
        let controller = FloatingPanelController()

        controller.applyInterfaceTheme(.light)
        #expect(controller.window?.appearance?.bestMatch(from: [.aqua, .darkAqua]) == .aqua)

        controller.applyInterfaceTheme(.dark)
        #expect(controller.window?.appearance?.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)

        controller.applyInterfaceTheme(.system)
        #expect(controller.window?.appearance == nil)
    }

    @Test
    @MainActor
    func floatingPanelKeepsNewestTranscriptCharactersVisibleWhenWidthCaps() {
        let controller = FloatingPanelController()

        let window = controller.window
        _ = window?.contentViewController?.view
        let label = findLabel(in: window?.contentView)

        #expect(label?.maximumNumberOfLines == 1)
        #expect(label?.lineBreakMode == .byTruncatingHead)
    }

    @Test
    @MainActor
    func floatingPanelSoftensTheDisappearingLeadingEdge() {
        let controller = FloatingPanelController()

        controller.showRecording(transcript: String(repeating: "Long transcript ", count: 32))

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let label = findLabel(in: window?.contentView)
        let mask = label?.layer?.mask as? CAGradientLayer
        let locations = mask?.locations as? [NSNumber]

        #expect(mask != nil)
        #expect(locations?.count == 3)
        #expect(locations?[0].doubleValue == 0)
    }

    @Test
    @MainActor
    func floatingPanelDoesNotFadeWhenTranscriptFitsWithinAvailableWidth() {
        let controller = FloatingPanelController()

        controller.showRefining(transcript: "Short")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let label = findLabel(in: window?.contentView)
        let mask = label?.layer?.mask as? CAGradientLayer

        #expect(label?.stringValue == "Refining...")
        #expect(mask == nil)
    }

    @Test
    @MainActor
    func floatingPanelDoesNotAnimateShortLiveTranscriptUpdates() {
        let controller = FloatingPanelController()

        controller.showRecording(transcript: "")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        controller.updateLive(transcript: "Hello", level: 0.25)

        let label = findLabel(in: window?.contentView)
        let animationKeys = label?.layer?.animationKeys() ?? []

        #expect(label?.stringValue == "Hello")
        #expect(animationKeys.contains("voicepi.transcriptUpdate") == false)
    }

    @Test
    @MainActor
    func recordingBannerRestoresBannerPaletteAfterModeSwitchHud() {
        let controller = FloatingPanelController()
        controller.window?.appearance = NSAppearance(named: .darkAqua)

        controller.showModeSwitch(modeTitle: "Refinement", refinementPromptTitle: "Meeting Notes")
        controller.showRecording(transcript: "")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let blurView = findSubview(in: window?.contentView, ofType: NSVisualEffectView.self)
        let expectedBackground = NSColor(calibratedWhite: 0.16, alpha: 0.96)

        #expect(blurView?.material == .underWindowBackground)
        #expect(color(from: blurView?.layer?.backgroundColor)?.isApproximatelyEqual(to: expectedBackground) == true)
        #expect(window?.frame.height == 56)
    }

    @Test
    @MainActor
    func listeningPlaceholderKeepsCompactBannerWidth() {
        let controller = FloatingPanelController()

        // First call makes window visible with entrance animation
        controller.showRecording(transcript: "Test")
        // Second call sets frame directly since window is already visible
        controller.showRecording(transcript: "")

        let width = controller.window?.frame.width ?? 0

        #expect(width == 260)
    }

    @Test
    @MainActor
    func refiningBannerReturnsToCompactBaselineWidthAfterLongTranscript() {
        let controller = FloatingPanelController()

        controller.showRecording(transcript: String(repeating: "Long transcript ", count: 18))
        let widthBeforeRefining = controller.window?.frame.width ?? 0

        controller.showRefining(transcript: "Long transcript")
        let widthDuringRefiningTransition = controller.window?.frame.width ?? 0

        #expect(widthBeforeRefining > 320)
        #expect(widthDuringRefiningTransition == 260)
    }

    @Test
    @MainActor
    func bannerAndRefiningWidthsStayCompactAfterModeSwitchHudWasShown() {
        let controller = FloatingPanelController()

        controller.showModeSwitch(
            modeTitle: "Refinement",
            refinementPromptTitle: String(repeating: "Long Prompt ", count: 8),
            autoHideDelayNanoseconds: nil
        )
        controller.showRecording(transcript: "")
        let recordingWidth = controller.window?.frame.width ?? 0

        controller.showRefining(transcript: "Long transcript")
        let refiningWidth = controller.window?.frame.width ?? 0

        #expect(recordingWidth == 260)
        #expect(refiningWidth == 260)
    }

    @Test
    @MainActor
    func refiningBannerUsesCircularActivityDotsInsteadOfRecordingWaveform() {
        let controller = FloatingPanelController()

        controller.showRefining(transcript: "Long transcript")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let refiningIndicator = findViews(
            in: window?.contentView,
            matchingIdentifier: "voicepi-refining-indicator"
        ).first
        let recordingWaveform = findViews(
            in: window?.contentView,
            matchingIdentifier: "voicepi-recording-waveform"
        ).first
        let indicatorDots = refiningIndicator?.layer?.sublayers ?? []

        #expect(refiningIndicator?.isHidden == false)
        #expect(recordingWaveform?.isHidden == true)
        #expect(indicatorDots.count == 5)
        #expect(indicatorDots.allSatisfy { abs($0.cornerRadius - ($0.bounds.height / 2)) < 0.5 })
    }

    @Test
    @MainActor
    func refiningBannerKeepsComfortableGapBetweenIndicatorAndText() {
        let controller = FloatingPanelController()
        controller.showRefining(transcript: "Long transcript")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let contentView = window?.contentView
        let refiningIndicator = findViews(
            in: contentView,
            matchingIdentifier: "voicepi-refining-indicator"
        ).first
        let label = findLabel(in: contentView)

        if let contentView, let refiningIndicator, let label {
            let indicatorFrame = refiningIndicator.convert(refiningIndicator.bounds, to: contentView)
            let labelFrame = label.convert(label.bounds, to: contentView)
            #expect(labelFrame.minX - indicatorFrame.maxX >= 18)
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    @MainActor
    func floatingPanelShowsModeSwitchHudCenteredOnScreen() {
        let controller = FloatingPanelController()
        controller.showModeSwitch(modeTitle: "Translate")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let modeLabels = findLabels(
            in: window?.contentView,
            matching: ["Disabled", "Refinement", "Translate"]
        )
        let visibleFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame

        #expect(modeLabels.count >= 1)
        #expect(window?.isVisible == true)

        if let window, let visibleFrame {
            #expect(abs(window.frame.midY - visibleFrame.midY) < 40)
        }
    }

    @Test
    @MainActor
    func floatingPanelShowsAllModeOptionsInModeSwitchHud() {
        let controller = FloatingPanelController()
        controller.showModeSwitch(modeTitle: "Translate")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let modeLabels = findLabels(
            in: window?.contentView,
            matching: ["Disabled", "Refinement", "Translate"]
        )
        let capsuleViews = findViews(in: window?.contentView, matchingIdentifier: "voicepi-mode-capsule")
            + findViews(in: window?.contentView, matchingIdentifier: "voicepi-mode-capsule-selected")

        #expect(modeLabels.count == 3)
        #expect(capsuleViews.count == 3)
        #expect(window?.frame.height == 136)
    }

    @Test
    @MainActor
    func modeSwitchHudHighlightsOnlyTheActiveMode() {
        let controller = FloatingPanelController()
        controller.showModeSwitch(modeTitle: "Refinement")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let selectedCapsules = findViews(
            in: window?.contentView,
            matchingIdentifier: "voicepi-mode-capsule-selected"
        )

        #expect(selectedCapsules.count == 1)
        #expect(selectedCapsules.first?.toolTip == "Refinement")
    }

    @Test
    @MainActor
    func refinementModeSwitchShowsPromptNameInRefinementSubtitle() {
        let controller = FloatingPanelController()
        controller.showModeSwitch(modeTitle: "Refinement", refinementPromptTitle: "Meeting Notes")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let promptLabels = findLabels(in: window?.contentView, matching: ["Meeting Notes"])
        let selectedCapsules = findViews(
            in: window?.contentView,
            matchingIdentifier: "voicepi-mode-capsule-selected"
        )

        #expect(promptLabels.count == 1)
        #expect(selectedCapsules.count == 1)
        #expect(selectedCapsules.first?.toolTip == "Refinement")
    }

    @Test
    @MainActor
    func modeSwitchHudUsesWideCapsuleGridLayout() {
        let controller = FloatingPanelController()
        controller.showModeSwitch(modeTitle: "Translate")

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        #expect((window?.frame.width ?? 0) >= 440)
        #expect(window?.frame.height == 136)
    }

    @Test
    @MainActor
    func refinementModeSwitchAcceptsLongPromptNamesInSubtitle() {
        let controller = FloatingPanelController()
        controller.showModeSwitch(
            modeTitle: "Refinement",
            refinementPromptTitle: "Detailed Meeting Notes For Product Planning"
        )

        let window = controller.window
        _ = window?.contentViewController?.view
        window?.contentView?.layoutSubtreeIfNeeded()

        let promptLabel = findLabels(
            in: window?.contentView,
            matching: ["Detailed Meeting Notes For Product Planning"]
        )

        #expect(promptLabel.count == 1)
        #expect((window?.frame.width ?? 0) >= 440)
    }

    @Test
    @MainActor
    func modeSwitchHudUsesDifferentPlacementThanRecordingOverlay() {
        let controller = FloatingPanelController()

        controller.showModeSwitch(modeTitle: "Refinement")
        let hudMidY = controller.window?.frame.midY

        controller.showRecording(transcript: "")
        let recordingMidY = controller.window?.frame.midY

        if let hudMidY, let recordingMidY {
            #expect(hudMidY > recordingMidY + 100)
        }
    }

    @Test
    @MainActor
    func modeSwitchHudCanRemainVisibleWithoutSchedulingAutoHide() {
        let controller = FloatingPanelController()

        controller.showModeSwitch(modeTitle: "Translate", autoHideDelayNanoseconds: nil)

        #expect(controller.isModeSwitchAutoHideScheduled == false)
        #expect(controller.window?.isVisible == true)
    }
}

private func findSubview<T: NSView>(in root: NSView?, ofType type: T.Type) -> T? {
    guard let root else { return nil }
    if let typed = root as? T {
        return typed
    }

    for subview in root.subviews {
        if let match = findSubview(in: subview, ofType: type) {
            return match
        }
    }

    return nil
}

private func findLabel(in root: NSView?) -> NSTextField? {
    guard let root else { return nil }
    if let label = root as? NSTextField,
       !label.isEditable,
       label.font?.pointSize == 15 {
        return label
    }

    for subview in root.subviews {
        if let match = findLabel(in: subview) {
            return match
        }
    }

    return nil
}

private func findLabels(in root: NSView?, matching texts: Set<String>) -> [NSTextField] {
    guard let root else { return [] }

    var matches: [NSTextField] = []
    if let label = root as? NSTextField, texts.contains(label.stringValue) {
        matches.append(label)
    }

    for subview in root.subviews {
        matches.append(contentsOf: findLabels(in: subview, matching: texts))
    }

    return matches
}

private func findViews(in root: NSView?, matchingIdentifier identifier: String) -> [NSView] {
    guard let root else { return [] }

    var matches: [NSView] = []
    if root.identifier?.rawValue == identifier {
        matches.append(root)
    }

    for subview in root.subviews {
        matches.append(contentsOf: findViews(in: subview, matchingIdentifier: identifier))
    }

    return matches
}

private func color(from cgColor: CGColor?) -> NSColor? {
    guard let cgColor else { return nil }
    return NSColor(cgColor: cgColor)
}

private extension NSColor {
    func isApproximatelyEqual(to other: NSColor, tolerance: CGFloat = 0.002) -> Bool {
        guard let lhs = usingColorSpace(.deviceRGB),
              let rhs = other.usingColorSpace(.deviceRGB) else {
            return false
        }

        return abs(lhs.redComponent - rhs.redComponent) <= tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) <= tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) <= tolerance
            && abs(lhs.alphaComponent - rhs.alphaComponent) <= tolerance
    }
}
