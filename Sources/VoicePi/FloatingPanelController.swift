import AppKit
import QuartzCore

@MainActor
final class FloatingPanelController: NSWindowController {
    enum Phase {
        case recording
        case refining
        case modeSwitch
    }

    private enum PresentationStyle {
        case banner
        case hud
    }

    private let minWidth: CGFloat = 260
    private let maxWidth: CGFloat = 660
    private let bottomInset: CGFloat = 44

    private let contentController = FloatingPanelContentViewController()
    private var presentationStyle: PresentationStyle = .banner
    private var autoHideTask: Task<Void, Never>?
    private(set) var isModeSwitchAutoHideScheduled = false

    init() {
        let panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: FloatingPanelSupport.compactBannerWidth,
                height: FloatingPanelSupport.compactBannerHeight
            ),
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
        contentController.panelSizeDidChange = { [weak self] width, height in
            self?.animatePanelFrame(toWidth: width, height: height)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showRecording(
        transcript: String = "",
        sourcePreviewText: String? = nil
    ) {
        contentController.loadViewIfNeeded()
        autoHideTask?.cancel()
        presentationStyle = .banner
        contentController.setPhase(.recording)
        contentController.updateTranscript(transcript)
        contentController.updateSourcePreview(sourcePreviewText)
        contentController.updateAudioLevel(0.02)
        presentIfNeeded()
    }

    func updateLive(transcript: String, level: CGFloat) {
        contentController.updateTranscript(transcript)
        contentController.updateAudioLevel(level)
    }

    func showRefining(
        transcript: String,
        sourcePreviewText: String? = nil
    ) {
        contentController.loadViewIfNeeded()
        autoHideTask?.cancel()
        presentationStyle = .banner
        contentController.setPhase(.refining)
        contentController.updateTranscript(transcript)
        contentController.updateSourcePreview(sourcePreviewText)
        contentController.updateAudioLevel(0.02)
        presentIfNeeded()
    }

    func showModeSwitch(
        modeTitle: String,
        refinementPromptTitle: String? = nil,
        autoHideDelayNanoseconds: UInt64? = 1_100_000_000
    ) {
        contentController.loadViewIfNeeded()
        autoHideTask?.cancel()
        autoHideTask = nil
        isModeSwitchAutoHideScheduled = false
        presentationStyle = .hud
        contentController.setPhase(.modeSwitch)
        contentController.updateModeSwitchTitle(modeTitle, refinementPromptTitle: refinementPromptTitle)
        presentIfNeeded()

        guard let autoHideDelayNanoseconds else {
            return
        }

        isModeSwitchAutoHideScheduled = true
        autoHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: autoHideDelayNanoseconds)
            guard let self else { return }
            self.hide()
        }
    }

    func hide(immediately: Bool = false, completion: (() -> Void)? = nil) {
        autoHideTask?.cancel()
        autoHideTask = nil
        isModeSwitchAutoHideScheduled = false
        guard let panel = window, panel.isVisible else {
            completion?()
            return
        }

        if immediately {
            panel.orderOut(nil)
            panel.alphaValue = 1
            contentController.resetForNextSession()
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
        contentController.loadViewIfNeeded()
        autoHideTask?.cancel()
        autoHideTask = nil
        isModeSwitchAutoHideScheduled = false
        contentController.resetForNextSession()
        presentationStyle = .banner
    }

    func applyInterfaceTheme(_ theme: InterfaceTheme) {
        window?.appearance = theme.appearance
    }

    private func presentIfNeeded() {
        guard let panel = window else { return }

        let width = clampedWidth(contentController.preferredPanelWidth)
        let targetFrame = frameForCurrentScreen(
            width: width,
            height: contentController.preferredPanelHeight
        )
        if RuntimeEnvironment.isRunningTests {
            panel.setFrame(targetFrame, display: false)
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }

        if panel.isVisible {
            panel.orderFrontRegardless()
            panel.setFrame(targetFrame, display: true)
            return
        }

        panel.alphaValue = 0
        panel.setFrame(targetFrame.insetBy(dx: -10, dy: -6), display: false)
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.orderFrontRegardless()
        panel.contentView?.layoutSubtreeIfNeeded()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.2, 1.0)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func animatePanelFrame(toWidth width: CGFloat, height: CGFloat) {
        guard let panel = window else { return }

        let targetFrame = frameForCurrentScreen(
            width: clampedWidth(width),
            height: height
        )

        guard panel.isVisible else {
            panel.setFrame(targetFrame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func clampedWidth(_ width: CGFloat) -> CGFloat {
        max(minWidth, min(maxWidth, width))
    }

    private func frameForCurrentScreen(width: CGFloat, height: CGFloat) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        switch presentationStyle {
        case .banner:
            return NSRect(
                x: round(visibleFrame.midX - width / 2),
                y: round(visibleFrame.minY + bottomInset),
                width: width,
                height: height
            )
        case .hud:
            return NSRect(
                x: round(visibleFrame.midX - width / 2),
                y: round(visibleFrame.midY - height / 2),
                width: width,
                height: height
            )
        }
    }
}

@MainActor
private final class FloatingPanelContentViewController: NSViewController {
    typealias Phase = FloatingPanelController.Phase

    var panelSizeDidChange: ((CGFloat, CGFloat) -> Void)?

    private let rootView = AppearanceAwareView()
    private let blurView = NSVisualEffectView()
    private let stackView = NSStackView()
    private let textStackView = NSStackView()
    private let modeSwitchContainer = NSStackView()
    private let waveformView = WaveformBarsView(frame: .zero)
    private let refiningIndicatorView = RefiningDotsView(frame: .zero)
    private let transcriptLabel = NSTextField(labelWithString: "")
    private let sourcePreviewLabel = NSTextField(labelWithString: "")
    private let modeCapsules: [ModeSwitchCapsuleView] = [
        ModeSwitchCapsuleView(title: "Disabled"),
        ModeSwitchCapsuleView(title: "Refinement"),
        ModeSwitchCapsuleView(title: "Translate")
    ]
    private let transcriptFadeMask = CAGradientLayer()
    private var heightConstraint: NSLayoutConstraint?
    private var bannerLayoutConstraints: [NSLayoutConstraint] = []
    private var modeSwitchLayoutConstraints: [NSLayoutConstraint] = []

    private(set) var preferredPanelWidth: CGFloat = FloatingPanelSupport.compactBannerWidth
    private(set) var preferredPanelHeight: CGFloat = FloatingPanelSupport.compactBannerHeight
    private var phase: Phase = .recording
    private var sourcePreview: String?
    private let compactBannerWidth: CGFloat = FloatingPanelSupport.compactBannerWidth
    private let maximumBannerWidth: CGFloat = FloatingPanelSupport.maximumBannerWidth
    private let bannerHorizontalInset: CGFloat = FloatingPanelSupport.bannerHorizontalInset
    private let bannerIndicatorWidth: CGFloat = FloatingPanelSupport.bannerIndicatorWidth
    private let recordingIndicatorSpacing: CGFloat = FloatingPanelSupport.recordingIndicatorSpacing
    private let refiningIndicatorSpacing: CGFloat = FloatingPanelSupport.refiningIndicatorSpacing
    private let transcriptFadeWidth: CGFloat = 28
    private let transcriptUpdateAnimationKey = "voicepi.transcriptUpdate"

    override func viewDidLayout() {
        super.viewDidLayout()
        updateTranscriptFadeMask()
    }

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
        transcriptLabel.lineBreakMode = .byTruncatingHead
        transcriptLabel.maximumNumberOfLines = 1
        transcriptLabel.wantsLayer = true
        transcriptLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        transcriptLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        sourcePreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        sourcePreviewLabel.font = .systemFont(ofSize: 11.5, weight: .regular)
        sourcePreviewLabel.textColor = NSColor.white.withAlphaComponent(0.62)
        sourcePreviewLabel.lineBreakMode = .byTruncatingTail
        sourcePreviewLabel.maximumNumberOfLines = 1
        sourcePreviewLabel.isHidden = true
        sourcePreviewLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        sourcePreviewLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        textStackView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.orientation = .vertical
        textStackView.spacing = 1
        textStackView.alignment = .leading
        textStackView.detachesHiddenViews = true
        textStackView.addArrangedSubview(transcriptLabel)
        textStackView.addArrangedSubview(sourcePreviewLabel)

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        waveformView.identifier = NSUserInterfaceItemIdentifier("voicepi-recording-waveform")
        waveformView.setContentHuggingPriority(.required, for: .horizontal)
        waveformView.setContentCompressionResistancePriority(.required, for: .horizontal)

        refiningIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        refiningIndicatorView.identifier = NSUserInterfaceItemIdentifier("voicepi-refining-indicator")
        refiningIndicatorView.isHidden = true
        refiningIndicatorView.setContentHuggingPriority(.required, for: .horizontal)
        refiningIndicatorView.setContentCompressionResistancePriority(.required, for: .horizontal)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = recordingIndicatorSpacing
        stackView.alignment = .centerY
        stackView.detachesHiddenViews = true
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)

        modeSwitchContainer.translatesAutoresizingMaskIntoConstraints = false
        modeSwitchContainer.orientation = .horizontal
        modeSwitchContainer.spacing = 12
        modeSwitchContainer.alignment = .centerY
        modeSwitchContainer.distribution = .fillEqually
        modeSwitchContainer.detachesHiddenViews = true
        modeSwitchContainer.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        modeSwitchContainer.isHidden = true

        rootView.addSubview(blurView)
        blurView.addSubview(stackView)
        blurView.addSubview(modeSwitchContainer)

        stackView.addArrangedSubview(waveformView)
        stackView.addArrangedSubview(refiningIndicatorView)
        stackView.addArrangedSubview(textStackView)
        stackView.setCustomSpacing(recordingIndicatorSpacing, after: waveformView)
        stackView.setCustomSpacing(refiningIndicatorSpacing, after: refiningIndicatorView)
        modeCapsules.forEach(modeSwitchContainer.addArrangedSubview)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: rootView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            waveformView.widthAnchor.constraint(equalToConstant: 44),
            waveformView.heightAnchor.constraint(equalToConstant: 32),
            refiningIndicatorView.widthAnchor.constraint(equalToConstant: 44),
            refiningIndicatorView.heightAnchor.constraint(equalToConstant: 32),
        ])
        bannerLayoutConstraints = [
            stackView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: blurView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor)
        ]
        modeSwitchLayoutConstraints = [
            modeSwitchContainer.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            modeSwitchContainer.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
            modeSwitchContainer.topAnchor.constraint(equalTo: blurView.topAnchor),
            modeSwitchContainer.bottomAnchor.constraint(equalTo: blurView.bottomAnchor)
        ]
        NSLayoutConstraint.activate(bannerLayoutConstraints)

        let heightConstraint = rootView.heightAnchor.constraint(equalToConstant: FloatingPanelSupport.compactBannerHeight)
        heightConstraint.isActive = true
        self.heightConstraint = heightConstraint

        setPhase(.recording)
        updateTranscript("")
        waveformView.update(level: 0.02)
        syncAppearance()
    }

    func setPhase(_ phase: Phase) {
        self.phase = phase
        waveformView.isHidden = phase != .recording
        refiningIndicatorView.isHidden = phase != .refining
        refiningIndicatorView.setAnimating(phase == .refining)
        applyLayout(for: phase)
        stackView.isHidden = phase == .modeSwitch
        modeSwitchContainer.isHidden = phase != .modeSwitch
        transcriptLabel.alignment = .left
        updateDisplayedText()
    }

    func updateTranscript(_ transcript: String) {
        let nextText = FloatingPanelSupport.displayedTranscript(for: phase, transcript: transcript)
        setTranscriptText(nextText, animated: shouldAnimateTranscriptUpdate(to: nextText))
        recalculatePreferredWidth()
    }

    func updateModeSwitchTitle(_ title: String, refinementPromptTitle: String? = nil) {
        updateModeSelection(title, refinementPromptTitle: refinementPromptTitle)
        recalculatePreferredWidth()
    }

    func updateSourcePreview(_ sourcePreview: String?) {
        self.sourcePreview = sourcePreview?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayedPreview = FloatingPanelSupport.displayedSourcePreview(self.sourcePreview)
        sourcePreviewLabel.stringValue = displayedPreview ?? ""
        sourcePreviewLabel.isHidden = displayedPreview == nil
        recalculatePreferredWidth()
    }

    func updateAudioLevel(_ level: CGFloat) {
        waveformView.update(level: level)
    }

    func resetForNextSession() {
        phase = .recording
        sourcePreview = nil
        transcriptLabel.stringValue = ""
        sourcePreviewLabel.stringValue = ""
        sourcePreviewLabel.isHidden = true
        waveformView.isHidden = false
        refiningIndicatorView.isHidden = true
        refiningIndicatorView.setAnimating(false)
        waveformView.update(level: 0.02)
        updateTranscriptFadeMask()
        recalculatePreferredWidth()
    }

    private func updateDisplayedText() {
        let currentText = transcriptLabel.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        switch phase {
        case .recording:
            setTranscriptText(
                currentText.isEmpty || Self.isRefiningPlaceholder(currentText)
                    ? FloatingPanelSupport.displayedTranscript(for: .recording, transcript: "")
                    : currentText,
                animated: false
            )
        case .refining:
            setTranscriptText(
                currentText.isEmpty
                    ? FloatingPanelSupport.displayedTranscript(for: .refining, transcript: "")
                    : currentText,
                animated: false
            )
        case .modeSwitch:
            updateModeSelection(currentText.isEmpty ? "Disabled" : currentText, refinementPromptTitle: nil)
        }

        recalculatePreferredWidth()
    }

    private func updateModeSelection(_ title: String, refinementPromptTitle: String?) {
        modeCapsules.forEach { capsule in
            if capsule.title == PostProcessingMode.refinement.title {
                capsule.setSubtitle(refinementPromptTitle ?? "Polish")
            }
            capsule.setSelected(capsule.title == title, animated: view.window?.isVisible == true)
        }
    }

    private func setTranscriptText(_ text: String, animated: Bool) {
        guard transcriptLabel.stringValue != text else {
            updateTranscriptFadeMask()
            return
        }

        if animated {
            animateTranscriptUpdate()
        }

        transcriptLabel.stringValue = text
        updateTranscriptFadeMask()
    }

    private static func isRefiningPlaceholder(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "Refining..." || trimmed.hasPrefix("Refining with ")
    }

    private func recalculatePreferredWidth() {
        switch phase {
        case .recording:
            preferredPanelWidth = bannerPreferredWidth()
            preferredPanelHeight = FloatingPanelSupport.bannerPreferredHeight(sourcePreview: sourcePreview)
            heightConstraint?.constant = preferredPanelHeight
        case .refining:
            preferredPanelWidth = bannerPreferredWidth()
            preferredPanelHeight = FloatingPanelSupport.bannerPreferredHeight(sourcePreview: sourcePreview)
            heightConstraint?.constant = preferredPanelHeight
        case .modeSwitch:
            preferredPanelWidth = 452
            preferredPanelHeight = 136
            heightConstraint?.constant = preferredPanelHeight
        }
        panelSizeDidChange?(preferredPanelWidth, preferredPanelHeight)
    }

    private func applyLayout(for phase: Phase) {
        if phase == .modeSwitch {
            NSLayoutConstraint.deactivate(bannerLayoutConstraints)
            NSLayoutConstraint.activate(modeSwitchLayoutConstraints)
        } else {
            NSLayoutConstraint.deactivate(modeSwitchLayoutConstraints)
            NSLayoutConstraint.activate(bannerLayoutConstraints)
        }
    }

    private func shouldAnimateTranscriptUpdate(to text: String) -> Bool {
        phase == .recording && transcriptNeedsFade(for: text)
    }

    private func animateTranscriptUpdate() {
        guard view.window?.isVisible == true, let layer = transcriptLabel.layer else { return }

        layer.removeAnimation(forKey: transcriptUpdateAnimationKey)

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.78
        opacity.toValue = 1

        let translation = CABasicAnimation(keyPath: "transform.translation.x")
        translation.fromValue = 5
        translation.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [opacity, translation]
        group.duration = 0.14
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)

        layer.add(group, forKey: transcriptUpdateAnimationKey)
    }

    private func updateTranscriptFadeMask() {
        guard let layer = transcriptLabel.layer else { return }

        let bounds = transcriptLabel.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard transcriptNeedsFade() else {
            layer.mask = nil
            return
        }

        let fadeFraction = max(0.08, min(0.22, transcriptFadeWidth / bounds.width))
        transcriptFadeMask.frame = bounds
        transcriptFadeMask.startPoint = CGPoint(x: 0, y: 0.5)
        transcriptFadeMask.endPoint = CGPoint(x: 1, y: 0.5)
        transcriptFadeMask.colors = [
            NSColor.clear.cgColor,
            NSColor.white.cgColor,
            NSColor.white.cgColor
        ]
        transcriptFadeMask.locations = [0, NSNumber(value: Double(fadeFraction)), 1]
        layer.mask = transcriptFadeMask
    }

    private func transcriptNeedsFade(for text: String? = nil) -> Bool {
        measuredTranscriptWidth(for: text) > maximumVisibleTranscriptWidth(for: phase)
    }

    private func bannerPreferredWidth() -> CGFloat {
        let transcript = transcriptLabel.stringValue
        guard !transcript.isEmpty else {
            return FloatingPanelSupport.bannerPreferredWidth(
                for: phase,
                transcript: FloatingPanelSupport.displayedTranscript(for: phase, transcript: transcript),
                sourcePreview: sourcePreview,
                font: transcriptLabel.font ?? .systemFont(ofSize: 15, weight: .medium)
            )
        }

        return FloatingPanelSupport.bannerPreferredWidth(
            for: phase,
            transcript: transcript,
            sourcePreview: sourcePreview,
            font: transcriptLabel.font ?? .systemFont(ofSize: 15, weight: .medium)
        )
    }

    private func maximumVisibleTranscriptWidth(for phase: Phase) -> CGFloat {
        FloatingPanelSupport.maximumVisibleTranscriptWidth(for: phase)
    }

    private func measuredTranscriptWidth(for text: String? = nil) -> CGFloat {
        FloatingPanelSupport.measuredTranscriptWidth(
            for: text ?? transcriptLabel.stringValue,
            font: transcriptLabel.font ?? .systemFont(ofSize: 15, weight: .medium)
        )
    }

    private func syncAppearance() {
        let palette = FloatingPanelPalette(appearance: view.effectiveAppearance, phase: phase)
        blurView.material = palette.material
        blurView.layer?.backgroundColor = palette.backgroundColor.cgColor
        blurView.layer?.borderWidth = 1
        blurView.layer?.borderColor = palette.borderColor.cgColor
        transcriptLabel.textColor = palette.textColor
        sourcePreviewLabel.textColor = palette.textColor.withAlphaComponent(0.62)
        waveformView.applyAppearance(barColor: palette.waveformColor)
        refiningIndicatorView.applyAppearance(dotColor: palette.waveformColor)
        modeCapsules.forEach { $0.applyPalette(palette) }
    }
}

final class ModeSwitchCapsuleView: NSView {
    let title: String
    private(set) var isSelected = false

    private let blurView = NSVisualEffectView()
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
        blurView.material = .hudWindow
        blurView.blendingMode = .withinWindow
        blurView.state = .active
        blurView.wantsLayer = true
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

    fileprivate func applyPalette(_ palette: FloatingPanelPalette) {
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

private final class RefiningDotsView: NSView {
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

private struct FloatingPanelPalette {
    let material: NSVisualEffectView.Material
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
        let isDarkTheme = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        material = phase == .modeSwitch ? .hudWindow : .underWindowBackground

        if isDarkTheme {
            backgroundColor = phase == .modeSwitch
                ? NSColor(calibratedWhite: 0.11, alpha: 0.78)
                : NSColor(calibratedWhite: 0.16, alpha: 0.96)
            borderColor = phase == .modeSwitch
                ? NSColor(calibratedWhite: 1.0, alpha: 0.12)
                : NSColor(calibratedWhite: 1.0, alpha: 0.08)
            textColor = NSColor.white.withAlphaComponent(0.96)
            waveformColor = NSColor.white.withAlphaComponent(0.95)
            selectedCapsuleColor = NSColor(calibratedWhite: 1.0, alpha: 0.20)
            selectedBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.18)
            unselectedCapsuleColor = NSColor(calibratedWhite: 1.0, alpha: 0.06)
            unselectedBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
            selectedTextColor = NSColor.white.withAlphaComponent(0.98)
            selectedSubtextColor = NSColor.white.withAlphaComponent(0.72)
        } else {
            backgroundColor = phase == .modeSwitch
                ? NSColor(calibratedRed: 0xF1 / 255.0, green: 0xF0 / 255.0, blue: 0xEB / 255.0, alpha: 0.78)
                : NSColor(calibratedRed: 0xF5 / 255.0, green: 0xF3 / 255.0, blue: 0xED / 255.0, alpha: 0.96)
            borderColor = phase == .modeSwitch
                ? NSColor(calibratedWhite: 0.0, alpha: 0.10)
                : NSColor(calibratedWhite: 0.0, alpha: 0.08)
            textColor = NSColor(calibratedWhite: 0.16, alpha: 1)
            waveformColor = NSColor(calibratedWhite: 0.18, alpha: 0.92)
            selectedCapsuleColor = NSColor(calibratedWhite: 1.0, alpha: 0.42)
            selectedBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.58)
            unselectedCapsuleColor = NSColor(calibratedWhite: 1.0, alpha: 0.16)
            unselectedBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.28)
            selectedTextColor = NSColor(calibratedWhite: 0.10, alpha: 1)
            selectedSubtextColor = NSColor(calibratedWhite: 0.16, alpha: 0.72)
        }
    }
}
