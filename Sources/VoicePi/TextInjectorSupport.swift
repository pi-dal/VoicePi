import Foundation

enum TextInjectorSupport {
    static func isLikelyCJKInputSource(
        id: String?,
        languages: [String],
        category: String?
    ) -> Bool {
        let lowercasedLanguages = languages.map { $0.lowercased() }
        if lowercasedLanguages.contains(where: { $0.hasPrefix("zh") || $0.hasPrefix("ja") || $0.hasPrefix("ko") }) {
            return true
        }

        let lowercasedID = (id ?? "").lowercased()
        if [
            "pinyin",
            "shuangpin",
            "zhuyin",
            "cangjie",
            "wubi",
            "stroke",
            "japanese",
            "kana",
            "romaji",
            "korean",
            "hangul"
        ].contains(where: { lowercasedID.contains($0) }) {
            return true
        }

        let lowercasedCategory = (category ?? "").lowercased()
        if lowercasedCategory.contains("inputmode") {
            return true
        }

        return false
    }
}

enum PasteboardRestoreDecision {
    static func shouldRestore(
        expectedInjectedChangeCount: Int,
        currentChangeCount: Int
    ) -> Bool {
        currentChangeCount == expectedInjectedChangeCount
    }
}
