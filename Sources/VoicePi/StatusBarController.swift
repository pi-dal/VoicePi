import AppKit
import Foundation

@MainActor
protocol StatusBarControllerDelegate: AnyObject {
    func statusBarControllerDidRequestStartRecording(_ controller: StatusBarController)
    func statusBarControllerDidRequestStopRecording(_ controller: StatusBarController)
    func statusBarController(_ controller: StatusBarController, didSelect language: SupportedLanguage)
    func statusBarController(_ controller: StatusBarController, didSelectASRBackend backend: ASRBackend)
    func statusBarController(_ controller: StatusBarController, didUpdateLLMEnabled enabled: Bool)
    func statusBarController(_ controller: StatusBarController, didSave configuration: LLMConfiguration)
    func statusBarController(_ controller: StatusBarController, didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration)
    func statusBarController(_ controller: StatusBarController, didUpdateActivationShortcut shortcut: ActivationShortcut)
    func statusBarController(_ controller: StatusBarController, didRequestTest configuration: LLMConfiguration) async -> Result<String, Error>
    func statusBarController(_ controller: StatusBarController, didRequestRemoteASRTest configuration: RemoteASRConfiguration) async -> Result<String, Error>
    func statusBarControllerDidRequestOpenAccessibilitySettings(_ controller: StatusBarController)
    func statusBarControllerDidRequestQuit(_ controller: StatusBarController)

    func statusBarControllerDidRequestOpenMicrophoneSettings(_ controller: StatusBarController)
    func statusBarControllerDidRequestOpenSpeechSettings(_ controller: StatusBarController)
    func statusBarControllerDidRequestOpenInputMonitoringSettings(_ controller: StatusBarController)
    func statusBarControllerDidRequestPromptAccessibilityPermission(_ controller: StatusBarController)
    func statusBarControllerDidRequestRefreshPermissions(_ controller: StatusBarController) async
}

@MainActor
final class StatusBarController: NSObject {
    weak var delegate: StatusBarControllerDelegate?

    private let model: AppModel
    private let statusItem: NSStatusItem

    private var menu: NSMenu?
    private weak var languageMenu: NSMenu?
    private weak var llmMenu: NSMenu?
    private weak var statusMenuItem: NSMenuItem?
    private weak var llmToggleItem: NSMenuItem?
    private weak var shortcutMenuItem: NSMenuItem?
    private var languageItems: [SupportedLanguage: NSMenuItem] = [:]

    private var settingsWindowController: SettingsWindowController?

    private var isRecording = false
    private var transientStatus: String?

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        rebuildMenu()
    }

    func start() {
        refreshAll()
    }

    func setRecording(_ recording: Bool) {
        isRecording = recording
        refreshStatusItemAppearance()
        refreshStatusSummary()
    }

    func setTransientStatus(_ text: String?) {
        transientStatus = text
        refreshStatusSummary()
    }

    func refreshAll() {
        refreshStatusItemAppearance()
        refreshLanguageMenuState()
        refreshLLMMenuState()
        refreshStatusSummary()
        settingsWindowController?.reloadFromModel()
    }

    func showSettingsWindow(section: SettingsSection = .home) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                model: model,
                delegate: self
            )
        }

        settingsWindowController?.show(section: section)
        settingsWindowController?.window?.center()
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.toolTip = "VoicePi"
        refreshStatusItemAppearance()
    }

    private func refreshStatusItemAppearance() {
        guard let button = statusItem.button else { return }

        button.image = statusBarIconImage(isRecording: isRecording)
    }

    static func statusBarIconResourceName(isRecording: Bool) -> String {
        "AppIcon"
    }

    private func statusBarIconImage(isRecording: Bool) -> NSImage? {
        let resourceName = Self.statusBarIconResourceName(isRecording: isRecording)

        if let url = Bundle.main.url(forResource: resourceName, withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false
            return image
        }

        let fallbackSymbolName = isRecording ? "mic.circle.fill" : "waveform.circle"
        return NSImage(
            systemSymbolName: fallbackSymbolName,
            accessibilityDescription: "VoicePi"
        )
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let headerItem = NSMenuItem(title: "VoicePi", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let statusSummaryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusSummaryItem.isEnabled = false
        menu.addItem(statusSummaryItem)
        self.statusMenuItem = statusSummaryItem

        menu.addItem(.separator())

        let holdToTalkItem = NSMenuItem(
            title: shortcutMenuTitle(),
            action: nil,
            keyEquivalent: ""
        )
        holdToTalkItem.isEnabled = false
        menu.addItem(holdToTalkItem)
        self.shortcutMenuItem = holdToTalkItem

        menu.addItem(.separator())

        let languageRoot = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu(title: "Language")
        languageRoot.submenu = languageMenu
        menu.addItem(languageRoot)
        self.languageMenu = languageMenu
        rebuildLanguageMenu()

        let llmRoot = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        let llmMenu = NSMenu(title: "LLM Refinement")
        llmRoot.submenu = llmMenu
        menu.addItem(llmRoot)
        self.llmMenu = llmMenu
        rebuildLLMMenu()

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit VoicePi",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        self.menu = menu
        self.statusItem.button?.menu = menu
        self.statusItem.menu = menu

        refreshAll()
    }

    private func rebuildLanguageMenu() {
        guard let languageMenu else { return }

        languageMenu.removeAllItems()
        languageItems.removeAll()

        for language in SupportedLanguage.allCases {
            let item = NSMenuItem(
                title: language.menuTitle,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.rawValue
            item.state = language == model.selectedLanguage ? .on : .off
            languageMenu.addItem(item)
            languageItems[language] = item
        }
    }

    private func rebuildLLMMenu() {
        guard let llmMenu else { return }

        llmMenu.removeAllItems()

        let toggle = NSMenuItem(
            title: "Enable LLM Refinement",
            action: #selector(toggleLLMRefinement(_:)),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = model.llmEnabled ? .on : .off
        llmMenu.addItem(toggle)
        llmToggleItem = toggle

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openLLMSettings),
            keyEquivalent: ""
        )
        settings.target = self
        llmMenu.addItem(settings)

        llmMenu.addItem(.separator())

        let endpointSummary = NSMenuItem(
            title: llmEndpointSummaryText(),
            action: nil,
            keyEquivalent: ""
        )
        endpointSummary.isEnabled = false
        llmMenu.addItem(endpointSummary)

        let modelSummary = NSMenuItem(
            title: llmModelSummaryText(),
            action: nil,
            keyEquivalent: ""
        )
        modelSummary.isEnabled = false
        llmMenu.addItem(modelSummary)
    }

    private func refreshLanguageMenuState() {
        if languageMenu == nil {
            rebuildLanguageMenu()
            return
        }

        for (language, item) in languageItems {
            item.state = language == model.selectedLanguage ? .on : .off
        }
    }

    private func refreshLLMMenuState() {
        llmToggleItem?.state = model.llmEnabled ? .on : .off

        if let llmMenu {
            let items = llmMenu.items
            if items.count >= 5 {
                items[3].title = llmEndpointSummaryText()
                items[4].title = llmModelSummaryText()
            } else {
                rebuildLLMMenu()
            }
        } else {
            rebuildLLMMenu()
        }
    }

    private func shortcutMenuTitle() -> String {
        "Press \(model.activationShortcut.menuTitle) to Start / Press Again to Paste"
    }

    private func refreshStatusSummary() {
        let permissionsSummary = permissionsSummaryText()
        let languageSummary = "Language: \(model.selectedLanguage.menuTitle)"

        let statusText: String
        if let transientStatus, !transientStatus.isEmpty {
            statusText = transientStatus
        } else if isRecording {
            statusText = "Recording…"
        } else if model.recordingState == .refining {
            statusText = "Refining…"
        } else {
            statusText = "Ready"
        }

        statusMenuItem?.title = "\(statusText) • \(languageSummary) • \(permissionsSummary)"
    }

    private func permissionsSummaryText() -> String {
        "Mic \(symbol(for: model.microphoneAuthorization)) / Speech \(symbol(for: model.speechAuthorization)) / AX \(symbol(for: model.accessibilityAuthorization))"
    }

    private func llmEndpointSummaryText() -> String {
        let text = model.llmConfiguration.trimmedBaseURL
        return text.isEmpty ? "API Base URL: Not configured" : "API Base URL: \(text)"
    }

    private func llmModelSummaryText() -> String {
        let text = model.llmConfiguration.trimmedModel
        return text.isEmpty ? "Model: Not configured" : "Model: \(text)"
    }

    private func symbol(for state: AuthorizationState) -> String {
        switch state {
        case .granted:
            return "✓"
        case .denied, .restricted:
            return "✗"
        case .unknown:
            return "…"
        }
    }

    @objc
    private func selectLanguage(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let language = SupportedLanguage(rawValue: rawValue)
        else {
            return
        }

        model.selectedLanguage = language
        refreshLanguageMenuState()
        refreshStatusSummary()
        settingsWindowController?.reloadFromModel()
        delegate?.statusBarController(self, didSelect: language)
    }

    @objc
    private func toggleLLMRefinement(_ sender: NSMenuItem) {
        let next = !model.llmEnabled
        model.llmEnabled = next
        refreshLLMMenuState()
        settingsWindowController?.reloadFromModel()
        delegate?.statusBarController(self, didUpdateLLMEnabled: next)
    }

    @objc
    private func openSettings() {
        showSettingsWindow(section: .home)
    }

    @objc
    private func openLLMSettings() {
        showSettingsWindow(section: .llm)
    }

    @objc
    private func quitApp() {
        delegate?.statusBarControllerDidRequestQuit(self)
    }
}

@MainActor
enum SettingsSection: Int, CaseIterable {
    case home = 0
    case permissions = 1
    case asr = 2
    case llm = 3

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .permissions:
            return "Permissions"
        case .asr:
            return "ASR"
        case .llm:
            return "LLM"
        }
    }
}

@MainActor
protocol SettingsWindowControllerDelegate: AnyObject {
    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSave configuration: LLMConfiguration
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSelectASRBackend backend: ASRBackend
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateActivationShortcut shortcut: ActivationShortcut
    )

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestTest configuration: LLMConfiguration
    ) async -> Result<String, Error>

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestRemoteASRTest configuration: RemoteASRConfiguration
    ) async -> Result<String, Error>

    func settingsWindowControllerDidRequestOpenMicrophoneSettings(_ controller: SettingsWindowController)
    func settingsWindowControllerDidRequestOpenSpeechSettings(_ controller: SettingsWindowController)
    func settingsWindowControllerDidRequestOpenAccessibilitySettings(_ controller: SettingsWindowController)
    func settingsWindowControllerDidRequestOpenInputMonitoringSettings(_ controller: SettingsWindowController)
    func settingsWindowControllerDidRequestPromptAccessibilityPermission(_ controller: SettingsWindowController)
    func settingsWindowControllerDidRequestRefreshPermissions(_ controller: SettingsWindowController) async
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    weak var delegate: SettingsWindowControllerDelegate?

    private let model: AppModel

    private let contentContainer = NSView()

    private let homeView = NSView()
    private let permissionsView = NSView()
    private let asrView = NSView()
    private let llmView = NSView()

    private let homeSummaryLabel = NSTextField(labelWithString: "")
    private let homePermissionSummaryLabel = NSTextField(labelWithString: "")
    private let homeLanguageLabel = NSTextField(labelWithString: "")
    private let homeShortcutLabel = NSTextField(labelWithString: "")
    private let homeASRLabel = NSTextField(labelWithString: "")
    private let homeLLMLabel = NSTextField(labelWithString: "")

    private let shortcutRecorderField = ShortcutRecorderField()
    private let shortcutHintLabel = NSTextField(labelWithString: "")

    private let microphoneStatusLabel = NSTextField(labelWithString: "")
    private let speechStatusLabel = NSTextField(labelWithString: "")
    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let permissionsHintLabel = NSTextField(labelWithString: "")

    private let baseURLField = NSTextField(string: "")
    private let apiKeyField = NSSecureTextField(string: "")
    private let modelField = NSTextField(string: "")
    private let asrBackendPopup = NSPopUpButton()
    private let asrBaseURLField = NSTextField(string: "")
    private let asrAPIKeyField = NSSecureTextField(string: "")
    private let asrModelField = NSTextField(string: "")
    private let asrPromptField = NSTextField(string: "")
    private let llmEnabledCheckbox = NSButton(checkboxWithTitle: "Enable LLM refinement", target: nil, action: nil)
    private let asrStatusLabel = NSTextField(labelWithString: "")
    private let llmStatusLabel = NSTextField(labelWithString: "")

    private let asrTestButton = NSButton(title: "Test Connection", target: nil, action: nil)
    private let asrSaveButton = NSButton(title: "Save", target: nil, action: nil)
    private let testButton = NSButton(title: "Test Connection", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)

    private var sectionButtons: [SettingsSection: NSButton] = [:]
    private var currentSection: SettingsSection = .home

    init(model: AppModel, delegate: SettingsWindowControllerDelegate?) {
        self.model = model
        self.delegate = delegate

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "VoicePi Settings"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 860, height: 620)
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .preference
        }
        window.center()

        super.init(window: window)
        window.delegate = self

        buildUI()
        reloadFromModel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        reloadFromModel()
    }

    func show(section: SettingsSection) {
        showWindow(nil)
        selectSection(section)
    }

    func reloadFromModel() {
        loadCurrentValues()
        refreshPermissionLabels()
        refreshHomeSection()
        refreshASRSection()
        refreshLLMSection()
    }

    func windowWillClose(_ notification: Notification) {
        model.closeSettings()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "VoicePi Settings")
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)

        let subtitleLabel = NSTextField(labelWithString: "A cleaner control center for permissions, dictation, and LLM refinement.")
        subtitleLabel.font = .systemFont(ofSize: 12.5)
        subtitleLabel.textColor = .secondaryLabelColor

        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.orientation = .vertical
        titleStack.spacing = 4
        titleStack.alignment = .leading

        let navigation = makeSectionNavigation()
        navigation.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = NSStackView(views: [titleStack, NSView(), navigation])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 18
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(headerRow)
        contentView.addSubview(separator)
        contentView.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            headerRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            headerRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 18),

            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 64),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -64),
            contentContainer.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 28),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 500)
        ])

        buildHomeView()
        buildPermissionsView()
        buildASRView()
        buildLLMView()

        contentContainer.addSubview(homeView)
        contentContainer.addSubview(permissionsView)
        contentContainer.addSubview(asrView)
        contentContainer.addSubview(llmView)

        [homeView, permissionsView, asrView, llmView].forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
            ])
        }

        selectSection(.home)
    }

    private func buildHomeView() {
        let contentStack = makePageStack()

        let introLabel = makeBodyLabel(
            "Press your chosen shortcut to start dictation, keep speaking hands-free, then press it again to stop and paste into the focused field."
        )

        let introCard = makeFeatureCard(
            icon: "waveform.circle.fill",
            title: "Quick Dictation",
            description: "VoicePi stays lightweight in the menu bar and keeps the main setup in one place."
        )

        let triggerCard = makeFeatureCard(
            icon: "keyboard",
            title: "Trigger",
            description: "Press your chosen shortcut once to start recording. Press it again to stop and inject the transcript."
        )

        homeLanguageLabel.font = .systemFont(ofSize: 13)
        homeLanguageLabel.alignment = .left
        homePermissionSummaryLabel.font = .systemFont(ofSize: 13)
        homePermissionSummaryLabel.alignment = .left
        homePermissionSummaryLabel.lineBreakMode = .byWordWrapping
        homePermissionSummaryLabel.maximumNumberOfLines = 0
        homeShortcutLabel.font = .systemFont(ofSize: 13)
        homeShortcutLabel.alignment = .left
        homeASRLabel.font = .systemFont(ofSize: 13)
        homeASRLabel.alignment = .left
        homeLLMLabel.font = .systemFont(ofSize: 13)
        homeLLMLabel.alignment = .left
        homeSummaryLabel.font = .systemFont(ofSize: 12.5)
        homeSummaryLabel.textColor = .secondaryLabelColor
        homeSummaryLabel.alignment = .left
        homeSummaryLabel.lineBreakMode = .byWordWrapping
        homeSummaryLabel.maximumNumberOfLines = 0

        shortcutRecorderField.target = self
        shortcutRecorderField.action = #selector(shortcutRecorderChanged(_:))
        shortcutHintLabel.font = .systemFont(ofSize: 12)
        shortcutHintLabel.textColor = .secondaryLabelColor
        shortcutHintLabel.alignment = .left
        shortcutHintLabel.lineBreakMode = .byWordWrapping
        shortcutHintLabel.maximumNumberOfLines = 0
        shortcutHintLabel.stringValue = "Click the shortcut field, then press the key combination you want to use."

        let shortcutControl = NSStackView(views: [shortcutRecorderField, shortcutHintLabel])
        shortcutControl.orientation = .vertical
        shortcutControl.spacing = 8
        shortcutControl.alignment = .leading

        let overviewSection = makeGroupedSection(rows: [
            makePreferenceRow(title: "Shortcut", control: shortcutControl),
            makePreferenceRow(title: "Recognition Language", control: homeLanguageLabel),
            makePreferenceRow(title: "Permissions", control: homePermissionSummaryLabel),
            makePreferenceRow(title: "ASR", control: homeASRLabel),
            makePreferenceRow(title: "LLM Refinement", control: homeLLMLabel)
        ])

        let actionsRow = makeButtonGroup([
            makePrimaryActionButton(title: "Open Permissions", action: #selector(openPermissionsSection)),
            makeSecondaryActionButton(title: "Open ASR", action: #selector(openASRSection)),
            makeSecondaryActionButton(title: "Open LLM", action: #selector(openLLMSection)),
            makeSecondaryActionButton(title: "Refresh", action: #selector(refreshPermissions))
        ])
        actionsRow.translatesAutoresizingMaskIntoConstraints = false

        let actionsCard = makeCardView()
        let actionsStack = NSStackView(views: [
            makeSectionTitle("Quick Actions"),
            makeBodyLabel("Jump directly to the parts of settings you are most likely to revisit."),
            actionsRow
        ])
        actionsStack.orientation = .vertical
        actionsStack.spacing = 12
        actionsStack.alignment = .leading
        pinCardContent(actionsStack, into: actionsCard)

        contentStack.addArrangedSubview(makeSectionHeader(title: "General", subtitle: "A roomier, Raycast-inspired overview of your current VoicePi setup."))
        contentStack.addArrangedSubview(introLabel)
        contentStack.addArrangedSubview(makeFeatureStrip([introCard, triggerCard]))
        contentStack.addArrangedSubview(overviewSection)
        contentStack.addArrangedSubview(actionsCard)
        contentStack.addArrangedSubview(homeSummaryLabel)

        homeView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: homeView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: homeView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: homeView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: homeView.bottomAnchor)
        ])
    }

    private func buildPermissionsView() {
        let contentStack = makePageStack()

        permissionsHintLabel.font = .systemFont(ofSize: 12.5)
        permissionsHintLabel.textColor = .secondaryLabelColor
        permissionsHintLabel.alignment = .left
        permissionsHintLabel.lineBreakMode = .byWordWrapping
        permissionsHintLabel.maximumNumberOfLines = 0
        permissionsHintLabel.stringValue = "Refresh after changing a permission in System Settings."

        microphoneStatusLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        microphoneStatusLabel.alignment = .center

        speechStatusLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        speechStatusLabel.alignment = .center

        accessibilityStatusLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        accessibilityStatusLabel.alignment = .center

        let permissionRows = NSStackView(views: [
            makePermissionCard(
                icon: "mic.fill",
                title: "Microphone",
                description: "Required for capturing your voice while you hold the shortcut.",
                statusLabel: microphoneStatusLabel,
                primaryButton: makePrimaryActionButton(title: "Open Settings", action: #selector(openMicrophoneSettings)),
                secondaryButtons: [makeSecondaryActionButton(title: "Refresh", action: #selector(refreshPermissions))]
            ),
            makePermissionCard(
                icon: "waveform",
                title: "Speech Recognition",
                description: "Required for on-device and Apple speech transcription services.",
                statusLabel: speechStatusLabel,
                primaryButton: makePrimaryActionButton(title: "Open Settings", action: #selector(openSpeechSettings)),
                secondaryButtons: [makeSecondaryActionButton(title: "Refresh", action: #selector(refreshPermissions))]
            ),
            makePermissionCard(
                icon: "figure.wave",
                title: "Accessibility",
                description: "Required for global shortcut monitoring and safe paste injection.",
                statusLabel: accessibilityStatusLabel,
                primaryButton: makePrimaryActionButton(title: "Open Settings", action: #selector(openAccessibilitySettingsFromSettings)),
                secondaryButtons: [makeSecondaryActionButton(title: "Prompt Again", action: #selector(promptAccessibilityPermission))]
            )
        ])
        permissionRows.orientation = .vertical
        permissionRows.spacing = 14
        permissionRows.alignment = .leading

        let extraCard = makePermissionCard(
            icon: "slider.horizontal.3",
            title: "Other",
            description: "Input Monitoring can help if you later expand event handling beyond the current setup.",
            statusLabel: nil,
            primaryButton: makePrimaryActionButton(title: "Input Monitoring", action: #selector(openInputMonitoringSettings)),
            secondaryButtons: [makeSecondaryActionButton(title: "Refresh All", action: #selector(refreshPermissions))]
        )

        contentStack.addArrangedSubview(makeSectionHeader(title: "Permissions", subtitle: "Manage the permissions VoicePi needs for recording, recognition, and paste injection."))
        contentStack.addArrangedSubview(permissionsHintLabel)
        contentStack.addArrangedSubview(permissionRows)
        contentStack.addArrangedSubview(extraCard)

        permissionsView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: permissionsView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: permissionsView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: permissionsView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: permissionsView.bottomAnchor)
        ])
    }

    private func buildASRView() {
        let contentStack = makePageStack()

        asrBackendPopup.removeAllItems()
        asrBackendPopup.addItems(withTitles: ASRBackend.allCases.map(\.title))
        asrBackendPopup.target = self
        asrBackendPopup.action = #selector(asrBackendChanged(_:))

        asrBaseURLField.placeholderString = "https://api.example.com/v1"
        asrAPIKeyField.placeholderString = "sk-..."
        asrModelField.placeholderString = "gpt-4o-mini-transcribe"
        asrPromptField.placeholderString = "Optional hint for terminology or context"

        asrStatusLabel.textColor = .secondaryLabelColor
        asrStatusLabel.font = .systemFont(ofSize: 12.5)
        asrStatusLabel.alignment = .left
        asrStatusLabel.lineBreakMode = .byWordWrapping
        asrStatusLabel.maximumNumberOfLines = 0

        asrTestButton.target = self
        asrTestButton.action = #selector(testRemoteASRConfiguration)

        asrSaveButton.target = self
        asrSaveButton.action = #selector(saveRemoteASRConfiguration)
        asrSaveButton.keyEquivalent = "\r"

        let configurationSection = makeGroupedSection(rows: [
            makePreferenceRow(title: "Backend", control: asrBackendPopup),
            makePreferenceRow(title: "API Base URL", control: asrBaseURLField),
            makePreferenceRow(title: "API Key", control: asrAPIKeyField),
            makePreferenceRow(title: "Model", control: asrModelField),
            makePreferenceRow(title: "Prompt", control: asrPromptField)
        ])

        let buttons = makeButtonGroup([
            makeSecondaryActionButton(title: "Test Connection", action: #selector(testRemoteASRConfiguration)),
            makePrimaryActionButton(title: "Save", action: #selector(saveRemoteASRConfiguration))
        ])

        contentStack.addArrangedSubview(makeSectionHeader(title: "ASR", subtitle: "Choose between built-in Apple Speech and a remote OpenAI-compatible transcription model."))
        contentStack.addArrangedSubview(makeBodyLabel("Use the remote backend when you want stronger large-model transcription quality. VoicePi will record locally, upload the captured audio after release, then inject the returned transcript."))
        contentStack.addArrangedSubview(configurationSection)
        contentStack.addArrangedSubview(buttons)
        contentStack.addArrangedSubview(asrStatusLabel)

        asrView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: asrView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: asrView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: asrView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: asrView.bottomAnchor),

            asrBaseURLField.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            asrAPIKeyField.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            asrModelField.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            asrPromptField.widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
    }

    private func buildLLMView() {
        let contentStack = makePageStack()

        baseURLField.placeholderString = "https://api.example.com/v1"
        apiKeyField.placeholderString = "sk-..."
        modelField.placeholderString = "gpt-4o-mini"

        llmEnabledCheckbox.target = self
        llmEnabledCheckbox.action = #selector(toggleLLMCheckbox(_:))

        llmStatusLabel.textColor = .secondaryLabelColor
        llmStatusLabel.font = .systemFont(ofSize: 12.5)
        llmStatusLabel.alignment = .left
        llmStatusLabel.lineBreakMode = .byWordWrapping
        llmStatusLabel.maximumNumberOfLines = 0

        testButton.target = self
        testButton.action = #selector(testConfiguration)

        saveButton.target = self
        saveButton.action = #selector(saveConfiguration)
        saveButton.keyEquivalent = "\r"

        let configurationSection = makeGroupedSection(rows: [
            makePreferenceRow(title: "Enabled", control: llmEnabledCheckbox),
            makePreferenceRow(title: "API Base URL", control: baseURLField),
            makePreferenceRow(title: "API Key", control: apiKeyField),
            makePreferenceRow(title: "Model", control: modelField)
        ])

        let buttons = makeButtonGroup([
            makeSecondaryActionButton(title: "Test Connection", action: #selector(testConfiguration)),
            makePrimaryActionButton(title: "Save", action: #selector(saveConfiguration))
        ])

        contentStack.addArrangedSubview(makeSectionHeader(title: "LLM", subtitle: "Optional conservative cleanup using an OpenAI-compatible endpoint."))
        contentStack.addArrangedSubview(makeBodyLabel("Only use this to correct obvious ASR mistakes. Text that already looks correct should remain unchanged."))
        contentStack.addArrangedSubview(configurationSection)
        contentStack.addArrangedSubview(buttons)
        contentStack.addArrangedSubview(llmStatusLabel)

        llmView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: llmView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: llmView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: llmView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: llmView.bottomAnchor),

            baseURLField.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            apiKeyField.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            modelField.widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
    }

    private func loadCurrentValues() {
        if let index = ASRBackend.allCases.firstIndex(of: model.asrBackend) {
            asrBackendPopup.selectItem(at: index)
        }
        asrBaseURLField.stringValue = model.remoteASRConfiguration.baseURL
        asrAPIKeyField.stringValue = model.remoteASRConfiguration.apiKey
        asrModelField.stringValue = model.remoteASRConfiguration.model
        asrPromptField.stringValue = model.remoteASRConfiguration.prompt
        baseURLField.stringValue = model.llmConfiguration.baseURL
        apiKeyField.stringValue = model.llmConfiguration.apiKey
        modelField.stringValue = model.llmConfiguration.model
        llmEnabledCheckbox.state = model.llmEnabled ? .on : .off

        if !shortcutRecorderField.isRecordingShortcut {
            shortcutRecorderField.shortcut = model.activationShortcut
        }
    }

    private func refreshHomeSection() {
        homeShortcutLabel.stringValue = "Current shortcut: \(model.activationShortcut.menuTitle)"
        homeLanguageLabel.stringValue = "Recognition language: \(model.selectedLanguage.menuTitle)"
        homePermissionSummaryLabel.stringValue = "Permissions: Mic \(statusTitle(for: model.microphoneAuthorization)), Speech \(statusTitle(for: model.speechAuthorization)), Accessibility \(statusTitle(for: model.accessibilityAuthorization))"
        homeASRLabel.stringValue = "ASR backend: \(model.asrBackend.title) • \(model.remoteASRConfiguration.isConfigured ? "Remote configured" : "Remote not configured")"
        homeLLMLabel.stringValue = "LLM refinement: \(model.llmEnabled ? "Enabled" : "Disabled") • \(model.llmConfiguration.isConfigured ? "Configured" : "Not configured")"
        shortcutHintLabel.stringValue = "Current shortcut: \(model.activationShortcut.displayString). Click the field above and press a new combination to replace it."

        if let errorState = model.errorState {
            homeSummaryLabel.stringValue = "Latest status: \(errorState.text)"
            homeSummaryLabel.textColor = .systemRed
        } else {
            homeSummaryLabel.stringValue = "VoicePi is ready to transcribe with the floating overlay, clipboard restoration, and input-method-safe paste flow."
            homeSummaryLabel.textColor = .secondaryLabelColor
        }
    }

    private func refreshASRSection() {
        let configuration = currentRemoteASRConfigurationFromFields()
        let isRemoteBackend = currentSelectedASRBackend() == .remoteOpenAICompatible

        asrBaseURLField.isEnabled = isRemoteBackend
        asrAPIKeyField.isEnabled = isRemoteBackend
        asrModelField.isEnabled = isRemoteBackend
        asrPromptField.isEnabled = isRemoteBackend
        asrTestButton.isEnabled = isRemoteBackend

        if !isRemoteBackend {
            asrStatusLabel.stringValue = "Apple Speech is active. VoicePi will use the built-in streaming recognizer."
        } else if configuration.isConfigured {
            asrStatusLabel.stringValue = "Remote large-model ASR is selected and configured."
        } else {
            asrStatusLabel.stringValue = "Remote large-model ASR is selected, but API Base URL, API Key, and Model are still required."
        }
    }

    private func refreshPermissionLabels() {
        microphoneStatusLabel.stringValue = permissionStatusText(for: model.microphoneAuthorization)
        speechStatusLabel.stringValue = permissionStatusText(for: model.speechAuthorization)
        accessibilityStatusLabel.stringValue = permissionStatusText(for: model.accessibilityAuthorization)
    }

    private func refreshLLMSection() {
        let configuration = currentConfigurationFromFields()
        let enabled = llmEnabledCheckbox.state == .on

        if enabled && configuration.isConfigured {
            llmStatusLabel.stringValue = "LLM refinement is enabled and configured."
        } else if enabled {
            llmStatusLabel.stringValue = "LLM refinement is enabled, but API Base URL, API Key, and Model are still required."
        } else {
            llmStatusLabel.stringValue = "LLM refinement is disabled. Enable it if you want conservative transcript cleanup before paste."
        }
    }

    private func currentConfigurationFromFields() -> LLMConfiguration {
        LLMConfiguration(
            baseURL: baseURLField.stringValue,
            apiKey: apiKeyField.stringValue,
            model: modelField.stringValue
        )
    }

    private func currentSelectedASRBackend() -> ASRBackend {
        let index = max(0, asrBackendPopup.indexOfSelectedItem)
        return ASRBackend.allCases[index]
    }

    private func currentRemoteASRConfigurationFromFields() -> RemoteASRConfiguration {
        RemoteASRConfiguration(
            baseURL: asrBaseURLField.stringValue,
            apiKey: asrAPIKeyField.stringValue,
            model: asrModelField.stringValue,
            prompt: asrPromptField.stringValue
        )
    }

    private func permissionStatusText(for state: AuthorizationState) -> String {
        switch state {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .unknown:
            return "Unknown"
        }
    }

    private func statusTitle(for state: AuthorizationState) -> String {
        switch state {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .unknown:
            return "Unknown"
        }
    }

    private func selectSection(_ section: SettingsSection) {
        currentSection = section

        for (candidate, button) in sectionButtons {
            let isSelected = candidate == section
            button.state = isSelected ? .on : .off
            if isSelected {
                button.contentTintColor = .labelColor
                button.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.85).cgColor
            } else {
                button.contentTintColor = .secondaryLabelColor
                button.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }

        homeView.isHidden = section != .home
        permissionsView.isHidden = section != .permissions
        asrView.isHidden = section != .asr
        llmView.isHidden = section != .llm
    }

    @objc
    private func sectionChanged(_ sender: NSButton) {
        guard let section = SettingsSection(rawValue: sender.tag) else { return }
        selectSection(section)
    }

    @objc
    private func openPermissionsSection() {
        selectSection(.permissions)
    }

    @objc
    private func openLLMSection() {
        selectSection(.llm)
    }

    @objc
    private func openASRSection() {
        selectSection(.asr)
    }

    @objc
    private func asrBackendChanged(_ sender: NSPopUpButton) {
        let backend = currentSelectedASRBackend()
        model.setASRBackend(backend)
        delegate?.settingsWindowController(self, didSelectASRBackend: backend)
        refreshHomeSection()
        refreshASRSection()
    }

    @objc
    private func shortcutRecorderChanged(_ sender: ShortcutRecorderField) {
        let shortcut = sender.shortcut

        guard !shortcut.isEmpty else {
            sender.shortcut = model.activationShortcut
            return
        }

        model.setActivationShortcut(shortcut)
        delegate?.settingsWindowController(self, didUpdateActivationShortcut: shortcut)
        reloadFromModel()
        window?.makeFirstResponder(nil)
    }

    @objc
    private func openMicrophoneSettings() {
        delegate?.settingsWindowControllerDidRequestOpenMicrophoneSettings(self)
    }

    @objc
    private func openSpeechSettings() {
        delegate?.settingsWindowControllerDidRequestOpenSpeechSettings(self)
    }

    @objc
    private func openAccessibilitySettingsFromSettings() {
        delegate?.settingsWindowControllerDidRequestOpenAccessibilitySettings(self)
    }

    @objc
    private func openInputMonitoringSettings() {
        delegate?.settingsWindowControllerDidRequestOpenInputMonitoringSettings(self)
    }

    @objc
    private func promptAccessibilityPermission() {
        delegate?.settingsWindowControllerDidRequestPromptAccessibilityPermission(self)
    }

    @objc
    private func refreshPermissions() {
        permissionsHintLabel.stringValue = "Refreshing permission status…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            await delegate?.settingsWindowControllerDidRequestRefreshPermissions(self)
            self.permissionsHintLabel.stringValue = "Manage permission changes in System Settings, then refresh here."
            self.reloadFromModel()
        }
    }

    @objc
    private func toggleLLMCheckbox(_ sender: NSButton) {
        model.llmEnabled = sender.state == .on
        refreshLLMSection()
    }

    @objc
    private func saveRemoteASRConfiguration() {
        let configuration = currentRemoteASRConfigurationFromFields()
        let backend = currentSelectedASRBackend()

        model.setASRBackend(backend)
        model.saveRemoteASRConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model,
            prompt: configuration.prompt
        )

        asrStatusLabel.stringValue = "Saved."
        delegate?.settingsWindowController(self, didSelectASRBackend: backend)
        delegate?.settingsWindowController(self, didSaveRemoteASRConfiguration: configuration)
        refreshHomeSection()
        refreshASRSection()
    }

    @objc
    private func testRemoteASRConfiguration() {
        let configuration = currentRemoteASRConfigurationFromFields()

        guard currentSelectedASRBackend() == .remoteOpenAICompatible else {
            asrStatusLabel.stringValue = "Switch to the remote backend before testing the remote ASR connection."
            return
        }

        guard configuration.isConfigured else {
            asrStatusLabel.stringValue = "Please complete API Base URL, API Key, and Model before testing."
            return
        }

        setASRButtonsEnabled(false)
        asrStatusLabel.stringValue = "Testing…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await delegate?.settingsWindowController(self, didRequestRemoteASRTest: configuration)

            switch result {
            case .success(let response):
                let preview = response.trimmingCharacters(in: .whitespacesAndNewlines)
                asrStatusLabel.stringValue = preview.isEmpty ? "Remote ASR test failed: empty response." : preview
            case .failure(let error):
                asrStatusLabel.stringValue = "Test failed: \(error.localizedDescription)"
            case .none:
                asrStatusLabel.stringValue = "Test unavailable."
            }

            self.setASRButtonsEnabled(true)
        }
    }

    @objc
    private func saveConfiguration() {
        let configuration = currentConfigurationFromFields()
        model.llmEnabled = llmEnabledCheckbox.state == .on
        model.saveLLMConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model
        )
        llmStatusLabel.stringValue = "Saved."
        delegate?.settingsWindowController(self, didSave: configuration)
    }

    @objc
    private func testConfiguration() {
        let configuration = currentConfigurationFromFields()

        guard configuration.isConfigured else {
            llmStatusLabel.stringValue = "Please complete API Base URL, API Key, and Model before testing."
            return
        }

        setLLMButtonsEnabled(false)
        llmStatusLabel.stringValue = "Testing…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await delegate?.settingsWindowController(self, didRequestTest: configuration)

            switch result {
            case .success(let response):
                let preview = response.trimmingCharacters(in: .whitespacesAndNewlines)
                llmStatusLabel.stringValue = preview.isEmpty ? "Test failed: empty response." : "Test succeeded."
            case .failure(let error):
                llmStatusLabel.stringValue = "Test failed: \(error.localizedDescription)"
            case .none:
                llmStatusLabel.stringValue = "Test unavailable."
            }

            setLLMButtonsEnabled(true)
        }
    }

    private func setLLMButtonsEnabled(_ enabled: Bool) {
        testButton.isEnabled = enabled
        saveButton.isEnabled = enabled
    }

    private func setASRButtonsEnabled(_ enabled: Bool) {
        asrTestButton.isEnabled = enabled && currentSelectedASRBackend() == .remoteOpenAICompatible
        asrSaveButton.isEnabled = enabled
    }

    private func makeCardView() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.32).cgColor
        return card
    }

    private func pinCardContent(_ content: NSView, into card: NSView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
    }

    private func makePageStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 20
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func makeGroupedSection(rows: [NSView] = [], customViews: [NSView] = []) -> NSView {
        let card = makeCardView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading

        let items = rows + customViews
        for (index, view) in items.enumerated() {
            stack.addArrangedSubview(view)

            if index < items.count - 1 {
                let separator = NSBox()
                separator.boxType = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                stack.addArrangedSubview(separator)
            }
        }

        pinCardContent(stack, into: card)
        return card
    }

    private func makePreferenceRow(title: String, control: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        control.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [titleLabel, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 24
        row.edgeInsets = NSEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)

        NSLayoutConstraint.activate([
            titleLabel.widthAnchor.constraint(equalToConstant: 190),
            control.widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])

        return row
    }

    private func makeSectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private func makeBodyLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    private func makeValueLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.alignment = .right
        return label
    }

    private func makeActionButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        return button
    }

    private func makePrimaryActionButton(title: String, action: Selector) -> NSButton {
        let button = makeActionButton(title: title, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        return button
    }

    private func makeSecondaryActionButton(title: String, action: Selector) -> NSButton {
        let button = makeActionButton(title: title, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        return button
    }

    private func makeButtonGroup(_ buttons: [NSButton]) -> NSStackView {
        let stack = NSStackView(views: buttons)
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        return stack
    }

    private func makeSectionHeader(title: String, subtitle: String) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.alignment = .left

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 3
        subtitleLabel.alignment = .left

        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        return stack
    }

    private func makeDetailStack(statusLabel: NSTextField, buttons: NSView) -> NSView {
        let stack = NSStackView(views: [statusLabel, buttons])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .trailing
        return stack
    }

    private func makeSectionNavigation() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY

        sectionButtons.removeAll()

        for section in SettingsSection.allCases {
            let button = NSButton(title: section.title, target: self, action: #selector(sectionChanged(_:)))
            button.tag = section.rawValue
            button.setButtonType(.toggle)
            button.bezelStyle = .texturedRounded
            button.controlSize = .large
            button.font = .systemFont(ofSize: 13, weight: .semibold)
            button.wantsLayer = true
            button.layer?.cornerRadius = 10
            button.layer?.masksToBounds = true
            button.image = NSImage(systemSymbolName: iconName(for: section), accessibilityDescription: section.title)
            button.imagePosition = .imageLeading
            button.contentTintColor = .secondaryLabelColor
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: 36)
            ])

            sectionButtons[section] = button
            stack.addArrangedSubview(button)
        }

        return stack
    }

    private func iconName(for section: SettingsSection) -> String {
        switch section {
        case .home:
            return "house"
        case .permissions:
            return "lock.shield"
        case .asr:
            return "waveform.and.mic"
        case .llm:
            return "sparkles"
        }
    }

    private func makeFeatureCard(icon: String, title: String, description: String) -> NSView {
        let card = makeCardView()

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let descriptionLabel = makeBodyLabel(description)

        let stack = NSStackView(views: [iconView, titleLabel, descriptionLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    private func makeFeatureStrip(_ cards: [NSView]) -> NSView {
        let stack = NSStackView(views: cards)
        stack.orientation = .horizontal
        stack.spacing = 14
        stack.distribution = .fillEqually
        stack.alignment = .top
        return stack
    }

    private func makePermissionCard(
        icon: String,
        title: String,
        description: String,
        statusLabel: NSTextField?,
        primaryButton: NSButton,
        secondaryButtons: [NSButton]
    ) -> NSView {
        let card = makeCardView()

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let descriptionLabel = makeBodyLabel(description)

        let headerStack = NSStackView(views: [iconView, titleLabel, NSView()])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 10

        if let statusLabel {
            let statusPill = makeStatusPill(label: statusLabel)
            headerStack.addArrangedSubview(statusPill)
        }

        var buttons = [primaryButton]
        buttons.append(contentsOf: secondaryButtons)
        let buttonRow = makeButtonGroup(buttons)

        let stack = NSStackView(views: [headerStack, descriptionLabel, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    private func makeStatusPill(label: NSTextField) -> NSView {
        let pill = NSView()
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 11
        pill.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.9).cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -4)
        ])

        return pill
    }
}

@MainActor
extension StatusBarController: SettingsWindowControllerDelegate {
    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSave configuration: LLMConfiguration
    ) {
        refreshLLMMenuState()
        refreshStatusSummary()
        delegate?.statusBarController(self, didSave: configuration)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateActivationShortcut shortcut: ActivationShortcut
    ) {
        shortcutMenuItem?.title = shortcutMenuTitle()
        refreshAll()
        delegate?.statusBarController(self, didUpdateActivationShortcut: shortcut)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration
    ) {
        refreshAll()
        delegate?.statusBarController(self, didSaveRemoteASRConfiguration: configuration)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSelectASRBackend backend: ASRBackend
    ) {
        refreshAll()
        delegate?.statusBarController(self, didSelectASRBackend: backend)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestTest configuration: LLMConfiguration
    ) async -> Result<String, Error> {
        await delegate?.statusBarController(self, didRequestTest: configuration)
            ?? .failure(NSError(
                domain: "VoicePi.StatusBarController",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No test handler is available."]
            ))
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestRemoteASRTest configuration: RemoteASRConfiguration
    ) async -> Result<String, Error> {
        await delegate?.statusBarController(self, didRequestRemoteASRTest: configuration)
            ?? .failure(NSError(
                domain: "VoicePi.StatusBarController",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No remote ASR test handler is available."]
            ))
    }

    func settingsWindowControllerDidRequestOpenMicrophoneSettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenMicrophoneSettings(self)
    }

    func settingsWindowControllerDidRequestOpenSpeechSettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenSpeechSettings(self)
    }

    func settingsWindowControllerDidRequestOpenAccessibilitySettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenAccessibilitySettings(self)
    }

    func settingsWindowControllerDidRequestOpenInputMonitoringSettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenInputMonitoringSettings(self)
    }

    func settingsWindowControllerDidRequestPromptAccessibilityPermission(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestPromptAccessibilityPermission(self)
    }

    func settingsWindowControllerDidRequestRefreshPermissions(_ controller: SettingsWindowController) async {
        await delegate?.statusBarControllerDidRequestRefreshPermissions(self)
        refreshAll()
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
        controlSize = .large
        font = .systemFont(ofSize: 13, weight: .semibold)
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
        return true
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
