import AppKit
import Foundation

final class ResultReviewPanelContentViewController: NSViewController {
    private let rootView = NSView()
    private let cardView = PanelSurfaceView()
    private let headerContainer = NSView()
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let brandStack = NSStackView()
    private let appIconView = NSImageView()
    private let brandLabel = NSTextField(labelWithString: "")

    private let originalRow = NSView()
    private let originalIconView = NSImageView()
    private let originalTextStack = NSStackView()
    private let originalSectionLabel = NSTextField(labelWithString: "")
    private let originalTextLabel = NSTextField(wrappingLabelWithString: "")

    private let promptRow = NSView()
    private let promptIconView = NSImageView()
    private let promptSectionLabel = NSTextField(labelWithString: "")
    private let promptPresetPopup = ThemedPopUpButton()
    private lazy var regenerateButton = StyledSettingsButton(
        title: "",
        role: .secondary,
        target: self,
        action: #selector(regeneratePressed)
    )
    private let interactionHintLabel = NSTextField(labelWithString: "")

    private let answerContainer = NSView()
    private let answerHeader = NSView()
    private let answerHeaderSeparator = NSView()
    private let answerTitleStack = NSStackView()
    private let answerIconView = NSImageView()
    private let answerTitleLabel = NSTextField(labelWithString: "")
    private let outputCopyButton = NSButton(title: "", target: nil, action: nil)
    private let outputScrollView = NSScrollView()
    private let outputTextView = NSTextView()

    private var payload: ResultReviewPanelPayload?
    private var state: ResultReviewPanelPresentationState?
    private var promptSelectionState: ResultReviewPanelPromptSelectionState?

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
        cardView.layer?.cornerRadius = 28
        cardView.layer?.masksToBounds = true
        cardView.layer?.borderWidth = 1

        configureHeader()
        configureOriginalRow()
        configurePromptRow()
        configureAnswerSection()

        let contentStack = NSStackView(views: [headerContainer, originalRow, promptRow, answerContainer])
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
            originalRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            promptRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            answerContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            originalRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            promptRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            answerContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 170)
        ])

        setPayload(
            ResultReviewPanelPayload(
                resultText: "Preview output",
                originalText: "Preview original",
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
        self.payload = payload
        if var promptSelectionState = self.promptSelectionState {
            promptSelectionState.applyPayload(payload)
            self.promptSelectionState = promptSelectionState
        } else {
            self.promptSelectionState = ResultReviewPanelPromptSelectionState(payload: payload)
        }
        state = ResultReviewPanelPresentationState(
            payload: payload,
            promptSelectionState: self.promptSelectionState
        )
        syncState()
    }

    func syncAppearance() {
        cardView.appearance = view.window?.appearance
        let appearance = view.window?.effectiveAppearance ?? view.effectiveAppearance
        let cardChrome = PanelTheme.surfaceChrome(for: appearance, style: .card)
        let rowChrome = PanelTheme.surfaceChrome(for: appearance, style: .row)
        let titleColor = PanelTheme.titleText(for: appearance)
        let subtitleColor = PanelTheme.subtitleText(for: appearance)

        cardView.layer?.backgroundColor = cardChrome.background.cgColor
        cardView.layer?.borderColor = cardChrome.border.cgColor
        answerContainer.layer?.backgroundColor = rowChrome.background.cgColor
        answerContainer.layer?.borderColor = rowChrome.border.cgColor
        answerHeaderSeparator.layer?.backgroundColor = rowChrome.border.cgColor

        brandLabel.textColor = titleColor
        originalIconView.contentTintColor = subtitleColor
        originalSectionLabel.textColor = titleColor
        originalTextLabel.textColor = subtitleColor
        promptIconView.contentTintColor = subtitleColor
        promptSectionLabel.textColor = titleColor
        interactionHintLabel.textColor = subtitleColor
        answerIconView.contentTintColor = subtitleColor
        answerTitleLabel.textColor = titleColor
        outputTextView.textColor = titleColor
        outputTextView.backgroundColor = .clear
        promptPresetPopup.appearance = view.window?.appearance
        promptPresetPopup.syncTheme()

        for button in [outputCopyButton] {
            button.contentTintColor = subtitleColor
        }

        closeButton.contentTintColor = subtitleColor
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

    var isInsertEnabled: Bool {
        state?.isInsertEnabled ?? false
    }

    private func syncState() {
        guard let state else { return }
        brandLabel.stringValue = state.titleText
        originalSectionLabel.stringValue = state.originalSectionTitle
        originalTextLabel.stringValue = state.originalDisplayText
        promptSectionLabel.stringValue = state.promptSectionTitle
        answerTitleLabel.stringValue = state.outputSectionTitle
        outputCopyButton.toolTip = state.outputCopyButtonTitle
        outputCopyButton.isEnabled = !state.outputCopyText.isEmpty
        promptPresetPopup.isEnabled = state.isPromptPickerEnabled
        regenerateButton.title = state.regenerateButtonTitle
        regenerateButton.applyAppearance(isSelected: false)
        regenerateButton.isEnabled = state.isRegenerateEnabled
        if let interactionHintText = state.interactionHintText {
            interactionHintLabel.stringValue = interactionHintText
            interactionHintLabel.isHidden = false
        } else {
            interactionHintLabel.stringValue = ""
            interactionHintLabel.isHidden = true
        }
        reloadPromptPresetPopup(
            options: state.promptOptions,
            selectedPresetID: state.promptPickerSelectedPresetID
        )
        outputTextView.string = state.outputDisplayText
        updateOutputTextLayout()
    }

    private func configureOriginalRow() {
        originalRow.translatesAutoresizingMaskIntoConstraints = false

        originalIconView.translatesAutoresizingMaskIntoConstraints = false
        originalIconView.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Original")
        originalIconView.imageScaling = .scaleProportionallyDown

        originalTextStack.translatesAutoresizingMaskIntoConstraints = false
        originalTextStack.orientation = .vertical
        originalTextStack.alignment = .leading
        originalTextStack.spacing = 2

        originalSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        originalSectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        originalSectionLabel.maximumNumberOfLines = 1

        originalTextLabel.translatesAutoresizingMaskIntoConstraints = false
        originalTextLabel.font = .systemFont(ofSize: 13, weight: .regular)
        originalTextLabel.maximumNumberOfLines = 3
        originalTextLabel.lineBreakMode = .byTruncatingTail

        originalTextStack.addArrangedSubview(originalSectionLabel)
        originalTextStack.addArrangedSubview(originalTextLabel)
        originalRow.addSubview(originalIconView)
        originalRow.addSubview(originalTextStack)

        NSLayoutConstraint.activate([
            originalIconView.leadingAnchor.constraint(equalTo: originalRow.leadingAnchor, constant: 2),
            originalIconView.topAnchor.constraint(equalTo: originalRow.topAnchor, constant: 8),
            originalIconView.widthAnchor.constraint(equalToConstant: 14),
            originalIconView.heightAnchor.constraint(equalToConstant: 14),

            originalTextStack.leadingAnchor.constraint(equalTo: originalIconView.trailingAnchor, constant: 10),
            originalTextStack.trailingAnchor.constraint(equalTo: originalRow.trailingAnchor, constant: -1),
            originalTextStack.topAnchor.constraint(equalTo: originalRow.topAnchor, constant: 6),
            originalTextStack.bottomAnchor.constraint(equalTo: originalRow.bottomAnchor, constant: -6)
        ])
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
        regenerateButton.setContentHuggingPriority(.required, for: .horizontal)
        regenerateButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        interactionHintLabel.translatesAutoresizingMaskIntoConstraints = false
        interactionHintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        interactionHintLabel.lineBreakMode = .byTruncatingTail
        interactionHintLabel.maximumNumberOfLines = 1

        promptRow.addSubview(promptIconView)
        promptRow.addSubview(promptSectionLabel)
        promptRow.addSubview(promptPresetPopup)
        promptRow.addSubview(regenerateButton)
        promptRow.addSubview(interactionHintLabel)

        NSLayoutConstraint.activate([
            promptIconView.leadingAnchor.constraint(equalTo: promptRow.leadingAnchor, constant: 2),
            promptIconView.topAnchor.constraint(greaterThanOrEqualTo: promptRow.topAnchor, constant: 8),
            promptIconView.widthAnchor.constraint(equalToConstant: 14),
            promptIconView.heightAnchor.constraint(equalToConstant: 14),

            regenerateButton.trailingAnchor.constraint(equalTo: promptRow.trailingAnchor, constant: -1),
            regenerateButton.centerYAnchor.constraint(equalTo: promptPresetPopup.centerYAnchor),

            promptSectionLabel.leadingAnchor.constraint(equalTo: promptIconView.trailingAnchor, constant: 10),
            promptSectionLabel.topAnchor.constraint(equalTo: promptRow.topAnchor, constant: 6),
            promptIconView.centerYAnchor.constraint(equalTo: promptSectionLabel.centerYAnchor),

            promptPresetPopup.leadingAnchor.constraint(equalTo: promptSectionLabel.trailingAnchor, constant: 10),
            promptPresetPopup.trailingAnchor.constraint(equalTo: regenerateButton.leadingAnchor, constant: -10),
            promptPresetPopup.centerYAnchor.constraint(equalTo: promptSectionLabel.centerYAnchor),
            promptPresetPopup.heightAnchor.constraint(equalToConstant: 28),
            promptPresetPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 170),

            interactionHintLabel.leadingAnchor.constraint(equalTo: promptSectionLabel.leadingAnchor),
            interactionHintLabel.trailingAnchor.constraint(lessThanOrEqualTo: promptRow.trailingAnchor, constant: -1),
            interactionHintLabel.topAnchor.constraint(equalTo: promptPresetPopup.bottomAnchor, constant: 3),
            interactionHintLabel.bottomAnchor.constraint(equalTo: promptRow.bottomAnchor, constant: -2)
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
        guard var promptSelectionState, let payload else {
            onPromptSelectionChanged?(presetID)
            return
        }
        promptSelectionState.setPendingPromptSelection(to: presetID, options: payload.availablePrompts)
        self.promptSelectionState = promptSelectionState
        onPromptSelectionChanged?(presetID)
        state = ResultReviewPanelPresentationState(
            payload: payload,
            promptSelectionState: promptSelectionState
        )
        syncState()
    }

    @objc
    private func regeneratePressed() {
        let selectedPresetID = promptPresetPopup.selectedItem?.representedObject as? String
        if var promptSelectionState {
            _ = promptSelectionState.consumePendingPromptPresetIDForRegenerate()
            self.promptSelectionState = promptSelectionState
        }
        if let selectedPresetID {
            onPromptSelectionChanged?(selectedPresetID)
        }
        onRegenerateRequested?()
    }

    @objc
    private func outputCopyPressed() {
        onOutputCopyRequested?()
    }
}
