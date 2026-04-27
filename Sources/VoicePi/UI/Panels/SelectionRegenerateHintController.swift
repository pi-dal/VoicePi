import AppKit
import QuartzCore

struct SelectionRegenerateHintPayload: Equatable {
    let sessionID: UUID
    let selectedText: String
    let hintText: String
    let actionTitle: String
    let anchorRectInScreen: NSRect?

    init(
        sessionID: UUID,
        selectedText: String,
        hintText: String? = nil,
        actionTitle: String = "Review",
        anchorRectInScreen: NSRect? = nil
    ) {
        self.sessionID = sessionID
        self.selectedText = selectedText
        self.hintText = hintText ?? "Review selection"
        self.actionTitle = actionTitle
        self.anchorRectInScreen = anchorRectInScreen
    }
}

enum SelectionRegenerateHintLayout {
    private static let horizontalGap: CGFloat = 10
    private static let verticalGap: CGFloat = 8
    private static let bottomInset: CGFloat = 80
    private static let screenInset: CGFloat = 12

    static func frame(
        for visibleFrame: NSRect,
        anchorRectInScreen: NSRect?,
        panelSize: NSSize
    ) -> NSRect {
        let width = panelSize.width
        let height = panelSize.height

        if let anchorRectInScreen, !anchorRectInScreen.isEmpty {
            var originX = anchorRectInScreen.maxX + horizontalGap
            var originY = anchorRectInScreen.midY - height / 2

            if originX + width > visibleFrame.maxX - screenInset {
                originX = anchorRectInScreen.minX - width - horizontalGap
            }
            if originX < visibleFrame.minX + screenInset {
                originX = min(
                    max(visibleFrame.minX + screenInset, anchorRectInScreen.midX - width / 2),
                    visibleFrame.maxX - width - screenInset
                )
                originY = anchorRectInScreen.maxY + verticalGap
            }

            originY = min(
                max(originY, visibleFrame.minY + screenInset),
                visibleFrame.maxY - height - screenInset
            )

            return NSRect(
                x: round(originX),
                y: round(originY),
                width: width,
                height: height
            )
        }

        return NSRect(
            x: round(visibleFrame.midX - width / 2),
            y: round(visibleFrame.minY + bottomInset),
            width: width,
            height: height
        )
    }
}

struct SelectionRegenerateHintPalette {
    let backgroundColor: NSColor
    let borderColor: NSColor
    let titleColor: NSColor
    let subtitleColor: NSColor
    let badgeBackgroundColor: NSColor
    let badgeBorderColor: NSColor
    let badgeSymbolColor: NSColor
    let primaryButtonBackgroundColor: NSColor
    let primaryButtonBorderColor: NSColor
    let primaryButtonTextColor: NSColor
    let primaryButtonHoverBackgroundColor: NSColor
    let primaryButtonHoverBorderColor: NSColor
    let primaryButtonHoverTextColor: NSColor

    init(appearance: NSAppearance) {
        let cardChrome = PanelTheme.surfaceChrome(for: appearance, style: .card)
        let pillChrome = PanelTheme.surfaceChrome(for: appearance, style: .pill)
        let primaryChrome = PanelTheme.buttonChrome(for: appearance, role: .primary)
        let primaryHoverChrome = PanelTheme.buttonChrome(
            for: appearance,
            role: .primary,
            isHighlighted: true
        )

        backgroundColor = cardChrome.background
        borderColor = cardChrome.border
        titleColor = PanelTheme.titleText(for: appearance)
        subtitleColor = PanelTheme.subtitleText(for: appearance)
        badgeBackgroundColor = pillChrome.background
        badgeBorderColor = pillChrome.border
        badgeSymbolColor = PanelTheme.accent(for: appearance)
        primaryButtonBackgroundColor = primaryChrome.fill
        primaryButtonBorderColor = primaryChrome.border
        primaryButtonTextColor = primaryChrome.text
        primaryButtonHoverBackgroundColor = primaryHoverChrome.fill
        primaryButtonHoverBorderColor = primaryHoverChrome.border
        primaryButtonHoverTextColor = primaryHoverChrome.text
    }
}

private final class SelectionRegenerateHintActionButtonCell: NSButtonCell {
    private let leadingInset: CGFloat
    private let trailingInset: CGFloat

    init(
        leadingInset: CGFloat = 10,
        trailingInset: CGFloat = 6
    ) {
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
        super.init(textCell: "")
        lineBreakMode = .byTruncatingTail
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        NSRect(
            x: rect.minX + leadingInset,
            y: rect.minY,
            width: max(0, rect.width - leadingInset - trailingInset),
            height: rect.height
        )
    }

    override func imageRect(forBounds rect: NSRect) -> NSRect {
        super.imageRect(forBounds: drawingRect(forBounds: rect))
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        super.titleRect(forBounds: drawingRect(forBounds: rect))
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: drawingRect(forBounds: cellFrame), in: controlView)
    }

    override func cellSize(forBounds aRect: NSRect) -> NSSize {
        let baseSize = super.cellSize(forBounds: aRect)
        return NSSize(
            width: baseSize.width + leadingInset + trailingInset,
            height: baseSize.height
        )
    }
}

private final class SelectionRegenerateHintActionButton: NSButton {
    private var trackingAreaRef: NSTrackingArea?
    private var isHovering = false

    var palette: SelectionRegenerateHintPalette? {
        didSet {
            syncAppearance(animated: false)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .inVisibleRect]
        let trackingAreaRef = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingAreaRef)
        self.trackingAreaRef = trackingAreaRef
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
        syncAppearance(animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        syncAppearance(animated: true)
    }

    override var isHighlighted: Bool {
        didSet {
            syncAppearance(animated: true)
        }
    }

    private func configure() {
        cell = SelectionRegenerateHintActionButtonCell()
        setButtonType(.momentaryPushIn)
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.borderWidth = 1
        image = NSImage(
            systemSymbolName: "doc.text.magnifyingglass",
            accessibilityDescription: "Review"
        )
        imagePosition = .imageLeading
        imageScaling = .scaleProportionallyDown
        font = .systemFont(ofSize: 12.5, weight: .semibold)
        setContentHuggingPriority(.required, for: .horizontal)
    }

    private func syncAppearance(animated: Bool) {
        guard let palette else { return }

        let useHoverStyle = isHovering || isHighlighted
        let backgroundColor = useHoverStyle
            ? palette.primaryButtonHoverBackgroundColor
            : palette.primaryButtonBackgroundColor
        let borderColor = useHoverStyle
            ? palette.primaryButtonHoverBorderColor
            : palette.primaryButtonBorderColor
        let textColor = useHoverStyle
            ? palette.primaryButtonHoverTextColor
            : palette.primaryButtonTextColor
        let transform = useHoverStyle
            ? CATransform3DMakeScale(1.02, 1.02, 1)
            : CATransform3DIdentity

        let applyChanges = {
            self.layer?.backgroundColor = backgroundColor.cgColor
            self.layer?.borderColor = borderColor.cgColor
            self.layer?.transform = transform
        }

        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.14)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1))
            applyChanges()
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            applyChanges()
            CATransaction.commit()
        }

        contentTintColor = textColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: textColor,
                .font: font ?? NSFont.systemFont(ofSize: 12.5, weight: .semibold)
            ]
        )
    }
}

@MainActor
final class SelectionRegenerateHintController: NSWindowController {
    private let panelWidth: CGFloat = 312
    private let panelHeight: CGFloat = 96

    private let rootView = NSView()
    private let blurView = PanelSurfaceView()
    private let contentStackView = NSStackView()
    private let textStackView = NSStackView()
    private let badgeView = NSView()
    private let badgeImageView = NSImageView()
    private let hintLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "")
    private let actionButton = SelectionRegenerateHintActionButton()

    private(set) var currentPayload: SelectionRegenerateHintPayload?
    private(set) var lastPresentedSessionID: UUID?

    var onPrimaryAction: ((SelectionRegenerateHintPayload) -> Void)?

    var isHintVisible: Bool {
        window?.isVisible == true
    }

    var displayedPreviewText: String {
        previewLabel.stringValue
    }

    var displayedActionTitle: String {
        actionButton.title
    }

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .none
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false

        super.init(window: panel)
        panel.contentView = rootView
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyInterfaceTheme(_ theme: InterfaceTheme) {
        window?.appearance = theme.appearance
        syncAppearance()
    }

    func show(payload: SelectionRegenerateHintPayload) {
        if let current = currentPayload, current == payload {
            return
        }

        currentPayload = payload
        lastPresentedSessionID = payload.sessionID
        hintLabel.stringValue = payload.hintText
        actionButton.title = payload.actionTitle
        applyPreviewText(for: payload.selectedText)
        syncAppearance()
        positionPanel(anchorRectInScreen: payload.anchorRectInScreen)

        guard let panel = window else { return }
        if RuntimeEnvironment.isRunningTests {
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }
        if panel.isVisible {
            panel.orderFrontRegardless()
            return
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel = window else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1
        currentPayload = nil
    }

    func performPrimaryAction() {
        guard let payload = currentPayload else { return }
        hide()
        onPrimaryAction?(payload)
    }

    @objc
    private func actionButtonClicked() {
        performPrimaryAction()
    }

    private func buildUI() {
        rootView.wantsLayer = true

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer?.cornerRadius = 18
        blurView.layer?.masksToBounds = true
        blurView.layer?.borderWidth = 1

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.orientation = .horizontal
        contentStackView.alignment = .centerY
        contentStackView.spacing = 12
        contentStackView.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)

        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.wantsLayer = true
        badgeView.layer?.cornerRadius = 10
        badgeView.layer?.borderWidth = 1

        badgeImageView.translatesAutoresizingMaskIntoConstraints = false
        badgeImageView.image = NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: "VoicePi review"
        )
        badgeImageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        badgeImageView.imageScaling = .scaleProportionallyDown
        badgeView.addSubview(badgeImageView)

        textStackView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.orientation = .vertical
        textStackView.alignment = .leading
        textStackView.spacing = 3

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 13.5, weight: .semibold)
        hintLabel.lineBreakMode = .byTruncatingTail

        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.font = .systemFont(ofSize: 11.5, weight: .regular)
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.maximumNumberOfLines = 2

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.target = self
        actionButton.action = #selector(actionButtonClicked)

        rootView.addSubview(blurView)
        blurView.addSubview(contentStackView)
        contentStackView.addArrangedSubview(badgeView)
        contentStackView.addArrangedSubview(textStackView)
        contentStackView.addArrangedSubview(actionButton)
        textStackView.addArrangedSubview(hintLabel)
        textStackView.addArrangedSubview(previewLabel)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: rootView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: blurView.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),

            badgeView.widthAnchor.constraint(equalToConstant: 32),
            badgeView.heightAnchor.constraint(equalToConstant: 32),

            badgeImageView.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            badgeImageView.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor),

            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 116),
            actionButton.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func syncAppearance() {
        let appearance = window?.effectiveAppearance ?? rootView.effectiveAppearance
        let palette = SelectionRegenerateHintPalette(appearance: appearance)

        blurView.layer?.backgroundColor = palette.backgroundColor.cgColor
        blurView.layer?.borderColor = palette.borderColor.cgColor
        hintLabel.textColor = palette.titleColor
        previewLabel.textColor = palette.subtitleColor
        badgeView.layer?.backgroundColor = palette.badgeBackgroundColor.cgColor
        badgeView.layer?.borderColor = palette.badgeBorderColor.cgColor
        badgeImageView.contentTintColor = palette.badgeSymbolColor
        actionButton.palette = palette
    }

    private func positionPanel(anchorRectInScreen: NSRect?) {
        guard let panel = window else { return }
        let visibleFrame = visibleFrame(for: anchorRectInScreen)

        let frame = SelectionRegenerateHintLayout.frame(
            for: visibleFrame,
            anchorRectInScreen: anchorRectInScreen,
            panelSize: NSSize(width: panelWidth, height: panelHeight)
        )
        panel.setFrameOrigin(frame.origin)
        panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))
    }

    private func visibleFrame(for anchorRectInScreen: NSRect?) -> NSRect {
        if let anchorRectInScreen, !anchorRectInScreen.isEmpty {
            let anchorPoint = NSPoint(x: anchorRectInScreen.midX, y: anchorRectInScreen.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) }) {
                return screen.visibleFrame
            }
        }

        return NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
    }

    private func applyPreviewText(for text: String) {
        let preview = buildPreview(from: text)
        previewLabel.isHidden = preview == nil
        previewLabel.stringValue = preview ?? ""
    }

    private func buildPreview(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let maximum = 96
        if trimmed.count <= maximum {
            return trimmed
        }
        return String(trimmed.prefix(maximum)) + "…"
    }
}
