import AppKit
import QuartzCore

private final class ExternalProcessorResultPanelWindow: NSPanel {
    var onEscapePressed: (() -> Void)?
    var onConfirmPressed: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscapePressed?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleKeyboardEvent(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleKeyboardEvent(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handleKeyboardEvent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return false
        }

        switch event.keyCode {
        case 53:
            onEscapePressed?()
            return true
        case 36, 76:
            var flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            flags.remove(.numericPad)
            guard flags.isEmpty else {
                return false
            }
            onConfirmPressed?()
            return true
        default:
            return false
        }
    }
}

@MainActor
final class ExternalProcessorResultPanelController: NSWindowController {
    private let clipboardWriter: ClipboardWriting
    private let contentController = ExternalProcessorResultPanelContentViewController()
    private var localKeyMonitor: Any?

    var onInsertRequested: ((String) -> Void)?
    var onCopyRequested: ((String) -> Void)?
    var onRetryRequested: (() -> Void)?
    var onDismissRequested: (() -> Void)?

    init(clipboardWriter: ClipboardWriting? = nil) {
        self.clipboardWriter = clipboardWriter ?? GeneralClipboardWriter()

        let initialFrame = ExternalProcessorResultPanelLayout.frame(
            for: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        )
        let panel = ExternalProcessorResultPanelWindow(
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
        panel.onEscapePressed = { [weak self] in
            self?.performDismiss()
        }
        panel.onConfirmPressed = { [weak self] in
            self?.performInsert()
        }
        contentController.onOriginalCopyRequested = { [weak self] in
            _ = self?.performCopyOriginal()
        }
        contentController.onResultCopyRequested = { [weak self] in
            _ = self?.performCopyResult()
        }
        contentController.onRetryRequested = { [weak self] in
            self?.performRetry()
        }
        contentController.onDismissRequested = { [weak self] in
            self?.performDismiss()
        }
        contentController.onInsertRequested = { [weak self] in
            self?.performInsert()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var displayedText: String {
        contentController.displayedText
    }

    func show(payload: ExternalProcessorResultPanelPayload) {
        contentController.loadViewIfNeeded()
        contentController.setPayload(payload)
        applyCurrentFrame(animated: window?.isVisible == true)
        installKeyMonitorIfNeeded()

        guard let panel = window else { return }
        if RuntimeEnvironment.isRunningTests {
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }
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
        removeKeyMonitor()
        guard let panel = window, panel.isVisible else {
            return
        }

        panel.orderOut(nil)
    }

    func performInsert() {
        onInsertRequested?(contentController.displayedText)
    }

    @discardableResult
    func performCopyOriginal() -> Bool {
        let originalText = contentController.originalTextForCopy
        let didCopy = clipboardWriter.write(string: originalText)
        if didCopy {
            onCopyRequested?(originalText)
        }
        return didCopy
    }

    @discardableResult
    func performCopyResult() -> Bool {
        let resultText = contentController.resultTextForCopy
        let didCopy = clipboardWriter.write(string: resultText)
        if didCopy {
            onCopyRequested?(resultText)
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
        return ExternalProcessorResultPanelLayout.frame(for: visibleFrame)
    }

    private func installKeyMonitorIfNeeded() {
        guard localKeyMonitor == nil else { return }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.window?.isVisible == true, self.window?.isKeyWindow == true else {
                return event
            }
            if self.handleMonitoredKeyEvent(event) {
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        guard let localKeyMonitor else { return }
        NSEvent.removeMonitor(localKeyMonitor)
        self.localKeyMonitor = nil
    }

    private func handleMonitoredKeyEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53:
            performDismiss()
            return true
        case 36, 76:
            var flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            flags.remove(.numericPad)
            guard flags.isEmpty else {
                return false
            }
            performInsert()
            return true
        default:
            return false
        }
    }
}

@MainActor
private final class ExternalProcessorResultPanelContentViewController: NSViewController {
    private let rootView = NSView()
    private let cardView = NSVisualEffectView()
    private let headerContainer = NSView()
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let brandStack = NSStackView()
    private let appIconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")

    private let sourceRow = NSView()
    private let sourceIconView = NSImageView()
    private let sourceTextStack = NSStackView()
    private let originalSectionLabel = NSTextField(labelWithString: "")
    private let sourcePreviewLabel = NSTextField(wrappingLabelWithString: "")
    private let originalCopyButton = NSButton(title: "", target: nil, action: nil)

    private let resultContainer = NSView()
    private let resultHeader = NSView()
    private let resultHeaderSeparator = NSView()
    private let resultTitleStack = NSStackView()
    private let resultIconView = NSImageView()
    private let resultSectionLabel = NSTextField(labelWithString: "")
    private let resultStatusBadge = NSView()
    private let resultStatusLabel = NSTextField(labelWithString: "")
    private let resultCopyButton = NSButton(title: "", target: nil, action: nil)

    private let footerRow = NSView()
    private let hintLabel = NSTextField(labelWithString: "")
    private let retryButton = NSButton(title: "", target: nil, action: nil)
    private let insertButton = NSButton(title: "", target: nil, action: nil)
    private let resultScrollView = NSScrollView()
    private let resultTextView = NSTextView()

    private var state: ExternalProcessorResultPanelPresentationState?

    var onOriginalCopyRequested: (() -> Void)?
    var onResultCopyRequested: (() -> Void)?
    var onRetryRequested: (() -> Void)?
    var onInsertRequested: (() -> Void)?
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
        cardView.layer?.borderWidth = 1

        configureHeader()
        configureSourceRow()
        configureResultSection()
        configureFooter()
        configureTextView(resultTextView)
        configureScrollView(resultScrollView, textView: resultTextView)

        let contentStack = NSStackView(views: [
            headerContainer,
            sourceRow,
            resultContainer,
            footerRow
        ])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12

        rootView.addSubview(cardView)
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: rootView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 22),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -22),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -18),

            headerContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            sourceRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            resultContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            footerRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            sourceRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            resultContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 190)
        ])

        setPayload(
            ExternalProcessorResultPanelPayload(
                resultText: "Preview result",
                originalText: "Preview original"
            )!
        )
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateResultTextLayout()
    }

    func setPayload(_ payload: ExternalProcessorResultPanelPayload) {
        state = ExternalProcessorResultPanelPresentationState(payload: payload)
        syncState()
    }

    func syncAppearance() {
        cardView.appearance = view.window?.appearance
        let isDark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let cardBackground = isDark
            ? NSColor(calibratedWhite: 0.145, alpha: 0.98)
            : NSColor(calibratedWhite: 0.945, alpha: 0.98)
        let cardBorder = isDark
            ? NSColor(calibratedWhite: 1.0, alpha: 0.1)
            : NSColor(calibratedWhite: 0.0, alpha: 0.07)
        let resultBackground = isDark
            ? NSColor(calibratedWhite: 0.17, alpha: 0.97)
            : NSColor(calibratedWhite: 0.98, alpha: 0.92)
        let resultBorder = isDark
            ? NSColor(calibratedWhite: 1.0, alpha: 0.12)
            : NSColor(calibratedWhite: 0.0, alpha: 0.08)
        let separatorColor = isDark
            ? NSColor(calibratedWhite: 1.0, alpha: 0.1)
            : NSColor(calibratedWhite: 0.0, alpha: 0.08)
        let badgeBackground = isDark
            ? NSColor(calibratedRed: 0.52, green: 0.41, blue: 0.12, alpha: 0.28)
            : NSColor(calibratedRed: 0.98, green: 0.89, blue: 0.63, alpha: 0.9)
        let badgeBorder = isDark
            ? NSColor(calibratedRed: 0.87, green: 0.73, blue: 0.31, alpha: 0.28)
            : NSColor(calibratedRed: 0.82, green: 0.68, blue: 0.28, alpha: 0.32)

        cardView.layer?.backgroundColor = cardBackground.cgColor
        cardView.layer?.borderColor = cardBorder.cgColor
        resultContainer.layer?.backgroundColor = resultBackground.cgColor
        resultContainer.layer?.borderColor = resultBorder.cgColor
        resultHeaderSeparator.layer?.backgroundColor = separatorColor.cgColor
        resultStatusBadge.layer?.backgroundColor = badgeBackground.cgColor
        resultStatusBadge.layer?.borderColor = badgeBorder.cgColor

        [titleLabel, originalSectionLabel, resultSectionLabel].forEach {
            $0.textColor = .labelColor
        }
        sourceIconView.contentTintColor = .secondaryLabelColor
        resultIconView.contentTintColor = .secondaryLabelColor
        hintLabel.textColor = .secondaryLabelColor
        sourcePreviewLabel.textColor = .secondaryLabelColor
        resultTextView.textColor = .labelColor
        resultTextView.font = .systemFont(ofSize: 14, weight: .regular)
        resultTextView.backgroundColor = .clear
        resultStatusLabel.textColor = isDark
            ? NSColor(calibratedRed: 0.96, green: 0.86, blue: 0.57, alpha: 0.98)
            : NSColor(calibratedRed: 0.44, green: 0.33, blue: 0.08, alpha: 0.98)
        [closeButton, originalCopyButton, resultCopyButton].forEach {
            $0.contentTintColor = .secondaryLabelColor
        }
    }

    var displayedText: String {
        state?.resultDisplayText ?? ""
    }

    var originalTextForCopy: String {
        state?.originalCopyText ?? ""
    }

    var resultTextForCopy: String {
        state?.resultCopyText ?? ""
    }

    private func syncState() {
        guard let state else { return }
        titleLabel.stringValue = state.titleText
        originalSectionLabel.stringValue = state.originalSectionTitle
        resultSectionLabel.stringValue = state.resultSectionTitle
        hintLabel.stringValue = state.interactionHintText
        sourcePreviewLabel.stringValue = state.originalPreviewText
        resultTextView.string = state.resultDisplayText
        originalCopyButton.toolTip = state.originalCopyButtonTitle
        resultCopyButton.toolTip = state.resultCopyButtonTitle
        retryButton.title = state.retryButtonTitle
        insertButton.title = state.insertButtonTitle
        resultStatusLabel.stringValue = state.resultStatusText
        resultStatusBadge.isHidden = state.resultStatusText.isEmpty
        resultCopyButton.isEnabled = !state.resultCopyText.isEmpty
        originalCopyButton.isEnabled = !state.originalCopyText.isEmpty
        updateResultTextLayout()
    }

    private func configureTextView(_ textView: NSTextView) {
        textView.isEditable = false
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.drawsBackground = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 120)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 2, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        textView.font = .systemFont(ofSize: 14, weight: .regular)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.frame = NSRect(x: 0, y: 0, width: 1, height: 120)
    }

    private func configureScrollView(_ scrollView: NSScrollView, textView: NSTextView) {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
    }

    private func configureIconButton(_ button: NSButton, symbolName: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = action
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.title = ""
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
    }

    private func configureFooterButton(_ button: NSButton, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.controlSize = .regular
    }

    private func configureHeader() {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false

        configureIconButton(closeButton, symbolName: "xmark", action: #selector(closePressed))

        brandStack.translatesAutoresizingMaskIntoConstraints = false
        brandStack.orientation = .horizontal
        brandStack.alignment = .centerY
        brandStack.spacing = 6

        appIconView.translatesAutoresizingMaskIntoConstraints = false
        appIconView.image = loadVoicePiIcon()
        appIconView.imageScaling = .scaleProportionallyUpOrDown

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        headerContainer.addSubview(closeButton)
        brandStack.addArrangedSubview(appIconView)
        brandStack.addArrangedSubview(titleLabel)
        headerContainer.addSubview(brandStack)

        NSLayoutConstraint.activate([
            headerContainer.heightAnchor.constraint(equalToConstant: 34),
            closeButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 22),
            brandStack.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            brandStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 18),
            appIconView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    private func configureSourceRow() {
        sourceRow.translatesAutoresizingMaskIntoConstraints = false

        sourceIconView.translatesAutoresizingMaskIntoConstraints = false
        sourceIconView.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Source")
        sourceIconView.imageScaling = .scaleProportionallyDown

        sourceTextStack.translatesAutoresizingMaskIntoConstraints = false
        sourceTextStack.orientation = .vertical
        sourceTextStack.alignment = .leading
        sourceTextStack.spacing = 2

        originalSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        originalSectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        sourcePreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        sourcePreviewLabel.font = .systemFont(ofSize: 13, weight: .regular)
        sourcePreviewLabel.maximumNumberOfLines = 2
        sourcePreviewLabel.lineBreakMode = .byTruncatingTail

        configureIconButton(originalCopyButton, symbolName: "doc.on.doc", action: #selector(copyOriginalPressed))

        sourceTextStack.addArrangedSubview(originalSectionLabel)
        sourceTextStack.addArrangedSubview(sourcePreviewLabel)
        sourceRow.addSubview(sourceIconView)
        sourceRow.addSubview(sourceTextStack)
        sourceRow.addSubview(originalCopyButton)

        NSLayoutConstraint.activate([
            sourceIconView.leadingAnchor.constraint(equalTo: sourceRow.leadingAnchor, constant: 2),
            sourceIconView.topAnchor.constraint(equalTo: sourceRow.topAnchor, constant: 8),
            sourceIconView.widthAnchor.constraint(equalToConstant: 14),
            sourceIconView.heightAnchor.constraint(equalToConstant: 14),

            originalCopyButton.trailingAnchor.constraint(equalTo: sourceRow.trailingAnchor, constant: -1),
            originalCopyButton.topAnchor.constraint(equalTo: sourceRow.topAnchor, constant: 6),
            originalCopyButton.widthAnchor.constraint(equalToConstant: 22),
            originalCopyButton.heightAnchor.constraint(equalToConstant: 22),

            sourceTextStack.leadingAnchor.constraint(equalTo: sourceIconView.trailingAnchor, constant: 10),
            sourceTextStack.trailingAnchor.constraint(equalTo: originalCopyButton.leadingAnchor, constant: -12),
            sourceTextStack.topAnchor.constraint(equalTo: sourceRow.topAnchor, constant: 6),
            sourceTextStack.bottomAnchor.constraint(equalTo: sourceRow.bottomAnchor, constant: -6)
        ])
    }

    private func configureResultSection() {
        resultContainer.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.wantsLayer = true
        resultContainer.layer?.cornerRadius = 14
        resultContainer.layer?.masksToBounds = true
        resultContainer.layer?.borderWidth = 1

        resultHeader.translatesAutoresizingMaskIntoConstraints = false
        resultHeaderSeparator.translatesAutoresizingMaskIntoConstraints = false
        resultHeaderSeparator.wantsLayer = true

        resultIconView.translatesAutoresizingMaskIntoConstraints = false
        resultIconView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Result")
        resultIconView.imageScaling = .scaleProportionallyDown

        resultSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        resultSectionLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        resultTitleStack.translatesAutoresizingMaskIntoConstraints = false
        resultTitleStack.orientation = .horizontal
        resultTitleStack.alignment = .centerY
        resultTitleStack.spacing = 6
        resultTitleStack.addArrangedSubview(resultIconView)
        resultTitleStack.addArrangedSubview(resultSectionLabel)

        resultStatusBadge.translatesAutoresizingMaskIntoConstraints = false
        resultStatusBadge.wantsLayer = true
        resultStatusBadge.layer?.cornerRadius = 8
        resultStatusBadge.layer?.masksToBounds = true
        resultStatusBadge.layer?.borderWidth = 1

        resultStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        resultStatusLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        resultStatusBadge.addSubview(resultStatusLabel)

        configureIconButton(resultCopyButton, symbolName: "doc.on.doc", action: #selector(copyResultPressed))

        resultContainer.addSubview(resultHeader)
        resultHeader.addSubview(resultTitleStack)
        resultHeader.addSubview(resultStatusBadge)
        resultHeader.addSubview(resultCopyButton)
        resultHeader.addSubview(resultHeaderSeparator)
        resultContainer.addSubview(resultScrollView)

        NSLayoutConstraint.activate([
            resultHeader.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor),
            resultHeader.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor),
            resultHeader.topAnchor.constraint(equalTo: resultContainer.topAnchor),
            resultHeader.heightAnchor.constraint(equalToConstant: 42),

            resultTitleStack.leadingAnchor.constraint(equalTo: resultHeader.leadingAnchor, constant: 14),
            resultTitleStack.centerYAnchor.constraint(equalTo: resultHeader.centerYAnchor),
            resultIconView.widthAnchor.constraint(equalToConstant: 14),
            resultIconView.heightAnchor.constraint(equalToConstant: 14),

            resultStatusBadge.leadingAnchor.constraint(equalTo: resultTitleStack.trailingAnchor, constant: 8),
            resultStatusBadge.centerYAnchor.constraint(equalTo: resultHeader.centerYAnchor),

            resultStatusLabel.leadingAnchor.constraint(equalTo: resultStatusBadge.leadingAnchor, constant: 8),
            resultStatusLabel.trailingAnchor.constraint(equalTo: resultStatusBadge.trailingAnchor, constant: -8),
            resultStatusLabel.topAnchor.constraint(equalTo: resultStatusBadge.topAnchor, constant: 3),
            resultStatusLabel.bottomAnchor.constraint(equalTo: resultStatusBadge.bottomAnchor, constant: -3),

            resultCopyButton.trailingAnchor.constraint(equalTo: resultHeader.trailingAnchor, constant: -10),
            resultCopyButton.centerYAnchor.constraint(equalTo: resultHeader.centerYAnchor),
            resultCopyButton.widthAnchor.constraint(equalToConstant: 22),
            resultCopyButton.heightAnchor.constraint(equalToConstant: 22),

            resultHeaderSeparator.leadingAnchor.constraint(equalTo: resultHeader.leadingAnchor),
            resultHeaderSeparator.trailingAnchor.constraint(equalTo: resultHeader.trailingAnchor),
            resultHeaderSeparator.bottomAnchor.constraint(equalTo: resultHeader.bottomAnchor),
            resultHeaderSeparator.heightAnchor.constraint(equalToConstant: 1),

            resultScrollView.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 12),
            resultScrollView.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -12),
            resultScrollView.topAnchor.constraint(equalTo: resultHeader.bottomAnchor, constant: 8),
            resultScrollView.bottomAnchor.constraint(equalTo: resultContainer.bottomAnchor, constant: -12)
        ])
    }

    private func configureFooter() {
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        hintLabel.lineBreakMode = .byTruncatingTail
        hintLabel.maximumNumberOfLines = 1

        configureFooterButton(retryButton, action: #selector(retryPressed))
        configureFooterButton(insertButton, action: #selector(insertPressed))

        let actionStack = NSStackView(views: [retryButton, insertButton])
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.orientation = .horizontal
        actionStack.alignment = .centerY
        actionStack.spacing = 10

        footerRow.addSubview(hintLabel)
        footerRow.addSubview(actionStack)

        NSLayoutConstraint.activate([
            actionStack.trailingAnchor.constraint(equalTo: footerRow.trailingAnchor),
            actionStack.centerYAnchor.constraint(equalTo: footerRow.centerYAnchor),

            hintLabel.leadingAnchor.constraint(equalTo: footerRow.leadingAnchor),
            hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionStack.leadingAnchor, constant: -10),
            hintLabel.centerYAnchor.constraint(equalTo: footerRow.centerYAnchor),
            footerRow.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func loadVoicePiIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }

    private func updateResultTextLayout() {
        guard let textContainer = resultTextView.textContainer else { return }

        let contentSize = resultScrollView.contentSize
        let textWidth = max(0, contentSize.width - resultTextView.textContainerInset.width * 2)
        textContainer.containerSize = NSSize(width: textWidth, height: .greatestFiniteMagnitude)
        textContainer.widthTracksTextView = true
        resultTextView.maxSize = NSSize(width: contentSize.width, height: .greatestFiniteMagnitude)

        guard let layoutManager = resultTextView.layoutManager else { return }
        let usedRect = layoutManager.usedRect(for: textContainer)
        let height = max(contentSize.height, usedRect.height + resultTextView.textContainerInset.height * 2)
        resultTextView.frame = NSRect(x: 0, y: 0, width: max(contentSize.width, 1), height: height)
    }

    @objc
    private func copyOriginalPressed() {
        onOriginalCopyRequested?()
    }

    @objc
    private func copyResultPressed() {
        onResultCopyRequested?()
    }

    @objc
    private func retryPressed() {
        onRetryRequested?()
    }

    @objc
    private func insertPressed() {
        onInsertRequested?()
    }

    @objc
    private func closePressed() {
        onDismissRequested?()
    }
}
