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

        let primaryCandidate = singleReplacement(in: injected, edited: edited)
        if let primaryCandidate,
           let suggestion = makeSuggestion(
            from: primaryCandidate,
            sourceApplication: sourceApplication,
            capturedAt: capturedAt
           ) {
            return suggestion
        }

        guard let fallbackCandidate = bestReplacementCandidate(
            in: injected,
            edited: edited
        ) else {
            return nil
        }

        return makeSuggestion(
            from: fallbackCandidate,
            sourceApplication: sourceApplication,
            capturedAt: capturedAt
        )
    }

    private func makeSuggestion(
        from replacement: (original: String, corrected: String),
        sourceApplication: String?,
        capturedAt: Date
    ) -> DictionarySuggestion? {
        let original = normalizeCandidateTerm(replacement.original)
        let corrected = focusedCorrectedTerm(
            original: original,
            corrected: replacement.corrected
        )
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

        let originalComparable = comparableTermForm(original)
        let correctedComparable = comparableTermForm(corrected)
        guard !originalComparable.isEmpty, !correctedComparable.isEmpty else {
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

        let punctuationNormalizedOriginal = normalizeWithoutPunctuation(original)
        let punctuationNormalizedCorrected = normalizeWithoutPunctuation(corrected)
        guard !punctuationNormalizedOriginal.isEmpty, !punctuationNormalizedCorrected.isEmpty else {
            return nil
        }

        guard punctuationNormalizedOriginal.caseInsensitiveCompare(punctuationNormalizedCorrected) != .orderedSame else {
            return nil
        }

        guard !introducesMixedScriptNoise(original: original, corrected: corrected) else {
            return nil
        }

        guard looksLikeTermVariant(
            originalComparable: originalComparable,
            correctedComparable: correctedComparable
        ) else {
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

    private func bestReplacementCandidate(
        in originalText: String,
        edited editedText: String
    ) -> (original: String, corrected: String)? {
        let originalTokens = splitIntoTokens(originalText)
        let editedTokens = splitIntoTokens(editedText)
        let normalizedOriginalTokens = originalTokens.map(DictionaryNormalization.normalized)
        let normalizedEditedTokens = editedTokens.map(DictionaryNormalization.normalized)

        guard !originalTokens.isEmpty, !editedTokens.isEmpty else {
            return nil
        }

        let originalWindows = tokenWindows(
            in: originalTokens,
            normalizedTokens: normalizedOriginalTokens,
            constrainedTo: changedTokenRegion(
                normalizedTokens: normalizedOriginalTokens,
                comparedTo: normalizedEditedTokens
            )
        )
        let editedWindows = tokenWindows(
            in: editedTokens,
            normalizedTokens: normalizedEditedTokens,
            constrainedTo: changedTokenRegion(
                normalizedTokens: normalizedEditedTokens,
                comparedTo: normalizedOriginalTokens
            )
        )

        guard !originalWindows.isEmpty, !editedWindows.isEmpty else {
            return nil
        }

        var bestCandidate: (original: String, corrected: String)?
        var bestScore = Int.min

        for originalWindow in originalWindows {
            for correctedWindow in editedWindows {
                if originalWindow.tokenCount != correctedWindow.tokenCount,
                   originalWindow.comparable != correctedWindow.comparable {
                    continue
                }

                let sharesLeadingComparableCharacter =
                    originalWindow.leadingComparableCharacter == correctedWindow.leadingComparableCharacter
                let hasContainmentRelation =
                    correctedWindow.comparable.contains(originalWindow.comparable)
                    || originalWindow.comparable.contains(correctedWindow.comparable)
                guard sharesLeadingComparableCharacter || hasContainmentRelation else {
                    continue
                }

                guard shouldConsiderFallbackCandidate(
                    original: originalWindow,
                    corrected: correctedWindow
                ) else {
                    continue
                }

                let score = candidateScore(
                    originalComparable: originalWindow.comparable,
                    candidateComparable: correctedWindow.comparable,
                    candidateTokenCount: correctedWindow.tokenCount
                )
                if score > bestScore {
                    bestScore = score
                    bestCandidate = (originalWindow.text, correctedWindow.text)
                }
            }
        }

        return bestCandidate
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

    private func focusedCorrectedTerm(
        original: String,
        corrected rawCorrected: String
    ) -> String {
        let normalizedRawCorrected = normalizeCandidateTerm(rawCorrected)
        guard !normalizedRawCorrected.isEmpty else {
            return ""
        }

        let comparableOriginal = comparableTermForm(original)
        guard !comparableOriginal.isEmpty else {
            return normalizedRawCorrected
        }

        guard splitIntoTokens(original).count <= 2 else {
            return normalizedRawCorrected
        }

        let candidates = correctedSuffixCandidates(
            in: rawCorrected,
            matching: comparableOriginal.first
        )
        let normalizedRawCorrectedComparable = comparableTermForm(normalizedRawCorrected)

        var bestCandidate = normalizedRawCorrected
        var bestScore = candidateScore(
            originalComparable: comparableOriginal,
            candidateComparable: normalizedRawCorrectedComparable,
            candidateTokenCount: splitIntoTokens(normalizedRawCorrected).count
        )

        for candidate in candidates {
            guard looksLikeTermVariant(
                originalComparable: comparableOriginal,
                correctedComparable: candidate.comparable
            ) else { continue }

            let score = candidateScore(
                originalComparable: comparableOriginal,
                candidateComparable: candidate.comparable,
                candidateTokenCount: candidate.tokenCount
            )
            if score > bestScore || (score == bestScore && candidate.normalizedText.count < bestCandidate.count) {
                bestCandidate = candidate.normalizedText
                bestScore = score
            }
        }

        return bestCandidate
    }

    private func correctedSuffixCandidates(
        in value: String,
        matching firstComparableCharacter: Character?
    ) -> [SuffixCandidate] {
        var candidates: [SuffixCandidate] = []
        var seenComparableForms: Set<String> = []
        let characters = Array(value)

        for startIndex in characters.indices {
            guard characters[startIndex].isAlphaNumeric else { continue }
            let rawCandidate = String(characters[startIndex...])
            let normalizedCandidate = normalizeCandidateTerm(rawCandidate)
            guard !normalizedCandidate.isEmpty else { continue }

            let comparable = comparableTermForm(normalizedCandidate)
            guard !comparable.isEmpty else { continue }
            if let firstComparableCharacter,
               comparable.first != firstComparableCharacter,
               !comparable.contains(String(firstComparableCharacter)) {
                continue
            }
            guard seenComparableForms.insert(comparable).inserted else { continue }

            candidates.append(
                SuffixCandidate(
                    normalizedText: normalizedCandidate,
                    comparable: comparable,
                    tokenCount: splitIntoTokens(normalizedCandidate).count
                )
            )
        }

        return candidates
    }

    private func candidateScore(
        originalComparable: String,
        candidateComparable: String,
        candidateTokenCount: Int
    ) -> Int {
        guard !candidateComparable.isEmpty else {
            return .min
        }

        let containmentRelation =
            candidateComparable.contains(originalComparable) || originalComparable.contains(candidateComparable)
        let commonLength: Int
        if candidateComparable == originalComparable {
            commonLength = originalComparable.count
        } else if containmentRelation {
            commonLength = min(candidateComparable.count, originalComparable.count)
        } else {
            commonLength = longestCommonSubstringLength(
                between: originalComparable,
                and: candidateComparable
            )
        }
        let containmentBonus = containmentRelation ? 1_000 : 0
        let tokenPenalty = candidateTokenCount * 10
        let lengthPenalty = abs(candidateComparable.count - originalComparable.count)

        return containmentBonus + (commonLength * 100) - tokenPenalty - lengthPenalty
    }

    private func tokenWindows(
        in tokens: [String],
        normalizedTokens: [String],
        constrainedTo region: Range<Int>
    ) -> [FallbackTokenWindow] {
        guard !tokens.isEmpty else { return [] }

        let maxWindowSize = min(4, tokens.count)
        var windows: [FallbackTokenWindow] = []
        var seenComparableForms: Set<String> = []
        for windowSize in 1...maxWindowSize {
            guard tokens.count >= windowSize else { continue }
            for start in 0...(tokens.count - windowSize) {
                let range = start..<(start + windowSize)
                guard range.overlaps(region) else { continue }
                let text = tokens[range].joined(separator: " ")
                let normalizedText = normalizeCandidateTerm(text)
                let comparable = comparableTermForm(normalizedText)
                guard !normalizedText.isEmpty, !comparable.isEmpty else { continue }
                guard seenComparableForms.insert(comparable).inserted else { continue }
                windows.append(
                    FallbackTokenWindow(
                        text: text,
                        normalizedText: normalizedText,
                        normalizedForm: DictionaryNormalization.normalized(normalizedText),
                        normalizedTokens: Array(normalizedTokens[range]),
                        normalizedTokenSet: Set(normalizedTokens[range]),
                        comparable: comparable,
                        leadingComparableCharacter: comparable.first,
                        tokenCount: windowSize
                    )
                )
            }
        }
        return windows
    }

    private func shouldConsiderFallbackCandidate(
        original: FallbackTokenWindow,
        corrected: FallbackTokenWindow
    ) -> Bool {
        guard original.normalizedForm != corrected.normalizedForm else {
            return false
        }

        guard looksLikeTermVariant(
            originalComparable: original.comparable,
            correctedComparable: corrected.comparable
        ) else {
            return false
        }

        if original.tokenCount != corrected.tokenCount {
            guard original.comparable == corrected.comparable else {
                return false
            }
        }

        guard !looksLikeLargeRewrite(original: original, corrected: corrected) else {
            return false
        }

        return true
    }

    private func looksLikeLargeRewrite(
        original: FallbackTokenWindow,
        corrected: FallbackTokenWindow
    ) -> Bool {
        if original.tokenCount > 4 || corrected.tokenCount > 4 {
            return true
        }

        if original.tokenCount > 1,
           corrected.tokenCount > 1,
           !original.normalizedTokenSet.isDisjoint(with: corrected.normalizedTokenSet) {
            return true
        }

        return false
    }

    private func changedTokenRegion(
        normalizedTokens: [String],
        comparedTo otherNormalizedTokens: [String]
    ) -> Range<Int> {
        guard !normalizedTokens.isEmpty else { return 0..<0 }

        let minimumLength = min(normalizedTokens.count, otherNormalizedTokens.count)
        var prefixLength = 0
        while prefixLength < minimumLength,
              normalizedTokens[prefixLength] == otherNormalizedTokens[prefixLength] {
            prefixLength += 1
        }

        var suffixLength = 0
        while suffixLength < (normalizedTokens.count - prefixLength),
              suffixLength < (otherNormalizedTokens.count - prefixLength),
              normalizedTokens[normalizedTokens.count - 1 - suffixLength]
                == otherNormalizedTokens[otherNormalizedTokens.count - 1 - suffixLength] {
            suffixLength += 1
        }

        let lowerBound = max(0, prefixLength - 1)
        let upperBound = min(normalizedTokens.count, max(lowerBound + 1, normalizedTokens.count - suffixLength + 1))
        return lowerBound..<upperBound
    }

    private func introducesMixedScriptNoise(
        original: String,
        corrected: String
    ) -> Bool {
        let originalProfile = letterScriptProfile(for: original)
        let correctedProfile = letterScriptProfile(for: corrected)

        return !originalProfile.isMixedAlphaScript && correctedProfile.isMixedAlphaScript
    }

    private func letterScriptProfile(for value: String) -> LetterScriptProfile {
        var hasASCIIAlpha = false
        var hasNonASCIIAlpha = false

        for scalar in value.unicodeScalars {
            guard CharacterSet.letters.contains(scalar) else { continue }
            if scalar.isASCII {
                hasASCIIAlpha = true
            } else {
                hasNonASCIIAlpha = true
            }

            if hasASCIIAlpha && hasNonASCIIAlpha {
                break
            }
        }

        return LetterScriptProfile(
            hasASCIIAlpha: hasASCIIAlpha,
            hasNonASCIIAlpha: hasNonASCIIAlpha
        )
    }

    private func looksLikeTermVariant(original: String, corrected: String) -> Bool {
        looksLikeTermVariant(
            originalComparable: comparableTermForm(original),
            correctedComparable: comparableTermForm(corrected)
        )
    }

    private func looksLikeTermVariant(
        originalComparable: String,
        correctedComparable: String
    ) -> Bool {
        guard !originalComparable.isEmpty, !correctedComparable.isEmpty else {
            return false
        }

        if originalComparable == correctedComparable {
            return true
        }

        if originalComparable.contains(correctedComparable) || correctedComparable.contains(originalComparable) {
            return true
        }

        let shorterLength = min(originalComparable.count, correctedComparable.count)
        let requiredSharedLength = max(3, (shorterLength * 2) / 3)
        return longestCommonSubstringLength(between: originalComparable, and: correctedComparable) >= requiredSharedLength
    }

    private func splitIntoTokens(_ value: String) -> [String] {
        value
            .split { $0.isWhitespace }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func comparableTermForm(_ value: String) -> String {
        let normalizedValue = DictionaryNormalization.normalized(value)
        var comparable = String()
        comparable.reserveCapacity(normalizedValue.count)

        for scalar in normalizedValue.unicodeScalars where CharacterSet.alphanumerics.contains(scalar) {
            comparable.unicodeScalars.append(scalar)
        }

        return comparable
    }

    private func longestCommonSubstringLength(between lhs: String, and rhs: String) -> Int {
        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)
        guard !lhsCharacters.isEmpty, !rhsCharacters.isEmpty else {
            return 0
        }

        var previousRow = Array(repeating: 0, count: rhsCharacters.count + 1)
        var longest = 0

        for lhsCharacter in lhsCharacters {
            var currentRow = Array(repeating: 0, count: rhsCharacters.count + 1)
            for (index, rhsCharacter) in rhsCharacters.enumerated() {
                if lhsCharacter == rhsCharacter {
                    currentRow[index + 1] = previousRow[index] + 1
                    longest = max(longest, currentRow[index + 1])
                }
            }
            previousRow = currentRow
        }

        return longest
    }

    private func normalizeCandidateTerm(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let scalars = trimmed.unicodeScalars
        let start = scalars.firstIndex(where: { CharacterSet.alphanumerics.contains($0) }) ?? scalars.startIndex
        let end = scalars.lastIndex(where: { CharacterSet.alphanumerics.contains($0) }) ?? scalars.index(before: scalars.endIndex)
        var normalized = String()
        normalized.reserveCapacity(trimmed.count)
        var previousWasWhitespace = false

        for scalar in scalars[start...end] {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if !normalized.isEmpty && !previousWasWhitespace {
                    normalized.append(" ")
                    previousWasWhitespace = true
                }
                continue
            }

            normalized.unicodeScalars.append(scalar)
            previousWasWhitespace = false
        }

        if normalized.last == " " {
            normalized.removeLast()
        }

        return normalized
    }

    private func normalizeWithoutPunctuation(_ value: String) -> String {
        var normalized = String()
        normalized.reserveCapacity(value.count)
        var previousWasWhitespace = false

        for scalar in value.unicodeScalars {
            if CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar) {
                continue
            }

            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if !normalized.isEmpty && !previousWasWhitespace {
                    normalized.append(" ")
                    previousWasWhitespace = true
                }
                continue
            }

            normalized.unicodeScalars.append(scalar)
            previousWasWhitespace = false
        }

        if normalized.last == " " {
            normalized.removeLast()
        }

        return normalized
    }

    private func containsAlphaNumeric(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }
}

private struct LetterScriptProfile {
    let hasASCIIAlpha: Bool
    let hasNonASCIIAlpha: Bool

    var isMixedAlphaScript: Bool {
        hasASCIIAlpha && hasNonASCIIAlpha
    }
}

private struct FallbackTokenWindow {
    let text: String
    let normalizedText: String
    let normalizedForm: String
    let normalizedTokens: [String]
    let normalizedTokenSet: Set<String>
    let comparable: String
    let leadingComparableCharacter: Character?
    let tokenCount: Int
}

private struct SuffixCandidate {
    let normalizedText: String
    let comparable: String
    let tokenCount: Int
}

private extension Character {
    var isAlphaNumeric: Bool {
        unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }
}
