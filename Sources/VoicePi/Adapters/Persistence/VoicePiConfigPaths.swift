import Foundation

struct VoicePiConfigPaths: Equatable {
    let rootDirectoryURL: URL
    let configuration: VoicePiFileConfiguration

    init(
        rootDirectoryURL: URL = VoicePiConfigPaths.defaultRootDirectoryURL(),
        configuration: VoicePiFileConfiguration = .init()
    ) {
        self.rootDirectoryURL = rootDirectoryURL.standardizedFileURL
        self.configuration = configuration
    }

    static func defaultRootDirectoryURL(
        fileManager: FileManager = .default
    ) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("voicepi", isDirectory: true)
            .standardizedFileURL
    }

    var configFileURL: URL {
        rootDirectoryURL.appendingPathComponent("config.toml", isDirectory: false)
    }

    var migrationMarkerURL: URL {
        rootDirectoryURL.appendingPathComponent(".migration-version", isDirectory: false)
    }

    var userPromptURL: URL {
        resolvePath(configuration.paths.userPrompt, isDirectory: false)
    }

    var promptPresetsDirectoryURL: URL {
        resolvePath(configuration.paths.userPromptsDirectory, isDirectory: true)
    }

    func promptPresetFileURL(for presetID: String) -> URL {
        promptPresetsDirectoryURL.appendingPathComponent(
            Self.promptPresetFilename(for: presetID),
            isDirectory: false
        )
    }

    var dictionaryURL: URL {
        resolvePath(configuration.paths.dictionary, isDirectory: false)
    }

    var dictionarySuggestionsURL: URL {
        resolvePath(configuration.paths.dictionarySuggestions, isDirectory: false)
    }

    var processorsURL: URL {
        resolvePath(configuration.paths.processors, isDirectory: false)
    }

    var promptWorkspaceURL: URL {
        resolvePath(configuration.paths.promptWorkspace, isDirectory: false)
    }

    var historyDirectoryURL: URL {
        resolvePath(configuration.history.directory, isDirectory: true)
    }

    func historyFileURL(for date: Date) -> URL {
        historyDirectoryURL.appendingPathComponent("\(Self.historyMonthString(for: date)).jsonl", isDirectory: false)
    }

    private func resolvePath(_ rawPath: String, isDirectory: Bool) -> URL {
        let expanded = (rawPath as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded, isDirectory: isDirectory).standardizedFileURL
        }

        return rootDirectoryURL
            .appendingPathComponent(expanded, isDirectory: isDirectory)
            .standardizedFileURL
    }

    static func historyMonthString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    static func promptPresetFilename(for presetID: String) -> String {
        let trimmed = presetID.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let scalarView = trimmed.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let base = String(scalarView)
        return (base.isEmpty ? "prompt" : base) + ".json"
    }
}
