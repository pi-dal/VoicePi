import Foundation
import OSLog
import VoicePiCore

// MARK: - macOS Voice History Extractor

/// Extracts Chinese phrases from the macOS HistoryStore and writes them
/// into the SharedLexiconStore (stored in Application Support).
///
/// This is the macOS counterpart of the iOS `VoiceHistoryExtractor`.
/// Both platforms now share the same extraction logic via `VoicePhraseExtractor`
/// and the same `SharedLexiconStore` / `LexiconDocument` schema.
enum MacVoiceHistoryExtractor {

    /// Run extraction: read macOS history, extract phrases, write to shared lexicon.
    /// Call from a background queue — this is a synchronous operation.
    static func runExtraction(
        historyStore: HistoryStoring,
        sharedLexiconStore: SharedLexiconStore
    ) {
        let document: HistoryDocument
        do {
            document = try historyStore.loadHistory()
        } catch {
            os_log(.error, "[MacVoiceHistoryExtractor] loadHistory failed: %{public}@",
                   error.localizedDescription)
            return
        }

        let entries = document.entries
        guard !entries.isEmpty else {
            os_log(.debug, "[MacVoiceHistoryExtractor] No history entries to process")
            return
        }

        // Convert entries to the (text, date) tuple format
        let tuples = entries.map { (text: $0.text, date: $0.createdAt) }

        // Use shared extraction logic from VoicePiCore
        let lexiconEntries = VoicePhraseExtractor.buildLexiconEntries(
            fromHistoryEntries: tuples,
            minFrequency: VoicePhraseExtractor.minFrequency,
            source: .voiceHistory
        )

        guard !lexiconEntries.isEmpty else {
            os_log(.debug, "[MacVoiceHistoryExtractor] No phrases met frequency threshold")
            return
        }

        // Write to shared lexicon
        sharedLexiconStore.replaceSource(.voiceHistory, with: lexiconEntries)

        os_log(.debug, "[MacVoiceHistoryExtractor] extracted %d phrases from %d history records",
               lexiconEntries.count, entries.count)
    }

    /// Get or create the Application Support directory for the shared lexicon.
    static func sharedLexiconDirectory() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        let voicePiDir = appSupport.appendingPathComponent("VoicePi", isDirectory: true)
        try? FileManager.default.createDirectory(at: voicePiDir, withIntermediateDirectories: true)
        return voicePiDir
    }
}
