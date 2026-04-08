import Foundation

protocol DictionarySuggestionExtracting {
    func extractSuggestion(
        injectedText: String,
        editedText: String,
        sourceApplication: String?,
        capturedAt: Date
    ) -> DictionarySuggestion?
}

struct DictionarySuggestionExtractor: DictionarySuggestionExtracting {
    let minimumReplacementLength: Int
    let maximumReplacementLength: Int

    init(
        minimumReplacementLength: Int = 2,
        maximumReplacementLength: Int = 48
    ) {
        self.minimumReplacementLength = minimumReplacementLength
        self.maximumReplacementLength = maximumReplacementLength
    }

    func extractSuggestion(
        injectedText: String,
        editedText: String,
        sourceApplication: String?,
        capturedAt: Date
    ) -> DictionarySuggestion? {
        let injected = injectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let edited = editedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !injected.isEmpty, !edited.isEmpty, injected != edited else {
            return nil
        }

        guard let replacement = singleReplacement(in: injected, edited: edited) else {
            return nil
        }

        let original = normalizeCandidateTerm(replacement.original)
        let corrected = normalizeCandidateTerm(replacement.corrected)
        guard !original.isEmpty, !corrected.isEmpty else {
            return nil
        }

        let originalLength = original.count
        let correctedLength = corrected.count
        guard (minimumReplacementLength...maximumReplacementLength).contains(originalLength),
              (minimumReplacementLength...maximumReplacementLength).contains(correctedLength)
        else {
            return nil
        }

        let normalizedOriginal = DictionaryNormalization.normalized(original)
        let normalizedCorrected = DictionaryNormalization.normalized(corrected)
        guard !normalizedOriginal.isEmpty, !normalizedCorrected.isEmpty else {
            return nil
        }

        guard normalizedOriginal != normalizedCorrected else {
            return nil
        }

        guard containsAlphaNumeric(original), containsAlphaNumeric(corrected) else {
            return nil
        }

        let punctuationNormalizedOriginal = normalizeWithoutPunctuation(original)
        let punctuationNormalizedCorrected = normalizeWithoutPunctuation(corrected)
        guard !punctuationNormalizedOriginal.isEmpty, !punctuationNormalizedCorrected.isEmpty else {
            return nil
        }

        guard punctuationNormalizedOriginal.caseInsensitiveCompare(punctuationNormalizedCorrected) != .orderedSame else {
            return nil
        }

        guard !looksLikeLargeRewrite(original: original, corrected: corrected) else {
            return nil
        }

        return DictionarySuggestion(
            originalFragment: original,
            correctedFragment: corrected,
            proposedCanonical: corrected,
            proposedAliases: [original],
            sourceApplication: sourceApplication,
            capturedAt: capturedAt
        )
    }

    private func singleReplacement(
        in originalText: String,
        edited editedText: String
    ) -> (original: String, corrected: String)? {
        let originalScalars = Array(originalText)
        let editedScalars = Array(editedText)
        let minimumLength = min(originalScalars.count, editedScalars.count)

        var prefixLength = 0
        while prefixLength < minimumLength && originalScalars[prefixLength] == editedScalars[prefixLength] {
            prefixLength += 1
        }

        var suffixLength = 0
        while suffixLength < (originalScalars.count - prefixLength),
              suffixLength < (editedScalars.count - prefixLength),
              originalScalars[originalScalars.count - 1 - suffixLength] == editedScalars[editedScalars.count - 1 - suffixLength]
        {
            suffixLength += 1
        }

        var originalStart = prefixLength
        var editedStart = prefixLength
        var originalEnd = originalScalars.count - suffixLength
        var editedEnd = editedScalars.count - suffixLength

        while originalStart > 0,
              editedStart > 0,
              originalScalars[originalStart - 1].isAlphaNumeric,
              editedScalars[editedStart - 1].isAlphaNumeric
        {
            originalStart -= 1
            editedStart -= 1
        }

        while originalEnd < originalScalars.count,
              editedEnd < editedScalars.count,
              originalScalars[originalEnd].isAlphaNumeric,
              editedScalars[editedEnd].isAlphaNumeric
        {
            originalEnd += 1
            editedEnd += 1
        }

        let originalRange = originalStart..<originalEnd
        let editedRange = editedStart..<editedEnd
        guard !originalRange.isEmpty, !editedRange.isEmpty else {
            return nil
        }

        let originalFragment = String(originalScalars[originalRange])
        let correctedFragment = String(editedScalars[editedRange])
        return (original: originalFragment, corrected: correctedFragment)
    }

    private func looksLikeLargeRewrite(original: String, corrected: String) -> Bool {
        let originalTokens = splitIntoTokens(original)
        let correctedTokens = splitIntoTokens(corrected)

        if originalTokens.count > 4 || correctedTokens.count > 4 {
            return true
        }

        if originalTokens.count > 1, correctedTokens.count > 1 {
            let originalSet = Set(originalTokens.map(DictionaryNormalization.normalized))
            let correctedSet = Set(correctedTokens.map(DictionaryNormalization.normalized))
            if !originalSet.intersection(correctedSet).isEmpty {
                return true
            }
        }

        return false
    }

    private func splitIntoTokens(_ value: String) -> [String] {
        value
            .split { $0.isWhitespace }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func normalizeCandidateTerm(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let scalars = trimmed.unicodeScalars
        let start = scalars.firstIndex(where: { CharacterSet.alphanumerics.contains($0) }) ?? scalars.startIndex
        let end = scalars.lastIndex(where: { CharacterSet.alphanumerics.contains($0) }) ?? scalars.index(before: scalars.endIndex)
        let sliced = String(scalars[start...end])

        return sliced
            .split { $0.isWhitespace }
            .map(String.init)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeWithoutPunctuation(_ value: String) -> String {
        let scalarView = value.unicodeScalars.filter { scalar in
            if CharacterSet.punctuationCharacters.contains(scalar) {
                return false
            }
            if CharacterSet.symbols.contains(scalar) {
                return false
            }
            return true
        }

        return String(String.UnicodeScalarView(scalarView))
            .split { $0.isWhitespace }
            .map(String.init)
            .joined(separator: " ")
    }

    private func containsAlphaNumeric(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }
}

private extension Character {
    var isAlphaNumeric: Bool {
        unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }
}
