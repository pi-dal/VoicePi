import AppKit
import Foundation
import Testing
@testable import VoicePi

@MainActor
struct AppModelFileConfigTests {
    @Test
    func appModelLoadsInitialStateFromFileConfigStore() throws {
        let fixture = try AppModelFileConfigFixture()
        defer { fixture.cleanup() }

        var configuration = VoicePiFileConfiguration()
        configuration.app.language = .japanese
        configuration.app.interfaceTheme = .dark
        configuration.text.postProcessingMode = .translation
        configuration.text.targetLanguage = .korean
        configuration.asr.backend = .remoteOpenAICompatible
        configuration.llm.baseURL = "https://llm.example.com"
        configuration.llm.apiKey = "llm-key"
        configuration.llm.model = "gpt-test"
        configuration.llm.enableThinking = true
        configuration.hotkeys.activation = .init(keyCodes: [35], modifierFlags: NSEvent.ModifierFlags.control.rawValue)
        try fixture.configStore.saveConfiguration(configuration)

        let workspace = PromptWorkspaceSettings(
            activeSelection: .preset("user.prompt"),
            userPresets: [PromptPreset(
                id: "user.prompt",
                title: "My Prompt",
                body: "Keep concise.",
                source: .user
            )]
        )
        try fixture.configStore.savePromptWorkspace(workspace, configuration: configuration)

        let model = fixture.makeModel()

        #expect(model.selectedLanguage == .japanese)
        #expect(model.interfaceTheme == .dark)
        #expect(model.postProcessingMode == .translation)
        #expect(model.targetLanguage == .korean)
        #expect(model.asrBackend == .remoteOpenAICompatible)
        #expect(model.llmConfiguration.baseURL == "https://llm.example.com")
        #expect(model.llmConfiguration.enableThinking == true)
        #expect(model.promptWorkspace == workspace)
    }

    @Test
    func freshFileConfigBootstrapUsesStandardActivationShortcut() throws {
        let fixture = try AppModelFileConfigFixture()
        defer { fixture.cleanup() }

        let model = fixture.makeModel()
        let configuration = try fixture.configStore.loadConfiguration()

        #expect(model.activationShortcut.isRegisteredHotkeyCompatible)
        #expect(model.activationShortcut.requiresInputMonitoring == false)
        #expect(configuration.hotkeys.activation.keyCodes == model.activationShortcut.keyCodes)
        #expect(configuration.hotkeys.activation.modifierFlags == model.activationShortcut.modifierFlagsRawValue)
    }

    @Test
    func changingLanguagePersistsToConfigToml() throws {
        let fixture = try AppModelFileConfigFixture()
        defer { fixture.cleanup() }

        let model = fixture.makeModel()
        model.selectedLanguage = .korean

        let reloadedConfiguration = try fixture.configStore.loadConfiguration()
        #expect(reloadedConfiguration.app.language == .korean)
    }

    @Test
    func savingLLMConfigurationPersistsToConfigToml() throws {
        let fixture = try AppModelFileConfigFixture()
        defer { fixture.cleanup() }

        let model = fixture.makeModel()
        model.saveLLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "llm-key",
            model: "gpt-5-mini",
            refinementPrompt: "Use bullets.",
            enableThinking: .some(false)
        )

        let reloadedConfiguration = try fixture.configStore.loadConfiguration()
        #expect(reloadedConfiguration.llm.baseURL == "https://llm.example.com")
        #expect(reloadedConfiguration.llm.apiKey == "llm-key")
        #expect(reloadedConfiguration.llm.model == "gpt-5-mini")
        #expect(reloadedConfiguration.llm.refinementPrompt == "Use bullets.")
        #expect(reloadedConfiguration.llm.enableThinking == false)
    }

    @Test
    func savingRemoteASRConfigurationPersistsToConfigToml() throws {
        let fixture = try AppModelFileConfigFixture()
        defer { fixture.cleanup() }

        let model = fixture.makeModel()
        model.setASRBackend(.remoteVolcengineASR)
        model.saveRemoteASRConfiguration(
            baseURL: "https://asr.example.com",
            apiKey: "asr-key",
            model: "bigmodel",
            prompt: "Prefer punctuation.",
            volcengineAppID: "app-id"
        )

        let reloadedConfiguration = try fixture.configStore.loadConfiguration()
        #expect(reloadedConfiguration.asr.backend == .remoteVolcengineASR)
        #expect(reloadedConfiguration.asr.remote.baseURL == "https://asr.example.com")
        #expect(reloadedConfiguration.asr.remote.apiKey == "asr-key")
        #expect(reloadedConfiguration.asr.remote.model == "bigmodel")
        #expect(reloadedConfiguration.asr.remote.prompt == "Prefer punctuation.")
        #expect(reloadedConfiguration.asr.remote.volcengineAppID == "app-id")
    }

    @Test
    func updatingShortcutsPersistsToConfigToml() throws {
        let fixture = try AppModelFileConfigFixture()
        defer { fixture.cleanup() }

        let model = fixture.makeModel()
        let mode = ActivationShortcut(
            keyCodes: [49],
            modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .shift]).intersection(.deviceIndependentFlagsMask).rawValue
        )
        let cancel = ActivationShortcut(
            keyCodes: [47],
            modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
        )
        model.setModeCycleShortcut(mode)
        model.setCancelShortcut(cancel)

        let reloadedConfiguration = try fixture.configStore.loadConfiguration()
        #expect(reloadedConfiguration.hotkeys.modeCycle.keyCodes == [49])
        #expect(reloadedConfiguration.hotkeys.modeCycle.modifierFlags == mode.modifierFlagsRawValue)
        #expect(reloadedConfiguration.hotkeys.cancel.keyCodes == [47])
        #expect(reloadedConfiguration.hotkeys.cancel.modifierFlags == cancel.modifierFlagsRawValue)
    }

    @Test
    func recordingHistoryAppendsCurrentMonthJSONL() throws {
        let fixture = try AppModelFileConfigFixture()
        defer { fixture.cleanup() }

        let model = fixture.makeModel()
        model.recordHistoryEntry(text: "History JSONL line", recordingDurationMilliseconds: 3210)

        let configuration = try fixture.configStore.loadConfiguration()
        let paths = fixture.configStore.resolvedPaths(for: configuration)
        let fileURL = paths.historyFileURL(for: Date())
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        #expect(content.contains("History JSONL line"))
    }

    @Test
    func invalidConfigTomlIsNotOverwrittenDuringModelBootstrap() throws {
        let fixture = try AppModelFileConfigFixture()
        defer { fixture.cleanup() }

        let invalidConfig = """
        [app
        language = "en-US"
        """
        try invalidConfig.write(
            to: fixture.rootURL.appendingPathComponent("config.toml", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )

        let model = fixture.makeModel()

        #expect(model.selectedLanguage == .simplifiedChinese)
        let persistedConfig = try String(
            contentsOf: fixture.rootURL.appendingPathComponent("config.toml", isDirectory: false),
            encoding: .utf8
        )
        #expect(persistedConfig == invalidConfig)
    }

    @Test
    func modelBootstrapDoesNotCreateUnusedSystemPromptFile() throws {
        let fixture = try AppModelFileConfigFixture()
        defer { fixture.cleanup() }

        _ = fixture.makeModel()

        let systemPromptURL = fixture.rootURL.appendingPathComponent("system-prompt.txt", isDirectory: false)
        #expect(FileManager.default.fileExists(atPath: systemPromptURL.path) == false)
    }
}

private struct AppModelFileConfigFixture {
    let defaults: UserDefaults
    let suiteName: String
    let rootURL: URL
    let configStore: VoicePiConfigStore

    init() throws {
        suiteName = "VoicePiTests.AppModelFileConfig.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoicePiTests.AppModelFileConfig.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        configStore = VoicePiConfigStore(
            paths: VoicePiConfigPaths(rootDirectoryURL: rootURL)
        )
    }

    @MainActor
    func makeModel() -> AppModel {
        AppModel(
            defaults: defaults,
            configStore: configStore
        )
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: rootURL)
    }
}
