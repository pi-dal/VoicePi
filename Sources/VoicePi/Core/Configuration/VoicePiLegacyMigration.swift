import AppKit
import Foundation

struct VoicePiLegacyMigration {
    static let currentMigrationVersion = 1

    let defaults: UserDefaults
    let configStore: VoicePiConfigStore
    let legacyDictionaryStore: DictionaryStoring
    let legacyHistoryStore: HistoryStoring
    let jsonDecoder: JSONDecoder
    let jsonEncoder: JSONEncoder
    let fileManager: FileManager

    init(
        defaults: UserDefaults,
        configStore: VoicePiConfigStore,
        legacyDictionaryStore: DictionaryStoring? = nil,
        legacyHistoryStore: HistoryStoring? = nil,
        jsonDecoder: JSONDecoder = JSONDecoder(),
        jsonEncoder: JSONEncoder = JSONEncoder(),
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.configStore = configStore
        self.legacyDictionaryStore = legacyDictionaryStore ?? (try? DictionaryStore(fileManager: fileManager)) ?? DictionaryStore(
            dictionaryFileURL: fileManager.temporaryDirectory.appendingPathComponent("VoicePi.LegacyDictionaryFallback.json"),
            suggestionsFileURL: fileManager.temporaryDirectory.appendingPathComponent("VoicePi.LegacyDictionarySuggestionsFallback.json")
        )
        self.legacyHistoryStore = legacyHistoryStore ?? (try? HistoryStore(fileManager: fileManager)) ?? HistoryStore(
            historyFileURL: fileManager.temporaryDirectory.appendingPathComponent("VoicePi.LegacyHistoryFallback.json")
        )
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
        self.fileManager = fileManager
    }

    func runIfNeeded() throws {
        let basePaths = configStore.resolvedPaths(for: .init())
        if migrationVersion(at: basePaths.migrationMarkerURL) >= Self.currentMigrationVersion {
            return
        }

        let configuration: VoicePiFileConfiguration
        if configStore.hasConfigFile() {
            configuration = try configStore.loadConfiguration()
        } else {
            configuration = buildConfigurationFromDefaults()
            try configStore.saveConfiguration(configuration)
        }

        let resolvedPaths = configStore.resolvedPaths(for: configuration)
        try migratePrompts(configuration: configuration, resolvedPaths: resolvedPaths)
        try migrateProcessors(configuration: configuration, resolvedPaths: resolvedPaths)
        try migrateDictionary(configuration: configuration, resolvedPaths: resolvedPaths)
        try migrateHistory(resolvedPaths: resolvedPaths)
        try writeMigrationMarker(at: resolvedPaths.migrationMarkerURL)
    }

    private func buildConfigurationFromDefaults() -> VoicePiFileConfiguration {
        let llmConfiguration: LLMConfiguration = decodeDefaultsValue(
            LLMConfiguration.self,
            key: AppModel.Keys.llmConfig,
            fallback: .init()
        )
        let remoteASRConfiguration: RemoteASRConfiguration = decodeDefaultsValue(
            RemoteASRConfiguration.self,
            key: AppModel.Keys.remoteASRConfig,
            fallback: .init()
        )
        let activationShortcut: ActivationShortcut = decodeDefaultsValue(
            ActivationShortcut.self,
            key: AppModel.Keys.activationShortcut,
            fallback: defaultActivationShortcut()
        )
        let modeCycleShortcut: ActivationShortcut = decodeDefaultsValue(
            ActivationShortcut.self,
            key: AppModel.Keys.modeCycleShortcut,
            fallback: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
        )
        let cancelShortcut: ActivationShortcut = decodeDefaultsValue(
            ActivationShortcut.self,
            key: AppModel.Keys.cancelShortcut,
            fallback: defaultCancelShortcut
        )
        let processorShortcut: ActivationShortcut = decodeDefaultsValue(
            ActivationShortcut.self,
            key: AppModel.Keys.processorShortcut,
            fallback: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
        )
        let promptCycleShortcut: ActivationShortcut = decodeDefaultsValue(
            ActivationShortcut.self,
            key: AppModel.Keys.promptCycleShortcut,
            fallback: ActivationShortcut(keyCodes: [], modifierFlagsRawValue: 0)
        )

        return VoicePiFileConfiguration(
            app: .init(
                language: loadEnum(SupportedLanguage.self, key: AppModel.Keys.selectedLanguage, fallback: .default),
                interfaceTheme: loadEnum(InterfaceTheme.self, key: AppModel.Keys.interfaceTheme, fallback: .system)
            ),
            asr: .init(
                backend: loadEnum(ASRBackend.self, key: AppModel.Keys.asrBackend, fallback: .default),
                remote: .init(
                    baseURL: remoteASRConfiguration.baseURL,
                    apiKey: remoteASRConfiguration.apiKey,
                    model: remoteASRConfiguration.model,
                    prompt: remoteASRConfiguration.prompt,
                    volcengineAppID: remoteASRConfiguration.volcengineAppID
                )
            ),
            text: .init(
                postProcessingMode: loadPostProcessingMode(),
                translationProvider: loadEnum(TranslationProvider.self, key: AppModel.Keys.translationProvider, fallback: .appleTranslate),
                refinementProvider: loadEnum(RefinementProvider.self, key: AppModel.Keys.refinementProvider, fallback: .llm),
                targetLanguage: loadEnum(
                    SupportedLanguage.self,
                    key: AppModel.Keys.targetLanguage,
                    fallback: loadEnum(SupportedLanguage.self, key: AppModel.Keys.selectedLanguage, fallback: .default)
                )
            ),
            llm: .init(
                baseURL: llmConfiguration.baseURL,
                apiKey: llmConfiguration.apiKey,
                model: llmConfiguration.model,
                refinementPrompt: llmConfiguration.refinementPrompt,
                enableThinking: llmConfiguration.enableThinking ?? false
            ),
            hotkeys: .init(
                activation: .init(
                    keyCodes: activationShortcut.keyCodes,
                    modifierFlags: activationShortcut.modifierFlagsRawValue
                ),
                cancel: .init(
                    keyCodes: cancelShortcut.keyCodes,
                    modifierFlags: cancelShortcut.modifierFlagsRawValue
                ),
                modeCycle: .init(
                    keyCodes: modeCycleShortcut.keyCodes,
                    modifierFlags: modeCycleShortcut.modifierFlagsRawValue
                ),
                processor: .init(
                    keyCodes: processorShortcut.keyCodes,
                    modifierFlags: processorShortcut.modifierFlagsRawValue
                ),
                promptCycle: .init(
                    keyCodes: promptCycleShortcut.keyCodes,
                    modifierFlags: promptCycleShortcut.modifierFlagsRawValue
                )
            ),
            history: .init(
                enabled: true,
                storeText: true,
                directory: "history"
            ),
            paths: .init()
        )
    }

    private func migratePrompts(
        configuration: VoicePiFileConfiguration,
        resolvedPaths: VoicePiConfigPaths
    ) throws {
        let llmConfiguration: LLMConfiguration = decodeDefaultsValue(
            LLMConfiguration.self,
            key: AppModel.Keys.llmConfig,
            fallback: .init()
        )
        let workspace: PromptWorkspaceSettings = decodeDefaultsValue(
            PromptWorkspaceSettings.self,
            key: AppModel.Keys.promptWorkspace,
            fallback: migratePromptWorkspaceFromDefaults(initialLLMConfiguration: llmConfiguration)
        )

        let promptWorkspaceExists = fileManager.fileExists(atPath: resolvedPaths.promptWorkspaceURL.path)
        let promptPresetFilesExist = directoryContainsJSONFiles(at: resolvedPaths.promptPresetsDirectoryURL)

        if !promptWorkspaceExists && !promptPresetFilesExist {
            try configStore.savePromptWorkspace(workspace, configuration: configuration)
        } else if !promptWorkspaceExists && promptPresetFilesExist {
            let existingWorkspace = try configStore.loadPromptWorkspace(configuration: configuration)
            try configStore.savePromptWorkspace(existingWorkspace, configuration: configuration)
        }
        if !fileManager.fileExists(atPath: resolvedPaths.userPromptURL.path) {
            try configStore.saveUserPrompt(llmConfiguration.refinementPrompt, configuration: configuration)
        }
    }

    private func migrateProcessors(
        configuration: VoicePiFileConfiguration,
        resolvedPaths: VoicePiConfigPaths
    ) throws {
        guard !fileManager.fileExists(atPath: resolvedPaths.processorsURL.path) else {
            return
        }

        let entries: [ExternalProcessorEntry] = decodeDefaultsValue(
            [ExternalProcessorEntry].self,
            key: AppModel.Keys.externalProcessorEntries,
            fallback: []
        )
        let selectedEntryID = defaults.string(forKey: AppModel.Keys.selectedExternalProcessorEntryID)
        try configStore.saveExternalProcessors(
            .init(entries: entries, selectedEntryID: selectedEntryID),
            configuration: configuration
        )
    }

    private func migrateDictionary(
        configuration: VoicePiFileConfiguration,
        resolvedPaths: VoicePiConfigPaths
    ) throws {
        if !fileManager.fileExists(atPath: resolvedPaths.dictionaryURL.path) {
            let dictionary = try legacyDictionaryStore.loadDictionary()
            try configStore.saveDictionary(dictionary, configuration: configuration)
        }
        if !fileManager.fileExists(atPath: resolvedPaths.dictionarySuggestionsURL.path) {
            let suggestions = try legacyDictionaryStore.loadSuggestions()
            try configStore.saveDictionarySuggestions(suggestions, configuration: configuration)
        }
    }

    private func migrateHistory(resolvedPaths: VoicePiConfigPaths) throws {
        let document = try legacyHistoryStore.loadHistory()
        try fileManager.createDirectory(at: resolvedPaths.historyDirectoryURL, withIntermediateDirectories: true)

        let grouped = Dictionary(grouping: document.entries) { entry in
            VoicePiConfigPaths.historyMonthString(for: entry.createdAt)
        }

        for month in grouped.keys.sorted() {
            let entries = grouped[month] ?? []
            let lines = try entries
                .sorted(by: { $0.createdAt > $1.createdAt })
                .map(encodeHistoryJSONLLine)
                .joined(separator: "\n")
            let payload = lines.isEmpty ? "" : "\(lines)\n"
            let url = resolvedPaths.historyDirectoryURL.appendingPathComponent("\(month).jsonl", isDirectory: false)
            guard !fileManager.fileExists(atPath: url.path) else {
                continue
            }
            try payload.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func encodeHistoryJSONLLine(_ entry: HistoryEntry) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let record = HistoryJSONLRecord(
            id: entry.id,
            text: entry.text,
            createdAt: entry.createdAt,
            characterCount: entry.characterCount,
            wordCount: entry.wordCount,
            recordingDurationMilliseconds: entry.recordingDurationMilliseconds
        )
        let data = try encoder.encode(record)
        return String(decoding: data, as: UTF8.self)
    }

    private func writeMigrationMarker(at url: URL) throws {
        let value = "\(Self.currentMigrationVersion)\n"
        try value.write(to: url, atomically: true, encoding: .utf8)
    }

    private func migrationVersion(at url: URL) -> Int {
        guard fileManager.fileExists(atPath: url.path) else {
            return 0
        }

        guard let rawValue = try? String(contentsOf: url, encoding: .utf8) else {
            return 0
        }

        return Int(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func directoryContainsJSONFiles(at url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }

        let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )
        return contents?.contains(where: { $0.pathExtension.lowercased() == "json" }) ?? false
    }

    private func loadPostProcessingMode() -> PostProcessingMode {
        if let mode = loadOptionalEnum(PostProcessingMode.self, key: AppModel.Keys.postProcessingMode) {
            return mode
        }
        let llmEnabled = defaults.object(forKey: AppModel.Keys.llmEnabled) as? Bool ?? false
        return llmEnabled ? .refinement : .disabled
    }

    private func loadEnum<T: RawRepresentable>(
        _ type: T.Type,
        key: String,
        fallback: T
    ) -> T where T.RawValue == String {
        loadOptionalEnum(type, key: key) ?? fallback
    }

    private func loadOptionalEnum<T: RawRepresentable>(
        _ type: T.Type,
        key: String
    ) -> T? where T.RawValue == String {
        guard let value = defaults.string(forKey: key) else { return nil }
        return T(rawValue: value)
    }

    private func decodeDefaultsValue<T: Decodable>(
        _ type: T.Type,
        key: String,
        fallback: T
    ) -> T {
        guard let data = defaults.data(forKey: key) else { return fallback }
        guard let value = try? jsonDecoder.decode(type, from: data) else { return fallback }
        return value
    }

    private func migratePromptWorkspaceFromDefaults(
        initialLLMConfiguration: LLMConfiguration
    ) -> PromptWorkspaceSettings {
        if
            let data = defaults.data(forKey: AppModel.Keys.promptSettings),
            let decoded = try? jsonDecoder.decode(PromptSettings.self, from: data),
            let library = try? PromptLibrary.loadBundled(),
            let resolved = try? PromptResolver.resolve(
                appID: .voicePi,
                globalSelection: decoded.defaultSelection,
                appSelection: decoded.selection(for: .voicePi) ?? .inherit,
                library: library,
                legacyCustomPrompt: initialLLMConfiguration.refinementPrompt
            ),
            let middleSection = resolved.middleSection,
            !middleSection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            let imported = PromptPreset(
                id: "user.imported.\(UUID().uuidString.lowercased())",
                title: resolved.title ?? "Imported Prompt",
                body: middleSection,
                source: .user
            )
            return .init(
                activeSelection: .preset(imported.id),
                userPresets: [imported]
            )
        }

        if !initialLLMConfiguration.trimmedRefinementPrompt.isEmpty {
            let imported = PromptPreset(
                id: "user.imported.\(UUID().uuidString.lowercased())",
                title: "Imported Prompt",
                body: initialLLMConfiguration.trimmedRefinementPrompt,
                source: .user
            )
            return .init(
                activeSelection: .preset(imported.id),
                userPresets: [imported]
            )
        }

        return .init()
    }

    private var defaultCancelShortcut: ActivationShortcut {
        ActivationShortcut(
            keyCodes: [47],
            modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
        )
    }

    private func defaultActivationShortcut() -> ActivationShortcut {
        if hasExistingInstallationState() {
            return .legacyDefault
        }
        return .default
    }

    private func hasExistingInstallationState() -> Bool {
        let legacyAndCurrentKeys = [
            AppModel.Keys.selectedLanguage,
            AppModel.Keys.llmEnabled,
            AppModel.Keys.llmConfig,
            AppModel.Keys.promptSettings,
            AppModel.Keys.promptWorkspace,
            AppModel.Keys.postProcessingMode,
            AppModel.Keys.translationProvider,
            AppModel.Keys.refinementProvider,
            AppModel.Keys.externalProcessorEntries,
            AppModel.Keys.selectedExternalProcessorEntryID,
            AppModel.Keys.targetLanguage,
            AppModel.Keys.modeCycleShortcut,
            AppModel.Keys.cancelShortcut,
            AppModel.Keys.processorShortcut,
            AppModel.Keys.promptCycleShortcut,
            AppModel.Keys.asrBackend,
            AppModel.Keys.remoteASRConfig,
            AppModel.Keys.interfaceTheme
        ]

        return legacyAndCurrentKeys.contains { defaults.object(forKey: $0) != nil }
    }
}

private struct HistoryJSONLRecord: Codable {
    let id: UUID
    let text: String
    let createdAt: Date
    let characterCount: Int
    let wordCount: Int
    let recordingDurationMilliseconds: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case createdAt = "created_at"
        case characterCount = "character_count"
        case wordCount = "word_count"
        case recordingDurationMilliseconds = "recording_duration_milliseconds"
    }
}
