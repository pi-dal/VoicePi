import Foundation

enum HistoryStoreError: LocalizedError, Equatable {
    case applicationSupportDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "VoicePi could not locate the Application Support directory for history storage."
        }
    }
}

private enum HistoryTextUsageCounter {
    static func count(in text: String) -> (characterCount: Int, wordCount: Int) {
        var characterCount = 0
        var wordCount = 0
        var inWord = false

        for scalar in text.unicodeScalars {
            let value = scalar.value
            if isCJKCharacter(value) {
                characterCount += 1
                if inWord {
                    wordCount += 1
                    inWord = false
                }
            } else if isLatinWordCharacter(value) {
                if !inWord {
                    inWord = true
                }
            } else if inWord {
                wordCount += 1
                inWord = false
            }
        }

        if inWord {
            wordCount += 1
        }

        return (characterCount, wordCount)
    }

    private static func isCJKCharacter(_ value: UInt32) -> Bool {
        (0x4E00...0x9FFF).contains(value)
            || (0x3400...0x4DBF).contains(value)
            || (0xF900...0xFAFF).contains(value)
    }

    private static func isLatinWordCharacter(_ value: UInt32) -> Bool {
        (0x41...0x5A).contains(value)
            || (0x61...0x7A).contains(value)
            || (0x30...0x39).contains(value)
            || value == 0x27
    }
}

struct HistoryUsageStats: Equatable {
    let sessionCount: Int
    let totalRecordingDurationMilliseconds: Int
    let totalCharacterCount: Int
    let totalWordCount: Int

    static let empty = HistoryUsageStats(
        sessionCount: 0,
        totalRecordingDurationMilliseconds: 0,
        totalCharacterCount: 0,
        totalWordCount: 0
    )

    init(
        sessionCount: Int,
        totalRecordingDurationMilliseconds: Int,
        totalCharacterCount: Int,
        totalWordCount: Int
    ) {
        self.sessionCount = max(0, sessionCount)
        self.totalRecordingDurationMilliseconds = max(0, totalRecordingDurationMilliseconds)
        self.totalCharacterCount = max(0, totalCharacterCount)
        self.totalWordCount = max(0, totalWordCount)
    }

    init(entries: [HistoryEntry]) {
        var sessionCount = 0
        var totalRecordingDurationMilliseconds = 0
        var totalCharacterCount = 0
        var totalWordCount = 0

        for entry in entries {
            sessionCount += 1
            totalRecordingDurationMilliseconds += entry.recordingDurationMilliseconds
            totalCharacterCount += entry.characterCount
            totalWordCount += entry.wordCount
        }

        self.init(
            sessionCount: sessionCount,
            totalRecordingDurationMilliseconds: totalRecordingDurationMilliseconds,
            totalCharacterCount: totalCharacterCount,
            totalWordCount: totalWordCount
        )
    }
}

enum HistoryStorePaths {
    static let historyFileName = "History.json"

    static func appSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw HistoryStoreError.applicationSupportDirectoryUnavailable
        }

        return root.appendingPathComponent("VoicePi", isDirectory: true)
    }

    static func historyFileURL(fileManager: FileManager = .default) throws -> URL {
        try appSupportDirectory(fileManager: fileManager)
            .appendingPathComponent(historyFileName, isDirectory: false)
    }
}

struct HistoryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let createdAt: Date
    let characterCount: Int
    let wordCount: Int
    let recordingDurationMilliseconds: Int

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        characterCount: Int? = nil,
        wordCount: Int? = nil,
        recordingDurationMilliseconds: Int = 0
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        let counts = HistoryTextUsageCounter.count(in: text)
        self.characterCount = max(0, characterCount ?? counts.characterCount)
        self.wordCount = max(0, wordCount ?? counts.wordCount)
        self.recordingDurationMilliseconds = max(0, recordingDurationMilliseconds)
    }
}

struct HistoryDocument: Codable, Equatable {
    var entries: [HistoryEntry] = []
}

protocol HistoryStoring {
    func loadHistory() throws -> HistoryDocument
    func saveHistory(_ document: HistoryDocument) throws
    func appendEntry(text: String, recordingDurationMilliseconds: Int) throws
}

final class HistoryStore: HistoryStoring {
    static let maximumEntryCount = 200

    private let historyFileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        historyFileURL: URL,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.historyFileURL = historyFileURL
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    convenience init(fileManager: FileManager = .default) throws {
        try self.init(
            historyFileURL: HistoryStorePaths.historyFileURL(fileManager: fileManager),
            fileManager: fileManager
        )
    }

    func loadHistory() throws -> HistoryDocument {
        if !fileManager.fileExists(atPath: historyFileURL.path) {
            let document = HistoryDocument()
            try saveHistory(document)
            return document
        }

        do {
            let data = try Data(contentsOf: historyFileURL)
            return try decoder.decode(HistoryDocument.self, from: data)
        } catch {
            // Legacy history files are dropped so new schema stays single-version only.
            try? fileManager.removeItem(at: historyFileURL)
            let document = HistoryDocument()
            try saveHistory(document)
            return document
        }
    }

    func saveHistory(_ document: HistoryDocument) throws {
        let directory = historyFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(document)
        try data.write(to: historyFileURL, options: .atomic)
    }

    func appendEntry(text: String, recordingDurationMilliseconds: Int = 0) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var document = try loadHistory()
        document.entries.insert(
            HistoryEntry(
                text: trimmed,
                recordingDurationMilliseconds: recordingDurationMilliseconds
            ),
            at: 0
        )
        if document.entries.count > Self.maximumEntryCount {
            document.entries = Array(document.entries.prefix(Self.maximumEntryCount))
        }
        try saveHistory(document)
    }
}
