import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let promptBindingActionBarTitle = "Bindings"
    static let promptBindingsButtonTitle = "Bindings"
    static let captureFrontmostAppButtonTitle = "Capture Frontmost App"
    static let captureCurrentWebsiteButtonTitle = "Capture Current Website"
    static let strictModeToggleLabel = "Strict Mode"
    static let refinementProviderLabel = "Refinement Provider"
    static let thinkingLabel = "Thinking"
    static let externalProcessorManagerSheetTitle = "Processors"
    static let externalProcessorManagerAddProcessorButtonTitle = "+"
    static let externalProcessorManagerAddArgumentButtonTitle = "+"
    static let externalProcessorManagerEmptyStateText = ExternalProcessorManagerPresentation.emptyStateText
    static let externalProcessorManagerManageButtonTitle = "Processors"
    static let navigationIconTopPadding: CGFloat = 6
    static let strictModeHelpText = "When on, app bindings override the active prompt for matching apps. When off, VoicePi always uses the active prompt."
    static let thinkingUnsetTitle = "Not Set"
    static let thinkingHelpText =
        "Optional. For mixed-thinking models, VoicePi only sends `enable_thinking` after you explicitly choose On or Off."
    static let promptEditorBodyHintText = "Add the instructions VoicePi should apply here. Leave it empty to keep the default refinement rules and only use this prompt for bindings."
    static let promptEditorBodyFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let promptEditorBodyTextInset = NSSize(width: 14, height: 12)
    static let builtInDefaultPromptPreviewText = "Built-in default prompt uses the base VoicePi refinement rules."

    weak var delegate: SettingsWindowControllerDelegate?

    let model: AppModel

    let contentContainer = NSView()

    let homeView = NSView()
    let permissionsView = NSView()
    let asrView = NSView()
    let llmView = NSView()
    let externalProcessorsView = NSView()
    let aboutView = NSView()
    let dictionaryView = NSScrollView()
    let historyView = NSScrollView()
    var pageScrollViews: [SettingsSection: NSScrollView] = [:]

    let homeSummaryLabel = NSTextField(labelWithString: "")
    let homeReadinessTitleLabel = NSTextField(labelWithString: "")
    let homeReadinessIconView = NSImageView()
    let homePermissionSummaryLabel = NSTextField(labelWithString: "")
    let homeLanguageLabel = NSTextField(labelWithString: "")
    let homeLanguageTitleLabel = NSTextField(labelWithString: "")
    let homeLanguageSubtitleLabel = NSTextField(labelWithString: "")
    let homeLanguagePopup = ThemedPopUpButton()
    let homeShortcutLabel = NSTextField(labelWithString: "")
    let homeCancelShortcutLabel = NSTextField(labelWithString: "")
    let homeModeShortcutLabel = NSTextField(labelWithString: "")
    let homePromptShortcutLabel = NSTextField(labelWithString: "")
    let homeProcessorShortcutLabel = NSTextField(labelWithString: "")
    let homeASRLabel = NSTextField(labelWithString: "")
    let homeLLMLabel = NSTextField(labelWithString: "")
    let dictionarySummaryLabel = NSTextField(labelWithString: "")
    let dictionaryPendingReviewLabel = NSTextField(labelWithString: "")
    let dictionarySearchField = NSSearchField()
    let dictionaryCollectionsStack = NSStackView()
    let dictionaryCollectionsFooterLabel = NSTextField(labelWithString: "")
    let dictionaryContentTitleLabel = NSTextField(labelWithString: "")
    let dictionaryContentSubtitleLabel = NSTextField(labelWithString: "")
    let dictionaryTermHeaderRow = NSStackView()
    let dictionaryTermRowsStack = NSStackView()
    let dictionarySuggestionRowsStack = NSStackView()
    var dictionaryTermsRowsScrollView: NSScrollView?
    var dictionarySuggestionRowsScrollView: NSScrollView?
    var dictionaryTermsRowsHeightConstraint: NSLayoutConstraint?
    var dictionarySuggestionRowsHeightConstraint: NSLayoutConstraint?
    var dictionarySelectedCollection: DictionaryCollectionSelection = .allTerms
    var dictionaryCollectionRowViews: [DictionaryCollectionSelection: ThemedSurfaceView] = [:]
    var dictionaryCollectionLookup: [ObjectIdentifier: DictionaryCollectionSelection] = [:]
    let historySummaryLabel = NSTextField(labelWithString: "")
    let historyUsageStatsLabel = NSTextField(labelWithString: "")
    let historyUsageCardsStack = NSView()
    let historyUsageDetailCard = ThemedSurfaceView(style: .card)
    let historyUsageDetailTitleLabel = NSTextField(labelWithString: "")
    let historyUsageDetailSubtitleLabel = NSTextField(labelWithString: "")
    let historyUsageHeatmapTitleLabel = NSTextField(labelWithString: "")
    let historyUsageLineChartView = HistoryUsageLineChartView()
    let historyUsageHeatmapView = HistoryUsageHeatmapView()
    let historyUsageTimeRangePopup = ThemedPopUpButton()
    let historyRowsStack = NSStackView()
    let historySessionCountLabel = NSTextField(labelWithString: "")
    let historySearchField = NSSearchField()
    let historyDateFilterPopup = ThemedPopUpButton()
    let historyPaginationStack = NSStackView()

    let shortcutRecorderField = ShortcutRecorderField()
    let shortcutHintLabel = NSTextField(labelWithString: "")
    let cancelShortcutRecorderField = ShortcutRecorderField()
    let cancelShortcutHintLabel = NSTextField(labelWithString: "")
    let modeShortcutRecorderField = ShortcutRecorderField()
    let modeShortcutHintLabel = NSTextField(labelWithString: "")
    let promptShortcutRecorderField = ShortcutRecorderField()
    let promptShortcutHintLabel = NSTextField(labelWithString: "")
    let processorShortcutRecorderField = ShortcutRecorderField()
    let processorShortcutHintLabel = NSTextField(labelWithString: "")
    lazy var homePrimaryActionButton = StyledSettingsButton(
        title: "Start Listening",
        role: .primary,
        target: self,
        action: #selector(startListeningFromHome)
    )

    let microphoneStatusLabel = NSTextField(labelWithString: "")
    let speechStatusLabel = NSTextField(labelWithString: "")
    let accessibilityStatusLabel = NSTextField(labelWithString: "")
    let inputMonitoringStatusLabel = NSTextField(labelWithString: "")
    let microphoneStatusIconView = NSImageView()
    let speechStatusIconView = NSImageView()
    let accessibilityStatusIconView = NSImageView()
    let inputMonitoringStatusIconView = NSImageView()
    let permissionsHintLabel = NSTextField(labelWithString: "")
    let asrSummaryLabel = NSTextField(labelWithString: "")
    let asrBackendCardsStack = NSStackView()
    let llmSummaryLabel = NSTextField(labelWithString: "")
    let aboutVersionLabel = NSTextField(labelWithString: "")
    let aboutBuildLabel = NSTextField(labelWithString: "")
    let aboutAuthorLabel = NSTextField(labelWithString: "")
    let aboutRepositoryLabel = NSTextField(labelWithString: "")
    let aboutWebsiteLabel = NSTextField(labelWithString: "")
    let aboutGitHubLabel = NSTextField(labelWithString: "")
    let aboutXLabel = NSTextField(labelWithString: "")
    let aboutUpdateTitleLabel = NSTextField(labelWithString: "")
    let aboutUpdateSummaryLabel = NSTextField(labelWithString: "")
    let aboutUpdateStatusLabel = NSTextField(labelWithString: "")
    let aboutUpdateSourceLabel = NSTextField(labelWithString: "")
    let aboutUpdateStrategyLabel = NSTextField(labelWithString: "")
    let aboutUpdateProgressLabel = NSTextField(labelWithString: "")
    let aboutUpdateProgressIndicator = NSProgressIndicator()
    lazy var aboutUpdatePrimaryButton = StyledSettingsButton(
        title: "Check for Updates",
        role: .primary,
        target: self,
        action: #selector(handleAboutUpdatePrimaryAction)
    )
    lazy var aboutUpdateSecondaryButton = StyledSettingsButton(
        title: "View Release",
        role: .secondary,
        target: self,
        action: #selector(handleAboutUpdateSecondaryAction)
    )
    let interfaceThemePopup = ThemedPopUpButton()
    let homeAppearanceTitleLabel = NSTextField(labelWithString: "")
    let homeAppearanceSubtitleLabel = NSTextField(labelWithString: "")

    let baseURLField = NSTextField(string: "")
    let apiKeyField = NSSecureTextField(string: "")
    let modelField = NSTextField(string: "")
    let thinkingPopup = ThemedPopUpButton()
    let refinementProviderPopup = ThemedPopUpButton()
    let activePromptPopup = ThemedPopUpButton()
    let promptStrictModeSwitch = NSSwitch()
    let resolvedPromptSummaryLabel = NSTextField(labelWithString: "")
    lazy var resolvedPromptBodyScrollView = Self.makeReadOnlyPromptPreviewScrollView(text: "")
    let promptRulesStrictModeLabel = NSTextField(labelWithString: "")
    let promptRulesBindingCoverageLabel = NSTextField(labelWithString: "")
    let promptRulesBindingCoverageIconView = NSImageView()
    lazy var externalProcessorManagerButton = StyledSettingsButton(
        title: "+ Add Processor",
        role: .secondary,
        target: self,
        action: #selector(addExternalProcessorFromPage)
    )
    let externalProcessorsSummaryLabel = NSTextField(labelWithString: "")
    let externalProcessorsDetailLabel = NSTextField(labelWithString: "")
    let externalProcessorsStatusLabel = NSTextField(labelWithString: "")
    let externalProcessorsRowsStack = NSStackView()
    lazy var externalProcessorsTestButton = StyledSettingsButton(
        title: "Test Run",
        role: .secondary,
        target: self,
        action: #selector(testSelectedExternalProcessorEntry)
    )
    lazy var editPromptButton = StyledSettingsButton(
        title: "Edit",
        role: .secondary,
        target: self,
        action: #selector(editPromptPreset)
    )
    lazy var newPromptButton = StyledSettingsButton(
        title: "New",
        role: .secondary,
        target: self,
        action: #selector(createPromptPreset)
    )
    lazy var promptBindingsButton = StyledSettingsButton(
        title: Self.promptBindingsButtonTitle,
        role: .secondary,
        target: self,
        action: #selector(openPromptBindingsEditor)
    )
    lazy var deletePromptButton = StyledSettingsButton(
        title: "Delete",
        role: .secondary,
        target: self,
        action: #selector(deletePromptPreset)
    )
    let asrRemoteProviderPopup = ThemedPopUpButton()
    let asrBaseURLField = NSTextField(string: "")
    let asrAPIKeyField = NSSecureTextField(string: "")
    let asrModelField = NSTextField(string: "")
    let asrVolcengineAppIDField = NSTextField(string: "")
    let asrPromptField = NSTextField(string: "")
    lazy var asrVolcengineAppIDRow = makePreferenceRow(
        title: "Volcengine AppID",
        control: asrVolcengineAppIDField
    )
    let asrConnectionDetailsContentStack = NSStackView()
    var asrRemoteConfigurationSection: NSView?
    var asrConnectionActionButtons: NSView?
    var asrLocalModeHintView: NSView?
    let postProcessingModePopup = ThemedPopUpButton()
    let translationProviderPopup = ThemedPopUpButton()
    let targetLanguagePopup = ThemedPopUpButton()
    var llmRefinementProviderRow: NSView?
    var llmTranslationProviderRow: NSView?
    var llmTargetLanguageRow: NSView?
    var llmThinkingRow: NSView?
    weak var textPromptCharacterCountLabel: NSTextField?
    weak var textLivePreviewInputField: NSTextField?
    weak var textLivePreviewOutputLabel: NSTextField?
    var textLivePreviewDebounceTimer: Timer?
    var textLivePreviewInputObserver: NSObjectProtocol?
    var textLivePreviewRequestID = 0
    let asrStatusView = ConnectionFeedbackView()
    let llmStatusView = ConnectionFeedbackView()

    let asrTestButton = NSButton(title: "Test Connection", target: nil, action: nil)
    let asrSaveButton = NSButton(title: "Save", target: nil, action: nil)
    let testButton = NSButton(title: "Test Connection", target: nil, action: nil)
    let saveButton = NSButton(title: "Save", target: nil, action: nil)

    var sectionButtons: [SettingsSection: NSButton] = [:]
    var asrBackendCardViews: [ASRBackendMode: ASRBackendModeChoiceView] = [:]
    var selectedASRBackendMode: ASRBackendMode = .local
    var currentSection: SettingsSection = .home
    var aboutUpdatePresentation = AppUpdateExperience.cardPresentation(for: .idle(source: .unknown))
    var aboutUpdatePrimaryAction: (() -> Void)?
    var aboutUpdateSecondaryAction: (() -> Void)?
    var promptLibrary: PromptLibrary?
    var promptLibraryLoadError: String?
    var promptWorkspaceDraft = PromptWorkspaceSettings()
    var promptDestinationInspector = PromptDestinationInspector()
    var promptEditorDraft: PromptPreset?
    var promptEditorSheetWindow: PreviewSheetWindow?
    weak var promptEditorNameField: NSTextField?
    weak var promptEditorAppBindingsField: NSTextField?
    weak var promptEditorWebsiteHostsField: NSTextField?
    weak var promptEditorBindingStatusLabel: NSTextField?
    weak var promptEditorBodyTextView: NSTextView?
    var externalProcessorManagerState = ExternalProcessorManagerState()
    var externalProcessorManagerSheetWindow: PreviewSheetWindow?
    var librarySubviewControls: [LibrarySubviewTabControl] = []
    var historyEntryByIdentifier: [String: HistoryEntry] = [:]
    var historyUsageMetricCardViews: [HistoryUsageMetric: ThemedSurfaceView] = [:]
    var historyUsageMetricValueLabels: [HistoryUsageMetric: NSTextField] = [:]
    var historyUsageMetricLookup: [ObjectIdentifier: HistoryUsageMetric] = [:]
    var historyUsageSelectedMetric: HistoryUsageMetric?
    var historyUsageTimeRange: HistoryUsageTimeRange = .oneWeek
    var historyDateFilter: HistoryListDateFilter = .allDates
    var historySortOrder: HistoryListSortOrder = .newestFirst
    var historyCurrentPage = 0
    weak var historyDocumentContainerView: NSView?
    weak var externalProcessorManagerSelectedEntryPopup: NSPopUpButton?
    weak var externalProcessorManagerFeedbackLabel: NSTextField?
    weak var externalProcessorManagerEntriesContainer: NSStackView?
    var externalProcessorManagerNameFields: [UUID: NSTextField] = [:]
    var externalProcessorManagerKindPopups: [UUID: NSPopUpButton] = [:]
    var externalProcessorManagerExecutablePathFields: [UUID: NSTextField] = [:]
    var externalProcessorManagerEnabledSwitches: [UUID: NSSwitch] = [:]
    var externalProcessorManagerArgumentFields: [UUID: [UUID: NSTextField]] = [:]
    var shouldRefreshPermissionsOnNextWindowActivation = false

    var resolvedPromptBodyTextView: NSTextView? {
        resolvedPromptBodyScrollView.documentView as? NSTextView
    }

    var isPromptEditorSheetPresented: Bool {
        promptEditorDraft != nil || promptEditorSheetWindow != nil || window?.attachedSheet != nil
    }

    var promptEditorSheetContentViewForTesting: NSView? {
        promptEditorSheetWindow?.contentView
    }

    var externalProcessorManagerSheetContentViewForTesting: NSView? {
        externalProcessorManagerSheetWindow?.contentView
    }

    init(model: AppModel, delegate: SettingsWindowControllerDelegate?) {
        self.model = model
        self.delegate = delegate

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsWindowChrome.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = SettingsWindowChrome.title
        window.isReleasedWhenClosed = false
        window.minSize = SettingsWindowChrome.minimumSize
        window.titlebarAppearsTransparent = false
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unifiedCompact
        }
        window.center()

        super.init(window: window)
        window.delegate = self

        buildUI()
        applyThemeAppearance()
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

    func show(section: SettingsSection, scrollToBottom: Bool = false) {
        if RuntimeEnvironment.isRunningTests {
            reloadFromModel()
            selectSection(section)
            if scrollToBottom {
                scrollPage(section: section, toBottom: true)
            }
            window?.orderOut(nil)
            return
        }
        showWindow(nil)
        selectSection(section)
        if scrollToBottom {
            scrollPage(section: section, toBottom: true)
        }
    }

    func openExternalProcessorManagerSheetFromShortcut() {
        show(section: .externalProcessors)
        presentExternalProcessorManagerSheet()
    }

    func setAboutUpdatePresentation(
        _ presentation: AppUpdateCardPresentation,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        aboutUpdatePresentation = presentation
        aboutUpdatePrimaryAction = primaryAction
        aboutUpdateSecondaryAction = secondaryAction
        applyAboutUpdatePresentation()
    }

    func reloadFromModel() {
        applyThemeAppearance()
        loadCurrentValues()
        refreshPermissionLabels()
        refreshHomeSection()
        refreshASRSection()
        refreshLLMSection()
        refreshExternalProcessorsSection()
        refreshDictionarySection()
        refreshHistorySection()
        if externalProcessorManagerSheetWindow != nil {
            externalProcessorManagerState = ExternalProcessorManagerState(
                entries: model.externalProcessorEntries,
                selectedEntryID: model.selectedExternalProcessorEntryID ?? model.externalProcessorEntries.first?.id
            )
            reloadExternalProcessorManagerSheet()
        }
    }

    @objc
    func handleAboutUpdatePrimaryAction() {
        aboutUpdatePrimaryAction?()
    }

    @objc
    func handleAboutUpdateSecondaryAction() {
        aboutUpdateSecondaryAction?()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        model.closeSettings()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        shouldRefreshPermissionsOnNextWindowActivation = currentSection == .permissions
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        guard shouldRefreshPermissionsOnNextWindowActivation else { return }
        shouldRefreshPermissionsOnNextWindowActivation = false
        guard currentSection == .permissions else { return }
        refreshPermissions(showProgressCopy: false)
    }

}
