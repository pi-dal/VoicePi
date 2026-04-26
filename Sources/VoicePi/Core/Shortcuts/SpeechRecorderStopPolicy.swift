import Foundation

struct SpeechRecorderStopPolicy: Equatable {
    let partialTranscriptFallbackDelay: Duration
    let emptyTranscriptFallbackDelay: Duration

    static let `default` = SpeechRecorderStopPolicy(
        partialTranscriptFallbackDelay: .milliseconds(120),
        emptyTranscriptFallbackDelay: .milliseconds(450)
    )

    func fallbackDelay(forCurrentTranscript transcript: String) -> Duration {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? emptyTranscriptFallbackDelay : partialTranscriptFallbackDelay
    }
}
