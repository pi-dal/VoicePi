import Foundation

enum DictionaryStoreError: LocalizedError, Equatable {
    case applicationSupportDirectoryUnavailable
    case suggestionNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "VoicePi could not locate the Application Support directory for dictionary storage."
        case .suggestionNotFound(let id):
            return "Dictionary suggestion \(id.uuidString) could not be found."
        }
    }
}

enum DictionaryStorePaths {
    static let dictionaryFileName = "Dictionary.json"
    static let suggestionsFileName = "DictionarySuggestions.json"

    static func appSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw DictionaryStoreError.applicationSupportDirectoryUnavailable
        }

        return root.appendingPathComponent("VoicePi", isDirectory: true)
    }

    static func dictionaryFileURL(fileManager: FileManager = .default) throws -> URL {
        try appSupportDirectory(fileManager: fileManager)
            .appendingPathComponent(dictionaryFileName, isDirectory: false)
    }

    static func suggestionsFileURL(fileManager: FileManager = .default) throws -> URL {
        try appSupportDirectory(fileManager: fileManager)
            .appendingPathComponent(suggestionsFileName, isDirectory: false)
    }
}

struct DictionaryApprovalResult: Equatable {
    let approvedSuggestion: DictionarySuggestion
    let dictionary: DictionaryDocument
    let suggestions: DictionarySuggestionDocument
}

protocol DictionaryStoring {
    func loadDictionary() throws -> DictionaryDocument
    func saveDictionary(_ document: DictionaryDocument) throws
    func loadSuggestions() throws -> DictionarySuggestionDocument
    func saveSuggestions(_ document: DictionarySuggestionDocument) throws
    func removeSuggestion(id: UUID) throws -> DictionarySuggestionDocument
    func approveSuggestion(id: UUID) throws -> DictionaryApprovalResult
}

final class DictionaryStore: DictionaryStoring {
    private let dictionaryFileURL: URL
    private let suggestionsFileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        dictionaryFileURL: URL,
        suggestionsFileURL: URL,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.dictionaryFileURL = dictionaryFileURL
        self.suggestionsFileURL = suggestionsFileURL
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    convenience init(fileManager: FileManager = .default) throws {
        try self.init(
            dictionaryFileURL: DictionaryStorePaths.dictionaryFileURL(fileManager: fileManager),
            suggestionsFileURL: DictionaryStorePaths.suggestionsFileURL(fileManager: fileManager),
            fileManager: fileManager
        )
    }

    convenience init(
        configPaths: VoicePiConfigPaths,
        fileManager: FileManager = .default
    ) {
        self.init(
            dictionaryFileURL: configPaths.dictionaryURL,
            suggestionsFileURL: configPaths.dictionarySuggestionsURL,
            fileManager: fileManager
        )
    }

    var configuredDictionaryFileURL: URL { dictionaryFileURL }
    var configuredSuggestionsFileURL: URL { suggestionsFileURL }

    func loadDictionary() throws -> DictionaryDocument {
        try loadDocument(
            at: dictionaryFileURL,
            fallback: DictionaryDocument(),
            saveFallback: saveDictionary
        )
    }

    func saveDictionary(_ document: DictionaryDocument) throws {
        try saveDocument(document, to: dictionaryFileURL)
    }

    func loadSuggestions() throws -> DictionarySuggestionDocument {
        try loadDocument(
            at: suggestionsFileURL,
            fallback: DictionarySuggestionDocument(),
            saveFallback: saveSuggestions
        )
    }

    func saveSuggestions(_ document: DictionarySuggestionDocument) throws {
        try saveDocument(document, to: suggestionsFileURL)
    }

    func removeSuggestion(id: UUID) throws -> DictionarySuggestionDocument {
        var suggestionsDocument = try loadSuggestions()
        suggestionsDocument.suggestions.removeAll { $0.id == id }
        try saveSuggestions(suggestionsDocument)
        return suggestionsDocument
    }

    func approveSuggestion(id: UUID) throws -> DictionaryApprovalResult {
        var suggestionsDocument = try loadSuggestions()
        guard let index = suggestionsDocument.suggestions.firstIndex(where: { $0.id == id }) else {
            throw DictionaryStoreError.suggestionNotFound(id)
        }

        let suggestion = suggestionsDocument.suggestions.remove(at: index)
        try saveSuggestions(suggestionsDocument)

        var dictionaryDocument = try loadDictionary()
        mergeApprovedSuggestion(suggestion, into: &dictionaryDocument)
        try saveDictionary(dictionaryDocument)

        return DictionaryApprovalResult(
            approvedSuggestion: suggestion,
            dictionary: dictionaryDocument,
            suggestions: suggestionsDocument
        )
    }

    private func mergeApprovedSuggestion(
        _ suggestion: DictionarySuggestion,
        into dictionaryDocument: inout DictionaryDocument
    ) {
        let proposedCanonical = DictionaryNormalization.trimmed(suggestion.proposedCanonical)
        let canonical = proposedCanonical.isEmpty
            ? DictionaryNormalization.trimmed(suggestion.correctedFragment)
            : proposedCanonical
        guard !canonical.isEmpty else { return }

        let normalizedSuggestedTerms: Set<String> = {
            let terms = [canonical] + suggestion.proposedAliases + [suggestion.originalFragment]
            return Set(terms.map(DictionaryNormalization.normalized).filter { !$0.isEmpty })
        }()

        let now = Date()
        if let existingIndex = dictionaryDocument.entries.firstIndex(where: { entry in
            let existingTerms = [entry.canonical] + entry.aliases
            let normalizedExisting = Set(
                existingTerms
                    .map(DictionaryNormalization.normalized)
                    .filter { !$0.isEmpty }
            )
            return !normalizedExisting.isDisjoint(with: normalizedSuggestedTerms)
        }) {
            var existing = dictionaryDocument.entries[existingIndex]
            let mergedAliases = existing.aliases + suggestion.proposedAliases + [suggestion.originalFragment]
            existing.aliases = DictionaryNormalization.uniqueAliases(
                mergedAliases,
                excluding: existing.canonical
            )
            existing.updatedAt = now
            dictionaryDocument.entries[existingIndex] = existing
            return
        }

        let newEntry = DictionaryEntry(
            canonical: canonical,
            aliases: suggestion.proposedAliases + [suggestion.originalFragment],
            isEnabled: true,
            createdAt: now,
            updatedAt: now
        )
        dictionaryDocument.entries.append(newEntry)
    }

    private func loadDocument<T: Codable>(
        at url: URL,
        fallback: T,
        saveFallback: (T) throws -> Void
    ) throws -> T {
        if !fileManager.fileExists(atPath: url.path) {
            try saveFallback(fallback)
            return fallback
        }

        let data = try Data(contentsOf: url)
        if data.isEmpty {
            try saveFallback(fallback)
            return fallback
        }
        return try decoder.decode(T.self, from: data)
    }

    private func saveDocument<T: Codable>(_ document: T, to url: URL) throws {
        if let directory = url.deletingLastPathComponent().standardizedFileURL as URL? {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
    }
}
