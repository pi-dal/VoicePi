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

    @Test
    func loadBacksUpCorruptHistoryBeforeResetting() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let historyURL = directoryURL.appendingPathComponent("LatencyHistory.json", isDirectory: false)
        try Data("not-json".utf8).write(to: historyURL)

        let store = RecordingLatencyHistoryStore(
            historyFileURL: historyURL,
            maximumSampleCount: 2
        )

        let document = try store.load()

        #expect(document.samples.isEmpty)
        #expect(FileManager.default.fileExists(atPath: historyURL.path))

        let siblingFiles = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        let backupFiles = siblingFiles.filter { $0.lastPathComponent.hasPrefix("LatencyHistory.json.corrupt") }
        #expect(backupFiles.count == 1)
        let backupContents = try Data(contentsOf: try #require(backupFiles.first))
        #expect(String(decoding: backupContents, as: UTF8.self) == "not-json")
    }

    @Test
    func historyReporterSchedulesAppendWithoutBlockingCaller() async {
        let store = BlockingHistoryStore(delayNanoseconds: 200_000_000)
        let reporter = RecordingLatencyHistoryReporter(store: store)
        let report = RecordingLatencyTrace(originTimestamp: 0).report(outcome: .success, finishedAt: 0)

        let start = ContinuousClock.now
        reporter.report(report)
        let elapsed = start.duration(to: ContinuousClock.now)

        #expect(elapsed < .milliseconds(50))
        await store.waitForAppend()
        #expect(store.appendCallCount == 1)
    }
}

private final class BlockingHistoryStore: RecordingLatencyHistoryAppending, @unchecked Sendable {
    let delayNanoseconds: UInt64
    private let lock = NSLock()
    private var _appendCallCount = 0

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    var appendCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _appendCallCount
    }

    func append(_ sample: RecordingLatencySample) throws {
        lock.lock()
        _appendCallCount += 1
        lock.unlock()
        Thread.sleep(forTimeInterval: Double(delayNanoseconds) / 1_000_000_000)
    }

    func waitForAppend() async {
        for _ in 0..<100 {
            if appendCallCount > 0 {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
