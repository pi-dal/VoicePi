import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum Keys {
        static let selectedLanguage = "selectedLanguage"
        static let llmEnabled = "llmEnabled"
        static let llmConfig = "llmConfig"
        static let promptSettings = "promptSettings"
        static let promptWorkspace = "promptWorkspace"
        static let postProcessingMode = "postProcessingMode"
        static let translationProvider = "translationProvider"
        static let refinementProvider = "refinementProvider"
        static let externalProcessorEntries = "externalProcessorEntries"
        static let selectedExternalProcessorEntryID = "selectedExternalProcessorEntryID"
        static let targetLanguage = "targetLanguage"
        static let activationShortcut = "activationShortcut"
        static let cancelShortcut = "cancelShortcut"
        static let modeCycleShortcut = "modeCycleShortcut"
        static let processorShortcut = "processorShortcut"
        static let promptCycleShortcut = "promptCycleShortcut"
        static let asrBackend = "asrBackend"
        static let remoteASRConfig = "remoteASRConfig"
        static let interfaceTheme = "interfaceTheme"
    }

    @Published var selectedLanguage: SupportedLanguage {
        didSet {
            defaults.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage)
        }
    }

    @Published var llmConfiguration: LLMConfiguration {
        didSet {
            persistConfiguration()
        }
    }

    @Published var promptWorkspace: PromptWorkspaceSettings {
        didSet {
            persistPromptWorkspace()
        }
    }

    @Published var postProcessingMode: PostProcessingMode {
        didSet {
            defaults.set(postProcessingMode.rawValue, forKey: Keys.postProcessingMode)
        }
    }

    @Published var translationProvider: TranslationProvider {
        didSet {
            defaults.set(translationProvider.rawValue, forKey: Keys.translationProvider)
        }
    }

    @Published var refinementProvider: RefinementProvider {
        didSet {
            defaults.set(refinementProvider.rawValue, forKey: Keys.refinementProvider)
        }
    }

    @Published var externalProcessorEntries: [ExternalProcessorEntry] {
        didSet {
            persistExternalProcessorEntries()
        }
    }

    @Published var selectedExternalProcessorEntryID: UUID? {
        didSet {
            persistSelectedExternalProcessorEntryID()
        }
    }

    @Published var targetLanguage: SupportedLanguage {
        didSet {
            defaults.set(targetLanguage.rawValue, forKey: Keys.targetLanguage)
        }
    }

    @Published var activationShortcut: ActivationShortcut {
        didSet {
            persistActivationShortcut()
        }
    }

    @Published var modeCycleShortcut: ActivationShortcut {
        didSet {
            persistModeCycleShortcut()
        }
    }

    @Published var cancelShortcut: ActivationShortcut {
        didSet {
            persistCancelShortcut()
        }
    }

    @Published var processorShortcut: ActivationShortcut {
        didSet {
            persistProcessorShortcut()
        }
    }

    @Published var promptCycleShortcut: ActivationShortcut {
        didSet {
            persistPromptCycleShortcut()
        }
    }

    @Published var asrBackend: ASRBackend {
        didSet {
            defaults.set(asrBackend.rawValue, forKey: Keys.asrBackend)
        }
    }

    @Published var remoteASRConfiguration: RemoteASRConfiguration {
        didSet {
            persistRemoteASRConfiguration()
        }
    }

    @Published var interfaceTheme: InterfaceTheme {
        didSet {
            defaults.set(interfaceTheme.rawValue, forKey: Keys.interfaceTheme)
        }
    }

    @Published var overlayState: OverlayState = .init()
    @Published var recordingState: RecordingState = .idle
    @Published var errorState: AppErrorState?
    @Published var isSettingsWindowPresented = false
    @Published var microphoneAuthorization: AuthorizationState = .unknown
    @Published var speechAuthorization: AuthorizationState = .unknown
    @Published var accessibilityAuthorization: AuthorizationState = .unknown
    @Published var inputMonitoringAuthorization: AuthorizationState = .unknown
    @Published var dictionaryEntries: [DictionaryEntry] = []
    @Published var dictionarySuggestions: [DictionarySuggestion] = []
    @Published var historyEntries: [HistoryEntry] = []

    let defaults: UserDefaults
    let dictionaryStore: DictionaryStoring?
    let historyStore: HistoryStoring?
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    lazy var cachedPromptLibrary: PromptLibrary? = try? PromptLibrary.loadBundled()

    init(
        defaults: UserDefaults = .standard,
        dictionaryStore: DictionaryStoring? = nil,
        historyStore: HistoryStoring? = nil
    ) {
        self.defaults = defaults
        if let dictionaryStore {
            self.dictionaryStore = dictionaryStore
        } else {
            self.dictionaryStore = try? DictionaryStore()
        }
        if let historyStore {
            self.historyStore = historyStore
        } else {
            self.historyStore = try? HistoryStore()
        }

        let initialSelectedLanguage: SupportedLanguage

        if
            let storedLanguage = defaults.string(forKey: Keys.selectedLanguage),
            let language = SupportedLanguage(rawValue: storedLanguage)
        {
            initialSelectedLanguage = language
        } else {
            initialSelectedLanguage = .default
        }
        self.selectedLanguage = initialSelectedLanguage

        let initialLLMConfiguration: LLMConfiguration
        if
            let data = defaults.data(forKey: Keys.llmConfig),
            let decoded = try? decoder.decode(LLMConfiguration.self, from: data)
        {
            initialLLMConfiguration = decoded
        } else {
            initialLLMConfiguration = .init()
        }
        self.llmConfiguration = initialLLMConfiguration

        let initialPromptWorkspace: PromptWorkspaceSettings
        let shouldPersistMigratedPromptWorkspace: Bool
        if
            let data = defaults.data(forKey: Keys.promptWorkspace),
            let decoded = try? decoder.decode(PromptWorkspaceSettings.self, from: data)
        {
            initialPromptWorkspace = decoded
            shouldPersistMigratedPromptWorkspace = false
        } else {
            initialPromptWorkspace = AppModel.migratePromptWorkspace(
                defaults: defaults,
                decoder: decoder,
                initialLLMConfiguration: initialLLMConfiguration
            )
            shouldPersistMigratedPromptWorkspace = true
        }
        self.promptWorkspace = initialPromptWorkspace

        if
            let storedMode = defaults.string(forKey: Keys.postProcessingMode),
            let mode = PostProcessingMode(rawValue: storedMode)
        {
            self.postProcessingMode = mode
        } else {
            let legacyEnabled = defaults.object(forKey: Keys.llmEnabled) as? Bool ?? false
            self.postProcessingMode = legacyEnabled ? .refinement : .disabled
        }

        if
            let storedProvider = defaults.string(forKey: Keys.translationProvider),
            let provider = TranslationProvider(rawValue: storedProvider)
        {
            self.translationProvider = provider
        } else {
            self.translationProvider = .appleTranslate
        }

        if
            let storedRefinementProvider = defaults.string(forKey: Keys.refinementProvider),
            let provider = RefinementProvider(rawValue: storedRefinementProvider)
        {
            self.refinementProvider = provider
        } else {
            self.refinementProvider = .llm
        }

        if
            let data = defaults.data(forKey: Keys.externalProcessorEntries),
            let decoded = try? decoder.decode([ExternalProcessorEntry].self, from: data)
        {
            self.externalProcessorEntries = decoded
        } else {
            self.externalProcessorEntries = []
        }

        if
            let storedSelectedExternalProcessorEntryID = defaults.string(forKey: Keys.selectedExternalProcessorEntryID),
            let uuid = UUID(uuidString: storedSelectedExternalProcessorEntryID)
        {
            self.selectedExternalProcessorEntryID = uuid
        } else {
            self.selectedExternalProcessorEntryID = nil
        }

        if
            let storedTargetLanguage = defaults.string(forKey: Keys.targetLanguage),
            let language = SupportedLanguage(rawValue: storedTargetLanguage)
        {
            self.targetLanguage = language
        } else {
            self.targetLanguage = initialSelectedLanguage
        }

        let shouldPersistActivationShortcut: Bool
        if
            let data = defaults.data(forKey: Keys.activationShortcut),
            let decoded = try? decoder.decode(ActivationShortcut.self, from: data),
            !decoded.isEmpty
        {
            self.activationShortcut = decoded
            shouldPersistActivationShortcut = false
        } else {
            self.activationShortcut = AppModel.defaultActivationShortcut(defaults: defaults)
            shouldPersistActivationShortcut = true
        }

        let shouldPersistModeCycleShortcut: Bool
        if
            let data = defaults.data(forKey: Keys.modeCycleShortcut),
            let decoded = try? decoder.decode(ActivationShortcut.self, from: data)
        {
            self.modeCycleShortcut = decoded
            shouldPersistModeCycleShortcut = false
        } else {
            self.modeCycleShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
            shouldPersistModeCycleShortcut = true
        }

        let shouldPersistCancelShortcut: Bool
        if
            let data = defaults.data(forKey: Keys.cancelShortcut),
            let decoded = try? decoder.decode(ActivationShortcut.self, from: data),
            !decoded.isEmpty
        {
            self.cancelShortcut = decoded
            shouldPersistCancelShortcut = false
        } else {
            self.cancelShortcut = AppModel.defaultCancelShortcut
            shouldPersistCancelShortcut = true
        }

        let shouldPersistProcessorShortcut: Bool
        if
            let data = defaults.data(forKey: Keys.processorShortcut),
            let decoded = try? decoder.decode(ActivationShortcut.self, from: data)
        {
            self.processorShortcut = decoded
            shouldPersistProcessorShortcut = false
        } else {
            self.processorShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
            shouldPersistProcessorShortcut = true
        }

        let shouldPersistPromptCycleShortcut: Bool
        if
            let data = defaults.data(forKey: Keys.promptCycleShortcut),
            let decoded = try? decoder.decode(ActivationShortcut.self, from: data)
        {
            self.promptCycleShortcut = decoded
            shouldPersistPromptCycleShortcut = false
        } else {
            self.promptCycleShortcut = ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
            shouldPersistPromptCycleShortcut = true
        }

        if
            let storedBackend = defaults.string(forKey: Keys.asrBackend),
            let backend = ASRBackend(rawValue: storedBackend)
        {
            self.asrBackend = backend
        } else {
            self.asrBackend = .default
        }

        if
            let data = defaults.data(forKey: Keys.remoteASRConfig),
            let decoded = try? decoder.decode(RemoteASRConfiguration.self, from: data)
        {
            self.remoteASRConfiguration = decoded
        } else {
            self.remoteASRConfiguration = .init()
        }

        if
            let storedTheme = defaults.string(forKey: Keys.interfaceTheme),
            let theme = InterfaceTheme(rawValue: storedTheme)
        {
            self.interfaceTheme = theme
        } else {
            self.interfaceTheme = .system
        }

        if shouldPersistMigratedPromptWorkspace {
            persistPromptWorkspace()
        }
        if shouldPersistActivationShortcut {
            persistActivationShortcut()
        }
        if shouldPersistModeCycleShortcut {
            persistModeCycleShortcut()
        }
        if shouldPersistCancelShortcut {
            persistCancelShortcut()
        }
        if shouldPersistProcessorShortcut {
            persistProcessorShortcut()
        }
        if shouldPersistPromptCycleShortcut {
            persistPromptCycleShortcut()
        }

        refreshDictionaryState()
        refreshHistoryState()
    }

    var isLLMReady: Bool {
        llmConfiguration.isConfigured
    }

    var isRemoteASRReady: Bool {
        asrBackend.isRemoteBackend && remoteASRConfiguration.isConfigured(for: asrBackend)
    }

    var llmEnabled: Bool {
        get { postProcessingMode == .refinement }
        set { postProcessingMode = newValue ? .refinement : .disabled }
    }

    var dictionaryTermCount: Int {
        dictionaryEntries.count
    }

    var pendingDictionarySuggestionCount: Int {
        dictionarySuggestions.count
    }

    var enabledDictionaryEntries: [DictionaryEntry] {
        dictionaryEntries.filter(\.isEnabled)
    }

    func recentHistoryEntries(limit: Int = 3) -> [HistoryEntry] {
        Array(historyEntries.prefix(max(0, limit)))
    }

    func updateOverlayRecording(transcript: String, level: CGFloat) {
        overlayState = OverlayState(
            phase: .recording,
            transcript: transcript,
            level: max(0, min(level, 1))
        )
        recordingState = .recording
    }

    func updateOverlayRecordingLevel(_ level: CGFloat) {
        overlayState = OverlayState(
            phase: .recording,
            transcript: overlayState.transcript,
            level: max(0, min(level, 1))
        )
        recordingState = .recording
    }

    func updateOverlayRefining(transcript: String = "Refining...") {
        overlayState = OverlayState(
            phase: .refining,
            transcript: transcript,
            level: overlayState.level
        )
        recordingState = .refining
    }

    func hideOverlay() {
        overlayState = .init()
        recordingState = .idle
    }

    func presentError(_ message: String) {
        errorState = .message(message)
    }

    func clearError() {
        errorState = nil
    }

    func openSettings() {
        isSettingsWindowPresented = true
    }

    func closeSettings() {
        isSettingsWindowPresented = false
    }

    func saveLLMConfiguration(
        baseURL: String,
        apiKey: String,
        model: String,
        refinementPrompt: String? = nil,
        enableThinking: Bool?? = nil
    ) {
        llmConfiguration = LLMConfiguration(
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            refinementPrompt: refinementPrompt ?? llmConfiguration.refinementPrompt,
            enableThinking: enableThinking ?? llmConfiguration.enableThinking
        )
    }

}
