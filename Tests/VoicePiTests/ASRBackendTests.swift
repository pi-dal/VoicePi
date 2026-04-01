import Testing
@testable import VoicePi

struct ASRBackendTests {
    @Test
    func appleSpeechBackendUsesStreamingRecorderMode() {
        #expect(ASRBackend.appleSpeech.speechRecorderMode == .appleSpeechStreaming)
    }

    @Test
    func remoteBackendUsesCaptureOnlyRecorderMode() {
        #expect(ASRBackend.remoteOpenAICompatible.speechRecorderMode == .captureOnly)
    }
}
