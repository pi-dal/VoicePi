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

        let primaryExtractorBenchmark = makeDictionarySuggestionExtractorPrimaryPathBenchmark()
        let fallbackExtractorBenchmark = makeDictionarySuggestionExtractorFallbackPathBenchmark()
        let normalizerBenchmark = makeDictionaryTextNormalizerBenchmark()

        let recentSessionSummary = try? RecordingLatencyHistoryStore().loadRecentSummary()

        let report = PerformanceBenchmarkReport.current(
            textInjectionTiming: .default,
            speechRecorderStopPolicy: .default,
            realtimeOverlayUpdateGate: .init(),
            learningLoopPolicy: .default,
            recentSessionSummary: recentSessionSummary ?? nil,
            microbenchmarks: [
                reportBenchmark,
                planBenchmark,
                primaryExtractorBenchmark,
                fallbackExtractorBenchmark,
                normalizerBenchmark
            ]
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
        let warmupIterations = min(1_000, max(100, iterations / 5))

        for _ in 0..<warmupIterations {
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

    private static func makeDictionarySuggestionExtractorPrimaryPathBenchmark() -> PerformanceBenchmarkReport.Microbenchmark {
        let extractor = DictionarySuggestionExtractor()
        let injectedText = "ship the cloud flare migration this afternoon"
        let editedText = "ship the Cloudflare migration this afternoon"
        let capturedAt = Date(timeIntervalSince1970: 1_710_000_000)

        return measure(
            id: "dictionary_suggestion_extractor_primary_path_ns_per_op",
            title: "Dictionary suggestion extractor (primary path)",
            iterations: 10_000
        ) {
            _ = extractor.extractSuggestion(
                injectedText: injectedText,
                editedText: editedText,
                sourceApplication: "Benchmark",
                capturedAt: capturedAt
            )
        }
    }

    private static func makeDictionarySuggestionExtractorFallbackPathBenchmark() -> PerformanceBenchmarkReport.Microbenchmark {
        let extractor = DictionarySuggestionExtractor()
        let injectedText = "ship the cloud flare migration with postgre metrics and fig ma handoff"
        let editedText = "ship the Cloudflare migration with PostgreSQL metrics and Figma handoff"
        let capturedAt = Date(timeIntervalSince1970: 1_710_000_000)

        return measure(
            id: "dictionary_suggestion_extractor_fallback_path_ns_per_op",
            title: "Dictionary suggestion extractor (fallback path)",
            iterations: 250
        ) {
            _ = extractor.extractSuggestion(
                injectedText: injectedText,
                editedText: editedText,
                sourceApplication: "Benchmark",
                capturedAt: capturedAt
            )
        }
    }

    private static func makeDictionaryTextNormalizerBenchmark() -> PerformanceBenchmarkReport.Microbenchmark {
        let entries = [
            DictionaryEntry(canonical: "Cloudflare", aliases: ["cloud flare", "Cloud flare"]),
            DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre", "postgres"]),
            DictionaryEntry(canonical: "Figma", aliases: ["fig ma"])
        ]
        let text = "ship the cloud flare migration with postgre metrics, then share the fig ma handoff"

        return measure(
            id: "dictionary_text_normalizer_ns_per_op",
            title: "Dictionary text normalizer",
            iterations: 5_000
        ) {
            _ = DictionaryTextNormalizer.normalize(text, entries: entries)
        }
    }
}
