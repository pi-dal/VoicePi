import AppKit
import Testing
@testable import VoicePi

struct FloatingPanelControllerTests {
    @Test
    @MainActor
    func floatingPanelUsesSettingsAlignedSurfaceInLightAppearance() {
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
        #expect(label?.textColor?.isApproximatelyEqual(to: expectedTextColor) == true)
    }

    @Test
    @MainActor
    func floatingPanelUsesSettingsAlignedSurfaceInDarkAppearance() {
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
