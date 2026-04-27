import Foundation
import Testing
@testable import VoicePi

@MainActor
struct PromptFilePersistenceTests {
    @Test
    func savingPromptWorkspacePersistsWorkspaceAndUserPromptFile() throws {
        let fixture = try PromptFilePersistenceFixture()
        defer { fixture.cleanup() }

        let model = fixture.makeModel()
        let preset = PromptPreset(
            id: "user.release-notes",
            title: "Release Notes",
            body: "Write concise markdown release notes.",
            source: .user
        )
        model.promptWorkspace = .init(
            activeSelection: .preset(preset.id),
            userPresets: [preset]
        )

        let configuration = try fixture.configStore.loadConfiguration()
        let paths = fixture.configStore.resolvedPaths(for: configuration)
        let persistedWorkspace = try fixture.configStore.loadPromptWorkspace(configuration: configuration)
        let persistedUserPrompt = try String(contentsOf: paths.userPromptURL, encoding: .utf8)
        let persistedWorkspaceJSON = try String(contentsOf: paths.promptWorkspaceURL, encoding: .utf8)
        let persistedPresetJSON = try String(
            contentsOf: fixture.rootURL.appendingPathComponent("prompts/user.release-notes.json", isDirectory: false),
            encoding: .utf8
        )

        #expect(persistedWorkspace.userPresets == [preset])
        #expect(persistedWorkspace.activeSelection == .preset(preset.id))
        #expect(persistedUserPrompt.contains("Write concise markdown release notes."))
        #expect(!persistedWorkspaceJSON.contains("\"userPresets\""))
        #expect(persistedPresetJSON.contains("Write concise markdown release notes."))
    }

    @Test
    func reloadFromDiskUpdatesModelPromptWorkspace() throws {
        let fixture = try PromptFilePersistenceFixture()
        defer { fixture.cleanup() }

        let model = fixture.makeModel()
        var configuration = try fixture.configStore.loadConfiguration()
        let preset = PromptPreset(
            id: "user.disk",
            title: "Disk Prompt",
            body: "Loaded from disk",
            source: .user
        )
        let workspace = PromptWorkspaceSettings(
            activeSelection: .preset(preset.id),
            userPresets: [preset]
        )
        try fixture.configStore.savePromptWorkspace(workspace, configuration: configuration)
        try fixture.configStore.saveUserPrompt("Loaded from disk", configuration: configuration)

        configuration.llm.refinementPrompt = "Loaded from disk"
        try fixture.configStore.saveConfiguration(configuration)
        model.reloadFromConfigStore()

        #expect(model.promptWorkspace == workspace)
        #expect(model.llmConfiguration.refinementPrompt == "Loaded from disk")
    }

    @Test
    func legacyEmbeddedWorkspacePromptsRemainReadableAndNormalizeOnSave() throws {
        let fixture = try PromptFilePersistenceFixture()
        defer { fixture.cleanup() }

        let configuration = try fixture.configStore.loadConfiguration()
        let legacyPreset = PromptPreset(
            id: "user.legacy",
            title: "Legacy Prompt",
            body: "Loaded from legacy workspace JSON",
            source: .user
        )
        let legacyWorkspace = PromptWorkspaceSettings(
            activeSelection: .preset(legacyPreset.id),
            userPresets: [legacyPreset]
        )
        let legacyWorkspaceData = try JSONEncoder().encode(legacyWorkspace)
        try legacyWorkspaceData.write(
            to: fixture.rootURL.appendingPathComponent("prompt-workspace.json", isDirectory: false),
            options: .atomic
        )

        let loadedWorkspace = try fixture.configStore.loadPromptWorkspace(configuration: configuration)
        #expect(loadedWorkspace == legacyWorkspace)

        try fixture.configStore.savePromptWorkspace(loadedWorkspace, configuration: configuration)

        let normalizedWorkspaceJSON = try String(
            contentsOf: fixture.rootURL.appendingPathComponent("prompt-workspace.json", isDirectory: false),
            encoding: .utf8
        )
        let normalizedPresetJSON = try String(
            contentsOf: fixture.rootURL.appendingPathComponent("prompts/user.legacy.json", isDirectory: false),
            encoding: .utf8
        )

        #expect(!normalizedWorkspaceJSON.contains("\"userPresets\""))
        #expect(normalizedPresetJSON.contains("Loaded from legacy workspace JSON"))
    }

    @Test
    func modelBootstrapNormalizesLegacyEmbeddedWorkspaceIntoPromptFiles() throws {
        let fixture = try PromptFilePersistenceFixture()
        defer { fixture.cleanup() }

        let legacyPreset = PromptPreset(
            id: "user.bootstrap",
            title: "Bootstrap Prompt",
            body: "Normalize during model startup",
            source: .user
        )
        let legacyWorkspace = PromptWorkspaceSettings(
            activeSelection: .preset(legacyPreset.id),
            userPresets: [legacyPreset]
        )
        let legacyWorkspaceData = try JSONEncoder().encode(legacyWorkspace)
        try legacyWorkspaceData.write(
            to: fixture.rootURL.appendingPathComponent("prompt-workspace.json", isDirectory: false),
            options: .atomic
        )

        let model = fixture.makeModel()
        #expect(model.promptWorkspace == legacyWorkspace)

        let normalizedWorkspaceJSON = try String(
            contentsOf: fixture.rootURL.appendingPathComponent("prompt-workspace.json", isDirectory: false),
            encoding: .utf8
        )
        let normalizedPresetJSON = try String(
            contentsOf: fixture.rootURL.appendingPathComponent("prompts/user.bootstrap.json", isDirectory: false),
            encoding: .utf8
        )

        #expect(!normalizedWorkspaceJSON.contains("\"userPresets\""))
        #expect(normalizedPresetJSON.contains("Normalize during model startup"))
    }
}

private struct PromptFilePersistenceFixture {
    let defaults: UserDefaults
    let suiteName: String
    let rootURL: URL
    let configStore: VoicePiConfigStore

    init() throws {
        suiteName = "VoicePiTests.PromptFiles.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoicePiTests.PromptFiles.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        configStore = VoicePiConfigStore(paths: VoicePiConfigPaths(rootDirectoryURL: rootURL))
    }

    @MainActor
    func makeModel() -> AppModel {
        AppModel(defaults: defaults, configStore: configStore)
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: rootURL)
    }
}
