import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import Foundation

@MainActor
extension AppModel {
    func refreshDictionaryState() {
        guard let dictionaryStore else { return }

        do {
            let dictionaryDocument = try dictionaryStore.loadDictionary()
            let suggestionsDocument = try dictionaryStore.loadSuggestions()
            applyDictionaryDocuments(
                dictionary: dictionaryDocument,
                suggestions: suggestionsDocument
            )
        } catch {
            handleDictionaryError(error, action: "load")
        }
    }

    func addDictionaryTerm(canonical: String, aliases: [String], tag: String? = nil) {
        let candidate = DictionaryEntry(canonical: canonical, aliases: aliases, tag: tag)
        guard !candidate.canonical.isEmpty else { return }

        withDictionaryDocument { dictionaryDocument in
            if let index = dictionaryDocument.entries.firstIndex(where: {
                DictionaryNormalization.normalized($0.canonical) == DictionaryNormalization.normalized(candidate.canonical)
            }) {
                var existing = dictionaryDocument.entries[index]
                existing.aliases = DictionaryNormalization.uniqueAliases(
                    existing.aliases + candidate.aliases,
                    excluding: existing.canonical
                )
                existing.tag = candidate.tag ?? existing.tag
                existing.updatedAt = Date()
                dictionaryDocument.entries[index] = existing
            } else {
                dictionaryDocument.entries.append(candidate)
            }
        }
    }

    func editDictionaryTerm(id: UUID, canonical: String, aliases: [String], tag: String?) {
        withDictionaryDocument { dictionaryDocument in
            guard let index = dictionaryDocument.entries.firstIndex(where: { $0.id == id }) else {
                return
            }

            let existing = dictionaryDocument.entries[index]
            let normalizedCanonical = DictionaryNormalization.trimmed(canonical)
            guard !normalizedCanonical.isEmpty else { return }

            dictionaryDocument.entries[index] = DictionaryEntry(
                id: existing.id,
                canonical: normalizedCanonical,
                aliases: aliases,
                tag: tag,
                isEnabled: existing.isEnabled,
                createdAt: existing.createdAt,
                updatedAt: Date()
            )
        }
    }

    func deleteDictionaryTerm(id: UUID) {
        withDictionaryDocument { dictionaryDocument in
            dictionaryDocument.entries.removeAll { $0.id == id }
        }
    }

    func setDictionaryTermEnabled(id: UUID, isEnabled: Bool) {
        withDictionaryDocument { dictionaryDocument in
            guard let index = dictionaryDocument.entries.firstIndex(where: { $0.id == id }) else {
                return
            }

            var entry = dictionaryDocument.entries[index]
            entry.isEnabled = isEnabled
            entry.updatedAt = Date()
            dictionaryDocument.entries[index] = entry
        }
    }

    @discardableResult
    func enqueueDictionarySuggestion(_ suggestion: DictionarySuggestion) -> Bool {
        var queued = false
        withSuggestionDocument { suggestionsDocument in
            let duplicateExists = suggestionsDocument.suggestions.contains { existing in
                existing.originalFragment == suggestion.originalFragment &&
                existing.correctedFragment == suggestion.correctedFragment &&
                existing.proposedCanonical == suggestion.proposedCanonical &&
                existing.proposedAliases == suggestion.proposedAliases &&
                existing.sourceApplication == suggestion.sourceApplication
            }
            guard !duplicateExists else { return }
            suggestionsDocument.suggestions.append(suggestion)
            queued = true
        }
        return queued
    }

    func approveDictionarySuggestion(id: UUID) {
        guard let dictionaryStore else { return }

        do {
            let result = try dictionaryStore.approveSuggestion(id: id)
            applyDictionaryDocuments(
                dictionary: result.dictionary,
                suggestions: result.suggestions
            )
        } catch {
            handleDictionaryError(error, action: "approve suggestion")
        }
    }

    func dismissDictionarySuggestion(id: UUID) {
        guard let dictionaryStore else { return }

        do {
            let suggestionsDocument = try dictionaryStore.removeSuggestion(id: id)
            applyDictionaryDocuments(
                dictionary: DictionaryDocument(entries: dictionaryEntries),
                suggestions: suggestionsDocument
            )
        } catch {
            handleDictionaryError(error, action: "dismiss suggestion")
        }
    }

    func importDictionaryTerms(fromPlainText text: String) {
        let lines = text
            .components(separatedBy: .newlines)
            .map(DictionaryNormalization.trimmed)
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }

        withDictionaryDocument { dictionaryDocument in
            for line in lines {
                guard let parsed = Self.parseImportedDictionaryLine(line) else { continue }
                let candidate = DictionaryEntry(
                    canonical: parsed.canonical,
                    aliases: parsed.aliases
                )
                guard !candidate.canonical.isEmpty else { continue }

                let normalizedCanonical = DictionaryNormalization.normalized(candidate.canonical)

                if let index = dictionaryDocument.entries.firstIndex(where: {
                    DictionaryNormalization.normalized($0.canonical) == normalizedCanonical
                }) {
                    var existing = dictionaryDocument.entries[index]
                    existing.aliases = DictionaryNormalization.uniqueAliases(
                        existing.aliases + candidate.aliases,
                        excluding: existing.canonical
                    )
                    existing.updatedAt = Date()
                    dictionaryDocument.entries[index] = existing
                    continue
                }

                let conflictsAlias = dictionaryDocument.entries.contains { entry in
                    entry.aliases.contains { DictionaryNormalization.normalized($0) == normalizedCanonical }
                }
                guard !conflictsAlias else { continue }

                dictionaryDocument.entries.append(candidate)
            }
        }
    }

    private static func parseImportedDictionaryLine(_ line: String) -> (canonical: String, aliases: [String])? {
        let trimmedLine = DictionaryNormalization.trimmed(line)
        guard !trimmedLine.isEmpty else { return nil }

        let segments = trimmedLine.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let canonical = DictionaryNormalization.trimmed(String(segments[0]))
        guard !canonical.isEmpty else { return nil }

        let aliases: [String]
        if segments.count == 2 {
            aliases = segments[1]
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { DictionaryNormalization.trimmed(String($0)) }
                .filter { !$0.isEmpty }
        } else {
            aliases = []
        }

        return (canonical, aliases)
    }

    func exportDictionaryAsPlainText() -> String {
        dictionaryEntries
            .map(\.canonical)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    func exportDictionaryAsJSON() -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let document = DictionaryDocument(entries: dictionaryEntries)
            let data = try encoder.encode(document)
            return String(decoding: data, as: UTF8.self)
        } catch {
            handleDictionaryError(error, action: "export")
            return "{}"
        }
    }

    func recordHistoryEntry(text: String, recordingDurationMilliseconds: Int = 0) {
        guard let historyStore else { return }

        do {
            try historyStore.appendEntry(
                text: text,
                recordingDurationMilliseconds: recordingDurationMilliseconds
            )
            refreshHistoryState()
        } catch {
            presentError("History update failed: \(error.localizedDescription)")
        }
    }

    func deleteHistoryEntry(id: UUID) {
        guard let historyStore else { return }

        do {
            var document = try historyStore.loadHistory()
            document.entries.removeAll { $0.id == id }
            try historyStore.saveHistory(document)
            refreshHistoryState()
        } catch {
            presentError("History delete failed: \(error.localizedDescription)")
        }
    }

    func persistConfiguration() {
        persistFileConfiguration { configuration in
            configuration.llm.baseURL = llmConfiguration.baseURL
            configuration.llm.apiKey = llmConfiguration.apiKey
            configuration.llm.model = llmConfiguration.model
            configuration.llm.refinementPrompt = llmConfiguration.refinementPrompt
            configuration.llm.enableThinking = llmConfiguration.enableThinking ?? false
        }

        do {
            try configStore.saveUserPrompt(
                llmConfiguration.refinementPrompt,
                configuration: activeFileConfiguration
            )
        } catch {
            presentError("Prompt save failed: \(error.localizedDescription)")
        }
    }

    func persistPromptWorkspace() {
        do {
            try configStore.savePromptWorkspace(
                promptWorkspace,
                configuration: activeFileConfiguration
            )
            try configStore.saveUserPrompt(
                resolvedRefinementPrompt(for: .voicePi) ?? "",
                configuration: activeFileConfiguration
            )
        } catch {
            presentError("Prompt workspace save failed: \(error.localizedDescription)")
        }
    }

    func persistExternalProcessorEntries() {
        persistExternalProcessorState()
    }

    func persistSelectedExternalProcessorEntryID() {
        persistExternalProcessorState()
    }

    func persistActivationShortcut() {
        persistFileConfiguration { configuration in
            configuration.hotkeys.activation = .init(
                keyCodes: activationShortcut.keyCodes,
                modifierFlags: activationShortcut.modifierFlagsRawValue
            )
        }
    }

    func persistModeCycleShortcut() {
        persistFileConfiguration { configuration in
            configuration.hotkeys.modeCycle = .init(
                keyCodes: modeCycleShortcut.keyCodes,
                modifierFlags: modeCycleShortcut.modifierFlagsRawValue
            )
        }
    }

    func persistCancelShortcut() {
        persistFileConfiguration { configuration in
            configuration.hotkeys.cancel = .init(
                keyCodes: cancelShortcut.keyCodes,
                modifierFlags: cancelShortcut.modifierFlagsRawValue
            )
        }
    }

    func persistProcessorShortcut() {
        persistFileConfiguration { configuration in
            configuration.hotkeys.processor = .init(
                keyCodes: processorShortcut.keyCodes,
                modifierFlags: processorShortcut.modifierFlagsRawValue
            )
        }
    }

    func persistPromptCycleShortcut() {
        persistFileConfiguration { configuration in
            configuration.hotkeys.promptCycle = .init(
                keyCodes: promptCycleShortcut.keyCodes,
                modifierFlags: promptCycleShortcut.modifierFlagsRawValue
            )
        }
    }

    func persistRemoteASRConfiguration() {
        persistFileConfiguration { configuration in
            configuration.asr.remote = .init(
                baseURL: remoteASRConfiguration.baseURL,
                apiKey: remoteASRConfiguration.apiKey,
                model: remoteASRConfiguration.model,
                prompt: remoteASRConfiguration.prompt,
                volcengineAppID: remoteASRConfiguration.volcengineAppID
            )
        }
    }

    private func persistExternalProcessorState() {
        do {
            try configStore.saveExternalProcessors(
                .init(
                    entries: externalProcessorEntries,
                    selectedEntryID: selectedExternalProcessorEntryID?.uuidString
                ),
                configuration: activeFileConfiguration
            )
        } catch {
            presentError("Processor configuration save failed: \(error.localizedDescription)")
        }
    }

    private func withDictionaryDocument(
        _ update: (inout DictionaryDocument) -> Void
    ) {
        guard let dictionaryStore else { return }

        do {
            var dictionaryDocument = try dictionaryStore.loadDictionary()
            update(&dictionaryDocument)
            try dictionaryStore.saveDictionary(dictionaryDocument)
            applyDictionaryDocuments(
                dictionary: dictionaryDocument,
                suggestions: DictionarySuggestionDocument(suggestions: dictionarySuggestions)
            )
        } catch {
            handleDictionaryError(error, action: "update")
        }
    }

    private func withSuggestionDocument(
        _ update: (inout DictionarySuggestionDocument) -> Void
    ) {
        guard let dictionaryStore else { return }

        do {
            var suggestionsDocument = try dictionaryStore.loadSuggestions()
            update(&suggestionsDocument)
            try dictionaryStore.saveSuggestions(suggestionsDocument)
            applyDictionaryDocuments(
                dictionary: DictionaryDocument(entries: dictionaryEntries),
                suggestions: suggestionsDocument
            )
        } catch {
            handleDictionaryError(error, action: "update suggestions")
        }
    }

    private func applyDictionaryDocuments(
        dictionary: DictionaryDocument,
        suggestions: DictionarySuggestionDocument
    ) {
        dictionaryEntries = dictionary.entries.sorted {
            $0.canonical.localizedCaseInsensitiveCompare($1.canonical) == .orderedAscending
        }
        dictionarySuggestions = suggestions.suggestions.sorted { lhs, rhs in
            lhs.capturedAt > rhs.capturedAt
        }
    }

    func refreshHistoryState() {
        guard let historyStore else { return }

        do {
            let document = try historyStore.loadHistory()
            historyEntries = document.entries.sorted { lhs, rhs in
                lhs.createdAt > rhs.createdAt
            }
        } catch {
            presentError("History load failed: \(error.localizedDescription)")
        }
    }

    private func handleDictionaryError(_ error: Error, action: String) {
        presentError("Dictionary \(action) failed: \(error.localizedDescription)")
    }
}
