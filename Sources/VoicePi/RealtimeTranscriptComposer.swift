import Foundation

enum RealtimeTranscriptComposer {
    static func merge(cumulative: String, incoming: String) -> String {
        let base = normalized(cumulative)
        let next = normalized(incoming)

        if base.isEmpty { return next }
        if next.isEmpty { return base }
        if base == next { return base }

        if next.hasPrefix(base) || next.contains(base) {
            return next
        }
        if base.hasPrefix(next) || base.contains(next) {
            return base
        }

        let overlap = overlapLength(suffixSource: base, prefixSource: next)
        if overlap > 0 {
            return base + String(next.dropFirst(overlap))
        }

        return appendRespectingBoundary(base, next)
    }

    static func joinWithSpace(_ segments: [String]) -> String {
        segments
            .map(normalized)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func overlapLength(suffixSource: String, prefixSource: String) -> Int {
        let left = Array(suffixSource)
        let right = Array(prefixSource)
        let maxLength = min(left.count, right.count)
        guard maxLength > 0 else { return 0 }

        for candidate in stride(from: maxLength, through: 1, by: -1) {
            if left.suffix(candidate).elementsEqual(right.prefix(candidate)) {
                return candidate
            }
        }
        return 0
    }

    private static func appendRespectingBoundary(_ base: String, _ incoming: String) -> String {
        guard
            let last = base.last,
            let first = incoming.first
        else {
            return base + incoming
        }

        if last.isASCIIWordLike && first.isASCIIWordLike {
            return "\(base) \(incoming)"
        }
        return base + incoming
    }
}

private extension Character {
    var isASCIIWordLike: Bool {
        unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "_")
        }
    }
}
