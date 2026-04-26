import AppKit
import Foundation

@MainActor
final class ASRBackendModeChoiceView: NSControl {
    let mode: ASRBackendMode

    var isSelectedChoice = false {
        didSet {
            syncTheme()
        }
    }

    private let iconContainer = NSView()
    private let iconView = NSImageView()
    private let badgeLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(labelWithString: "")
    private let checkmarkView = NSImageView()
    private var trackingAreaRef: NSTrackingArea?
    private var isHovered = false

    init(mode: ASRBackendMode, target: AnyObject?, action: Selector) {
        self.mode = mode
        super.init(frame: .zero)
        self.target = target
        self.action = action
        wantsLayer = true
        focusRingType = .none
        setupUI()
        syncTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        syncTheme()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        syncTheme()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        syncTheme()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        sendAction(action, to: target)
    }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        layer?.masksToBounds = false

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 14

        let iconSymbol = mode.iconSymbolName
        iconView.image = NSImage(systemSymbolName: iconSymbol, accessibilityDescription: mode.title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconContainer.addSubview(iconView)

        badgeLabel.stringValue = mode.subtitle
        badgeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        badgeLabel.lineBreakMode = .byTruncatingTail
        badgeLabel.maximumNumberOfLines = 1

        titleLabel.stringValue = mode.title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 2

        descriptionLabel.stringValue = mode.description
        descriptionLabel.font = .systemFont(ofSize: 11.5)
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 3

        checkmarkView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Selected")
        checkmarkView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.setContentCompressionResistancePriority(.required, for: .horizontal)
        checkmarkView.setContentHuggingPriority(.required, for: .horizontal)

        let headerRow = NSStackView(views: [iconContainer, NSView(), checkmarkView])
        headerRow.orientation = .horizontal
        headerRow.alignment = .top
        headerRow.spacing = 10

        let textStack = NSStackView(views: [badgeLabel, titleLabel, descriptionLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let stack = NSStackView(views: [headerRow, textStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            iconContainer.widthAnchor.constraint(equalToConstant: 52),
            iconContainer.heightAnchor.constraint(equalToConstant: 52),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])
    }

    private func syncTheme() {
        let palette = SettingsWindowTheme.palette(for: effectiveAppearance)
        let baseChrome = SettingsWindowTheme.surfaceChrome(for: effectiveAppearance, style: .row)
        let darkMode = SettingsWindowTheme.isDark(effectiveAppearance)

        let backgroundColor: NSColor
        let borderColor: NSColor
        if isSelectedChoice {
            backgroundColor = palette.accent.withAlphaComponent(darkMode ? 0.13 : 0.10)
            borderColor = palette.accent
        } else if isHovered {
            backgroundColor = darkMode
                ? NSColor.white.withAlphaComponent(0.060)
                : NSColor.black.withAlphaComponent(0.035)
            borderColor = palette.accent.withAlphaComponent(darkMode ? 0.30 : 0.18)
        } else {
            backgroundColor = baseChrome.background
            borderColor = baseChrome.border
        }

        layer?.backgroundColor = backgroundColor.cgColor
        layer?.borderColor = borderColor.cgColor
        layer?.borderWidth = isSelectedChoice ? 1.5 : 1
        layer?.cornerRadius = 16
        layer?.shadowColor = baseChrome.shadowColor.cgColor
        layer?.shadowOpacity = baseChrome.shadowOpacity
        layer?.shadowRadius = baseChrome.shadowRadius
        layer?.shadowOffset = baseChrome.shadowOffset

        iconContainer.layer?.backgroundColor = palette.accent.withAlphaComponent(darkMode ? 0.16 : 0.10).cgColor
        titleLabel.textColor = isSelectedChoice ? palette.titleText : .labelColor
        descriptionLabel.textColor = darkMode
            ? NSColor(calibratedWhite: 1, alpha: 0.70)
            : .secondaryLabelColor
        badgeLabel.textColor = isSelectedChoice ? palette.accent : palette.subtitleText
        iconView.contentTintColor = isSelectedChoice ? palette.accent : palette.subtitleText
        checkmarkView.isHidden = !isSelectedChoice
        checkmarkView.contentTintColor = palette.accent
    }
}

@MainActor
final class LibrarySubviewTabControl: NSView {
    let historyButton = LibrarySubviewTabButton(
        title: "History",
        identifier: "library.subview.button.history",
        indicatorIdentifier: "library.subview.indicator.history"
    )
    let dictionaryButton = LibrarySubviewTabButton(
        title: "Dictionary",
        identifier: "library.subview.button.dictionary",
        indicatorIdentifier: "library.subview.indicator.dictionary"
    )

    var selectedSection: SettingsSection {
        didSet {
            applySelectionState()
        }
    }

    init(
        selectedSection: SettingsSection,
        target: AnyObject?,
        historyAction: Selector,
        dictionaryAction: Selector
    ) {
        self.selectedSection = selectedSection == .dictionary ? .dictionary : .history
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("library.subview.control")
        wantsLayer = true

        historyButton.target = target
        historyButton.action = historyAction
        dictionaryButton.target = target
        dictionaryButton.action = dictionaryAction

        let stack = NSStackView(views: [historyButton, dictionaryButton])
        stack.orientation = .horizontal
        stack.spacing = 0
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            historyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 112),
            dictionaryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 124),
            heightAnchor.constraint(equalToConstant: 42)
        ])

        applySelectionState()
        syncTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        syncTheme()
        applySelectionState()
    }

    private func applySelectionState() {
        historyButton.isSegmentSelected = selectedSection == .history
        dictionaryButton.isSegmentSelected = selectedSection == .dictionary
    }

    private func syncTheme() {
        let darkMode = SettingsWindowTheme.isDark(effectiveAppearance)
        if darkMode {
            layer?.backgroundColor = NSColor(
                calibratedRed: 0x17 / 255.0,
                green: 0x1B / 255.0,
                blue: 0x1D / 255.0,
                alpha: 0.98
            ).cgColor
            layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.06).cgColor
        } else {
            let chrome = SettingsWindowTheme.surfaceChrome(for: effectiveAppearance, style: .pill)
            layer?.backgroundColor = chrome.background.cgColor
            layer?.borderColor = chrome.border.cgColor
        }
        layer?.borderWidth = 1
        layer?.cornerRadius = 8
    }
}

@MainActor
final class ProviderSubviewTabControl: NSView {
    let asrButton = LibrarySubviewTabButton(
        title: "ASR",
        identifier: "provider.subview.button.asr",
        indicatorIdentifier: "provider.subview.indicator.asr"
    )
    let llmButton = LibrarySubviewTabButton(
        title: "LLM",
        identifier: "provider.subview.button.llm",
        indicatorIdentifier: "provider.subview.indicator.llm"
    )

    var selectedSubview: ProviderSubview {
        didSet {
            applySelectionState()
        }
    }

    init(
        selectedSubview: ProviderSubview,
        target: AnyObject?,
        asrAction: Selector,
        llmAction: Selector
    ) {
        self.selectedSubview = selectedSubview
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("provider.subview.control")
        wantsLayer = true

        asrButton.target = target
        asrButton.action = asrAction
        llmButton.target = target
        llmButton.action = llmAction

        let stack = NSStackView(views: [asrButton, llmButton])
        stack.orientation = .horizontal
        stack.spacing = 0
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            asrButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 112),
            llmButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 124),
            heightAnchor.constraint(equalToConstant: 42)
        ])

        applySelectionState()
        syncTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        syncTheme()
        applySelectionState()
    }

    private func applySelectionState() {
        asrButton.isSegmentSelected = selectedSubview == .asr
        llmButton.isSegmentSelected = selectedSubview == .llm
    }

    private func syncTheme() {
        let darkMode = SettingsWindowTheme.isDark(effectiveAppearance)
        if darkMode {
            layer?.backgroundColor = NSColor(
                calibratedRed: 0x17 / 255.0,
                green: 0x1B / 255.0,
                blue: 0x1D / 255.0,
                alpha: 0.98
            ).cgColor
            layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.06).cgColor
        } else {
            let chrome = SettingsWindowTheme.surfaceChrome(for: effectiveAppearance, style: .pill)
            layer?.backgroundColor = chrome.background.cgColor
            layer?.borderColor = chrome.border.cgColor
        }
        layer?.borderWidth = 1
        layer?.cornerRadius = 8
    }
}

@MainActor
final class LibrarySubviewTabButton: NSButton {
    let titleLabel = NSTextField(labelWithString: "")
    let indicatorView = NSView()
    private let displayTitle: String

    var isSegmentSelected = false {
        didSet {
            updateAppearance()
        }
    }

    init(title: String, identifier: String, indicatorIdentifier: String) {
        self.displayTitle = title
        super.init(frame: .zero)
        self.title = ""
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        indicatorView.identifier = NSUserInterfaceItemIdentifier(indicatorIdentifier)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func configure() {
        setButtonType(.momentaryChange)
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        focusRingType = .none
        imagePosition = .noImage
        alignment = .center
        setAccessibilityLabel(displayTitle)

        titleLabel.stringValue = displayTitle
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.wantsLayer = true
        addSubview(titleLabel)
        addSubview(indicatorView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: indicatorView.topAnchor, constant: -8),
            indicatorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            indicatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            indicatorView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            indicatorView.heightAnchor.constraint(equalToConstant: 2)
        ])

        updateAppearance()
    }

    private func updateAppearance() {
        let palette = SettingsWindowTheme.palette(for: effectiveAppearance)
        let isDarkTheme = SettingsWindowTheme.isDark(effectiveAppearance)
        let textColor = isSegmentSelected
            ? palette.accent
            : (isDarkTheme ? NSColor(calibratedWhite: 0.82, alpha: 1) : palette.titleText)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = textColor
        indicatorView.isHidden = !isSegmentSelected
        indicatorView.layer?.backgroundColor = palette.accent.cgColor
        indicatorView.layer?.cornerRadius = 1
    }
}
