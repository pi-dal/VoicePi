import AppKit
import Foundation

@MainActor
final class StyledSettingsButton: NSButton {
    enum Role {
        case primary
        case secondary
        case navigation
    }

    private let role: Role
    private let navigationHorizontalPadding: CGFloat = 16
    private let navigationVerticalPadding: CGFloat = 8
    private let navigationIndicatorLayer = CALayer()
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false

    init(title: String, role: Role, target: AnyObject?, action: Selector) {
        self.role = role
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        bezelStyle = .regularSquare
        controlSize = .regular
        wantsLayer = true
        focusRingType = .none
        font = .systemFont(ofSize: role == .navigation ? 12 : 13, weight: role == .navigation ? .medium : .semibold)
        imagePosition = role == .navigation ? .imageAbove : .imageLeading
        layer?.masksToBounds = false
        layer?.cornerRadius = role == .navigation ? 0 : 12
        setButtonType(role == .navigation ? .toggle : .momentaryPushIn)
        if role == .navigation {
            imageScaling = .scaleProportionallyDown
            imageHugsTitle = true
            navigationIndicatorLayer.cornerRadius = 1.5
            navigationIndicatorLayer.opacity = 0
            layer?.addSublayer(navigationIndicatorLayer)
        }
        applyAppearance(isSelected: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance(isSelected: role == .navigation && state == .on)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        guard role == .navigation else { return }

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard role == .navigation else { return }
        isHovered = true
        applyAppearance(isSelected: state == .on)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard role == .navigation else { return }
        isHovered = false
        applyAppearance(isSelected: state == .on)
    }

    override func layout() {
        super.layout()

        guard role == .navigation else { return }
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: layer?.cornerRadius ?? 0,
            cornerHeight: layer?.cornerRadius ?? 0,
            transform: nil
        )

        let indicatorWidth = min(max(52, bounds.width * 0.52), bounds.width - 26)
        navigationIndicatorLayer.frame = CGRect(
            x: floor((bounds.width - indicatorWidth) / 2),
            y: bounds.height - 6,
            width: floor(indicatorWidth),
            height: 3
        )
    }

    override var isHighlighted: Bool {
        didSet {
            applyAppearance(isSelected: role == .navigation && state == .on)
        }
    }

    func applyAppearance(isSelected: Bool) {
        let themeRole: SettingsWindowButtonRole
        switch role {
        case .primary:
            themeRole = .primary
        case .secondary:
            themeRole = .secondary
        case .navigation:
            themeRole = .navigation
        }

        let chrome = SettingsWindowTheme.buttonChrome(
            for: effectiveAppearance,
            role: themeRole,
            isSelected: isSelected,
            isHovered: isHovered,
            isHighlighted: isHighlighted
        )
        let borderAlpha = chrome.border.usingColorSpace(.deviceRGB)?.alphaComponent ?? 0
        let accentColor = SettingsWindowTheme.palette(for: effectiveAppearance).accent

        CATransaction.begin()
        CATransaction.setAnimationDuration(role == .navigation ? 0.12 : 0.0)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        layer?.backgroundColor = chrome.fill.cgColor
        layer?.borderWidth = borderAlpha > 0 ? 1 : 0
        layer?.borderColor = chrome.border.cgColor
        layer?.shadowColor = chrome.shadowColor.cgColor
        layer?.shadowOpacity = chrome.shadowOpacity
        layer?.shadowRadius = chrome.shadowRadius
        layer?.shadowOffset = chrome.shadowOffset
        layer?.cornerRadius = chrome.cornerRadius
        if role == .navigation {
            navigationIndicatorLayer.backgroundColor = accentColor.cgColor
            navigationIndicatorLayer.opacity = isSelected ? 1 : 0
        }
        CATransaction.commit()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: chrome.text,
                .font: font ?? NSFont.systemFont(ofSize: role == .navigation ? 12 : 13, weight: .semibold),
                .paragraphStyle: paragraph
            ]
        )
        contentTintColor = chrome.text
        image?.isTemplate = true
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        switch role {
        case .primary, .secondary:
            return NSSize(
                width: base.width + 22,
                height: max(SettingsLayoutMetrics.actionButtonHeight, base.height + 8)
            )
        case .navigation:
            let titleWidth = ceil((attributedTitle.length > 0 ? attributedTitle : NSAttributedString(string: title)).size().width)
            let imageWidth = image.map { ceil($0.size.width) } ?? 0
            let paddedWidth = max(titleWidth, imageWidth) + navigationHorizontalPadding * 2
            return NSSize(
                width: max(SettingsLayoutMetrics.navigationButtonMinWidth, paddedWidth),
                height: max(SettingsLayoutMetrics.navigationButtonHeight, base.height + navigationVerticalPadding * 2)
            )
        }
    }
}

@MainActor
final class AboutActionRowButton: NSButton {
    private let symbolName: String
    private let titleLabel = NSTextField(labelWithString: "")
    private let leadingIconView = NSImageView()
    private let trailingIconView = NSImageView()
    private let contentStack = NSStackView()
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false

    init(title: String, symbolName: String, target: AnyObject?, action: Selector) {
        self.symbolName = symbolName
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        bezelStyle = .regularSquare
        controlSize = .regular
        wantsLayer = true
        focusRingType = .none
        setButtonType(.momentaryPushIn)
        imagePosition = .noImage
        setAccessibilityLabel(title)
        toolTip = title
        attributedTitle = NSAttributedString(string: title)

        leadingIconView.translatesAutoresizingMaskIntoConstraints = false
        leadingIconView.symbolConfiguration = .init(pointSize: 20, weight: .medium)
        leadingIconView.setContentHuggingPriority(.required, for: .horizontal)
        leadingIconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        trailingIconView.translatesAutoresizingMaskIntoConstraints = false
        trailingIconView.image = NSImage(
            systemSymbolName: "arrow.right",
            accessibilityDescription: title
        )?.withSymbolConfiguration(.init(pointSize: 18, weight: .semibold))
        trailingIconView.setContentHuggingPriority(.required, for: .horizontal)
        trailingIconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(leadingIconView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(NSView())
        contentStack.addArrangedSubview(trailingIconView)
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            leadingIconView.widthAnchor.constraint(equalToConstant: 26),
            leadingIconView.heightAnchor.constraint(equalToConstant: 26),
            trailingIconView.widthAnchor.constraint(equalToConstant: 18),
            trailingIconView.heightAnchor.constraint(equalToConstant: 18)
        ])

        applyAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {}

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        applyAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        applyAppearance()
    }

    override var isHighlighted: Bool {
        didSet {
            applyAppearance()
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 300, height: 58)
    }

    private func applyAppearance() {
        let chrome = SettingsWindowTheme.buttonChrome(
            for: effectiveAppearance,
            role: .secondary,
            isSelected: false,
            isHovered: isHovered,
            isHighlighted: isHighlighted
        )
        let borderAlpha = chrome.border.usingColorSpace(.deviceRGB)?.alphaComponent ?? 0

        layer?.backgroundColor = chrome.fill.cgColor
        layer?.borderWidth = borderAlpha > 0 ? 1 : 0
        layer?.borderColor = chrome.border.cgColor
        layer?.shadowColor = chrome.shadowColor.cgColor
        layer?.shadowOpacity = chrome.shadowOpacity
        layer?.shadowRadius = chrome.shadowRadius
        layer?.shadowOffset = chrome.shadowOffset
        layer?.cornerRadius = 14

        let textColor = chrome.text
        titleLabel.textColor = textColor
        leadingIconView.image = preferredLeadingIcon()
        leadingIconView.contentTintColor = textColor
        trailingIconView.contentTintColor = textColor.withAlphaComponent(0.9)
    }

    private func preferredLeadingIcon() -> NSImage? {
        let candidates: [String]
        switch symbolName {
        case "logo.github":
            candidates = [
                "logo.github",
                "chevron.left.forwardslash.chevron.right",
                "link"
            ]
        default:
            candidates = [symbolName]
        }

        return candidates.lazy.compactMap { candidate in
            NSImage(
                systemSymbolName: candidate,
                accessibilityDescription: self.title
            )?.withSymbolConfiguration(.init(pointSize: 20, weight: .medium))
        }.first
    }
}

@MainActor
final class IconOnlySettingsButton: NSButton {
    private let symbolName: String
    private let iconAccessibilityLabel: String

    init(symbolName: String, accessibilityLabel: String, target: AnyObject?, action: Selector) {
        self.symbolName = symbolName
        self.iconAccessibilityLabel = accessibilityLabel
        super.init(frame: .zero)
        self.target = target
        self.action = action
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        bezelStyle = .regularSquare
        controlSize = .regular
        wantsLayer = true
        focusRingType = .none
        setButtonType(.momentaryPushIn)
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        title = ""
        toolTip = accessibilityLabel
        setAccessibilityLabel(accessibilityLabel)
        applyAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    private func applyAppearance() {
        let chrome = SettingsWindowTheme.buttonChrome(
            for: effectiveAppearance,
            role: .secondary,
            isSelected: false,
            isHovered: false,
            isHighlighted: isHighlighted
        )
        let borderAlpha = chrome.border.usingColorSpace(.deviceRGB)?.alphaComponent ?? 0

        layer?.backgroundColor = chrome.fill.cgColor
        layer?.borderWidth = borderAlpha > 0 ? 1 : 0
        layer?.borderColor = chrome.border.cgColor
        layer?.shadowColor = chrome.shadowColor.cgColor
        layer?.shadowOpacity = chrome.shadowOpacity
        layer?.shadowRadius = chrome.shadowRadius
        layer?.shadowOffset = chrome.shadowOffset
        layer?.cornerRadius = chrome.cornerRadius
        contentTintColor = chrome.text
        imagePosition = .imageOnly
        image = [symbolName, "pencil"]
            .lazy
            .compactMap { candidate in
                NSImage(
                    systemSymbolName: candidate,
                    accessibilityDescription: self.iconAccessibilityLabel
                )?.withSymbolConfiguration(.init(pointSize: 13, weight: .semibold))
            }
            .first
        image?.isTemplate = true
    }
}

