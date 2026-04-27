import AppKit
import QuartzCore

@MainActor
protocol ClipboardWriting: AnyObject {
    func write(string: String) -> Bool
}

@MainActor
final class GeneralClipboardWriter: ClipboardWriting {
    func write(string: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(string, forType: .string)
    }
}

@MainActor
final class InputFallbackPanelController: NSWindowController {
    private let panelWidth: CGFloat = 436
    private let collapsedHeight: CGFloat = 132
    private let expandedHeight: CGFloat = 182
    private let bottomInset: CGFloat = 44

    private let clipboardWriter: ClipboardWriting
    private let contentController = InputFallbackPanelContentViewController()
    private let autoHideDelay: Duration
    private let fadeOutDuration: TimeInterval
    private var autoHideTask: Task<Void, Never>?
    var onCopySuccess: (() -> Void)?

    init(
        clipboardWriter: ClipboardWriting? = nil,
        autoHideDelay: Duration = .seconds(5),
        fadeOutDuration: TimeInterval = 0.18,
        onCopySuccess: (() -> Void)? = nil
    ) {
        self.clipboardWriter = clipboardWriter ?? GeneralClipboardWriter()
        self.autoHideDelay = autoHideDelay
        self.fadeOutDuration = fadeOutDuration
        self.onCopySuccess = onCopySuccess

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 196),
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
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .none
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false

        super.init(window: panel)

        panel.contentViewController = contentController
        contentController.onCopyRequested = { [weak self] in
            _ = self?.performCopy()
        }
        contentController.onDismissRequested = { [weak self] in
            self?.performDismiss()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var titleText: String {
        contentController.titleText
    }

    var descriptionText: String {
        contentController.descriptionText
    }

    var displayedText: String {
        contentController.displayedText
    }

    var toggleTitle: String? {
        contentController.toggleTitle
    }

    var isExpanded: Bool {
        contentController.isExpanded
    }

    func show(payload: InputFallbackPanelPayload) {
        contentController.loadViewIfNeeded()
        contentController.setPayload(payload)
        applyCurrentFrame(animated: window?.isVisible == true)
        if RuntimeEnvironment.isRunningTests {
            autoHideTask?.cancel()
            autoHideTask = nil
            window?.orderOut(nil)
            return
        }
        scheduleAutoHide()

        guard let panel = window else { return }
        if panel.isVisible {
            panel.orderFrontRegardless()
            return
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel = window, panel.isVisible else {
            return
        }

        autoHideTask?.cancel()
        autoHideTask = nil
        panel.orderOut(nil)
    }

    func performDismiss() {
        hide()
    }

    func toggleExpansion() {
        contentController.toggleExpansion()
        applyCurrentFrame(animated: window?.isVisible == true)
        scheduleAutoHide()
    }

    @discardableResult
    func performCopy() -> Bool {
        let didCopy = clipboardWriter.write(string: contentController.copyText)
        if didCopy {
            hide()
            onCopySuccess?()
        }
        return didCopy
    }

    func applyInterfaceTheme(_ theme: InterfaceTheme) {
        window?.appearance = theme.appearance
        contentController.syncAppearance()
    }

    private func applyCurrentFrame(animated: Bool) {
        guard let panel = window else { return }

        let targetFrame = frameForCurrentScreen(height: contentController.isExpanded ? expandedHeight : collapsedHeight)
        guard animated, panel.isVisible else {
            panel.setFrame(targetFrame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.autoHideDelay)
            guard !Task.isCancelled else { return }
            self.fadeOutAndHide()
        }
    }

    private func fadeOutAndHide() {
        autoHideTask?.cancel()
        autoHideTask = nil
        guard let panel = window, panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
    }

    private func frameForCurrentScreen(height: CGFloat) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: round(visibleFrame.midX - panelWidth / 2),
            y: round(visibleFrame.minY + bottomInset),
            width: panelWidth,
            height: height
        )
    }
}

@MainActor
private final class InputFallbackPanelContentViewController: NSViewController {
    private let titleLabel = NSTextField(labelWithString: "No Input Field Detected")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "VoicePi couldn't paste automatically. Copy and paste it yourself.")
    private let transcriptLabel = NSTextField(wrappingLabelWithString: "")
    private let toggleButton = NSButton(title: "", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let dismissButton = NSButton(title: "", target: nil, action: nil)
    private let blurView = PanelSurfaceView()
    private let footerView = NSView()
    private let rootView = NSView()
    private var state: InputFallbackPanelPresentationState?
    var onCopyRequested: (() -> Void)?
    var onDismissRequested: (() -> Void)?

    override func loadView() {
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.wantsLayer = true

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer?.cornerRadius = 28
        blurView.layer?.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        descriptionLabel.maximumNumberOfLines = 1
        descriptionLabel.lineBreakMode = .byTruncatingTail

        transcriptLabel.translatesAutoresizingMaskIntoConstraints = false
        transcriptLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        transcriptLabel.maximumNumberOfLines = 0
        transcriptLabel.lineBreakMode = .byWordWrapping

        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.isBordered = false
        toggleButton.bezelStyle = .inline
        toggleButton.target = self
        toggleButton.action = #selector(togglePressed(_:))
        toggleButton.font = .systemFont(ofSize: 12.5, weight: .medium)

        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.isBordered = false
        copyButton.bezelStyle = .regularSquare
        copyButton.target = self
        copyButton.action = #selector(copyPressed(_:))
        copyButton.font = .systemFont(ofSize: 13, weight: .semibold)
        copyButton.wantsLayer = true

        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.isBordered = false
        dismissButton.bezelStyle = .regularSquare
        dismissButton.target = self
        dismissButton.action = #selector(dismissPressed(_:))
        dismissButton.image = NSImage(
            systemSymbolName: "xmark",
            accessibilityDescription: "Close"
        )
        dismissButton.imageScaling = .scaleProportionallyDown
        dismissButton.contentTintColor = .labelColor
        dismissButton.wantsLayer = true

        footerView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(blurView)
        blurView.addSubview(titleLabel)
        blurView.addSubview(dismissButton)
        blurView.addSubview(descriptionLabel)
        blurView.addSubview(transcriptLabel)
        blurView.addSubview(footerView)
        footerView.addSubview(toggleButton)
        footerView.addSubview(copyButton)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: rootView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dismissButton.leadingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: blurView.topAnchor, constant: 15),

            dismissButton.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -14),
            dismissButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 26),
            dismissButton.heightAnchor.constraint(equalToConstant: 26),

            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -18),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            transcriptLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            transcriptLabel.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -18),
            transcriptLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 10),

            footerView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 18),
            footerView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -18),
            footerView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor, constant: -12),
            footerView.heightAnchor.constraint(equalToConstant: 34),

            toggleButton.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            toggleButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),

            copyButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            copyButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            copyButton.heightAnchor.constraint(equalToConstant: 32),
            copyButton.widthAnchor.constraint(equalToConstant: 96),

            transcriptLabel.bottomAnchor.constraint(lessThanOrEqualTo: footerView.topAnchor, constant: -10)
        ])

        syncAppearance()
    }

    var titleText: String {
        titleLabel.stringValue
    }

    var descriptionText: String {
        descriptionLabel.stringValue
    }

    var displayedText: String {
        transcriptLabel.stringValue
    }

    var toggleTitle: String? {
        toggleButton.isHidden ? nil : toggleButton.title
    }

    var isExpanded: Bool {
        state?.isExpanded ?? false
    }

    var copyText: String {
        state?.copyText ?? ""
    }

    func setPayload(_ payload: InputFallbackPanelPayload) {
        state = InputFallbackPanelPresentationState(payload: payload)
        updatePresentation()
    }

    func toggleExpansion() {
        guard let state else { return }
        self.state = state.toggled()
        updatePresentation()
    }

    func syncAppearance() {
        let appearance = view.window?.effectiveAppearance ?? view.effectiveAppearance
        let palette = InputFallbackPanelPalette(appearance: appearance)
        blurView.layer?.backgroundColor = palette.backgroundColor.cgColor
        blurView.layer?.borderWidth = 1
        blurView.layer?.borderColor = palette.borderColor.cgColor
        titleLabel.textColor = palette.titleColor
        descriptionLabel.textColor = palette.secondaryTextColor
        transcriptLabel.textColor = palette.textColor
        toggleButton.contentTintColor = palette.toggleColor
        toggleButton.font = .systemFont(ofSize: 12.5, weight: .medium)
        styleCapsuleButton(
            copyButton,
            backgroundColor: palette.primaryButtonBackgroundColor,
            borderColor: palette.primaryButtonBorderColor,
            textColor: palette.primaryButtonTextColor,
            cornerRadius: 15
        )
        styleCapsuleButton(
            dismissButton,
            backgroundColor: palette.secondaryButtonBackgroundColor,
            borderColor: palette.secondaryButtonBorderColor,
            textColor: palette.secondaryButtonTextColor,
            cornerRadius: 13
        )
        dismissButton.contentTintColor = palette.secondaryButtonTextColor
    }

    @objc
    private func togglePressed(_ sender: NSButton) {
        _ = sender
        toggleExpansion()
    }

    @objc
    private func copyPressed(_ sender: NSButton) {
        _ = sender
        onCopyRequested?()
    }

    @objc
    private func dismissPressed(_ sender: NSButton) {
        _ = sender
        onDismissRequested?()
    }

    private func updatePresentation() {
        transcriptLabel.stringValue = state?.displayText ?? ""
        toggleButton.title = state?.toggleTitle ?? ""
        toggleButton.isHidden = state?.toggleTitle == nil
        transcriptLabel.maximumNumberOfLines = (state?.isExpanded ?? false) ? 4 : 1
        syncAppearance()
    }

    private func styleCapsuleButton(
        _ button: NSButton,
        backgroundColor: NSColor,
        borderColor: NSColor,
        textColor: NSColor,
        cornerRadius: CGFloat
    ) {
        button.layer?.backgroundColor = backgroundColor.cgColor
        button.layer?.borderColor = borderColor.cgColor
        button.layer?.borderWidth = 1
        button.layer?.cornerRadius = cornerRadius
        button.contentTintColor = textColor
    }
}
