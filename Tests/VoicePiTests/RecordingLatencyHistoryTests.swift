import Foundation
import Testing
@testable import VoicePi

struct RecordingLatencyHistoryTests {
    @Test
    func recentSummaryUsesSuccessfulSamplesAndDerivedDurations() {
        let samples = [
            RecordingLatencySample(
                createdAt: Date(timeIntervalSince1970: 300),
                outcome: .failed("timeout"),
                totalMilliseconds: 1200,
                firstPartialMilliseconds: 140,
                stopRequestedMilliseconds: 400,
                transcriptResolvedMilliseconds: nil
            ),
            RecordingLatencySample(
                createdAt: Date(timeIntervalSince1970: 200),
                outcome: .success,
                totalMilliseconds: 700,
                firstPartialMilliseconds: 110,
                stopRequestedMilliseconds: 250,
                transcriptResolvedMilliseconds: 530
            ),
            RecordingLatencySample(
                createdAt: Date(timeIntervalSince1970: 100),
                outcome: .success,
                totalMilliseconds: 920,
                firstPartialMilliseconds: 120,
                stopRequestedMilliseconds: 300,
                transcriptResolvedMilliseconds: 640
            )
        ]

        let summary = RecordingLatencyRecentSummary.make(from: samples)

        #expect(
            summary == RecordingLatencyRecentSummary(
                successfulSessionCount: 2,
                firstPartialP50Milliseconds: 115,
                stopToTranscriptP50Milliseconds: 310,
                stopToDeliveryP50Milliseconds: 535
            )
        )
    }

    @Test
    func storeAppendsNewestSamplesAndCapsHistory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let historyURL = directoryURL.appendingPathComponent("LatencyHistory.json", isDirectory: false)
        let store = RecordingLatencyHistoryStore(
            historyFileURL: historyURL,
            maximumSampleCount: 2
        )

        try store.append(
            RecordingLatencySample(
                createdAt: Date(timeIntervalSince1970: 100),
                outcome: .success,
                totalMilliseconds: 800,
                firstPartialMilliseconds: 120,
                stopRequestedMilliseconds: 260,
                transcriptResolvedMilliseconds: 520
            )
        )
        try store.append(
            RecordingLatencySample(
                createdAt: Date(timeIntervalSince1970: 200),
                outcome: .success,
                totalMilliseconds: 780,
                firstPartialMilliseconds: 118,
                stopRequestedMilliseconds: 250,
                transcriptResolvedMilliseconds: 500
            )
        )
        try store.append(
            RecordingLatencySample(
                createdAt: Date(timeIntervalSince1970: 300),
                outcome: .cancelled,
                totalMilliseconds: 400,
                firstPartialMilliseconds: nil,
                stopRequestedMilliseconds: 180,
                transcriptResolvedMilliseconds: nil
            )
        )

        let document = try store.load()

        #expect(document.samples.count == 2)
        #expect(document.samples.map(\.createdAt) == [
            Date(timeIntervalSince1970: 300),
            Date(timeIntervalSince1970: 200)
        ])
    }
}
