import Testing
@testable import VoicePi

struct RecordingLatencyTraceTests {
    @Test
    func unifiedLogReporterUsesPrivatePrivacyForSummary() {
        let sink = RecordingLatencyLogSinkStub()
        let reporter = UnifiedLogRecordingLatencyReporter(logWriter: sink)
        let report = RecordingLatencyTrace(originTimestamp: 0).report(
            outcome: .failed("contains user text"),
            finishedAt: 1
        )

        reporter.report(report)

        #expect(sink.entries == [
            .init(summary: report.summary, privacy: .private)
        ])
    }

    @Test
    func firstPartialUsesEarliestObservedTimestamp() {
        var trace = RecordingLatencyTrace(originTimestamp: 10)

        trace.mark(.recordingStarted, at: 10.045)
        trace.mark(.firstPartialReceived, at: 10.210)
        trace.mark(.firstPartialReceived, at: 10.390)

        let report = trace.report(outcome: .cancelled, finishedAt: 10.450)

        #expect(report.measurements == [
            .init(milestone: .recordingStarted, milliseconds: 45),
            .init(milestone: .firstPartialReceived, milliseconds: 210)
        ])
        #expect(report.totalMilliseconds == 450)
    }

    @Test
    func summaryOnlyIncludesReachedMilestonesInStableOrder() {
        var trace = RecordingLatencyTrace(originTimestamp: 100)

        trace.mark(.recordingStarted, at: 100.030)
        trace.mark(.stopRequested, at: 101.000)
        trace.mark(.transcriptResolved, at: 101.240)

        let report = trace.report(outcome: .success)

        #expect(
            report.summary ==
                "recording_latency outcome=success total_ms=1240 recording_started_ms=30 stop_requested_ms=1000 transcript_resolved_ms=1240"
        )
    }

    @Test
    func failedSummaryIncludesReason() {
        var trace = RecordingLatencyTrace(originTimestamp: 50)

        trace.mark(.recordingStarted, at: 50.055)
        trace.mark(.stopRequested, at: 50.880)
        trace.mark(.transcriptResolved, at: 50.940)

        let report = trace.report(
            outcome: .failed("Injection timeout"),
            finishedAt: 51.110
        )

        #expect(
            report.summary ==
                "recording_latency outcome=failed total_ms=1110 recording_started_ms=55 stop_requested_ms=880 transcript_resolved_ms=940 reason=\"Injection timeout\""
        )
    }
}

private final class RecordingLatencyLogSinkStub: RecordingLatencyLogWriting, @unchecked Sendable {
    private(set) var entries: [Entry] = []

    struct Entry: Equatable {
        let summary: String
        let privacy: RecordingLatencyLogPrivacy
    }

    func log(summary: String, privacy: RecordingLatencyLogPrivacy) {
        entries.append(.init(summary: summary, privacy: privacy))
    }
}
