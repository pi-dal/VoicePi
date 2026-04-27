import AppKit
import Foundation
import Testing
@testable import VoicePi

struct VoicePiLegacyMigrationTests {
    @Test
    func migrationMovesLegacyDefaultsAndFilesIntoConfigRoot() throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("VoicePiTests.LegacyMigration.\(UUID().uuidString)", isDirectory: true)
        let configRoot = tempRoot.appendingPathComponent("config", isDirectory: true)
        let legacyRoot = tempRoot.appendingPathComponent("legacy", isDirectory: true)
        try fileManager.createDirectory(at: configRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let suiteName = "VoicePiTests.LegacyMigration.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(SupportedLanguage.english.rawValue, forKey: AppModel.Keys.selectedLanguage)
        defaults.set(PostProcessingMode.translation.rawValue, forKey: AppModel.Keys.postProcessingMode)
        defaults.set(TranslationProvider.llm.rawValue, forKey: AppModel.Keys.translationProvider)
        defaults.set(RefinementProvider.externalProcessor.rawValue, forKey: AppModel.Keys.refinementProvider)
        defaults.set(SupportedLanguage.japanese.rawValue, forKey: AppModel.Keys.targetLanguage)
        defaults.set(ASRBackend.remoteOpenAICompatible.rawValue, forKey: AppModel.Keys.asrBackend)
        defaults.set(InterfaceTheme.dark.rawValue, forKey: AppModel.Keys.interfaceTheme)

        let llmConfiguration = LLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "llm-key",
            model: "gpt-test",
            refinementPrompt: "Legacy prompt",
            enableThinking: false
        )
        defaults.set(try JSONEncoder().encode(llmConfiguration), forKey: AppModel.Keys.llmConfig)

        let remoteConfiguration = RemoteASRConfiguration(
            baseURL: "https://asr.example.com",
            apiKey: "asr-key",
            model: "whisper",
            prompt: "Prefer punctuation",
            volcengineAppID: "volc-app"
        )
        defaults.set(try JSONEncoder().encode(remoteConfiguration), forKey: AppModel.Keys.remoteASRConfig)

        let promptPreset = PromptPreset(
            id: "user.migrated",
            title: "Migrated Prompt",
            body: "Use concise markdown bullets.",
            source: .user
        )
        let workspace = PromptWorkspaceSettings(
            activeSelection: .preset(promptPreset.id),
            userPresets: [promptPreset]
        )
        defaults.set(try JSONEncoder().encode(workspace), forKey: AppModel.Keys.promptWorkspace)

        let processorEntry = ExternalProcessorEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Alma",
            kind: .almaCLI,
            executablePath: "/usr/local/bin/alma",
            additionalArguments: [ExternalProcessorArgument(value: "--raw")],
            isEnabled: true
        )
        defaults.set(try JSONEncoder().encode([processorEntry]), forKey: AppModel.Keys.externalProcessorEntries)
        defaults.set(processorEntry.id.uuidString, forKey: AppModel.Keys.selectedExternalProcessorEntryID)
        defaults.set(
            try JSONEncoder().encode(ActivationShortcut(keyCodes: [35], modifierFlagsRawValue: NSEvent.ModifierFlags.control.rawValue)),
            forKey: AppModel.Keys.activationShortcut
        )

        let legacyDictionaryStore = DictionaryStore(
            dictionaryFileURL: legacyRoot.appendingPathComponent("Dictionary.json", isDirectory: false),
            suggestionsFileURL: legacyRoot.appendingPathComponent("DictionarySuggestions.json", isDirectory: false)
        )
        try legacyDictionaryStore.saveDictionary(.init(entries: [
            DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre"])
        ]))
        try legacyDictionaryStore.saveSuggestions(.init(suggestions: [
            DictionarySuggestion(
                originalFragment: "cloud flare",
                correctedFragment: "Cloudflare",
                proposedCanonical: "Cloudflare",
                proposedAliases: ["cloud flare"]
            )
        ]))

        let legacyHistoryStore = HistoryStore(
            historyFileURL: legacyRoot.appendingPathComponent("History.json", isDirectory: false)
        )
        try legacyHistoryStore.saveHistory(.init(entries: [
            HistoryEntry(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                text: "Legacy first entry",
                createdAt: Date(timeIntervalSince1970: 1_744_860_800),
                recordingDurationMilliseconds: 1_000
            ),
            HistoryEntry(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                text: "Legacy second entry",
                createdAt: Date(timeIntervalSince1970: 1_744_947_200),
                recordingDurationMilliseconds: 2_000
            )
        ]))

        let configStore = VoicePiConfigStore(
            paths: VoicePiConfigPaths(rootDirectoryURL: configRoot)
        )
        let migration = VoicePiLegacyMigration(
            defaults: defaults,
            configStore: configStore,
            legacyDictionaryStore: legacyDictionaryStore,
            legacyHistoryStore: legacyHistoryStore
        )

        try migration.runIfNeeded()

        let migratedConfiguration = try configStore.loadConfiguration()
        let migratedPaths = configStore.resolvedPaths(for: migratedConfiguration)

        #expect(fileManager.fileExists(atPath: migratedPaths.configFileURL.path))
        #expect(fileManager.fileExists(atPath: migratedPaths.userPromptURL.path))
        #expect(fileManager.fileExists(atPath: migratedPaths.dictionaryURL.path))
        #expect(fileManager.fileExists(atPath: migratedPaths.dictionarySuggestionsURL.path))
        #expect(fileManager.fileExists(atPath: migratedPaths.historyFileURL(for: Date(timeIntervalSince1970: 1_744_947_200)).path))

        #expect(migratedConfiguration.app.language == .english)
        #expect(migratedConfiguration.app.interfaceTheme == .dark)
        #expect(migratedConfiguration.text.postProcessingMode == .translation)
        #expect(migratedConfiguration.asr.backend == .remoteOpenAICompatible)

        let migratedWorkspace = try configStore.loadPromptWorkspace(configuration: migratedConfiguration)
        #expect(migratedWorkspace.userPresets == [promptPreset])

        let processorsDocument = try configStore.loadExternalProcessors(configuration: migratedConfiguration)
        #expect(processorsDocument.entries == [processorEntry])
        #expect(processorsDocument.selectedEntryID == processorEntry.id.uuidString)
    }

    @Test
    func migrationResumesWhenConfigExistsWithoutCompletionMarker() throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("VoicePiTests.LegacyMigration.Resume.\(UUID().uuidString)", isDirectory: true)
        let configRoot = tempRoot.appendingPathComponent("config", isDirectory: true)
        let legacyRoot = tempRoot.appendingPathComponent("legacy", isDirectory: true)
        try fileManager.createDirectory(at: configRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let suiteName = "VoicePiTests.LegacyMigration.Resume.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let llmConfiguration = LLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "llm-key",
            model: "gpt-test",
            refinementPrompt: "Resume prompt",
            enableThinking: false
        )
        defaults.set(try JSONEncoder().encode(llmConfiguration), forKey: AppModel.Keys.llmConfig)

        let legacyDictionaryStore = DictionaryStore(
            dictionaryFileURL: legacyRoot.appendingPathComponent("Dictionary.json", isDirectory: false),
            suggestionsFileURL: legacyRoot.appendingPathComponent("DictionarySuggestions.json", isDirectory: false)
        )
        try legacyDictionaryStore.saveDictionary(.init(entries: [
            DictionaryEntry(canonical: "Resume", aliases: ["resume"])
        ]))

        let legacyHistoryStore = HistoryStore(
            historyFileURL: legacyRoot.appendingPathComponent("History.json", isDirectory: false)
        )
        let historyEntryDate = Date(timeIntervalSince1970: 1_744_860_800)
        try legacyHistoryStore.saveHistory(.init(entries: [
            HistoryEntry(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                text: "Resume migration history",
                createdAt: historyEntryDate,
                recordingDurationMilliseconds: 1_000
            )
        ]))

        let configStore = VoicePiConfigStore(
            paths: VoicePiConfigPaths(rootDirectoryURL: configRoot)
        )
        try configStore.saveConfiguration(.init())

        let migration = VoicePiLegacyMigration(
            defaults: defaults,
            configStore: configStore,
            legacyDictionaryStore: legacyDictionaryStore,
            legacyHistoryStore: legacyHistoryStore
        )

        try migration.runIfNeeded()

        let configuration = try configStore.loadConfiguration()
        let paths = configStore.resolvedPaths(for: configuration)

        #expect(fileManager.fileExists(atPath: paths.migrationMarkerURL.path))
        #expect(fileManager.fileExists(atPath: paths.promptWorkspaceURL.path))
        #expect(fileManager.fileExists(atPath: paths.userPromptURL.path))
        #expect(fileManager.fileExists(atPath: paths.dictionaryURL.path))
        #expect(fileManager.fileExists(atPath: paths.historyFileURL(for: historyEntryDate).path))
    }
}
