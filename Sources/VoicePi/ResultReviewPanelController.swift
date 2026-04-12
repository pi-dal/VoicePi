import AppKit
import QuartzCore

private final class ResultReviewPanelWindow: NSPanel {
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
            guard canConfirmInsert(for: event) else {
                return false
            }
            onConfirmPressed?()
            return true
        default:
            return false
        }
    }

    private func canConfirmInsert(for event: NSEvent) -> Bool {
        var flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        flags.remove(.numericPad)
        return flags.isEmpty
    }
}

@MainActor
final class ResultReviewPanelController: NSWindowController {
    private let clipboardWriter: ClipboardWriting
    private let contentController = ResultReviewPanelContentViewController()
    private var localKeyMonitor: Any?

    var onInsertRequested: ((String) -> Void)?
    var onCopyRequested: ((String) -> Void)?
    var onPromptSelectionChanged: ((String) -> Void)?
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
        panel.onEscapePressed = { [weak self] in
            self?.performDismiss()
        }
        panel.onConfirmPressed = { [weak self] in
            self?.performInsert()
        }
        contentController.onPromptSelectionChanged = { [weak self] presetID in
            self?.onPromptSelectionChanged?(presetID)
        }
        contentController.onRegenerateRequested = { [weak self] in
            self?.performRetry()
        }
        contentController.onOutputCopyRequested = { [weak self] in
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

    var displayedPromptText: String {
        contentController.selectedPromptTitle
    }

    var displayedText: String {
        contentController.displayedText
    }

    var outputCopyButtonTitle: String {
        contentController.outputCopyButtonTitle
    }

    var copyButtonTitle: String {
        outputCopyButtonTitle
    }

    func show(payload: ResultReviewPanelPayload) {
        contentController.loadViewIfNeeded()
        contentController.setPayload(payload)
        applyCurrentFrame(animated: window?.isVisible == true)
        installKeyMonitorIfNeeded()

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
    func performCopy() -> Bool {
        let outputText = contentController.outputTextForCopy
        let didCopy = clipboardWriter.write(string: outputText)
        if didCopy {
            onCopyRequested?(outputText)
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
private final class ResultReviewPanelContentViewController: NSViewController {
    private let rootView = NSView()
    private let cardView = NSVisualEffectView()
    private let headerContainer = NSView()
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let brandStack = NSStackView()
    private let appIconView = NSImageView()
    private let brandLabel = NSTextField(labelWithString: "")

    private let promptRow = NSView()
    private let promptIconView = NSImageView()
    private let promptSectionLabel = NSTextField(labelWithString: "")
    private let promptPresetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let regenerateButton = NSButton(title: "", target: nil, action: nil)

    private let answerContainer = NSView()
    private let answerHeader = NSView()
    private let answerHeaderSeparator = NSView()
    private let answerTitleStack = NSStackView()
    private let answerIconView = NSImageView()
    private let answerTitleLabel = NSTextField(labelWithString: "")
    private let outputCopyButton = NSButton(title: "", target: nil, action: nil)
    private let outputScrollView = NSScrollView()
    private let outputTextView = NSTextView()

    private var state: ResultReviewPanelPresentationState?

    var onPromptSelectionChanged: ((String) -> Void)?
    var onRegenerateRequested: (() -> Void)?
    var onOutputCopyRequested: (() -> Void)?
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
        configurePromptRow()
        configureAnswerSection()

        let contentStack = NSStackView(views: [headerContainer, promptRow, answerContainer])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.distribution = .fill
        contentStack.spacing = 10

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

            headerContainer.heightAnchor.constraint(equalToConstant: 34),
            headerContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            promptRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            answerContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            promptRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 38),
            answerContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 170)
        ])

        setPayload(
            ResultReviewPanelPayload(
                resultText: "Preview output",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                selectedPromptTitle: PromptPreset.builtInDefault.title,
                availablePrompts: [
                    .init(presetID: PromptPreset.builtInDefaultID, title: PromptPreset.builtInDefault.title),
                    .init(presetID: "user.preview", title: "Preview Prompt")
                ]
            )!
        )
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateOutputTextLayout()
    }

    func setPayload(_ payload: ResultReviewPanelPayload) {
        state = ResultReviewPanelPresentationState(payload: payload)
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
        let answerBackground = isDark
            ? NSColor(calibratedWhite: 0.17, alpha: 0.97)
            : NSColor(calibratedWhite: 0.98, alpha: 0.92)
        let answerBorder = isDark
            ? NSColor(calibratedWhite: 1.0, alpha: 0.12)
            : NSColor(calibratedWhite: 0.0, alpha: 0.08)
        let separatorColor = isDark
            ? NSColor(calibratedWhite: 1.0, alpha: 0.1)
            : NSColor(calibratedWhite: 0.0, alpha: 0.08)
        let iconTint = isDark
            ? NSColor(calibratedWhite: 0.9, alpha: 0.95)
            : NSColor.secondaryLabelColor

        cardView.layer?.backgroundColor = cardBackground.cgColor
        cardView.layer?.borderColor = cardBorder.cgColor
        answerContainer.layer?.backgroundColor = answerBackground.cgColor
        answerContainer.layer?.borderColor = answerBorder.cgColor
        answerHeaderSeparator.layer?.backgroundColor = separatorColor.cgColor

        brandLabel.textColor = .labelColor
        promptIconView.contentTintColor = .secondaryLabelColor
        promptSectionLabel.textColor = .labelColor
        answerIconView.contentTintColor = .secondaryLabelColor
        answerTitleLabel.textColor = .labelColor
        outputTextView.textColor = .labelColor
        outputTextView.backgroundColor = .clear
        promptPresetPopup.appearance = view.window?.appearance

        for button in [outputCopyButton] {
            button.contentTintColor = iconTint
        }

        closeButton.contentTintColor = .secondaryLabelColor
    }

    var titleText: String {
        state?.titleText ?? "VoicePi"
    }

    var selectedPromptTitle: String {
        state?.selectedPromptTitle ?? ""
    }

    var selectedPromptPresetID: String {
        state?.selectedPromptPresetID ?? PromptPreset.builtInDefaultID
    }

    var displayedText: String {
        state?.outputDisplayText ?? ""
    }

    var outputTextForCopy: String {
        state?.outputCopyText ?? ""
    }

    var outputCopyButtonTitle: String {
        state?.outputCopyButtonTitle ?? "Copy"
    }

    private func syncState() {
        guard let state else { return }
        brandLabel.stringValue = state.titleText
        promptSectionLabel.stringValue = "Prompt"
        answerTitleLabel.stringValue = state.outputSectionTitle
        outputCopyButton.toolTip = state.outputCopyButtonTitle
        outputCopyButton.isEnabled = !state.outputCopyText.isEmpty
        promptPresetPopup.isEnabled = state.isPromptPickerEnabled
        regenerateButton.title = state.regenerateButtonTitle
        regenerateButton.isEnabled = state.isRegenerateEnabled
        reloadPromptPresetPopup(
            options: state.promptOptions,
            selectedPresetID: state.selectedPromptPresetID
        )
        outputTextView.string = state.outputDisplayText
        updateOutputTextLayout()
    }

    private func configureHeader() {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isBordered = false
        closeButton.bezelStyle = .regularSquare
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.imageScaling = .scaleProportionallyDown

        brandStack.translatesAutoresizingMaskIntoConstraints = false
        brandStack.orientation = .horizontal
        brandStack.alignment = .centerY
        brandStack.distribution = .fill
        brandStack.spacing = 6

        appIconView.translatesAutoresizingMaskIntoConstraints = false
        appIconView.image = loadVoicePiIcon()
        appIconView.imageScaling = .scaleProportionallyUpOrDown

        brandLabel.translatesAutoresizingMaskIntoConstraints = false
        brandLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        brandLabel.maximumNumberOfLines = 1

        headerContainer.addSubview(closeButton)
        brandStack.addArrangedSubview(appIconView)
        brandStack.addArrangedSubview(brandLabel)
        headerContainer.addSubview(brandStack)

        NSLayoutConstraint.activate([
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

    private func configurePromptRow() {
        promptRow.translatesAutoresizingMaskIntoConstraints = false

        promptIconView.translatesAutoresizingMaskIntoConstraints = false
        promptIconView.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Prompt")
        promptIconView.imageScaling = .scaleProportionallyDown

        promptSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        promptSectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        promptSectionLabel.maximumNumberOfLines = 1

        promptPresetPopup.translatesAutoresizingMaskIntoConstraints = false
        promptPresetPopup.target = self
        promptPresetPopup.action = #selector(promptPresetChanged)
        promptPresetPopup.font = .systemFont(ofSize: 13, weight: .regular)
        promptPresetPopup.controlSize = .regular
        promptPresetPopup.setContentHuggingPriority(.defaultLow, for: .horizontal)
        promptPresetPopup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        regenerateButton.translatesAutoresizingMaskIntoConstraints = false
        regenerateButton.target = self
        regenerateButton.action = #selector(regeneratePressed)
        regenerateButton.bezelStyle = .rounded
        regenerateButton.controlSize = .small
        regenerateButton.setContentHuggingPriority(.required, for: .horizontal)
        regenerateButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        promptRow.addSubview(promptIconView)
        promptRow.addSubview(promptSectionLabel)
        promptRow.addSubview(promptPresetPopup)
        promptRow.addSubview(regenerateButton)

        NSLayoutConstraint.activate([
            promptIconView.leadingAnchor.constraint(equalTo: promptRow.leadingAnchor, constant: 2),
            promptIconView.topAnchor.constraint(greaterThanOrEqualTo: promptRow.topAnchor, constant: 8),
            promptIconView.bottomAnchor.constraint(lessThanOrEqualTo: promptRow.bottomAnchor, constant: -8),
            promptIconView.centerYAnchor.constraint(equalTo: promptRow.centerYAnchor),
            promptIconView.widthAnchor.constraint(equalToConstant: 14),
            promptIconView.heightAnchor.constraint(equalToConstant: 14),

            regenerateButton.trailingAnchor.constraint(equalTo: promptRow.trailingAnchor, constant: -1),
            regenerateButton.centerYAnchor.constraint(equalTo: promptRow.centerYAnchor),

            promptSectionLabel.leadingAnchor.constraint(equalTo: promptIconView.trailingAnchor, constant: 10),
            promptSectionLabel.centerYAnchor.constraint(equalTo: promptRow.centerYAnchor),

            promptPresetPopup.leadingAnchor.constraint(equalTo: promptSectionLabel.trailingAnchor, constant: 10),
            promptPresetPopup.trailingAnchor.constraint(equalTo: regenerateButton.leadingAnchor, constant: -10),
            promptPresetPopup.centerYAnchor.constraint(equalTo: promptRow.centerYAnchor),
            promptPresetPopup.heightAnchor.constraint(equalToConstant: 28),
            promptPresetPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 170)
        ])
    }

    private func configureAnswerSection() {
        answerContainer.translatesAutoresizingMaskIntoConstraints = false
        answerContainer.wantsLayer = true
        answerContainer.layer?.cornerRadius = 14
        answerContainer.layer?.masksToBounds = true
        answerContainer.layer?.borderWidth = 1

        answerHeader.translatesAutoresizingMaskIntoConstraints = false
        answerHeaderSeparator.translatesAutoresizingMaskIntoConstraints = false
        answerHeaderSeparator.wantsLayer = true

        answerIconView.translatesAutoresizingMaskIntoConstraints = false
        answerIconView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Answer")
        answerIconView.imageScaling = .scaleProportionallyDown

        answerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        answerTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        answerTitleLabel.maximumNumberOfLines = 1

        answerTitleStack.translatesAutoresizingMaskIntoConstraints = false
        answerTitleStack.orientation = .horizontal
        answerTitleStack.alignment = .centerY
        answerTitleStack.spacing = 6
        answerTitleStack.addArrangedSubview(answerIconView)
        answerTitleStack.addArrangedSubview(answerTitleLabel)

        configureActionIconButton(outputCopyButton, action: #selector(outputCopyPressed))
        configureOutputScrollView()

        answerContainer.addSubview(answerHeader)
        answerHeader.addSubview(answerTitleStack)
        answerHeader.addSubview(outputCopyButton)
        answerHeader.addSubview(answerHeaderSeparator)
        answerContainer.addSubview(outputScrollView)

        NSLayoutConstraint.activate([
            answerHeader.leadingAnchor.constraint(equalTo: answerContainer.leadingAnchor),
            answerHeader.trailingAnchor.constraint(equalTo: answerContainer.trailingAnchor),
            answerHeader.topAnchor.constraint(equalTo: answerContainer.topAnchor),
            answerHeader.heightAnchor.constraint(equalToConstant: 42),

            answerTitleStack.leadingAnchor.constraint(equalTo: answerHeader.leadingAnchor, constant: 14),
            answerTitleStack.centerYAnchor.constraint(equalTo: answerHeader.centerYAnchor),
            answerIconView.widthAnchor.constraint(equalToConstant: 14),
            answerIconView.heightAnchor.constraint(equalToConstant: 14),

            outputCopyButton.trailingAnchor.constraint(equalTo: answerHeader.trailingAnchor, constant: -10),
            outputCopyButton.centerYAnchor.constraint(equalTo: answerHeader.centerYAnchor),
            outputCopyButton.widthAnchor.constraint(equalToConstant: 22),
            outputCopyButton.heightAnchor.constraint(equalToConstant: 22),

            answerHeaderSeparator.leadingAnchor.constraint(equalTo: answerHeader.leadingAnchor),
            answerHeaderSeparator.trailingAnchor.constraint(equalTo: answerHeader.trailingAnchor),
            answerHeaderSeparator.bottomAnchor.constraint(equalTo: answerHeader.bottomAnchor),
            answerHeaderSeparator.heightAnchor.constraint(equalToConstant: 1),

            outputScrollView.leadingAnchor.constraint(equalTo: answerContainer.leadingAnchor, constant: 12),
            outputScrollView.trailingAnchor.constraint(equalTo: answerContainer.trailingAnchor, constant: -12),
            outputScrollView.topAnchor.constraint(equalTo: answerHeader.bottomAnchor, constant: 8),
            outputScrollView.bottomAnchor.constraint(equalTo: answerContainer.bottomAnchor, constant: -12)
        ])
    }

    private func configureActionIconButton(_ button: NSButton, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = action
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.title = ""
        button.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
    }

    private func configureOutputScrollView() {
        outputScrollView.translatesAutoresizingMaskIntoConstraints = false
        outputScrollView.hasVerticalScroller = true
        outputScrollView.drawsBackground = false
        outputScrollView.borderType = .noBorder
        outputScrollView.autohidesScrollers = true
        configureOutputTextView()
        outputScrollView.documentView = outputTextView
    }

    private func configureOutputTextView() {
        outputTextView.isEditable = false
        outputTextView.isSelectable = true
        outputTextView.isVerticallyResizable = true
        outputTextView.isHorizontallyResizable = false
        outputTextView.drawsBackground = false
        outputTextView.autoresizingMask = [.width]
        outputTextView.minSize = NSSize(width: 0, height: 120)
        outputTextView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        outputTextView.textContainerInset = NSSize(width: 2, height: 4)
        outputTextView.textContainer?.lineFragmentPadding = 0
        outputTextView.textContainer?.widthTracksTextView = true
        outputTextView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        outputTextView.font = .systemFont(ofSize: 14, weight: .regular)
        outputTextView.frame = NSRect(x: 0, y: 0, width: 1, height: 120)
    }

    private func loadVoicePiIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }

    private func updateOutputTextLayout() {
        guard let textContainer = outputTextView.textContainer else { return }

        let contentSize = outputScrollView.contentSize
        let textWidth = max(0, contentSize.width - outputTextView.textContainerInset.width * 2)
        textContainer.containerSize = NSSize(width: textWidth, height: .greatestFiniteMagnitude)
        textContainer.widthTracksTextView = true
        outputTextView.maxSize = NSSize(width: contentSize.width, height: .greatestFiniteMagnitude)

        guard let layoutManager = outputTextView.layoutManager else { return }
        let usedRect = layoutManager.usedRect(for: textContainer)
        let height = max(contentSize.height, usedRect.height + outputTextView.textContainerInset.height * 2)
        outputTextView.frame = NSRect(x: 0, y: 0, width: max(contentSize.width, 1), height: height)
    }

    private func reloadPromptPresetPopup(
        options: [ResultReviewPanelPromptOption],
        selectedPresetID: String
    ) {
        let previousSelection = promptPresetPopup.selectedItem?.representedObject as? String
        promptPresetPopup.removeAllItems()
        for option in options {
            promptPresetPopup.addItem(withTitle: option.title)
            promptPresetPopup.lastItem?.representedObject = option.presetID
        }

        let targetPresetID = options.contains(where: { $0.presetID == selectedPresetID })
            ? selectedPresetID
            : previousSelection
        if let targetPresetID,
           let index = promptPresetPopup.itemArray.firstIndex(where: {
               ($0.representedObject as? String) == targetPresetID
           }) {
            promptPresetPopup.selectItem(at: index)
        } else if promptPresetPopup.numberOfItems > 0 {
            promptPresetPopup.selectItem(at: 0)
        }
    }

    @objc
    private func closePressed() {
        onDismissRequested?()
    }

    @objc
    private func promptPresetChanged() {
        guard let presetID = promptPresetPopup.selectedItem?.representedObject as? String else {
            return
        }
        onPromptSelectionChanged?(presetID)
    }

    @objc
    private func regeneratePressed() {
        onRegenerateRequested?()
    }

    @objc
    private func outputCopyPressed() {
        onOutputCopyRequested?()
    }
}
