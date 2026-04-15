import CoreGraphics
import Foundation

struct RealtimeOverlayUpdateGate: Equatable {
    enum Update: Equatable {
        case none
        case levelOnly(level: CGFloat)
        case transcriptAndLevel(transcript: String, level: CGFloat)
    }

    let minimumMeterUpdateInterval: TimeInterval

    private(set) var lastPublishedTranscript: String = ""
    private(set) var lastPublishedLevel: CGFloat = 0
    private(set) var lastPublishedAt: TimeInterval?

    init(minimumMeterUpdateInterval: TimeInterval = 1.0 / 30.0) {
        self.minimumMeterUpdateInterval = minimumMeterUpdateInterval
    }

    mutating func consume(
        transcript: String,
        level: CGFloat,
        now: TimeInterval
    ) -> Update {
        if transcript != lastPublishedTranscript {
            lastPublishedTranscript = transcript
            lastPublishedLevel = level
            lastPublishedAt = now
            return .transcriptAndLevel(transcript: transcript, level: level)
        }

        guard shouldPublishLevel(now: now) else {
            return .none
        }

        lastPublishedLevel = level
        lastPublishedAt = now
        return .levelOnly(level: level)
    }

    mutating func reset() {
        lastPublishedTranscript = ""
        lastPublishedLevel = 0
        lastPublishedAt = nil
    }

    private func shouldPublishLevel(now: TimeInterval) -> Bool {
        guard let lastPublishedAt else {
            return true
        }

        return now - lastPublishedAt >= minimumMeterUpdateInterval
    }
}
