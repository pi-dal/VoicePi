import Foundation
import TOMLKit

struct VoicePiProcessorsDocument: Codable, Equatable {
    var entries: [ExternalProcessorEntry]
    var selectedEntryID: String?

    init(
        entries: [ExternalProcessorEntry] = [],
        selectedEntryID: String? = nil
    ) {
        self.entries = entries
        self.selectedEntryID = selectedEntryID
    }
}

private struct PromptWorkspaceManifest: Codable, Equatable {
    var activeSelection: PromptActiveSelection
    var strictModeEnabled: Bool
    var userPresetIDs: [String]

    init(
        activeSelection: PromptActiveSelection = .builtInDefault,
        strictModeEnabled: Bool = true,
        userPresetIDs: [String] = []
    ) {
        self.activeSelection = activeSelection
        self.strictModeEnabled = strictModeEnabled
        self.userPresetIDs = userPresetIDs
    }

    init(workspace: PromptWorkspaceSettings) {
        self.activeSelection = workspace.activeSelection
        self.strictModeEnabled = workspace.strictModeEnabled
        self.userPresetIDs = workspace.userPresets.map(\.id)
    }
}

private struct LoadedPromptWorkspaceDocument {
    let workspace: PromptWorkspaceSettings
    let preferredPresetIDs: [String]
}

final class VoicePiConfigStore {
    private let basePaths: VoicePiConfigPaths
    private let fileManager: FileManager
    private let tomlEncoder: TOMLEncoder
    private let tomlDecoder: TOMLDecoder
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    init(
        paths: VoicePiConfigPaths = .init(),
        fileManager: FileManager = .default,
        tomlEncoder: TOMLEncoder = TOMLEncoder(),
        tomlDecoder: TOMLDecoder = TOMLDecoder(),
        jsonEncoder: JSONEncoder = JSONEncoder(),
        jsonDecoder: JSONDecoder = JSONDecoder()
    ) {
        self.basePaths = paths
        self.fileManager = fileManager
        self.tomlEncoder = tomlEncoder
        self.tomlDecoder = tomlDecoder
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var rootDirectoryURL: URL { basePaths.rootDirectoryURL }

    func resolvedPaths(for configuration: VoicePiFileConfiguration) -> VoicePiConfigPaths {
        VoicePiConfigPaths(
            rootDirectoryURL: basePaths.rootDirectoryURL,
            configuration: configuration
        )
    }

    func hasConfigFile() -> Bool {
        fileManager.fileExists(atPath: basePaths.configFileURL.path)
    }

    func ensureConfigRootExists(configuration: VoicePiFileConfiguration = .init()) throws {
        let resolved = resolvedPaths(for: configuration)
        try fileManager.createDirectory(at: resolved.rootDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resolved.historyDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resolved.promptPresetsDirectoryURL, withIntermediateDirectories: true)
    }

    func loadConfiguration() throws -> VoicePiFileConfiguration {
        if !hasConfigFile() {
            let defaultConfiguration = VoicePiFileConfiguration()
            try saveConfiguration(defaultConfiguration)
            return defaultConfiguration
        }

        let tomlString = try String(contentsOf: basePaths.configFileURL, encoding: .utf8)
        return try tomlDecoder.decode(VoicePiFileConfiguration.self, from: tomlString)
    }

    func saveConfiguration(_ configuration: VoicePiFileConfiguration) throws {
        try ensureConfigRootExists(configuration: configuration)
        let tomlString = try tomlEncoder.encode(configuration)
        try tomlString.write(
            to: basePaths.configFileURL,
            atomically: true,
            encoding: .utf8
        )
    }

    func loadUserPrompt(configuration: VoicePiFileConfiguration) throws -> String {
        try loadTextFile(at: resolvedPaths(for: configuration).userPromptURL)
    }

    func saveUserPrompt(
        _ prompt: String,
        configuration: VoicePiFileConfiguration
    ) throws {
        try saveTextFile(prompt, to: resolvedPaths(for: configuration).userPromptURL)
    }

    func loadPromptWorkspace(configuration: VoicePiFileConfiguration) throws -> PromptWorkspaceSettings {
        let paths = resolvedPaths(for: configuration)
        let loadedDocument = try loadPromptWorkspaceDocument(
            at: paths.promptWorkspaceURL,
            fallback: PromptWorkspaceSettings()
        )
        let filePresets = try loadPromptPresetFiles(from: paths.promptPresetsDirectoryURL)
        if filePresets.isEmpty {
            return loadedDocument.workspace
        }

        return PromptWorkspaceSettings(
            activeSelection: loadedDocument.workspace.activeSelection,
            strictModeEnabled: loadedDocument.workspace.strictModeEnabled,
            userPresets: orderedPromptPresets(
                from: filePresets,
                preferredIDs: loadedDocument.preferredPresetIDs
            )
        )
    }

    func savePromptWorkspace(
        _ workspace: PromptWorkspaceSettings,
        configuration: VoicePiFileConfiguration
    ) throws {
        let paths = resolvedPaths(for: configuration)
        try ensureConfigRootExists(configuration: configuration)

        let userPresets = workspace.userPresets.filter { $0.source == .user }
        try fileManager.createDirectory(at: paths.promptPresetsDirectoryURL, withIntermediateDirectories: true)

        var expectedFilenames: Set<String> = []
        for preset in userPresets {
            let fileURL = paths.promptPresetFileURL(for: preset.id)
            expectedFilenames.insert(fileURL.lastPathComponent)
            try saveJSONDocument(preset, to: fileURL)
        }

        let existingPresetFiles = try fileManager.contentsOfDirectory(
            at: paths.promptPresetsDirectoryURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "json" }

        for fileURL in existingPresetFiles where !expectedFilenames.contains(fileURL.lastPathComponent) {
            try fileManager.removeItem(at: fileURL)
        }

        let manifest = PromptWorkspaceManifest(
            activeSelection: workspace.activeSelection,
            strictModeEnabled: workspace.strictModeEnabled,
            userPresetIDs: userPresets.map(\.id)
        )
        try saveJSONDocument(manifest, to: paths.promptWorkspaceURL)
    }

    func normalizePromptWorkspaceStorageIfNeeded(
        configuration: VoicePiFileConfiguration
    ) throws {
        let paths = resolvedPaths(for: configuration)
        guard let legacyWorkspace = try loadLegacyEmbeddedPromptWorkspaceIfPresent(
            at: paths.promptWorkspaceURL
        ) else {
            return
        }

        let filePresets = try loadPromptPresetFiles(from: paths.promptPresetsDirectoryURL)
        let effectiveWorkspace: PromptWorkspaceSettings
        if filePresets.isEmpty {
            effectiveWorkspace = legacyWorkspace
        } else {
            effectiveWorkspace = PromptWorkspaceSettings(
                activeSelection: legacyWorkspace.activeSelection,
                strictModeEnabled: legacyWorkspace.strictModeEnabled,
                userPresets: orderedPromptPresets(
                    from: filePresets,
                    preferredIDs: legacyWorkspace.userPresets.map(\.id)
                )
            )
        }

        try savePromptWorkspace(effectiveWorkspace, configuration: configuration)
    }

    func loadExternalProcessors(configuration: VoicePiFileConfiguration) throws -> VoicePiProcessorsDocument {
        try loadJSONDocument(
            at: resolvedPaths(for: configuration).processorsURL,
            fallback: VoicePiProcessorsDocument()
        )
    }

    func saveExternalProcessors(
        _ document: VoicePiProcessorsDocument,
        configuration: VoicePiFileConfiguration
    ) throws {
        try saveJSONDocument(
            document,
            to: resolvedPaths(for: configuration).processorsURL
        )
    }

    func loadDictionary(configuration: VoicePiFileConfiguration) throws -> DictionaryDocument {
        try loadJSONDocument(
            at: resolvedPaths(for: configuration).dictionaryURL,
            fallback: DictionaryDocument()
        )
    }

    func saveDictionary(
        _ dictionary: DictionaryDocument,
        configuration: VoicePiFileConfiguration
    ) throws {
        try saveJSONDocument(
            dictionary,
            to: resolvedPaths(for: configuration).dictionaryURL
        )
    }

    func loadDictionarySuggestions(configuration: VoicePiFileConfiguration) throws -> DictionarySuggestionDocument {
        try loadJSONDocument(
            at: resolvedPaths(for: configuration).dictionarySuggestionsURL,
            fallback: DictionarySuggestionDocument()
        )
    }

    func saveDictionarySuggestions(
        _ suggestions: DictionarySuggestionDocument,
        configuration: VoicePiFileConfiguration
    ) throws {
        try saveJSONDocument(
            suggestions,
            to: resolvedPaths(for: configuration).dictionarySuggestionsURL
        )
    }

    private func loadTextFile(at url: URL) throws -> String {
        if !fileManager.fileExists(atPath: url.path) {
            try saveTextFile("", to: url)
            return ""
        }

        let data = try Data(contentsOf: url)
        return String(decoding: data, as: UTF8.self)
    }

    private func loadPromptWorkspaceDocument(
        at url: URL,
        fallback: PromptWorkspaceSettings
    ) throws -> LoadedPromptWorkspaceDocument {
        guard fileManager.fileExists(atPath: url.path) else {
            return .init(
                workspace: fallback,
                preferredPresetIDs: fallback.userPresets.map(\.id)
            )
        }

        let data = try Data(contentsOf: url)
        if let manifest = try? jsonDecoder.decode(PromptWorkspaceManifest.self, from: data) {
            return .init(
                workspace: PromptWorkspaceSettings(
                    activeSelection: manifest.activeSelection,
                    strictModeEnabled: manifest.strictModeEnabled,
                    userPresets: []
                ),
                preferredPresetIDs: manifest.userPresetIDs
            )
        }

        let workspace = try jsonDecoder.decode(PromptWorkspaceSettings.self, from: data)
        return .init(
            workspace: workspace,
            preferredPresetIDs: workspace.userPresets.map(\.id)
        )
    }

    private func loadPromptPresetFiles(from directoryURL: URL) throws -> [PromptPreset] {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try files.map { fileURL in
            let data = try Data(contentsOf: fileURL)
            return try jsonDecoder.decode(PromptPreset.self, from: data)
        }
    }

    private func loadLegacyEmbeddedPromptWorkspaceIfPresent(
        at url: URL
    ) throws -> PromptWorkspaceSettings? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        if (try? jsonDecoder.decode(PromptWorkspaceManifest.self, from: data)) != nil {
            return nil
        }

        let workspace = try jsonDecoder.decode(PromptWorkspaceSettings.self, from: data)
        return workspace.userPresets.isEmpty ? nil : workspace
    }

    private func orderedPromptPresets(
        from presets: [PromptPreset],
        preferredIDs: [String]
    ) -> [PromptPreset] {
        let presetsByID = Dictionary(uniqueKeysWithValues: presets.map { ($0.id, $0) })
        var orderedPresets: [PromptPreset] = []
        var remainingPresets = presetsByID

        let effectiveIDs = preferredIDs.isEmpty ? presets.map(\.id) : preferredIDs
        for presetID in effectiveIDs {
            guard let preset = remainingPresets.removeValue(forKey: presetID) else { continue }
            orderedPresets.append(preset)
        }

        if !remainingPresets.isEmpty {
            orderedPresets.append(
                contentsOf: remainingPresets.values.sorted {
                    $0.resolvedTitle.localizedCaseInsensitiveCompare($1.resolvedTitle) == .orderedAscending
                }
            )
        }

        return orderedPresets
    }

    private func saveTextFile(_ value: String, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = Data(value.utf8)
        try data.write(to: url, options: .atomic)
    }

    private func loadJSONDocument<T: Codable>(
        at url: URL,
        fallback: T
    ) throws -> T {
        if !fileManager.fileExists(atPath: url.path) {
            try saveJSONDocument(fallback, to: url)
            return fallback
        }

        let data = try Data(contentsOf: url)
        return try jsonDecoder.decode(T.self, from: data)
    }

    private func saveJSONDocument<T: Codable>(
        _ value: T,
        to url: URL
    ) throws {
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try jsonEncoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
