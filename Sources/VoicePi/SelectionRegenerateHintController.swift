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
        actionTitle: String = "Regenerate",
        anchorRectInScreen: NSRect? = nil
    ) {
        self.sessionID = sessionID
        self.selectedText = selectedText
        self.hintText = hintText ?? "Regenerate selection"
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
    let material: NSVisualEffectView.Material
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
        let isDarkTheme = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        material = .underWindowBackground

        if isDarkTheme {
            backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 0.96)
            borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.10)
            titleColor = NSColor.white.withAlphaComponent(0.97)
            subtitleColor = NSColor.white.withAlphaComponent(0.70)
            badgeBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
            badgeBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12)
            badgeSymbolColor = NSColor.white.withAlphaComponent(0.86)
            primaryButtonBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.14)
            primaryButtonBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.16)
            primaryButtonTextColor = NSColor.white.withAlphaComponent(0.98)
            primaryButtonHoverBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.22)
            primaryButtonHoverBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.24)
            primaryButtonHoverTextColor = NSColor.white
        } else {
            backgroundColor = NSColor(calibratedRed: 0xF4 / 255.0, green: 0xF1 / 255.0, blue: 0xE9 / 255.0, alpha: 0.97)
            borderColor = NSColor(calibratedWhite: 0.0, alpha: 0.08)
            titleColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
            subtitleColor = NSColor(calibratedWhite: 0.28, alpha: 0.90)
            badgeBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.52)
            badgeBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.70)
            badgeSymbolColor = NSColor(calibratedWhite: 0.18, alpha: 0.95)
            primaryButtonBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.70)
            primaryButtonBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.76)
            primaryButtonTextColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
            primaryButtonHoverBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.92)
            primaryButtonHoverBorderColor = NSColor(calibratedWhite: 1.0, alpha: 0.98)
            primaryButtonHoverTextColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
        }
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
        setButtonType(.momentaryPushIn)
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.borderWidth = 1
        image = NSImage(
            systemSymbolName: "arrow.triangle.2.circlepath",
            accessibilityDescription: "Regenerate"
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
    private let blurView = NSVisualEffectView()
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
        blurView.state = .active
        blurView.blendingMode = .withinWindow
        blurView.wantsLayer = true
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
            accessibilityDescription: "VoicePi regenerate"
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

        blurView.material = palette.material
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
