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

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

struct HistoryDocument: Codable, Equatable {
    var entries: [HistoryEntry] = []
}

protocol HistoryStoring {
    func loadHistory() throws -> HistoryDocument
    func saveHistory(_ document: HistoryDocument) throws
    func appendEntry(text: String) throws
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

        let data = try Data(contentsOf: historyFileURL)
        return try decoder.decode(HistoryDocument.self, from: data)
    }

    func saveHistory(_ document: HistoryDocument) throws {
        let directory = historyFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(document)
        try data.write(to: historyFileURL, options: .atomic)
    }

    func appendEntry(text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var document = try loadHistory()
        document.entries.insert(HistoryEntry(text: trimmed), at: 0)
        if document.entries.count > Self.maximumEntryCount {
            document.entries = Array(document.entries.prefix(Self.maximumEntryCount))
        }
        try saveHistory(document)
    }
}
