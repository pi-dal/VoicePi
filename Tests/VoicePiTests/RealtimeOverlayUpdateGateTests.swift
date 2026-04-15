import CoreGraphics
import Testing
@testable import VoicePi

struct RealtimeOverlayUpdateGateTests {
    @Test
    func transcriptChangesPublishImmediately() {
        var gate = RealtimeOverlayUpdateGate()

        let update = gate.consume(
            transcript: "hello",
            level: 0.25,
            now: 0
        )

        #expect(update == .transcriptAndLevel(transcript: "hello", level: 0.25))
    }

    @Test
    func repeatedMeterOnlyUpdatesAreThrottled() {
        var gate = RealtimeOverlayUpdateGate()

        _ = gate.consume(transcript: "hello", level: 0.25, now: 0)

        let immediate = gate.consume(
            transcript: "hello",
            level: 0.4,
            now: 0.010
        )
        let delayed = gate.consume(
            transcript: "hello",
            level: 0.45,
            now: 0.040
        )

        #expect(immediate == .none)
        #expect(delayed == .levelOnly(level: 0.45))
    }

    @Test
    func repeatedTranscriptIsSuppressedUntilMeterWindowOpens() {
        var gate = RealtimeOverlayUpdateGate()

        _ = gate.consume(transcript: "hello", level: 0.25, now: 0)

        let repeatedTranscript = gate.consume(
            transcript: "hello",
            level: 0.25,
            now: 0.015
        )

        #expect(repeatedTranscript == .none)
    }
}
