import Foundation
import Testing
@testable import VoicePi

struct VoicePiConfigPathsTests {
    @Test
    func defaultRootDirectoryMatchesDotConfigVoicePi() {
        let paths = VoicePiConfigPaths()
        let root = paths.rootDirectoryURL.standardizedFileURL.path
        let expectedSuffix = "/.config/voicepi"

        #expect(root.hasSuffix(expectedSuffix))
    }

    @Test
    func customRootDirectoryOverrideIsUsed() {
        let root = URL(fileURLWithPath: "/tmp/voicepi-config-tests", isDirectory: true)
        let paths = VoicePiConfigPaths(rootDirectoryURL: root)

        #expect(paths.rootDirectoryURL.standardizedFileURL == root.standardizedFileURL)
    }

    @Test
    func configFilePathResolvesToConfigToml() {
        let root = URL(fileURLWithPath: "/tmp/voicepi-config-tests", isDirectory: true)
        let paths = VoicePiConfigPaths(rootDirectoryURL: root)

        #expect(paths.configFileURL == root.appendingPathComponent("config.toml", isDirectory: false))
    }

    @Test
    func historyDirectoryResolvesUnderRoot() {
        let root = URL(fileURLWithPath: "/tmp/voicepi-config-tests", isDirectory: true)
        let paths = VoicePiConfigPaths(rootDirectoryURL: root)

        #expect(paths.historyDirectoryURL == root.appendingPathComponent("history", isDirectory: true))
        #expect(
            paths.historyFileURL(for: Date(timeIntervalSince1970: 1_744_860_800))
                == root.appendingPathComponent("history/2025-04.jsonl", isDirectory: false)
        )
    }

    @Test
    func relativePathSettingsResolveWithinRoot() {
        let root = URL(fileURLWithPath: "/tmp/voicepi-config-tests", isDirectory: true)
        var configuration = VoicePiFileConfiguration()
        configuration.paths.userPrompt = "prompts/user-prompt.txt"
        configuration.paths.userPromptsDirectory = "prompt-library"
        configuration.paths.dictionary = "data/dictionary.json"
        configuration.paths.dictionarySuggestions = "data/dictionary-suggestions.json"
        configuration.paths.processors = "data/processors.json"
        configuration.paths.promptWorkspace = "data/workspace.json"
        configuration.history.directory = "history-files"

        let paths = VoicePiConfigPaths(rootDirectoryURL: root, configuration: configuration)

        #expect(paths.userPromptURL == root.appendingPathComponent("prompts/user-prompt.txt", isDirectory: false))
        #expect(paths.promptPresetsDirectoryURL == root.appendingPathComponent("prompt-library", isDirectory: true))
        #expect(paths.promptPresetFileURL(for: "user.release-notes") == root.appendingPathComponent("prompt-library/user.release-notes.json", isDirectory: false))
        #expect(paths.dictionaryURL == root.appendingPathComponent("data/dictionary.json", isDirectory: false))
        #expect(paths.dictionarySuggestionsURL == root.appendingPathComponent("data/dictionary-suggestions.json", isDirectory: false))
        #expect(paths.processorsURL == root.appendingPathComponent("data/processors.json", isDirectory: false))
        #expect(paths.promptWorkspaceURL == root.appendingPathComponent("data/workspace.json", isDirectory: false))
        #expect(paths.historyDirectoryURL == root.appendingPathComponent("history-files", isDirectory: true))
    }
}
