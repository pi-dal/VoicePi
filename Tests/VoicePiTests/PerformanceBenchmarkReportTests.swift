import Testing
@testable import VoicePi

struct PerformanceBenchmarkReportTests {
    @Test
    func budgetMetricsCompareLegacyAndCurrentLatencyBudgets() {
        let report = PerformanceBenchmarkReport.current(
            textInjectionTiming: .default,
            speechRecorderStopPolicy: .default,
            realtimeOverlayUpdateGate: .init(),
            learningLoopPolicy: .default,
            microbenchmarks: []
        )

        #expect(
            report.budgetMetrics == [
                .init(
                    id: "text_injection_ascii_blocking_ms",
                    title: "ASCII text injection blocking latency",
                    legacyValue: 260,
                    currentValue: 78,
                    unit: "ms"
                ),
                .init(
                    id: "text_injection_cjk_blocking_ms",
                    title: "CJK text injection blocking latency",
                    legacyValue: 470,
                    currentValue: 128,
                    unit: "ms"
                ),
                .init(
                    id: "post_injection_idle_polls_per_minute",
                    title: "Post-injection idle accessibility polls",
                    legacyValue: 240,
                    currentValue: 100,
                    unit: "polls/min"
                ),
                .init(
                    id: "floating_panel_repeated_partial_layouts",
                    title: "Floating panel layout recalculations for 10 identical partials",
                    legacyValue: 10,
                    currentValue: 1,
                    unit: "layouts"
                ),
                .init(
                    id: "speech_stop_partial_fallback_ms",
                    title: "Speech stop fallback delay with partial transcript",
                    legacyValue: 450,
                    currentValue: 120,
                    unit: "ms"
                ),
                .init(
                    id: "recording_meter_overlay_updates_per_second",
                    title: "Recording meter-only overlay updates per second",
                    legacyValue: 43,
                    currentValue: 30,
                    unit: "updates/s"
                )
            ]
        )
    }

    @Test
    func scenarioMetricsModelPostRecordingDeliveryUnderFixedUpstreamAssumptions() {
        let report = PerformanceBenchmarkReport.current(
            textInjectionTiming: .default,
            speechRecorderStopPolicy: .default,
            realtimeOverlayUpdateGate: .init(),
            learningLoopPolicy: .default,
            microbenchmarks: []
        )

        #expect(
            report.scenarioMetrics == [
                .init(
                    id: "modeled_stop_to_delivery_ascii_ms",
                    title: "Modeled stop-to-delivery latency (ASCII)",
                    legacyValue: 770,
                    currentValue: 588,
                    unit: "ms",
                    assumptions: "fixed transcript_finalize=280ms refine=230ms"
                ),
                .init(
                    id: "modeled_stop_to_delivery_cjk_ms",
                    title: "Modeled stop-to-delivery latency (CJK)",
                    legacyValue: 980,
                    currentValue: 638,
                    unit: "ms",
                    assumptions: "fixed transcript_finalize=280ms refine=230ms"
                ),
                .init(
                    id: "modeled_stop_to_transcript_local_partial_ms",
                    title: "Modeled stop-to-transcript latency (local partial available)",
                    legacyValue: 450,
                    currentValue: 120,
                    unit: "ms",
                    assumptions: "apple_speech final callback pending, latest partial already available"
                )
            ]
        )
    }

    @Test
    func renderedTextIncludesStableImprovementPercentages() {
        let report = PerformanceBenchmarkReport.current(
            textInjectionTiming: .default,
            speechRecorderStopPolicy: .default,
            realtimeOverlayUpdateGate: .init(),
            learningLoopPolicy: .default,
            recentSessionSummary: .init(
                successfulSessionCount: 4,
                firstPartialP50Milliseconds: 180,
                stopToTranscriptP50Milliseconds: 420,
                stopToDeliveryP50Milliseconds: 690
            ),
            microbenchmarks: [
                .init(
                    id: "recording_latency_trace_report_ns_per_op",
                    title: "Recording latency trace report",
                    iterations: 200_000,
                    nanosecondsPerIteration: 88.4
                )
            ]
        )

        #expect(
            report.renderedText() ==
                """
                VoicePi performance benchmarks
                Budgets:
                - text_injection_ascii_blocking_ms current=78ms legacy=260ms improvement=70.0%
                - text_injection_cjk_blocking_ms current=128ms legacy=470ms improvement=72.8%
                - post_injection_idle_polls_per_minute current=100polls/min legacy=240polls/min improvement=58.3%
                - floating_panel_repeated_partial_layouts current=1layouts legacy=10layouts improvement=90.0%
                - speech_stop_partial_fallback_ms current=120ms legacy=450ms improvement=73.3%
                - recording_meter_overlay_updates_per_second current=30updates/s legacy=43updates/s improvement=30.2%
                Modeled scenarios:
                - modeled_stop_to_delivery_ascii_ms current=588ms legacy=770ms improvement=23.6% assumptions="fixed transcript_finalize=280ms refine=230ms"
                - modeled_stop_to_delivery_cjk_ms current=638ms legacy=980ms improvement=34.9% assumptions="fixed transcript_finalize=280ms refine=230ms"
                - modeled_stop_to_transcript_local_partial_ms current=120ms legacy=450ms improvement=73.3% assumptions="apple_speech final callback pending, latest partial already available"
                Recent sessions:
                - recent_successful_sessions count=4
                - recent_first_partial_p50_ms value=180ms
                - recent_stop_to_transcript_p50_ms value=420ms
                - recent_stop_to_delivery_p50_ms value=690ms
                Microbenchmarks:
                - recording_latency_trace_report_ns_per_op ns_per_op=88.4 iterations=200000
                """
        )
    }
}
