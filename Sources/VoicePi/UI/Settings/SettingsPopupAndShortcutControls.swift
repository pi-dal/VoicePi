import AppKit
import Foundation

@MainActor
final class ThemedPopUpButton: NSPopUpButton {
    var leadingSymbolName: String? {
        didSet {
            applyAttributedTitles()
            invalidateIntrinsicContentSize()
        }
    }

    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        configure()
    }

    convenience init() {
        self.init(frame: .zero, pullsDown: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        syncTheme()
    }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        let iconInset: CGFloat = leadingSymbolName == nil ? 0 : 4
        return NSSize(width: max(80, base.width + 6 + iconInset), height: max(34, base.height + 8))
    }

    override func addItem(withTitle title: String) {
        super.addItem(withTitle: title)
        applyAttributedTitles()
    }

    override func addItems(withTitles itemTitles: [String]) {
        super.addItems(withTitles: itemTitles)
        applyAttributedTitles()
    }

    override func insertItem(withTitle title: String, at index: Int) {
        super.insertItem(withTitle: title, at: index)
        applyAttributedTitles()
    }

    override func removeAllItems() {
        super.removeAllItems()
        applyAttributedTitles()
    }

    private func configure() {
        if !(cell is ThemedPopUpButtonCell) {
            let themedCell = ThemedPopUpButtonCell(textCell: "", pullsDown: pullsDown)
            themedCell.arrowPosition = .arrowAtCenter
            self.cell = themedCell
        }
        font = .systemFont(ofSize: 13, weight: .medium)
        controlSize = .regular
        bezelStyle = .regularSquare
        isBordered = false
        wantsLayer = true
        focusRingType = .none
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        syncTheme()
    }

    func syncTheme() {
        let resolvedAppearance = resolvedAppearance()
        let foregroundColor = resolvedForegroundColor()
        let backgroundColor = resolvedBackgroundColor()
        let borderColor = resolvedBorderColor()
        appearance = resolvedAppearance
        menu?.appearance = resolvedAppearance
        contentTintColor = foregroundColor
        layer?.backgroundColor = backgroundColor.cgColor
        layer?.borderColor = borderColor.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 11
        applyAttributedTitles(foregroundColor: foregroundColor)
    }

    private func applyAttributedTitles(foregroundColor: NSColor? = nil) {
        let color = foregroundColor ?? resolvedForegroundColor()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = leadingSymbolName == nil ? .center : .left
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .paragraphStyle: paragraphStyle
        ]

        for item in itemArray {
            item.attributedTitle = NSAttributedString(string: item.title, attributes: attributes)
        }

        if let selectedItem, let selectedTitle = selectedItem.attributedTitle {
            attributedTitle = selectedTitle
        } else {
            attributedTitle = NSAttributedString(string: "")
        }

        needsDisplay = true
    }

    fileprivate func resolvedForegroundColor() -> NSColor {
        let isDarkTheme = resolvedAppearance().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDarkTheme
            ? NSColor(calibratedWhite: 0.93, alpha: 1)
            : NSColor(calibratedWhite: 0.22, alpha: 1)
    }

    private func resolvedBackgroundColor() -> NSColor {
        let isDarkTheme = resolvedAppearance().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDarkTheme
            ? NSColor(
                calibratedRed: 0x33 / 255.0,
                green: 0x38 / 255.0,
                blue: 0x3B / 255.0,
                alpha: 0.96
            )
            : NSColor(
                calibratedRed: 0xF3 / 255.0,
                green: 0xEE / 255.0,
                blue: 0xE6 / 255.0,
                alpha: 0.98
            )
    }

    private func resolvedBorderColor() -> NSColor {
        let isDarkTheme = resolvedAppearance().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDarkTheme
            ? NSColor(calibratedWhite: 1, alpha: 0.055)
            : NSColor(calibratedWhite: 0, alpha: 0.05)
    }

    private func resolvedAppearance() -> NSAppearance {
        window?.appearance
            ?? superview?.effectiveAppearance
            ?? appearance
            ?? NSApp?.effectiveAppearance
            ?? NSAppearance(named: .aqua)!
    }

    fileprivate func resolvedLeadingSymbolImage() -> NSImage? {
        guard let leadingSymbolName else { return nil }
        let image = NSImage(
            systemSymbolName: leadingSymbolName,
            accessibilityDescription: titleOfSelectedItem ?? leadingSymbolName
        )
        return image?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
    }
}

private final class ThemedPopUpButtonCell: NSPopUpButtonCell {
    private let horizontalInset: CGFloat = 4
    private let trailingArrowInset: CGFloat = 8
    private let centeredContentInset: CGFloat = 10
    private let leadingIconInset: CGFloat = 8
    private let leadingIconSize: CGFloat = 12
    private let leadingIconSpacing: CGFloat = 4

    override func drawBorderAndBackground(withFrame cellFrame: NSRect, in controlView: NSView) {
        // The control view draws its own rounded container.
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        let hasLeadingIcon = (controlView as? ThemedPopUpButton)?.leadingSymbolName != nil
        if hasLeadingIcon {
            let leadingInset = leadingIconInset + leadingIconSize + leadingIconSpacing
            return NSRect(
                x: rect.minX + leadingInset,
                y: rect.minY,
                width: max(0, rect.width - leadingInset - (trailingArrowInset + 6)),
                height: rect.height
            )
        }
        let contentInset = max(horizontalInset, centeredContentInset)
        return NSRect(
            x: rect.minX + contentInset,
            y: rect.minY,
            width: max(0, rect.width - contentInset - max(contentInset, trailingArrowInset + 8)),
            height: rect.height
        )
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let textRect = titleRect(forBounds: cellFrame)
        let title = attributedTitle
        let titleSize = title.size()
        if let popup = controlView as? ThemedPopUpButton,
           let icon = popup.resolvedLeadingSymbolImage()?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: leadingIconSize, weight: .medium)
           ) {
            let iconRect = NSRect(
                x: cellFrame.minX + leadingIconInset,
                y: cellFrame.midY - leadingIconSize / 2,
                width: leadingIconSize,
                height: leadingIconSize
            )
            let tintedIcon = icon.copy() as? NSImage
            tintedIcon?.isTemplate = true
            popup.resolvedForegroundColor().set()
            tintedIcon?.draw(
                in: iconRect.integral,
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )

            let drawRect = NSRect(
                x: textRect.minX,
                y: textRect.midY - titleSize.height / 2,
                width: min(textRect.width, titleSize.width),
                height: titleSize.height
            )
            title.draw(in: drawRect.integral)
            return
        }

        let drawRect = NSRect(
            x: textRect.midX - min(textRect.width, titleSize.width) / 2,
            y: textRect.midY - titleSize.height / 2,
            width: min(textRect.width, titleSize.width),
            height: titleSize.height
        )

        title.draw(in: drawRect.integral)
    }

    override func cellSize(forBounds aRect: NSRect) -> NSSize {
        let baseSize = super.cellSize(forBounds: aRect)
        return NSSize(
            width: baseSize.width + 2,
            height: baseSize.height
        )
    }
}

@MainActor
final class ShortcutRecorderField: NSButton {
    var shortcut: ActivationShortcut = .default {
        didSet {
            if !isRecordingShortcut {
                previewShortcut = nil
            }
            updateAppearance()
        }
    }

    private(set) var isRecordingShortcut = false
    private var previewShortcut: ActivationShortcut?
    private var recorderState = ShortcutRecorderState()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setButtonType(.momentaryPushIn)
        bezelStyle = .rounded
        controlSize = .regular
        font = .systemFont(ofSize: 12.5, weight: .semibold)
        wantsLayer = true
        focusRingType = .default
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            isRecordingShortcut = true
            recorderState.reset()
            previewShortcut = nil
            updateAppearance()
        }
        return didBecome
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            isRecordingShortcut = false
            recorderState.reset()
            previewShortcut = nil
            updateAppearance()
        }
        return didResign
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handleKeyDownEvent(event)
        return isRecordingShortcut && !event.isARepeat
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }

        handleKeyDownEvent(event)
    }

    override func keyUp(with event: NSEvent) {
        guard isRecordingShortcut else { return }
        applyRecorderResult(recorderState.handleKeyUp(event.keyCode, modifiers: event.modifierFlags))
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecordingShortcut else { return }

        applyRecorderResult(recorderState.handleFlagsChanged(event.modifierFlags))
    }

    private func handleKeyDownEvent(_ event: NSEvent) {
        guard isRecordingShortcut else { return }
        guard !event.isARepeat else { return }

        applyRecorderResult(recorderState.handleKeyDown(event.keyCode, modifiers: event.modifierFlags))
    }

    private func applyRecorderResult(_ result: ShortcutRecorderResult) {
        previewShortcut = result.previewShortcut

        if let committedShortcut = result.committedShortcut, !committedShortcut.isEmpty {
            shortcut = committedShortcut
            sendAction(action, to: target)
            window?.makeFirstResponder(nil)
            return
        }

        updateAppearance()
    }

    private func updateAppearance() {
        if isRecordingShortcut {
            title = previewShortcut?.displayString ?? "Type Shortcut…"
        } else {
            title = shortcut.displayString
        }
    }
}

extension NSColor {
    func lighter(by amount: CGFloat = 0.18) -> NSColor {
        blended(withFraction: amount, of: .white) ?? self
    }

    func darker(by amount: CGFloat = 0.18) -> NSColor {
        blended(withFraction: amount, of: .black) ?? self
    }
}
