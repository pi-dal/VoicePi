import AppKit
import Foundation

@MainActor
final class AppUpdatePanelController: NSWindowController, NSWindowDelegate {
    private let titleLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "")
    private let strategyLabel = NSTextField(labelWithString: "")
    private let progressLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let releaseNotesTitleLabel = NSTextField(labelWithString: "Release Notes")
    private let releaseNotesTextView = NSTextView(
        frame: NSRect(
            x: 0,
            y: 0,
            width: SettingsLayoutMetrics.updatePanelWidth
                - (SettingsLayoutMetrics.updatePanelOuterInset * 2)
                - (SettingsLayoutMetrics.cardPaddingHorizontal * 2),
            height: SettingsLayoutMetrics.updatePanelNotesHeight
        )
    )
    private let releaseNotesScrollView = NSScrollView()
    private lazy var primaryButton = StyledSettingsButton(
        title: "",
        role: .primary,
        target: self,
        action: #selector(handlePrimaryAction)
    )
    private lazy var secondaryButton = StyledSettingsButton(
        title: "",
        role: .secondary,
        target: self,
        action: #selector(handleSecondaryAction)
    )
    private lazy var tertiaryButton = StyledSettingsButton(
        title: "",
        role: .secondary,
        target: self,
        action: #selector(handleTertiaryAction)
    )

    private var primaryRole: AppUpdateActionRole = .dismiss
    private var secondaryRole: AppUpdateActionRole?
    private var tertiaryRole: AppUpdateActionRole?
    private var actionHandler: ((AppUpdateActionRole) -> Void)?
    var interfaceAppearance: NSAppearance? {
        didSet {
            window?.appearance = interfaceAppearance
            syncTheme()
        }
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: SettingsLayoutMetrics.updatePanelWidth,
                height: SettingsLayoutMetrics.updatePanelMinHeight
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoicePi Update"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(
            width: SettingsLayoutMetrics.updatePanelWidth,
            height: SettingsLayoutMetrics.updatePanelMinHeight
        )
        window.titlebarAppearsTransparent = true
        window.center()

        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(
        _ presentation: AppUpdatePanelPresentation,
        actionHandler: @escaping (AppUpdateActionRole) -> Void
    ) {
        self.actionHandler = actionHandler
        syncTheme()
        apply(presentation)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismissPanel() {
        close()
    }

    func windowWillClose(_ notification: Notification) {
        actionHandler = nil
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        syncTheme()

        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.lineBreakMode = .byWordWrapping
        summaryLabel.maximumNumberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 11.5, weight: .semibold)
        statusLabel.textColor = .secondaryLabelColor
        sourceLabel.font = .systemFont(ofSize: 12)
        sourceLabel.textColor = .secondaryLabelColor
        strategyLabel.font = .systemFont(ofSize: 12)
        strategyLabel.textColor = .secondaryLabelColor
        strategyLabel.lineBreakMode = .byWordWrapping
        strategyLabel.maximumNumberOfLines = 0
        progressLabel.font = .systemFont(ofSize: 11.5)
        progressLabel.textColor = .tertiaryLabelColor
        progressIndicator.controlSize = .small
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.isIndeterminate = false
        releaseNotesTitleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        releaseNotesTextView.isEditable = false
        releaseNotesTextView.isSelectable = true
        releaseNotesTextView.isAutomaticLinkDetectionEnabled = true
        releaseNotesTextView.isHorizontallyResizable = false
        releaseNotesTextView.isVerticallyResizable = true
        releaseNotesTextView.autoresizingMask = [.width]
        releaseNotesTextView.drawsBackground = false
        releaseNotesTextView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        releaseNotesTextView.textContainerInset = NSSize(width: 0, height: 4)
        releaseNotesTextView.textColor = .secondaryLabelColor
        releaseNotesTextView.font = .systemFont(ofSize: 12)
        releaseNotesTextView.minSize = NSSize(
            width: releaseNotesTextView.frame.width,
            height: SettingsLayoutMetrics.updatePanelNotesHeight
        )
        releaseNotesTextView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        releaseNotesTextView.textContainer?.containerSize = NSSize(
            width: releaseNotesTextView.frame.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        releaseNotesTextView.textContainer?.widthTracksTextView = true
        releaseNotesScrollView.drawsBackground = false
        releaseNotesScrollView.hasVerticalScroller = true
        releaseNotesScrollView.hasHorizontalScroller = false
        releaseNotesScrollView.documentView = releaseNotesTextView
        releaseNotesScrollView.translatesAutoresizingMaskIntoConstraints = false
        releaseNotesScrollView.heightAnchor.constraint(
            equalToConstant: SettingsLayoutMetrics.updatePanelNotesHeight
        ).isActive = true

        let statusPill = ThemedSurfaceView(style: .pill)
        statusPill.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -10),
            statusLabel.topAnchor.constraint(equalTo: statusPill.topAnchor, constant: 4),
            statusLabel.bottomAnchor.constraint(equalTo: statusPill.bottomAnchor, constant: -4)
        ])

        let headerRow = NSStackView(views: [titleLabel, NSView(), statusPill])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 10

        let detailStack = NSStackView(views: [sourceLabel, strategyLabel])
        detailStack.orientation = .vertical
        detailStack.spacing = 4
        detailStack.alignment = .leading

        let progressStack = NSStackView(views: [progressLabel, progressIndicator])
        progressStack.orientation = .vertical
        progressStack.spacing = 6
        progressStack.alignment = .leading

        let notesStack = NSStackView(views: [releaseNotesTitleLabel, releaseNotesScrollView])
        notesStack.orientation = .vertical
        notesStack.spacing = 8
        notesStack.alignment = .leading

        let buttonRow = NSStackView(views: [primaryButton, secondaryButton, tertiaryButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY

        let container = ThemedSurfaceView(style: .card)
        container.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView(views: [headerRow, summaryLabel, detailStack, progressStack, notesStack, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        contentView.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SettingsLayoutMetrics.updatePanelOuterInset),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SettingsLayoutMetrics.updatePanelOuterInset),
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SettingsLayoutMetrics.updatePanelOuterInset),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SettingsLayoutMetrics.updatePanelOuterInset),

            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: SettingsLayoutMetrics.cardPaddingHorizontal),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -SettingsLayoutMetrics.cardPaddingHorizontal),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: SettingsLayoutMetrics.cardPaddingVertical),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -SettingsLayoutMetrics.cardPaddingVertical),

            progressIndicator.widthAnchor.constraint(equalTo: stack.widthAnchor),
            releaseNotesScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func syncTheme() {
        guard let window, let contentView = window.contentView else { return }
        window.appearance = interfaceAppearance
        let appearance = interfaceAppearance ?? window.effectiveAppearance
        let pageBackgroundColor = PanelTheme.pageBackground(for: appearance)
        window.backgroundColor = pageBackgroundColor
        contentView.layer?.backgroundColor = pageBackgroundColor.cgColor
    }

    private func apply(_ presentation: AppUpdatePanelPresentation) {
        titleLabel.stringValue = presentation.title
        summaryLabel.stringValue = presentation.summary
        statusLabel.stringValue = presentation.statusText
        sourceLabel.stringValue = presentation.sourceText
        strategyLabel.stringValue = presentation.strategyText

        primaryButton.title = presentation.primaryAction.title
        primaryButton.isEnabled = presentation.primaryAction.isEnabled
        primaryButton.applyAppearance(isSelected: false)
        primaryRole = presentation.primaryAction.role

        if let secondary = presentation.secondaryAction {
            secondaryButton.isHidden = false
            secondaryButton.title = secondary.title
            secondaryButton.isEnabled = secondary.isEnabled
            secondaryButton.applyAppearance(isSelected: false)
            secondaryRole = secondary.role
        } else {
            secondaryButton.isHidden = true
            secondaryButton.isEnabled = false
            secondaryRole = nil
        }

        if let tertiary = presentation.tertiaryAction {
            tertiaryButton.isHidden = false
            tertiaryButton.title = tertiary.title
            tertiaryButton.isEnabled = tertiary.isEnabled
            tertiaryButton.applyAppearance(isSelected: false)
            tertiaryRole = tertiary.role
        } else {
            tertiaryButton.isHidden = true
            tertiaryButton.isEnabled = false
            tertiaryRole = nil
        }

        if let progress = presentation.progress {
            progressLabel.isHidden = false
            progressIndicator.isHidden = false
            progressLabel.stringValue = progress.label
            progressIndicator.isIndeterminate = progress.isIndeterminate
            if progress.isIndeterminate {
                progressIndicator.startAnimation(nil)
            } else {
                progressIndicator.stopAnimation(nil)
                progressIndicator.doubleValue = progress.fraction ?? 0
            }
        } else {
            progressLabel.isHidden = true
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(nil)
        }

        if let notes = presentation.releaseNotes {
            releaseNotesTitleLabel.isHidden = false
            releaseNotesScrollView.isHidden = false
            releaseNotesTextView.textStorage?.setAttributedString(
                AppUpdateReleaseNotesRenderer.attributedString(from: notes)
            )
            releaseNotesTextView.sizeToFit()
        } else {
            releaseNotesTitleLabel.isHidden = true
            releaseNotesScrollView.isHidden = true
            releaseNotesTextView.string = ""
        }
    }

    @objc
    private func handlePrimaryAction() {
        actionHandler?(primaryRole)
    }

    @objc
    private func handleSecondaryAction() {
        if let secondaryRole {
            actionHandler?(secondaryRole)
        }
    }

    @objc
    private func handleTertiaryAction() {
        if let tertiaryRole {
            actionHandler?(tertiaryRole)
        }
    }
}

@MainActor
final class PreviewSheetWindow: NSWindow {
    var onCloseRequest: (() -> Void)?

    override func performClose(_ sender: Any?) {
        if let onCloseRequest {
            onCloseRequest()
        } else {
            super.performClose(sender)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        if let onCloseRequest {
            onCloseRequest()
        } else {
            super.cancelOperation(sender)
        }
    }
}
