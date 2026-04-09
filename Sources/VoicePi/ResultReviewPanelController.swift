import AppKit
import QuartzCore

private final class ResultReviewPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class ResultReviewPanelController: NSWindowController {
    private let clipboardWriter: ClipboardWriting
    private let contentController = ResultReviewPanelContentViewController()

    var onInsertRequested: ((String) -> Void)?
    var onCopyRequested: ((String) -> Void)?
    var onRetryRequested: (() -> Void)?
    var onDismissRequested: (() -> Void)?

    init(clipboardWriter: ClipboardWriting? = nil) {
        self.clipboardWriter = clipboardWriter ?? GeneralClipboardWriter()

        let initialFrame = ResultReviewPanelLayout.frame(
            for: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        )
        let panel = ResultReviewPanelWindow(
            contentRect: initialFrame,
            styleMask: [.borderless],
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
        contentController.onInsertRequested = { [weak self] in
            self?.performInsert()
        }
        contentController.onCopyRequested = { [weak self] in
            _ = self?.performCopy()
        }
        contentController.onRetryRequested = { [weak self] in
            self?.performRetry()
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

    var insertButtonTitle: String {
        contentController.insertButtonTitle
    }

    var copyButtonTitle: String {
        contentController.copyButtonTitle
    }

    var retryButtonTitle: String {
        contentController.retryButtonTitle
    }

    var dismissButtonTitle: String {
        contentController.dismissButtonTitle
    }

    func show(payload: ResultReviewPanelPayload) {
        contentController.loadViewIfNeeded()
        contentController.setPayload(payload)
        applyCurrentFrame(animated: window?.isVisible == true)

        guard let panel = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        if panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

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

        panel.orderOut(nil)
    }

    func performInsert() {
        onInsertRequested?(contentController.displayedText)
    }

    @discardableResult
    func performCopy() -> Bool {
        let didCopy = clipboardWriter.write(string: contentController.displayedText)
        if didCopy {
            onCopyRequested?(contentController.displayedText)
        }
        return didCopy
    }

    func performRetry() {
        onRetryRequested?()
    }

    func performDismiss() {
        hide()
        onDismissRequested?()
    }

    func applyInterfaceTheme(_ theme: InterfaceTheme) {
        window?.appearance = theme.appearance
        contentController.syncAppearance()
    }

    private func applyCurrentFrame(animated: Bool) {
        guard let panel = window else { return }

        let targetFrame = frameForCurrentScreen()
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

    private func frameForCurrentScreen() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return ResultReviewPanelLayout.frame(for: visibleFrame)
    }
}

@MainActor
private final class ResultReviewPanelContentViewController: NSViewController {
    private let rootView = NSView()
    private let cardView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "")
    private let transcriptScrollView = NSScrollView()
    private let transcriptView = NSTextView()
    private let footerView = NSStackView()
    private let insertButton = NSButton(title: "", target: nil, action: nil)
    private let copyButton = NSButton(title: "", target: nil, action: nil)
    private let retryButton = NSButton(title: "", target: nil, action: nil)
    private let dismissButton = NSButton(title: "", target: nil, action: nil)
    private var state: ResultReviewPanelPresentationState?

    var onInsertRequested: (() -> Void)?
    var onCopyRequested: (() -> Void)?
    var onRetryRequested: (() -> Void)?
    var onDismissRequested: (() -> Void)?

    override func loadView() {
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = 28
        rootView.layer?.masksToBounds = true

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.material = .underWindowBackground
        cardView.blendingMode = .withinWindow
        cardView.state = .active
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 28
        cardView.layer?.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.maximumNumberOfLines = 1

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        descriptionLabel.maximumNumberOfLines = 2
        descriptionLabel.lineBreakMode = .byWordWrapping

        transcriptScrollView.translatesAutoresizingMaskIntoConstraints = false
        transcriptScrollView.hasVerticalScroller = true
        transcriptScrollView.drawsBackground = false
        transcriptScrollView.borderType = .noBorder
        transcriptScrollView.autohidesScrollers = true

        transcriptView.isEditable = false
        transcriptView.isSelectable = true
        transcriptView.isVerticallyResizable = true
        transcriptView.isHorizontallyResizable = false
        transcriptView.drawsBackground = false
        transcriptView.textContainerInset = NSSize(width: 2, height: 4)
        transcriptView.textContainer?.lineFragmentPadding = 0
        transcriptView.font = .systemFont(ofSize: 14, weight: .regular)

        transcriptScrollView.documentView = transcriptView

        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.orientation = .horizontal
        footerView.alignment = .centerY
        footerView.distribution = .fillProportionally
        footerView.spacing = 10

        configureButton(insertButton, action: #selector(insertPressed))
        configureButton(copyButton, action: #selector(copyPressed))
        configureButton(retryButton, action: #selector(retryPressed))
        configureButton(dismissButton, action: #selector(dismissPressed))
        insertButton.keyEquivalent = "\r"
        dismissButton.keyEquivalent = "\u{1B}"

        footerView.addArrangedSubview(insertButton)
        footerView.addArrangedSubview(copyButton)
        footerView.addArrangedSubview(retryButton)
        footerView.addArrangedSubview(NSView())
        footerView.addArrangedSubview(dismissButton)

        let contentStack = NSStackView(views: [titleLabel, descriptionLabel, transcriptScrollView, footerView])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.distribution = .fill
        contentStack.spacing = 12

        rootView.addSubview(cardView)
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: rootView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24),

            transcriptScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            footerView.widthAnchor.constraint(equalTo: contentStack.widthAnchor)
        ])

        setPayload(ResultReviewPanelPayload(text: "Preview")!)
    }

    func setPayload(_ payload: ResultReviewPanelPayload) {
        state = ResultReviewPanelPresentationState(payload: payload)
        syncState()
    }

    func syncAppearance() {
        guard let appearance = view.window?.appearance else { return }
        cardView.appearance = appearance
    }

    var titleText: String {
        state?.titleText ?? "Review Result"
    }

    var descriptionText: String {
        state?.descriptionText ?? "Review the output before inserting it back into the target."
    }

    var displayedText: String {
        state?.displayText ?? ""
    }

    var insertButtonTitle: String {
        state?.insertButtonTitle ?? "Insert"
    }

    var copyButtonTitle: String {
        state?.copyButtonTitle ?? "Copy"
    }

    var retryButtonTitle: String {
        state?.retryButtonTitle ?? "Retry"
    }

    var dismissButtonTitle: String {
        state?.dismissButtonTitle ?? "Dismiss"
    }

    private func syncState() {
        guard let state else { return }
        titleLabel.stringValue = state.titleText
        descriptionLabel.stringValue = state.descriptionText
        transcriptView.string = state.displayText
        insertButton.title = state.insertButtonTitle
        copyButton.title = state.copyButtonTitle
        retryButton.title = state.retryButtonTitle
        dismissButton.title = state.dismissButtonTitle
    }

    private func configureButton(_ button: NSButton, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.controlSize = .regular
    }

    @objc
    private func insertPressed() {
        onInsertRequested?()
    }

    @objc
    private func copyPressed() {
        onCopyRequested?()
    }

    @objc
    private func retryPressed() {
        onRetryRequested?()
    }

    @objc
    private func dismissPressed() {
        onDismissRequested?()
    }
}
