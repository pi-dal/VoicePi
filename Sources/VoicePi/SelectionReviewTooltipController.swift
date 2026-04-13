import AppKit
import QuartzCore

struct SelectionReviewTooltipPayload: Equatable {
    private static let titleCharacterLimit = 56
    private static let summaryCharacterLimit = 84
    private static let buttonTitleCharacterLimit = 28

    let titleText: String
    let summaryText: String
    let regenerateButtonTitle: String
    let dismissButtonTitle: String

    init(
        titleText: String = "Selection matches latest VoicePi text",
        summaryText: String = "Open the review panel to regenerate from the original transcript.",
        regenerateButtonTitle: String = "Review",
        dismissButtonTitle: String = "Later"
    ) {
        self.titleText = Self.truncatedText(
            titleText,
            limit: Self.titleCharacterLimit
        )
        self.summaryText = Self.truncatedText(
            summaryText,
            limit: Self.summaryCharacterLimit
        )
        self.regenerateButtonTitle = Self.truncatedText(
            regenerateButtonTitle,
            limit: Self.buttonTitleCharacterLimit
        )
        self.dismissButtonTitle = Self.truncatedText(
            dismissButtonTitle,
            limit: Self.buttonTitleCharacterLimit
        )
    }

    private static func truncatedText(_ rawText: String, limit: Int) -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return String(trimmed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

@MainActor
final class SelectionReviewTooltipController: NSWindowController {
    private let panelWidth: CGFloat = 448
    private let panelHeight: CGFloat = 132
    private let bottomInset: CGFloat = 58

    private let rootView = NSView()
    private let blurView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(wrappingLabelWithString: "")
    private let regenerateButton = NSButton(title: "", target: nil, action: nil)
    private let dismissButton = NSButton(title: "", target: nil, action: nil)

    private(set) var currentPayload: SelectionReviewTooltipPayload?

    var onRegenerateRequested: (() -> Void)?
    var onDismissRequested: (() -> Void)?

    var isTooltipVisible: Bool {
        window?.isVisible == true
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

    func show(payload: SelectionReviewTooltipPayload) {
        currentPayload = payload
        titleLabel.stringValue = payload.titleText
        summaryLabel.stringValue = payload.summaryText
        regenerateButton.title = payload.regenerateButtonTitle
        dismissButton.title = payload.dismissButtonTitle
        syncAppearance()
        if RuntimeEnvironment.isRunningTests {
            return
        }
        positionPanel()

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

    func performRegenerate() {
        hide()
        onRegenerateRequested?()
    }

    func performDismiss() {
        hide()
        onDismissRequested?()
    }

    private func buildUI() {
        rootView.wantsLayer = true

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.material = .hudWindow
        blurView.state = .active
        blurView.blendingMode = .withinWindow
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 18
        blurView.layer?.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14.5, weight: .semibold)
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = .systemFont(ofSize: 12.5, weight: .regular)
        summaryLabel.maximumNumberOfLines = 1
        summaryLabel.lineBreakMode = .byTruncatingTail

        configureButtons()

        let actionRow = NSStackView(views: [regenerateButton, dismissButton])
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.distribution = .fill
        actionRow.spacing = 8

        rootView.addSubview(blurView)
        blurView.addSubview(titleLabel)
        blurView.addSubview(summaryLabel)
        blurView.addSubview(actionRow)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: rootView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: blurView.topAnchor, constant: 12),

            summaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            summaryLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            actionRow.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            actionRow.trailingAnchor.constraint(lessThanOrEqualTo: titleLabel.trailingAnchor),
            actionRow.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 10),
            actionRow.bottomAnchor.constraint(equalTo: blurView.bottomAnchor, constant: -12),

            regenerateButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            regenerateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 132),
            regenerateButton.widthAnchor.constraint(lessThanOrEqualToConstant: 240),

            dismissButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
    }

    private func configureButtons() {
        OverlayButtonStyler.configureBase(
            regenerateButton,
            action: #selector(regenerateClicked),
            target: self,
            font: .systemFont(ofSize: 13, weight: .semibold)
        )
        regenerateButton.image = NSImage(
            systemSymbolName: "doc.text.magnifyingglass",
            accessibilityDescription: "Review"
        )
        regenerateButton.imagePosition = .imageLeading
        regenerateButton.imageHugsTitle = true
        regenerateButton.imageScaling = .scaleProportionallyDown
        if let cell = regenerateButton.cell as? NSButtonCell {
            cell.wraps = false
            cell.lineBreakMode = .byTruncatingTail
        }

        OverlayButtonStyler.configureBase(
            dismissButton,
            action: #selector(dismissClicked),
            target: self,
            font: .systemFont(ofSize: 12.5, weight: .medium)
        )
    }

    private func syncAppearance() {
        let appearance = window?.effectiveAppearance ?? rootView.effectiveAppearance
        let isDarkTheme = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        if isDarkTheme {
            blurView.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.96).cgColor
            blurView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
            titleLabel.textColor = NSColor.white.withAlphaComponent(0.96)
            summaryLabel.textColor = NSColor.white.withAlphaComponent(0.75)
        } else {
            blurView.layer?.backgroundColor = NSColor(calibratedRed: 0xF5 / 255.0, green: 0xF3 / 255.0, blue: 0xED / 255.0, alpha: 0.96).cgColor
            blurView.layer?.borderColor = NSColor(calibratedWhite: 0.0, alpha: 0.08).cgColor
            titleLabel.textColor = NSColor(calibratedWhite: 0.13, alpha: 1)
            summaryLabel.textColor = NSColor(calibratedWhite: 0.2, alpha: 0.82)
        }

        blurView.layer?.borderWidth = 1
        OverlayButtonStyler.style(
            regenerateButton,
            role: .primary,
            appearance: appearance,
            cornerRadius: 15
        )
        OverlayButtonStyler.style(
            dismissButton,
            role: .secondary,
            appearance: appearance,
            cornerRadius: 14
        )
    }

    private func positionPanel() {
        guard let panel = window else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel.setFrame(
            NSRect(
                x: round(visibleFrame.midX - panelWidth / 2),
                y: round(visibleFrame.minY + bottomInset),
                width: panelWidth,
                height: panelHeight
            ),
            display: true
        )
    }

    @objc
    private func regenerateClicked() {
        performRegenerate()
    }

    @objc
    private func dismissClicked() {
        performDismiss()
    }
}
