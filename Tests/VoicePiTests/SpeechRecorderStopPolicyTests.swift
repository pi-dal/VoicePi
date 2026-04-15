import Testing
@testable import VoicePi

struct SpeechRecorderStopPolicyTests {
    @Test
    func usesShortGracePeriodWhenPartialTranscriptAlreadyExists() {
        #expect(
            SpeechRecorderStopPolicy.default.fallbackDelay(
                forCurrentTranscript: "hello world"
            ) == .milliseconds(120)
        )
    }

    @Test
    func keepsLongerGracePeriodWhenNoTranscriptHasArrivedYet() {
        #expect(
            SpeechRecorderStopPolicy.default.fallbackDelay(
                forCurrentTranscript: " \n "
            ) == .milliseconds(450)
        )
    }
}
