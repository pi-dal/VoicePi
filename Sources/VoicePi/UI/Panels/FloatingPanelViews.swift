import AppKit
import Foundation

final class ModeSwitchCapsuleView: NSView {
    let title: String
    private(set) var isSelected = false

    private let blurView = PanelSurfaceView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private var palette: FloatingPanelPalette?

    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("voicepi-mode-capsule")
        toolTip = title
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer?.cornerRadius = 22
        blurView.layer?.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.alignment = .center

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.stringValue = switch title {
        case "Disabled": "Raw"
        case "Refinement": "Polish"
        default: "Convert"
        }
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1

        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 3

        addSubview(blurView)
        blurView.addSubview(stack)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
            heightAnchor.constraint(equalToConstant: 94),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSubtitle(_ subtitle: String) {
        subtitleLabel.stringValue = subtitle
    }

    func applyPalette(_ palette: FloatingPanelPalette) {
        self.palette = palette
        if isSelected {
            titleLabel.textColor = palette.selectedTextColor
            subtitleLabel.textColor = palette.selectedSubtextColor
            blurView.layer?.backgroundColor = palette.selectedCapsuleColor.cgColor
            blurView.layer?.borderColor = palette.selectedBorderColor.cgColor
        } else {
            titleLabel.textColor = palette.textColor.withAlphaComponent(0.82)
            subtitleLabel.textColor = palette.textColor.withAlphaComponent(0.52)
            blurView.layer?.backgroundColor = palette.unselectedCapsuleColor.cgColor
            blurView.layer?.borderColor = palette.unselectedBorderColor.cgColor
        }
        blurView.layer?.borderWidth = 1
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        isSelected = selected
        identifier = NSUserInterfaceItemIdentifier(
            selected ? "voicepi-mode-capsule-selected" : "voicepi-mode-capsule"
        )

        let scale: CGFloat = selected ? 1.0 : 0.94
        let alpha: CGFloat = selected ? 1.0 : 0.9

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.2, 1.0)
                animator().alphaValue = alpha
            }
        } else {
            alphaValue = alpha
        }

        layer?.sublayerTransform = CATransform3DMakeScale(scale, scale, 1)
        if let palette {
            applyPalette(palette)
        }
    }
}

final class AppearanceAwareView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}

final class WaveformBarsView: NSView {
    private let weights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private let barLayers: [CALayer] = (0..<5).map { _ in CALayer() }
    private let stateQueue = DispatchQueue(label: "voicepi.waveform.state")

    private var displayLink: CVDisplayLink?
    private var targetLevel: CGFloat = 0.02
    private var smoothedLevel: CGFloat = 0.02
    private var animatedHeights: [CGFloat] = Array(repeating: 6, count: 5)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        stopDisplayLink()
    }

    override var isFlipped: Bool {
        true
    }

    func update(level: CGFloat) {
        let clamped = max(0, min(1, level))
        stateQueue.async {
            self.targetLevel = clamped
        }
    }

    override func layout() {
        super.layout()
        render()
    }

    private func setup() {
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = false
        setupBars()
        startDisplayLinkIfNeeded()
    }

    private func setupBars() {
        guard let rootLayer = layer else { return }

        for bar in barLayers {
            bar.backgroundColor = NSColor.white.withAlphaComponent(0.95).cgColor
            bar.cornerRadius = 3
            bar.masksToBounds = true
            rootLayer.addSublayer(bar)
        }
    }

    func applyAppearance(barColor: NSColor) {
        for bar in barLayers {
            bar.backgroundColor = barColor.cgColor
        }
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }

        var link: CVDisplayLink?
        let status = CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard status == kCVReturnSuccess, let link else { return }

        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, context in
            guard let context else { return kCVReturnSuccess }
            let view = Unmanaged<WaveformBarsView>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                view.tick()
            }
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())

        displayLink = link
        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        guard let displayLink else { return }
        CVDisplayLinkStop(displayLink)
        self.displayLink = nil
    }

    private func tick() {
        let latestTarget = stateQueue.sync { targetLevel }
        let attack: CGFloat = 0.40
        let release: CGFloat = 0.15
        let factor = latestTarget > smoothedLevel ? attack : release
        smoothedLevel += (latestTarget - smoothedLevel) * factor
        render()
    }

    private func render() {
        let availableWidth = bounds.width
        let availableHeight = bounds.height
        guard availableWidth > 0, availableHeight > 0 else { return }

        let barWidth: CGFloat = 6
        let spacing = (availableWidth - barWidth * 5) / 4
        let minHeight: CGFloat = 6
        let maxHeight = availableHeight

        for index in 0..<barLayers.count {
            let bar = barLayers[index]
            let jitter = CGFloat.random(in: -0.04...0.04)
            let weightedLevel = max(0, min(1, smoothedLevel * weights[index] + jitter))
            let visibleLevel = max(0.10, weightedLevel)
            let targetHeight = minHeight + (maxHeight - minHeight) * visibleLevel

            animatedHeights[index] += (targetHeight - animatedHeights[index]) * 0.36
            let finalHeight = max(minHeight, min(maxHeight, animatedHeights[index]))

            let x = CGFloat(index) * (barWidth + spacing)
            let y = (availableHeight - finalHeight) / 2

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bar.frame = CGRect(x: x, y: y, width: barWidth, height: finalHeight)
            CATransaction.commit()
        }
    }
}

final class RefiningDotsView: NSView {
    private let dotLayers: [CALayer] = (0..<5).map { _ in CALayer() }
    private let animationKey = "voicepi.refiningDotsPulse"
    private var dotColor = NSColor.white.withAlphaComponent(0.95)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var isFlipped: Bool {
        true
    }

    override func layout() {
        super.layout()
        render()
    }

    func applyAppearance(dotColor: NSColor) {
        self.dotColor = dotColor
        dotLayers.forEach { $0.backgroundColor = dotColor.cgColor }
    }

    func setAnimating(_ isAnimating: Bool) {
        if isAnimating {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    private func setup() {
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = false

        for dot in dotLayers {
            dot.backgroundColor = dotColor.cgColor
            dot.masksToBounds = true
            layer?.addSublayer(dot)
        }
    }

    private func render() {
        let availableWidth = bounds.width
        let availableHeight = bounds.height
        guard availableWidth > 0, availableHeight > 0 else { return }

        let dotDiameter = min(availableHeight * 0.56, 9)
        let totalDotsWidth = dotDiameter * CGFloat(dotLayers.count)
        let spacing = max(4, (availableWidth - totalDotsWidth) / CGFloat(max(dotLayers.count - 1, 1)))
        let occupiedWidth = totalDotsWidth + spacing * CGFloat(dotLayers.count - 1)
        let originX = max(0, (availableWidth - occupiedWidth) / 2)
        let originY = (availableHeight - dotDiameter) / 2

        for (index, dot) in dotLayers.enumerated() {
            let x = originX + CGFloat(index) * (dotDiameter + spacing)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dot.frame = CGRect(x: x, y: originY, width: dotDiameter, height: dotDiameter)
            dot.cornerRadius = dotDiameter / 2
            CATransaction.commit()
        }
    }

    private func startAnimating() {
        for (index, dot) in dotLayers.enumerated() {
            guard dot.animation(forKey: animationKey) == nil else { continue }

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.78, 1.0, 0.78]
            scale.keyTimes = [0, 0.5, 1]

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.38, 1.0, 0.38]
            opacity.keyTimes = [0, 0.5, 1]

            let group = CAAnimationGroup()
            group.animations = [scale, opacity]
            group.duration = 0.92
            group.repeatCount = .infinity
            group.beginTime = CACurrentMediaTime() + Double(index) * 0.08
            group.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            group.isRemovedOnCompletion = false

            dot.add(group, forKey: animationKey)
        }
    }

    private func stopAnimating() {
        for dot in dotLayers {
            dot.removeAnimation(forKey: animationKey)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dot.opacity = 1
            dot.transform = CATransform3DIdentity
            CATransaction.commit()
        }
    }
}

struct FloatingPanelPalette {
    let backgroundColor: NSColor
    let borderColor: NSColor
    let textColor: NSColor
    let waveformColor: NSColor
    let selectedCapsuleColor: NSColor
    let selectedBorderColor: NSColor
    let unselectedCapsuleColor: NSColor
    let unselectedBorderColor: NSColor
    let selectedTextColor: NSColor
    let selectedSubtextColor: NSColor

    init(appearance: NSAppearance, phase: FloatingPanelContentViewController.Phase) {
        let themePalette = SettingsWindowTheme.palette(for: appearance)
        let pillChrome = PanelTheme.surfaceChrome(for: appearance, style: .pill)
        let borderChrome = PanelTheme.surfaceChrome(
            for: appearance,
            style: phase == .modeSwitch ? .card : .row
        )
        let primaryChrome = PanelTheme.buttonChrome(for: appearance, role: .primary)
        backgroundColor = borderChrome.background
        borderColor = borderChrome.border
        textColor = PanelTheme.titleText(for: appearance)
        waveformColor = PanelTheme.titleText(for: appearance).withAlphaComponent(0.92)
        selectedCapsuleColor = themePalette.accent.withAlphaComponent(
            SettingsWindowTheme.isDark(appearance) ? 0.30 : 0.16
        )
        selectedBorderColor = themePalette.accent.withAlphaComponent(
            SettingsWindowTheme.isDark(appearance) ? 0.42 : 0.22
        )
        unselectedCapsuleColor = pillChrome.background
        unselectedBorderColor = pillChrome.border
        selectedTextColor = primaryChrome.text
        selectedSubtextColor = primaryChrome.text.withAlphaComponent(0.78)
    }
}
