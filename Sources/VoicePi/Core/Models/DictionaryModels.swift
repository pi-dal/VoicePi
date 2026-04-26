import Foundation

enum DictionarySchemaVersion {
    static let current = 1
}

struct DictionaryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var canonical: String
    var aliases: [String]
    var tag: String?
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        canonical: String,
        aliases: [String] = [],
        tag: String? = nil,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.canonical = DictionaryNormalization.trimmed(canonical)
        self.aliases = DictionaryNormalization.uniqueAliases(aliases, excluding: self.canonical)
        self.tag = DictionaryNormalization.optionalTrimmed(tag)
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

struct DictionaryDocument: Codable, Equatable {
    var version: Int
    var entries: [DictionaryEntry]

    init(
        version: Int = DictionarySchemaVersion.current,
        entries: [DictionaryEntry] = []
    ) {
        self.version = version
        self.entries = entries
    }
}

struct DictionarySuggestion: Codable, Equatable, Identifiable {
    let id: UUID
    let originalFragment: String
    let correctedFragment: String
    let proposedCanonical: String
    let proposedAliases: [String]
    let sourceApplication: String?
    let capturedAt: Date

    init(
        id: UUID = UUID(),
        originalFragment: String,
        correctedFragment: String,
        proposedCanonical: String,
        proposedAliases: [String] = [],
        sourceApplication: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.originalFragment = DictionaryNormalization.trimmed(originalFragment)
        self.correctedFragment = DictionaryNormalization.trimmed(correctedFragment)

        let canonicalCandidate = DictionaryNormalization.trimmed(proposedCanonical)
        let fallbackCanonical = DictionaryNormalization.trimmed(correctedFragment)
        let canonical = canonicalCandidate.isEmpty ? fallbackCanonical : canonicalCandidate

        self.proposedCanonical = canonical
        self.proposedAliases = DictionaryNormalization.uniqueAliases(
            proposedAliases + [self.originalFragment],
            excluding: canonical
        )
        let trimmedSource = sourceApplication?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceApplication = trimmedSource?.isEmpty == true ? nil : trimmedSource
        self.capturedAt = capturedAt
    }
}

struct DictionarySuggestionDocument: Codable, Equatable {
    var version: Int
    var suggestions: [DictionarySuggestion]

    init(
        version: Int = DictionarySchemaVersion.current,
        suggestions: [DictionarySuggestion] = []
    ) {
        self.version = version
        self.suggestions = suggestions
    }
}

enum DictionaryNormalization {
    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalized(_ value: String) -> String {
        trimmed(value)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
    }

    static func optionalTrimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = trimmed(value)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    static func uniqueAliases(_ aliases: [String], excluding canonical: String) -> [String] {
        let canonicalTrimmed = trimmed(canonical)
        var seen: Set<String> = []
        var result: [String] = []

        for alias in aliases {
            let trimmedAlias = trimmed(alias)
            guard !trimmedAlias.isEmpty else { continue }
            guard trimmedAlias != canonicalTrimmed else { continue }

            let normalizedAlias = normalized(trimmedAlias)
            guard !normalizedAlias.isEmpty else { continue }
            guard seen.insert(normalizedAlias).inserted else { continue }

            result.append(trimmedAlias)
        }

        return result
    }
}
