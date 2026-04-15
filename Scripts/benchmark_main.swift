import Foundation

@main
struct VoicePiBenchmarkMain {
    static func main() {
        let reportBenchmark = measure(
            id: "recording_latency_trace_report_ns_per_op",
            title: "Recording latency trace report",
            iterations: 200_000
        ) {
            var trace = RecordingLatencyTrace(originTimestamp: 100)
            trace.mark(.recordingStarted, at: 100.030)
            trace.mark(.firstPartialReceived, at: 100.180)
            trace.mark(.stopRequested, at: 101.200)
            trace.mark(.transcriptResolved, at: 101.480)
            trace.mark(.refinementCompleted, at: 101.710)
            _ = trace.report(outcome: .success, finishedAt: 101.900)
        }

        let planBenchmark = measure(
            id: "text_injection_execution_plan_make_ns_per_op",
            title: "Text injection execution plan construction",
            iterations: 400_000
        ) {
            _ = TextInjectionExecutionPlan.make(
                needsInputSourceSwitch: true,
                timing: .default
            ).blockingLatencyMilliseconds
        }

        let recentSessionSummary = try? RecordingLatencyHistoryStore().loadRecentSummary()

        let report = PerformanceBenchmarkReport.current(
            textInjectionTiming: .default,
            speechRecorderStopPolicy: .default,
            realtimeOverlayUpdateGate: .init(),
            learningLoopPolicy: .default,
            recentSessionSummary: recentSessionSummary ?? nil,
            microbenchmarks: [reportBenchmark, planBenchmark]
        )

        print(report.renderedText())
    }

    private static func measure(
        id: String,
        title: String,
        iterations: Int,
        body: () -> Void
    ) -> PerformanceBenchmarkReport.Microbenchmark {
        let clock = ContinuousClock()

        for _ in 0..<10_000 {
            body()
        }

        let duration = clock.measure {
            for _ in 0..<iterations {
                body()
            }
        }

        let totalNanoseconds =
            (Double(duration.components.seconds) * 1_000_000_000)
            + (Double(duration.components.attoseconds) / 1_000_000_000)

        return PerformanceBenchmarkReport.Microbenchmark(
            id: id,
            title: title,
            iterations: iterations,
            nanosecondsPerIteration: totalNanoseconds / Double(iterations)
        )
    }
}
