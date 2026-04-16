import Foundation

enum DictionaryTextNormalizer {
    static func normalize(
        _ text: String,
        entries: [DictionaryEntry]
    ) -> String {
        var normalizedText = text
        let replacements = entries
            .filter(\.isEnabled)
            .flatMap { entry -> [(alias: String, canonical: String)] in
                let canonical = entry.canonical.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !canonical.isEmpty else { return [] }
                let aliases = DictionaryNormalization.uniqueAliases(entry.aliases, excluding: canonical)
                return aliases.map { ($0, canonical) }
            }
            .sorted { lhs, rhs in
                lhs.alias.count > rhs.alias.count
            }

        for replacement in replacements {
            normalizedText = replaceWholeTermMatches(
                in: normalizedText,
                alias: replacement.alias,
                canonical: replacement.canonical
            )
        }

        return normalizedText
    }

    private static func replaceWholeTermMatches(
        in text: String,
        alias: String,
        canonical: String
    ) -> String {
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAlias.isEmpty else { return text }

        guard let regex = try? NSRegularExpression(
            pattern: NSRegularExpression.escapedPattern(for: trimmedAlias),
            options: [.caseInsensitive]
        ) else {
            return text
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        var rewritten = text
        for match in matches.reversed() {
            guard let range = Range(match.range, in: rewritten) else { continue }
            guard isWholeTermMatch(in: rewritten, range: range) else { continue }
            rewritten.replaceSubrange(range, with: canonical)
        }

        return rewritten
    }

    private static func isWholeTermMatch(
        in text: String,
        range: Range<String.Index>
    ) -> Bool {
        if range.lowerBound > text.startIndex {
            let previous = text[text.index(before: range.lowerBound)]
            if previous.isDictionaryWordCharacter {
                return false
            }
        }

        if range.upperBound < text.endIndex {
            let next = text[range.upperBound]
            if next.isDictionaryWordCharacter {
                return false
            }
        }

        return true
    }
}

private extension Character {
    var isDictionaryWordCharacter: Bool {
        unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }
}
