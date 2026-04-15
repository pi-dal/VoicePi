import Foundation

struct PerformanceBenchmarkReport: Equatable {
    struct BudgetMetric: Equatable {
        let id: String
        let title: String
        let legacyValue: Int
        let currentValue: Int
        let unit: String

        var improvementPercentage: Double {
            guard legacyValue > 0 else { return 0 }
            return (Double(legacyValue - currentValue) / Double(legacyValue)) * 100
        }
    }

    struct ScenarioMetric: Equatable {
        let id: String
        let title: String
        let legacyValue: Int
        let currentValue: Int
        let unit: String
        let assumptions: String

        var improvementPercentage: Double {
            guard legacyValue > 0 else { return 0 }
            return (Double(legacyValue - currentValue) / Double(legacyValue)) * 100
        }
    }

    struct Microbenchmark: Equatable {
        let id: String
        let title: String
        let iterations: Int
        let nanosecondsPerIteration: Double
    }

    let budgetMetrics: [BudgetMetric]
    let scenarioMetrics: [ScenarioMetric]
    let recentSessionSummary: RecordingLatencyRecentSummary?
    let microbenchmarks: [Microbenchmark]

    static func current(
        textInjectionTiming: TextInjectionTiming,
        speechRecorderStopPolicy: SpeechRecorderStopPolicy,
        realtimeOverlayUpdateGate: RealtimeOverlayUpdateGate,
        learningLoopPolicy: PostInjectionLearningLoopPolicy,
        recentSessionSummary: RecordingLatencyRecentSummary? = nil,
        microbenchmarks: [Microbenchmark]
    ) -> PerformanceBenchmarkReport {
        let asciiPlan = TextInjectionExecutionPlan.make(
            needsInputSourceSwitch: false,
            timing: textInjectionTiming
        )
        let cjkPlan = TextInjectionExecutionPlan.make(
            needsInputSourceSwitch: true,
            timing: textInjectionTiming
        )
        let fixedUpstreamAssumptions = "fixed transcript_finalize=280ms refine=230ms"
        let fixedTranscriptFinalizeMilliseconds = 280
        let fixedRefinementMilliseconds = 230
        let partialStopFallbackMilliseconds = durationMilliseconds(
            speechRecorderStopPolicy.fallbackDelay(forCurrentTranscript: "partial transcript")
        )

        return PerformanceBenchmarkReport(
            budgetMetrics: [
                BudgetMetric(
                    id: "text_injection_ascii_blocking_ms",
                    title: "ASCII text injection blocking latency",
                    legacyValue: 260,
                    currentValue: asciiPlan.blockingLatencyMilliseconds,
                    unit: "ms"
                ),
                BudgetMetric(
                    id: "text_injection_cjk_blocking_ms",
                    title: "CJK text injection blocking latency",
                    legacyValue: 470,
                    currentValue: cjkPlan.blockingLatencyMilliseconds,
                    unit: "ms"
                ),
                BudgetMetric(
                    id: "post_injection_idle_polls_per_minute",
                    title: "Post-injection idle accessibility polls",
                    legacyValue: 240,
                    currentValue: pollsPerMinute(for: learningLoopPolicy.idlePollingInterval),
                    unit: "polls/min"
                ),
                BudgetMetric(
                    id: "floating_panel_repeated_partial_layouts",
                    title: "Floating panel layout recalculations for 10 identical partials",
                    legacyValue: 10,
                    currentValue: repeatedPartialLayouts(sampleCount: 10),
                    unit: "layouts"
                ),
                BudgetMetric(
                    id: "speech_stop_partial_fallback_ms",
                    title: "Speech stop fallback delay with partial transcript",
                    legacyValue: 450,
                    currentValue: partialStopFallbackMilliseconds,
                    unit: "ms"
                ),
                BudgetMetric(
                    id: "recording_meter_overlay_updates_per_second",
                    title: "Recording meter-only overlay updates per second",
                    legacyValue: legacyMeterOverlayUpdatesPerSecond(),
                    currentValue: currentMeterOverlayUpdatesPerSecond(gate: realtimeOverlayUpdateGate),
                    unit: "updates/s"
                )
            ],
            scenarioMetrics: [
                ScenarioMetric(
                    id: "modeled_stop_to_delivery_ascii_ms",
                    title: "Modeled stop-to-delivery latency (ASCII)",
                    legacyValue: fixedTranscriptFinalizeMilliseconds + fixedRefinementMilliseconds + 260,
                    currentValue: fixedTranscriptFinalizeMilliseconds + fixedRefinementMilliseconds + asciiPlan.blockingLatencyMilliseconds,
                    unit: "ms",
                    assumptions: fixedUpstreamAssumptions
                ),
                ScenarioMetric(
                    id: "modeled_stop_to_delivery_cjk_ms",
                    title: "Modeled stop-to-delivery latency (CJK)",
                    legacyValue: fixedTranscriptFinalizeMilliseconds + fixedRefinementMilliseconds + 470,
                    currentValue: fixedTranscriptFinalizeMilliseconds + fixedRefinementMilliseconds + cjkPlan.blockingLatencyMilliseconds,
                    unit: "ms",
                    assumptions: fixedUpstreamAssumptions
                ),
                ScenarioMetric(
                    id: "modeled_stop_to_transcript_local_partial_ms",
                    title: "Modeled stop-to-transcript latency (local partial available)",
                    legacyValue: 450,
                    currentValue: partialStopFallbackMilliseconds,
                    unit: "ms",
                    assumptions: "apple_speech final callback pending, latest partial already available"
                )
            ],
            recentSessionSummary: recentSessionSummary,
            microbenchmarks: microbenchmarks
        )
    }

    func renderedText() -> String {
        let budgetLines = budgetMetrics.map { metric in
            "- \(metric.id) current=\(metric.currentValue)\(metric.unit) legacy=\(metric.legacyValue)\(metric.unit) improvement=\(Self.format(metric.improvementPercentage))%"
        }
        let scenarioLines = scenarioMetrics.map { metric in
            "- \(metric.id) current=\(metric.currentValue)\(metric.unit) legacy=\(metric.legacyValue)\(metric.unit) improvement=\(Self.format(metric.improvementPercentage))% assumptions=\"\(metric.assumptions)\""
        }
        let recentSessionLines = recentSessionSummary.map { summary in
            [
                "- recent_successful_sessions count=\(summary.successfulSessionCount)",
                summary.firstPartialP50Milliseconds.map { "- recent_first_partial_p50_ms value=\($0)ms" },
                summary.stopToTranscriptP50Milliseconds.map { "- recent_stop_to_transcript_p50_ms value=\($0)ms" },
                summary.stopToDeliveryP50Milliseconds.map { "- recent_stop_to_delivery_p50_ms value=\($0)ms" }
            ]
            .compactMap { $0 }
        } ?? []
        let microbenchmarkLines = microbenchmarks.map { metric in
            "- \(metric.id) ns_per_op=\(Self.format(metric.nanosecondsPerIteration)) iterations=\(metric.iterations)"
        }
        var lines = ["VoicePi performance benchmarks", "Budgets:"]
        lines.append(contentsOf: budgetLines)
        lines.append("Modeled scenarios:")
        lines.append(contentsOf: scenarioLines)
        lines.append("Recent sessions:")
        lines.append(contentsOf: recentSessionLines)
        lines.append("Microbenchmarks:")
        lines.append(contentsOf: microbenchmarkLines)
        return lines.joined(separator: "\n")
    }

    private static func pollsPerMinute(for interval: Duration) -> Int {
        let components = interval.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
        guard seconds > 0 else { return 0 }
        return Int((60.0 / seconds).rounded())
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func repeatedPartialLayouts(sampleCount: Int) -> Int {
        var presentationState = FloatingPanelTranscriptPresentationState()
        var layoutCount = 0

        for _ in 0..<max(0, sampleCount) {
            let update = presentationState.prepareUpdate(for: .recording, transcript: "hello")
            if update.requiresLayoutRecalculation {
                layoutCount += 1
            }
        }

        return layoutCount
    }

    private static func legacyMeterOverlayUpdatesPerSecond() -> Int {
        Int((44_100.0 / 1_024.0).rounded())
    }

    private static func currentMeterOverlayUpdatesPerSecond(gate: RealtimeOverlayUpdateGate) -> Int {
        guard gate.minimumMeterUpdateInterval > 0 else {
            return legacyMeterOverlayUpdatesPerSecond()
        }

        return Int((1.0 / gate.minimumMeterUpdateInterval).rounded())
    }

    private static func durationMilliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        let secondsMilliseconds = components.seconds * 1_000
        let attosecondsMilliseconds = components.attoseconds / 1_000_000_000_000_000
        return Int(secondsMilliseconds + attosecondsMilliseconds)
    }
}
