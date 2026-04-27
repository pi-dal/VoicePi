import AppKit
import QuartzCore

struct DictionarySuggestionToastPayload: Equatable {
    let sessionID: UUID
    let suggestion: DictionarySuggestion
    let summaryText: String

    init(
        sessionID: UUID,
        suggestion: DictionarySuggestion,
        summaryText: String? = nil
    ) {
        self.sessionID = sessionID
        self.suggestion = suggestion
        self.summaryText = summaryText ?? "Saved to suggestions. Approve now or review later."
    }
}

@MainActor
final class DictionarySuggestionToastController: NSWindowController {
    static let approveTitle = "Approve"
    static let reviewTitle = "Review"
    static let dismissTitle = "Dismiss"

    private let panelWidth: CGFloat = 420
    private let panelHeight: CGFloat = 130
    private let bottomInset: CGFloat = 58

    private let titleLabel = NSTextField(labelWithString: "Dictionary suggestion captured")
    private let summaryLabel = NSTextField(labelWithString: "")
    private lazy var approveButton = StyledSettingsButton(
        title: Self.approveTitle,
        role: .primary,
        target: self,
        action: #selector(approveClicked)
    )
    private lazy var reviewButton = StyledSettingsButton(
        title: Self.reviewTitle,
        role: .secondary,
        target: self,
        action: #selector(reviewClicked)
    )
    private lazy var dismissButton = StyledSettingsButton(
        title: Self.dismissTitle,
        role: .secondary,
        target: self,
        action: #selector(dismissClicked)
    )
    private let rootView = NSView()
    private let blurView = PanelSurfaceView()

    private(set) var currentPayload: DictionarySuggestionToastPayload?
    private(set) var lastPresentedSessionID: UUID?

    var onApprove: ((DictionarySuggestion) -> Void)?
    var onReview: ((DictionarySuggestion) -> Void)?
    var onDismiss: ((DictionarySuggestion) -> Void)?

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 130),
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

    var actionTitles: [String] {
        [approveButton.title, reviewButton.title, dismissButton.title]
    }

    var summaryText: String {
        summaryLabel.stringValue
    }

    var isToastVisible: Bool {
        window?.isVisible == true
    }

    func applyInterfaceTheme(_ theme: InterfaceTheme) {
        window?.appearance = theme.appearance
        syncAppearance()
    }

    func show(payload: DictionarySuggestionToastPayload) {
        if lastPresentedSessionID == payload.sessionID {
            return
        }

        currentPayload = payload
        lastPresentedSessionID = payload.sessionID
        summaryLabel.stringValue = payload.summaryText
        positionPanel()

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

    func performApprove() {
        guard let payload = currentPayload else { return }
        hide()
        onApprove?(payload.suggestion)
    }

    func performReview() {
        guard let payload = currentPayload else { return }
        hide()
        onReview?(payload.suggestion)
    }

    func performDismiss() {
        guard let payload = currentPayload else { return }
        hide()
        onDismiss?(payload.suggestion)
    }

    private func buildUI() {
        rootView.wantsLayer = true

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer?.cornerRadius = 18
        blurView.layer?.masksToBounds = true
        blurView.layer?.borderWidth = 1

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14.5, weight: .semibold)

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = .systemFont(ofSize: 12.5, weight: .regular)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.maximumNumberOfLines = 1

        configureButton(approveButton, action: #selector(approveClicked))
        configureButton(reviewButton, action: #selector(reviewClicked))
        configureButton(dismissButton, action: #selector(dismissClicked))

        let buttonRow = NSStackView(views: [approveButton, reviewButton, dismissButton])
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY

        rootView.addSubview(blurView)
        blurView.addSubview(titleLabel)
        blurView.addSubview(summaryLabel)
        blurView.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: rootView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: blurView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: blurView.topAnchor, constant: 12),

            summaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            summaryLabel.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -16),
            summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            buttonRow.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            buttonRow.trailingAnchor.constraint(lessThanOrEqualTo: blurView.trailingAnchor, constant: -16),
            buttonRow.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 12),
            buttonRow.bottomAnchor.constraint(equalTo: blurView.bottomAnchor, constant: -12)
        ])

        syncAppearance()
    }

    private func configureButton(_ button: NSButton, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = action
        button.setContentHuggingPriority(.required, for: .horizontal)
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
    private func approveClicked() {
        performApprove()
    }

    @objc
    private func reviewClicked() {
        performReview()
    }

    @objc
    private func dismissClicked() {
        performDismiss()
    }

    private func syncAppearance() {
        let appearance = window?.effectiveAppearance ?? rootView.effectiveAppearance
        let cardChrome = PanelTheme.surfaceChrome(for: appearance, style: .card)
        blurView.layer?.backgroundColor = cardChrome.background.cgColor
        blurView.layer?.borderColor = cardChrome.border.cgColor
        titleLabel.textColor = PanelTheme.titleText(for: appearance)
        summaryLabel.textColor = PanelTheme.subtitleText(for: appearance)
        approveButton.applyAppearance(isSelected: false)
        reviewButton.applyAppearance(isSelected: false)
        dismissButton.applyAppearance(isSelected: false)
    }
}
