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
    var onRetryRequested: ((String) -> Void)?
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
            guard self?.contentController.isInsertEnabled == true else {
                return
            }
            self?.performInsert()
        }
        contentController.onPromptCopyRequested = { [weak self] in
            _ = self?.performPromptCopy()
        }
        contentController.onOutputCopyRequested = { [weak self] in
            _ = self?.performCopy()
        }
        contentController.onRetryRequested = { [weak self] in
            self?.performRetry()
        }
        contentController.onInsertRequested = { [weak self] in
            self?.performInsert()
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
        contentController.displayedPromptText
    }

    var displayedText: String {
        contentController.displayedText
    }

    var promptCopyButtonTitle: String {
        contentController.promptCopyButtonTitle
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
        if RuntimeEnvironment.isRunningTests {
            return
        }

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
    func performPromptCopy() -> Bool {
        let promptText = contentController.promptTextForCopy
        guard !promptText.isEmpty else {
            return false
        }

        let didCopy = clipboardWriter.write(string: promptText)
        if didCopy {
            onCopyRequested?(promptText)
        }
        return didCopy
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
        onRetryRequested?(contentController.selectedPromptPresetID)
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
            guard flags.isEmpty, contentController.isInsertEnabled else {
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
    private let promptTextLabel = NSTextField(wrappingLabelWithString: "")
    private let promptCopyButton = NSButton(title: "", target: nil, action: nil)
    private let promptPicker = ThemedPopUpButton()

    private let answerContainer = NSView()
    private let answerHeader = NSView()
    private let answerHeaderSeparator = NSView()
    private let answerTitleStack = NSStackView()
    private let answerIconView = NSImageView()
    private let answerTitleLabel = NSTextField(labelWithString: "")
    private let outputCopyButton = NSButton(title: "", target: nil, action: nil)
    private let outputScrollView = NSScrollView()
    private let outputTextView = NSTextView()
    private let answerActionRow = NSStackView()
    private let answerStatusRow = NSStackView()
    private let regenerationProgressIndicator = NSProgressIndicator()
    private let answerStatusLabel = NSTextField(labelWithString: "")
    private let regenerateButton = NSButton(title: "", target: nil, action: nil)
    private let insertButton = NSButton(title: "", target: nil, action: nil)

    private var payload: ResultReviewPanelPayload?
    private var state: ResultReviewPanelPresentationState?

    var onPromptCopyRequested: (() -> Void)?
    var onOutputCopyRequested: (() -> Void)?
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
            answerContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 208)
        ])

        setPayload(ResultReviewPanelPayload(text: "Preview output", sourceText: "Preview prompt")!)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateOutputTextLayout()
    }

    func setPayload(_ payload: ResultReviewPanelPayload) {
        self.payload = payload
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
        cardView.layer?.backgroundColor = cardBackground.cgColor
        cardView.layer?.borderColor = cardBorder.cgColor
        answerContainer.layer?.backgroundColor = answerBackground.cgColor
        answerContainer.layer?.borderColor = answerBorder.cgColor
        answerHeaderSeparator.layer?.backgroundColor = separatorColor.cgColor

        brandLabel.textColor = .labelColor
        promptIconView.contentTintColor = .secondaryLabelColor
        promptTextLabel.textColor = .labelColor
        answerIconView.contentTintColor = .secondaryLabelColor
        answerTitleLabel.textColor = .labelColor
        answerStatusLabel.textColor = .secondaryLabelColor
        outputTextView.textColor = .labelColor
        outputTextView.backgroundColor = .clear
        promptPicker.syncTheme()

        OverlayButtonStyler.style(
            promptCopyButton,
            role: .subtle,
            appearance: view.effectiveAppearance,
            cornerRadius: 12
        )
        OverlayButtonStyler.style(
            outputCopyButton,
            role: .subtle,
            appearance: view.effectiveAppearance,
            cornerRadius: 12
        )
        OverlayButtonStyler.style(
            regenerateButton,
            role: .secondary,
            appearance: view.effectiveAppearance
        )
        OverlayButtonStyler.style(
            insertButton,
            role: .primary,
            appearance: view.effectiveAppearance
        )

        closeButton.contentTintColor = .secondaryLabelColor
    }

    var titleText: String {
        state?.titleText ?? "VoicePi"
    }

    var displayedPromptText: String {
        state?.promptDisplayText ?? ""
    }

    var promptTextForCopy: String {
        state?.promptCopyText ?? ""
    }

    var displayedText: String {
        state?.outputDisplayText ?? ""
    }

    var outputTextForCopy: String {
        state?.outputCopyText ?? ""
    }

    var promptCopyButtonTitle: String {
        state?.promptCopyButtonTitle ?? "Copy"
    }

    var outputCopyButtonTitle: String {
        state?.outputCopyButtonTitle ?? "Copy"
    }

    var selectedPromptPresetID: String {
        guard let selectedPresetID = promptPicker.selectedItem?.representedObject as? String else {
            return state?.selectedPromptPresetID ?? PromptPreset.builtInDefaultID
        }
        return selectedPresetID
    }

    var isInsertEnabled: Bool {
        insertButton.isEnabled
    }

    private func syncState() {
        guard let state else { return }
        brandLabel.stringValue = state.titleText
        promptTextLabel.stringValue = state.promptDisplayText
        answerTitleLabel.stringValue = state.outputSectionTitle
        promptCopyButton.title = state.promptCopyButtonTitle
        outputCopyButton.title = state.outputCopyButtonTitle
        promptCopyButton.toolTip = nil
        outputCopyButton.toolTip = nil
        promptCopyButton.isEnabled = !state.promptCopyText.isEmpty
        outputCopyButton.isEnabled = !state.outputCopyText.isEmpty
        regenerateButton.title = state.regenerateButtonTitle
        regenerateButton.isEnabled = state.isRegenerateEnabled
        insertButton.title = state.insertButtonTitle
        insertButton.isEnabled = state.isInsertEnabled
        insertButton.toolTip = state.showsFooterProgress ? nil : state.footerStatusText
        promptPicker.isEnabled = state.isPromptPickerEnabled
        answerStatusLabel.stringValue = state.footerStatusText
        if state.showsFooterProgress {
            regenerationProgressIndicator.startAnimation(nil)
        } else {
            regenerationProgressIndicator.stopAnimation(nil)
        }
        reloadPromptPickerItems()
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
        promptIconView.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Prompt")
        promptIconView.imageScaling = .scaleProportionallyDown

        promptTextLabel.translatesAutoresizingMaskIntoConstraints = false
        promptTextLabel.font = .systemFont(ofSize: 14, weight: .regular)
        promptTextLabel.maximumNumberOfLines = 2
        promptTextLabel.lineBreakMode = .byTruncatingTail

        configureInlineActionButton(promptCopyButton, action: #selector(promptCopyPressed))

        promptRow.addSubview(promptIconView)
        promptRow.addSubview(promptTextLabel)
        promptRow.addSubview(promptCopyButton)

        NSLayoutConstraint.activate([
            promptIconView.leadingAnchor.constraint(equalTo: promptRow.leadingAnchor, constant: 2),
            promptIconView.topAnchor.constraint(greaterThanOrEqualTo: promptRow.topAnchor, constant: 8),
            promptIconView.bottomAnchor.constraint(lessThanOrEqualTo: promptRow.bottomAnchor, constant: -8),
            promptIconView.centerYAnchor.constraint(equalTo: promptRow.centerYAnchor),
            promptIconView.widthAnchor.constraint(equalToConstant: 14),
            promptIconView.heightAnchor.constraint(equalToConstant: 14),

            promptCopyButton.trailingAnchor.constraint(equalTo: promptRow.trailingAnchor, constant: -1),
            promptCopyButton.centerYAnchor.constraint(equalTo: promptRow.centerYAnchor),
            promptCopyButton.heightAnchor.constraint(equalToConstant: 24),

            promptTextLabel.leadingAnchor.constraint(equalTo: promptIconView.trailingAnchor, constant: 10),
            promptTextLabel.trailingAnchor.constraint(equalTo: promptCopyButton.leadingAnchor, constant: -12),
            promptTextLabel.topAnchor.constraint(equalTo: promptRow.topAnchor, constant: 8),
            promptTextLabel.bottomAnchor.constraint(equalTo: promptRow.bottomAnchor, constant: -8)
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

        configureInlineActionButton(outputCopyButton, action: #selector(outputCopyPressed))
        configureInlineActionButton(regenerateButton, action: #selector(regeneratePressed))
        configureInlineActionButton(insertButton, action: #selector(insertPressed))
        insertButton.bezelColor = NSColor.controlAccentColor
        insertButton.font = .systemFont(ofSize: 12.5, weight: .semibold)
        promptPicker.translatesAutoresizingMaskIntoConstraints = false
        promptPicker.target = self
        promptPicker.action = #selector(promptPickerChanged(_:))
        promptPicker.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        answerActionRow.translatesAutoresizingMaskIntoConstraints = false
        answerActionRow.orientation = .horizontal
        answerActionRow.alignment = .centerY
        answerActionRow.spacing = 8
        answerActionRow.addArrangedSubview(promptPicker)
        answerActionRow.addArrangedSubview(NSView())
        answerActionRow.addArrangedSubview(regenerateButton)
        answerActionRow.addArrangedSubview(insertButton)

        answerStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        answerStatusLabel.font = .systemFont(ofSize: 11.5, weight: .regular)
        answerStatusLabel.maximumNumberOfLines = 1
        answerStatusLabel.lineBreakMode = .byTruncatingTail
        answerStatusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        regenerationProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        regenerationProgressIndicator.style = .spinning
        regenerationProgressIndicator.controlSize = .small
        regenerationProgressIndicator.isIndeterminate = true
        regenerationProgressIndicator.isDisplayedWhenStopped = false
        regenerationProgressIndicator.setContentHuggingPriority(.required, for: .horizontal)
        regenerationProgressIndicator.setContentCompressionResistancePriority(.required, for: .horizontal)

        answerStatusRow.translatesAutoresizingMaskIntoConstraints = false
        answerStatusRow.orientation = .horizontal
        answerStatusRow.alignment = .centerY
        answerStatusRow.spacing = 6
        answerStatusRow.addArrangedSubview(regenerationProgressIndicator)
        answerStatusRow.addArrangedSubview(answerStatusLabel)
        answerStatusRow.addArrangedSubview(NSView())
        configureOutputScrollView()

        answerContainer.addSubview(answerHeader)
        answerHeader.addSubview(answerTitleStack)
        answerHeader.addSubview(outputCopyButton)
        answerHeader.addSubview(answerHeaderSeparator)
        answerContainer.addSubview(outputScrollView)
        answerContainer.addSubview(answerStatusRow)
        answerContainer.addSubview(answerActionRow)

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
            outputCopyButton.heightAnchor.constraint(equalToConstant: 24),

            answerHeaderSeparator.leadingAnchor.constraint(equalTo: answerHeader.leadingAnchor),
            answerHeaderSeparator.trailingAnchor.constraint(equalTo: answerHeader.trailingAnchor),
            answerHeaderSeparator.bottomAnchor.constraint(equalTo: answerHeader.bottomAnchor),
            answerHeaderSeparator.heightAnchor.constraint(equalToConstant: 1),

            outputScrollView.leadingAnchor.constraint(equalTo: answerContainer.leadingAnchor, constant: 12),
            outputScrollView.trailingAnchor.constraint(equalTo: answerContainer.trailingAnchor, constant: -12),
            outputScrollView.topAnchor.constraint(equalTo: answerHeader.bottomAnchor, constant: 8),
            outputScrollView.bottomAnchor.constraint(equalTo: answerStatusRow.topAnchor, constant: -8),

            answerStatusRow.leadingAnchor.constraint(equalTo: answerContainer.leadingAnchor, constant: 12),
            answerStatusRow.trailingAnchor.constraint(equalTo: answerContainer.trailingAnchor, constant: -12),
            answerStatusRow.bottomAnchor.constraint(equalTo: answerActionRow.topAnchor, constant: -8),
            answerStatusRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 14),

            answerActionRow.leadingAnchor.constraint(equalTo: answerContainer.leadingAnchor, constant: 12),
            answerActionRow.trailingAnchor.constraint(equalTo: answerContainer.trailingAnchor, constant: -12),
            answerActionRow.bottomAnchor.constraint(equalTo: answerContainer.bottomAnchor, constant: -12),

            regenerateButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
            regenerateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 126),
            insertButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
            insertButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 96)
        ])
    }

    private func configureInlineActionButton(_ button: NSButton, action: Selector) {
        OverlayButtonStyler.configureBase(
            button,
            action: action,
            target: self,
            font: .systemFont(ofSize: 12.5, weight: .medium)
        )
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

    private func reloadPromptPickerItems() {
        guard let payload else { return }
        promptPicker.removeAllItems()

        for option in payload.availablePrompts {
            let title = option.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = title.isEmpty ? PromptPreset.builtInDefault.title : title
            promptPicker.addItem(withTitle: displayTitle)
            promptPicker.lastItem?.representedObject = option.presetID
        }

        if promptPicker.numberOfItems == 0 {
            promptPicker.addItem(withTitle: PromptPreset.builtInDefault.title)
            promptPicker.lastItem?.representedObject = PromptPreset.builtInDefaultID
        }

        let selectedIndex = promptPicker.indexOfItem(withRepresentedObject: state?.selectedPromptPresetID ?? PromptPreset.builtInDefaultID)
        if selectedIndex >= 0 {
            promptPicker.selectItem(at: selectedIndex)
        } else {
            promptPicker.selectItem(at: 0)
        }
    }

    @objc
    private func closePressed() {
        onDismissRequested?()
    }

    @objc
    private func promptCopyPressed() {
        onPromptCopyRequested?()
    }

    @objc
    private func outputCopyPressed() {
        onOutputCopyRequested?()
    }

    @objc
    private func regeneratePressed() {
        onRetryRequested?()
    }

    @objc
    private func insertPressed() {
        onInsertRequested?()
    }

    @objc
    private func promptPickerChanged(_ sender: NSPopUpButton) {
        guard sender.selectedItem != nil else { return }
    }
}
