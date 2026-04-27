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
            guard !isApplyingPersistedState else { return }
            persistFileConfiguration { $0.app.language = selectedLanguage }
        }
    }

    @Published var llmConfiguration: LLMConfiguration {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistConfiguration()
        }
    }

    @Published var promptWorkspace: PromptWorkspaceSettings {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistPromptWorkspace()
        }
    }

    @Published var postProcessingMode: PostProcessingMode {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistFileConfiguration { $0.text.postProcessingMode = postProcessingMode }
        }
    }

    @Published var translationProvider: TranslationProvider {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistFileConfiguration { $0.text.translationProvider = translationProvider }
        }
    }

    @Published var refinementProvider: RefinementProvider {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistFileConfiguration { $0.text.refinementProvider = refinementProvider }
        }
    }

    @Published var externalProcessorEntries: [ExternalProcessorEntry] {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistExternalProcessorEntries()
        }
    }

    @Published var selectedExternalProcessorEntryID: UUID? {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistSelectedExternalProcessorEntryID()
        }
    }

    @Published var targetLanguage: SupportedLanguage {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistFileConfiguration { $0.text.targetLanguage = targetLanguage }
        }
    }

    @Published var activationShortcut: ActivationShortcut {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistActivationShortcut()
        }
    }

    @Published var modeCycleShortcut: ActivationShortcut {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistModeCycleShortcut()
        }
    }

    @Published var cancelShortcut: ActivationShortcut {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistCancelShortcut()
        }
    }

    @Published var processorShortcut: ActivationShortcut {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistProcessorShortcut()
        }
    }

    @Published var promptCycleShortcut: ActivationShortcut {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistPromptCycleShortcut()
        }
    }

    @Published var asrBackend: ASRBackend {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistFileConfiguration { $0.asr.backend = asrBackend }
        }
    }

    @Published var remoteASRConfiguration: RemoteASRConfiguration {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistRemoteASRConfiguration()
        }
    }

    @Published var interfaceTheme: InterfaceTheme {
        didSet {
            guard !isApplyingPersistedState else { return }
            persistFileConfiguration { $0.app.interfaceTheme = interfaceTheme }
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
    var dictionaryStore: DictionaryStoring?
    var historyStore: HistoryStoring?
    let configStore: VoicePiConfigStore
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    lazy var cachedPromptLibrary: PromptLibrary? = try? PromptLibrary.loadBundled()

    private let shouldManageDictionaryStore: Bool
    private let shouldManageHistoryStore: Bool
    private var fileConfiguration: VoicePiFileConfiguration
    private var isApplyingPersistedState = false

    init(
        defaults: UserDefaults = .standard,
        dictionaryStore: DictionaryStoring? = nil,
        historyStore: HistoryStoring? = nil,
        configStore: VoicePiConfigStore? = nil,
        configRootURL: URL? = nil
    ) {
        self.defaults = defaults
        self.shouldManageDictionaryStore = dictionaryStore == nil
        self.shouldManageHistoryStore = historyStore == nil

        if let configStore {
            self.configStore = configStore
        } else {
            let root = configRootURL ?? Self.defaultConfigRootURL(for: defaults)
            self.configStore = VoicePiConfigStore(
                paths: VoicePiConfigPaths(rootDirectoryURL: root)
            )
        }

        let migration = VoicePiLegacyMigration(
            defaults: defaults,
            configStore: self.configStore,
            legacyDictionaryStore: dictionaryStore,
            legacyHistoryStore: historyStore
        )
        do {
            try migration.runIfNeeded()
        } catch {
            print("VoicePi migration failed: \(error)")
        }

        let initialConfiguration: VoicePiFileConfiguration
        let loadedConfigurationSuccessfully: Bool
        do {
            initialConfiguration = try self.configStore.loadConfiguration()
            loadedConfigurationSuccessfully = true
        } catch {
            print("VoicePi config load failed, using defaults: \(error)")
            initialConfiguration = .init()
            loadedConfigurationSuccessfully = false
        }
        self.fileConfiguration = initialConfiguration

        if loadedConfigurationSuccessfully {
            do {
                try self.configStore.normalizePromptWorkspaceStorageIfNeeded(configuration: initialConfiguration)
            } catch {
                print("VoicePi prompt workspace normalization failed: \(error)")
            }
        }

        let resolvedPaths = self.configStore.resolvedPaths(for: initialConfiguration)
        if let dictionaryStore {
            self.dictionaryStore = dictionaryStore
        } else {
            self.dictionaryStore = DictionaryStore(configPaths: resolvedPaths)
        }
        if let historyStore {
            self.historyStore = historyStore
        } else {
            self.historyStore = HistoryStore(configPaths: resolvedPaths)
        }

        let initialPromptWorkspace = (try? self.configStore.loadPromptWorkspace(configuration: initialConfiguration)) ?? .init()
        let processorDocument = (try? self.configStore.loadExternalProcessors(configuration: initialConfiguration)) ?? .init()
        let persistedUserPrompt = (try? self.configStore.loadUserPrompt(configuration: initialConfiguration))

        let loadedActivationShortcut = ActivationShortcut(
            keyCodes: initialConfiguration.hotkeys.activation.keyCodes,
            modifierFlagsRawValue: initialConfiguration.hotkeys.activation.modifierFlags
        )
        let loadedCancelShortcut = ActivationShortcut(
            keyCodes: initialConfiguration.hotkeys.cancel.keyCodes,
            modifierFlagsRawValue: initialConfiguration.hotkeys.cancel.modifierFlags
        )

        self.selectedLanguage = initialConfiguration.app.language
        self.llmConfiguration = .init(
            baseURL: initialConfiguration.llm.baseURL,
            apiKey: initialConfiguration.llm.apiKey,
            model: initialConfiguration.llm.model,
            refinementPrompt: {
                let fromFile = persistedUserPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return fromFile.isEmpty ? initialConfiguration.llm.refinementPrompt : fromFile
            }(),
            enableThinking: initialConfiguration.llm.enableThinking
        )
        self.promptWorkspace = initialPromptWorkspace
        self.postProcessingMode = initialConfiguration.text.postProcessingMode
        self.translationProvider = initialConfiguration.text.translationProvider
        self.refinementProvider = initialConfiguration.text.refinementProvider
        self.externalProcessorEntries = processorDocument.entries
        self.selectedExternalProcessorEntryID = processorDocument.selectedEntryID.flatMap(UUID.init(uuidString:))
        self.targetLanguage = initialConfiguration.text.targetLanguage
        self.activationShortcut = loadedActivationShortcut.isEmpty
            ? AppModel.defaultActivationShortcut(defaults: defaults)
            : loadedActivationShortcut
        self.modeCycleShortcut = ActivationShortcut(
            keyCodes: initialConfiguration.hotkeys.modeCycle.keyCodes,
            modifierFlagsRawValue: initialConfiguration.hotkeys.modeCycle.modifierFlags
        )
        self.cancelShortcut = loadedCancelShortcut.isEmpty
            ? AppModel.defaultCancelShortcut
            : loadedCancelShortcut
        self.processorShortcut = ActivationShortcut(
            keyCodes: initialConfiguration.hotkeys.processor.keyCodes,
            modifierFlagsRawValue: initialConfiguration.hotkeys.processor.modifierFlags
        )
        self.promptCycleShortcut = ActivationShortcut(
            keyCodes: initialConfiguration.hotkeys.promptCycle.keyCodes,
            modifierFlagsRawValue: initialConfiguration.hotkeys.promptCycle.modifierFlags
        )
        self.asrBackend = initialConfiguration.asr.backend
        self.remoteASRConfiguration = .init(
            baseURL: initialConfiguration.asr.remote.baseURL,
            apiKey: initialConfiguration.asr.remote.apiKey,
            model: initialConfiguration.asr.remote.model,
            prompt: initialConfiguration.asr.remote.prompt,
            volcengineAppID: initialConfiguration.asr.remote.volcengineAppID
        )
        self.interfaceTheme = initialConfiguration.app.interfaceTheme

        if loadedConfigurationSuccessfully && loadedActivationShortcut.isEmpty {
            persistActivationShortcut()
        }
        if loadedConfigurationSuccessfully && loadedCancelShortcut.isEmpty {
            persistCancelShortcut()
        }

        refreshDictionaryState()
        refreshHistoryState()
    }

    private static func defaultConfigRootURL(
        for defaults: UserDefaults,
        fileManager: FileManager = .default
    ) -> URL {
        if defaults === UserDefaults.standard {
            return VoicePiConfigPaths.defaultRootDirectoryURL(fileManager: fileManager)
        }

        let markerKey = "voicepi.fileConfigRootPath"
        if let existingPath = defaults.string(forKey: markerKey), !existingPath.isEmpty {
            return URL(fileURLWithPath: existingPath, isDirectory: true)
        }

        let generatedRoot = fileManager.temporaryDirectory
            .appendingPathComponent("VoicePiUserDefaultsConfig", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defaults.set(generatedRoot.path, forKey: markerKey)
        return generatedRoot
    }

    func persistFileConfiguration(
        _ mutate: (inout VoicePiFileConfiguration) -> Void
    ) {
        var updated = fileConfiguration
        mutate(&updated)
        fileConfiguration = updated

        do {
            try configStore.saveConfiguration(updated)
        } catch {
            presentError("Configuration save failed: \(error.localizedDescription)")
        }
    }

    var activeFileConfiguration: VoicePiFileConfiguration {
        fileConfiguration
    }

    func reloadFromConfigStore() {
        do {
            let updatedConfiguration = try configStore.loadConfiguration()
            try configStore.normalizePromptWorkspaceStorageIfNeeded(configuration: updatedConfiguration)
            let workspace = try configStore.loadPromptWorkspace(configuration: updatedConfiguration)
            let processors = try configStore.loadExternalProcessors(configuration: updatedConfiguration)
            let persistedUserPrompt = try configStore.loadUserPrompt(configuration: updatedConfiguration)

            if shouldManageDictionaryStore {
                dictionaryStore = DictionaryStore(
                    configPaths: configStore.resolvedPaths(for: updatedConfiguration)
                )
            }
            if shouldManageHistoryStore {
                historyStore = HistoryStore(
                    configPaths: configStore.resolvedPaths(for: updatedConfiguration)
                )
            }

            isApplyingPersistedState = true
            fileConfiguration = updatedConfiguration
            selectedLanguage = updatedConfiguration.app.language
            llmConfiguration = .init(
                baseURL: updatedConfiguration.llm.baseURL,
                apiKey: updatedConfiguration.llm.apiKey,
                model: updatedConfiguration.llm.model,
                refinementPrompt: {
                    let fromFile = persistedUserPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    return fromFile.isEmpty ? updatedConfiguration.llm.refinementPrompt : fromFile
                }(),
                enableThinking: updatedConfiguration.llm.enableThinking
            )
            promptWorkspace = workspace
            postProcessingMode = updatedConfiguration.text.postProcessingMode
            translationProvider = updatedConfiguration.text.translationProvider
            refinementProvider = updatedConfiguration.text.refinementProvider
            externalProcessorEntries = processors.entries
            selectedExternalProcessorEntryID = processors.selectedEntryID.flatMap(UUID.init(uuidString:))
            targetLanguage = updatedConfiguration.text.targetLanguage
            activationShortcut = .init(
                keyCodes: updatedConfiguration.hotkeys.activation.keyCodes,
                modifierFlagsRawValue: updatedConfiguration.hotkeys.activation.modifierFlags
            )
            modeCycleShortcut = .init(
                keyCodes: updatedConfiguration.hotkeys.modeCycle.keyCodes,
                modifierFlagsRawValue: updatedConfiguration.hotkeys.modeCycle.modifierFlags
            )
            cancelShortcut = .init(
                keyCodes: updatedConfiguration.hotkeys.cancel.keyCodes,
                modifierFlagsRawValue: updatedConfiguration.hotkeys.cancel.modifierFlags
            )
            processorShortcut = .init(
                keyCodes: updatedConfiguration.hotkeys.processor.keyCodes,
                modifierFlagsRawValue: updatedConfiguration.hotkeys.processor.modifierFlags
            )
            promptCycleShortcut = .init(
                keyCodes: updatedConfiguration.hotkeys.promptCycle.keyCodes,
                modifierFlagsRawValue: updatedConfiguration.hotkeys.promptCycle.modifierFlags
            )
            asrBackend = updatedConfiguration.asr.backend
            remoteASRConfiguration = .init(
                baseURL: updatedConfiguration.asr.remote.baseURL,
                apiKey: updatedConfiguration.asr.remote.apiKey,
                model: updatedConfiguration.asr.remote.model,
                prompt: updatedConfiguration.asr.remote.prompt,
                volcengineAppID: updatedConfiguration.asr.remote.volcengineAppID
            )
            interfaceTheme = updatedConfiguration.app.interfaceTheme
            isApplyingPersistedState = false

            refreshDictionaryState()
            refreshHistoryState()
        } catch {
            isApplyingPersistedState = false
            presentError("Configuration reload failed: \(error.localizedDescription)")
        }
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
