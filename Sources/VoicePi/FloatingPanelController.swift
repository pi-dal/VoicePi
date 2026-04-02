import AppKit
import QuartzCore

@MainActor
final class FloatingPanelController: NSWindowController {
    enum Phase {
        case recording
        case refining
    }

    private let minWidth: CGFloat = 260
    private let maxWidth: CGFloat = 660
    private let panelHeight: CGFloat = 56
    private let bottomInset: CGFloat = 44

    private let contentController = FloatingPanelContentViewController()

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false

        super.init(window: panel)

        panel.contentViewController = contentController
        contentController.widthDidChange = { [weak self] width in
            self?.animateWidth(to: width)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showRecording(transcript: String = "") {
        contentController.setPhase(.recording)
        contentController.updateTranscript(transcript)
        contentController.updateAudioLevel(0.02)
        presentIfNeeded()
    }

    func updateLive(transcript: String, level: CGFloat) {
        contentController.updateTranscript(transcript)
        contentController.updateAudioLevel(level)
    }

    func showRefining(transcript: String) {
        contentController.setPhase(.refining)
        contentController.updateTranscript(transcript)
        contentController.updateAudioLevel(0.02)
        presentIfNeeded()
    }

    func hide(completion: (() -> Void)? = nil) {
        guard let panel = window, panel.isVisible else {
            completion?()
            return
        }

        let originalFrame = panel.frame
        let scaledWidth = originalFrame.width * 0.95
        let scaledHeight = originalFrame.height * 0.95
        let targetFrame = NSRect(
            x: originalFrame.midX - scaledWidth / 2,
            y: originalFrame.midY - scaledHeight / 2,
            width: scaledWidth,
            height: scaledHeight
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.35, 0.0, 0.8, 1.0)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(targetFrame, display: true)
        } completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
            panel.setFrame(originalFrame, display: false)
            self.contentController.resetForNextSession()
            completion?()
        }
    }

    func reset() {
        contentController.resetForNextSession()
    }

    func applyInterfaceTheme(_ theme: InterfaceTheme) {
        window?.appearance = theme.appearance
    }

    private func presentIfNeeded() {
        guard let panel = window else { return }

        let width = clampedWidth(contentController.preferredPanelWidth)
        let targetFrame = frameForCurrentScreen(width: width)

        if panel.isVisible {
            panel.orderFrontRegardless()
            panel.setFrame(targetFrame, display: true)
            return
        }

        panel.alphaValue = 0
        panel.setFrame(targetFrame.insetBy(dx: -10, dy: -6), display: false)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.2, 1.0)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func animateWidth(to width: CGFloat) {
        guard let panel = window else { return }

        let targetFrame = frameForCurrentScreen(width: clampedWidth(width))

        guard panel.isVisible else {
            panel.setFrame(targetFrame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func clampedWidth(_ width: CGFloat) -> CGFloat {
        max(minWidth, min(maxWidth, width))
    }

    private func frameForCurrentScreen(width: CGFloat) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        return NSRect(
            x: round(visibleFrame.midX - width / 2),
            y: round(visibleFrame.minY + bottomInset),
            width: width,
            height: panelHeight
        )
    }
}

@MainActor
private final class FloatingPanelContentViewController: NSViewController {
    enum Phase {
        case recording
        case refining
    }

    var widthDidChange: ((CGFloat) -> Void)?

    private let rootView = AppearanceAwareView()
    private let blurView = NSVisualEffectView()
    private let stackView = NSStackView()
    private let waveformView = WaveformBarsView(frame: .zero)
    private let transcriptLabel = NSTextField(labelWithString: "")

    private(set) var preferredPanelWidth: CGFloat = 260
    private var phase: Phase = .recording

    override func loadView() {
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.onAppearanceChange = { [weak self] in
            self?.syncAppearance()
        }
        rootView.wantsLayer = true
        rootView.layer?.masksToBounds = false

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.material = .underWindowBackground
        blurView.state = .active
        blurView.blendingMode = .withinWindow
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 28
        blurView.layer?.masksToBounds = true

        transcriptLabel.translatesAutoresizingMaskIntoConstraints = false
        transcriptLabel.font = .systemFont(ofSize: 15, weight: .medium)
        transcriptLabel.textColor = NSColor.white.withAlphaComponent(0.96)
        transcriptLabel.lineBreakMode = .byTruncatingTail
        transcriptLabel.maximumNumberOfLines = 1
        transcriptLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        transcriptLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        waveformView.setContentHuggingPriority(.required, for: .horizontal)
        waveformView.setContentCompressionResistancePriority(.required, for: .horizontal)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 14
        stackView.alignment = .centerY
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)

        rootView.addSubview(blurView)
        blurView.addSubview(stackView)

        stackView.addArrangedSubview(waveformView)
        stackView.addArrangedSubview(transcriptLabel)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: rootView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: blurView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),

            waveformView.widthAnchor.constraint(equalToConstant: 44),
            waveformView.heightAnchor.constraint(equalToConstant: 32),

            rootView.heightAnchor.constraint(equalToConstant: 56)
        ])

        setPhase(.recording)
        updateTranscript("")
        waveformView.update(level: 0.02)
        syncAppearance()
    }

    func setPhase(_ phase: Phase) {
        self.phase = phase
        updateDisplayedText()
    }

    func updateTranscript(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        switch phase {
        case .recording:
            transcriptLabel.stringValue = trimmed.isEmpty ? "正在聆听…" : transcript
        case .refining:
            transcriptLabel.stringValue = "Refining..."
        }

        recalculatePreferredWidth()
    }

    func updateAudioLevel(_ level: CGFloat) {
        waveformView.update(level: level)
    }

    func resetForNextSession() {
        phase = .recording
        transcriptLabel.stringValue = ""
        waveformView.update(level: 0.02)
        recalculatePreferredWidth()
    }

    private func updateDisplayedText() {
        let currentText = transcriptLabel.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        switch phase {
        case .recording:
            transcriptLabel.stringValue = currentText.isEmpty || currentText == "Refining..." ? "正在聆听…" : currentText
        case .refining:
            transcriptLabel.stringValue = "Refining..."
        }

        recalculatePreferredWidth()
    }

    private func recalculatePreferredWidth() {
        let text = transcriptLabel.stringValue as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: transcriptLabel.font ?? NSFont.systemFont(ofSize: 15, weight: .medium)
        ]
        let measuredTextWidth = ceil(text.size(withAttributes: attributes).width)
        let elasticTextWidth = max(160, min(560, measuredTextWidth + 8))
        preferredPanelWidth = 18 + 44 + 14 + elasticTextWidth + 18
        widthDidChange?(preferredPanelWidth)
    }

    private func syncAppearance() {
        let palette = FloatingPanelPalette(appearance: view.effectiveAppearance)
        blurView.material = palette.material
        blurView.layer?.backgroundColor = palette.backgroundColor.cgColor
        blurView.layer?.borderWidth = 1
        blurView.layer?.borderColor = palette.borderColor.cgColor
        transcriptLabel.textColor = palette.textColor
        waveformView.applyAppearance(barColor: palette.waveformColor)
    }
}

private final class AppearanceAwareView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}

private final class WaveformBarsView: NSView {
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

private struct FloatingPanelPalette {
    let material: NSVisualEffectView.Material
    let backgroundColor: NSColor
    let borderColor: NSColor
    let textColor: NSColor
    let waveformColor: NSColor

    init(appearance: NSAppearance) {
        let isDarkTheme = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        material = .underWindowBackground

        if isDarkTheme {
            backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 0.96)
            borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
            textColor = NSColor.white.withAlphaComponent(0.96)
            waveformColor = NSColor.white.withAlphaComponent(0.95)
        } else {
            backgroundColor = NSColor(calibratedRed: 0xF5 / 255.0, green: 0xF3 / 255.0, blue: 0xED / 255.0, alpha: 0.96)
            borderColor = NSColor(calibratedWhite: 0.0, alpha: 0.08)
            textColor = NSColor(calibratedWhite: 0.16, alpha: 1)
            waveformColor = NSColor(calibratedWhite: 0.18, alpha: 0.92)
        }
    }
}
