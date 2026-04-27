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

    init(entry: HistoryEntry) {
        self.id = entry.id
        self.text = entry.text
        self.createdAt = entry.createdAt
        self.characterCount = entry.characterCount
        self.wordCount = entry.wordCount
        self.recordingDurationMilliseconds = entry.recordingDurationMilliseconds
    }

    var entry: HistoryEntry {
        HistoryEntry(
            id: id,
            text: text,
            createdAt: createdAt,
            characterCount: characterCount,
            wordCount: wordCount,
            recordingDurationMilliseconds: recordingDurationMilliseconds
        )
    }
}

final class HistoryStore: HistoryStoring {
    static let maximumEntryCount = 200

    private enum StorageMode {
        case jsonFile(URL)
        case monthlyJSONL(URL)
    }

    private let storageMode: StorageMode
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        historyFileURL: URL,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.storageMode = .jsonFile(historyFileURL)
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    init(
        historyDirectoryURL: URL,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.storageMode = .monthlyJSONL(historyDirectoryURL)
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

    convenience init(
        configPaths: VoicePiConfigPaths,
        fileManager: FileManager = .default
    ) {
        self.init(
            historyDirectoryURL: configPaths.historyDirectoryURL,
            fileManager: fileManager
        )
    }

    func loadHistory() throws -> HistoryDocument {
        switch storageMode {
        case .jsonFile(let historyFileURL):
            return try loadHistoryDocumentFile(from: historyFileURL)
        case .monthlyJSONL(let historyDirectoryURL):
            return try loadMonthlyHistory(from: historyDirectoryURL)
        }
    }

    func saveHistory(_ document: HistoryDocument) throws {
        switch storageMode {
        case .jsonFile(let historyFileURL):
            try saveHistoryDocumentFile(document, to: historyFileURL)
        case .monthlyJSONL(let historyDirectoryURL):
            try saveMonthlyHistory(document, to: historyDirectoryURL)
        }
    }

    func appendEntry(text: String, recordingDurationMilliseconds: Int = 0) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch storageMode {
        case .jsonFile:
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
        case .monthlyJSONL(let historyDirectoryURL):
            try appendMonthlyJSONLEntry(
                HistoryEntry(
                    text: trimmed,
                    recordingDurationMilliseconds: recordingDurationMilliseconds
                ),
                to: historyDirectoryURL
            )
        }
    }

    private func loadHistoryDocumentFile(from historyFileURL: URL) throws -> HistoryDocument {
        if !fileManager.fileExists(atPath: historyFileURL.path) {
            let document = HistoryDocument()
            try saveHistoryDocumentFile(document, to: historyFileURL)
            return document
        }

        do {
            let data = try Data(contentsOf: historyFileURL)
            return try decoder.decode(HistoryDocument.self, from: data)
        } catch {
            try? fileManager.removeItem(at: historyFileURL)
            let document = HistoryDocument()
            try saveHistoryDocumentFile(document, to: historyFileURL)
            return document
        }
    }

    private func saveHistoryDocumentFile(_ document: HistoryDocument, to historyFileURL: URL) throws {
        let directory = historyFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(document)
        try data.write(to: historyFileURL, options: .atomic)
    }

    private func loadMonthlyHistory(from historyDirectoryURL: URL) throws -> HistoryDocument {
        if !fileManager.fileExists(atPath: historyDirectoryURL.path) {
            try fileManager.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true)
            return HistoryDocument()
        }

        let files = try fileManager.contentsOfDirectory(
            at: historyDirectoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "jsonl" }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }

        var entries: [HistoryEntry] = []
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            for line in content.split(whereSeparator: \.isNewline) {
                let data = Data(line.utf8)
                let record = try decoder.decode(HistoryJSONLRecord.self, from: data)
                entries.append(record.entry)
            }
        }

        entries.sort { $0.createdAt > $1.createdAt }
        if entries.count > Self.maximumEntryCount {
            entries = Array(entries.prefix(Self.maximumEntryCount))
        }

        return HistoryDocument(entries: entries)
    }

    private func saveMonthlyHistory(_ document: HistoryDocument, to historyDirectoryURL: URL) throws {
        try fileManager.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true)

        let existingFiles = try fileManager.contentsOfDirectory(
            at: historyDirectoryURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "jsonl" }
        for file in existingFiles {
            try fileManager.removeItem(at: file)
        }

        let grouped = Dictionary(grouping: document.entries) { entry in
            VoicePiConfigPaths.historyMonthString(for: entry.createdAt)
        }

        let lineEncoder = JSONEncoder()
        lineEncoder.outputFormatting = [.sortedKeys]
        for month in grouped.keys.sorted() {
            let entries = (grouped[month] ?? []).sorted(by: { $0.createdAt > $1.createdAt })
            let lines = try entries.map { entry -> String in
                try encodeMonthlyJSONLLine(for: entry, encoder: lineEncoder)
            }
            let payload = lines.isEmpty ? "" : "\(lines.joined(separator: "\n"))\n"
            let fileURL = historyDirectoryURL.appendingPathComponent("\(month).jsonl", isDirectory: false)
            try payload.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func appendMonthlyJSONLEntry(
        _ entry: HistoryEntry,
        to historyDirectoryURL: URL
    ) throws {
        try fileManager.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true)

        let fileURL = historyDirectoryURL.appendingPathComponent(
            "\(VoicePiConfigPaths.historyMonthString(for: entry.createdAt)).jsonl",
            isDirectory: false
        )
        let lineEncoder = JSONEncoder()
        lineEncoder.outputFormatting = [.sortedKeys]
        let payload = "\(try encodeMonthlyJSONLLine(for: entry, encoder: lineEncoder))\n"

        if !fileManager.fileExists(atPath: fileURL.path) {
            try payload.write(to: fileURL, atomically: true, encoding: .utf8)
            return
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        if let data = payload.data(using: .utf8) {
            try handle.write(contentsOf: data)
        }
    }

    private func encodeMonthlyJSONLLine(
        for entry: HistoryEntry,
        encoder: JSONEncoder
    ) throws -> String {
        let data = try encoder.encode(HistoryJSONLRecord(entry: entry))
        return String(decoding: data, as: UTF8.self)
    }
}
