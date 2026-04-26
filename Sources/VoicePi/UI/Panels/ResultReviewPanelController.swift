import AppKit
import QuartzCore

private final class ResultReviewPanelWindow: NSPanel {
    var onEscapePressed: (() -> Void)?
    var onConfirmPressed: (() -> Void)?
    var canConsumeConfirmShortcut: ((NSEvent) -> Bool)?

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
            guard canConsumeConfirmShortcut?(event) == true else {
                return false
            }
            onConfirmPressed?()
            return true
        default:
            return false
        }
    }
}

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
        panel.canConsumeConfirmShortcut = { [weak self] event in
            Self.shouldConsumeConfirmShortcut(
                event,
                isInsertEnabled: self?.contentController.isInsertEnabled ?? false
            )
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

    var isInsertEnabled: Bool {
        contentController.isInsertEnabled
    }

    func show(payload: ResultReviewPanelPayload) {
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
        guard contentController.isInsertEnabled else { return }
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
            guard Self.shouldConsumeConfirmShortcut(
                event,
                isInsertEnabled: contentController.isInsertEnabled
            ) else {
                return false
            }
            performInsert()
            return true
        default:
            return false
        }
    }

    static func shouldConsumeConfirmShortcut(
        _ event: NSEvent,
        isInsertEnabled: Bool
    ) -> Bool {
        guard isInsertEnabled else {
            return false
        }
        guard event.isARepeat == false else {
            return false
        }
        var flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        flags.subtract([.numericPad, .function, .capsLock])
        return flags.isEmpty
    }
}
