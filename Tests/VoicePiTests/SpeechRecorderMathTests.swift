import Testing
@testable import VoicePi

struct SpeechRecorderMathTests {
    @Test
    func normalizeDecibelsClampsIntoZeroToOneRange() {
        #expect(SpeechRecorderMath.normalizeDecibels(-100) == 0)
        #expect(SpeechRecorderMath.normalizeDecibels(0) == 1)
    }

    @Test
    func envelopeUsesFasterAttackThanRelease() {
        let attackValue = SpeechRecorderMath.applyEnvelope(current: 0.2, target: 1.0)
        let releaseValue = SpeechRecorderMath.applyEnvelope(current: 0.8, target: 0.0)

        #expect(attackValue > 0.2)
        #expect(releaseValue < 0.8)
        #expect(attackValue - 0.2 > 0.8 - releaseValue)
    }
}
