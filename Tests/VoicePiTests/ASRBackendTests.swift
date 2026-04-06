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

    @Test
    func aliyunBackendUsesCaptureOnlyRecorderMode() {
        #expect(ASRBackend.remoteAliyunASR.speechRecorderMode == .captureOnly)
    }

    @Test
    func volcengineBackendUsesCaptureOnlyRecorderMode() {
        #expect(ASRBackend.remoteVolcengineASR.speechRecorderMode == .captureOnly)
    }

    @Test
    func remoteBackendFlagMatchesBackendType() {
        #expect(ASRBackend.appleSpeech.isRemoteBackend == false)
        #expect(ASRBackend.remoteOpenAICompatible.isRemoteBackend)
        #expect(ASRBackend.remoteAliyunASR.isRemoteBackend)
        #expect(ASRBackend.remoteVolcengineASR.isRemoteBackend)
    }

    @Test
    func realtimeStreamingFlagMatchesBackendType() {
        #expect(ASRBackend.appleSpeech.usesRealtimeStreaming == false)
        #expect(ASRBackend.remoteOpenAICompatible.usesRealtimeStreaming == false)
        #expect(ASRBackend.remoteAliyunASR.usesRealtimeStreaming)
        #expect(ASRBackend.remoteVolcengineASR.usesRealtimeStreaming)
    }

    @Test
    func aliyunPlaceholderUsesCompatibleModeBaseURL() {
        #expect(
            ASRBackend.remoteAliyunASR.remoteBaseURLPlaceholder
                == "https://dashscope.aliyuncs.com/compatible-mode/v1"
        )
        #expect(ASRBackend.remoteAliyunASR.remoteModelPlaceholder == "fun-asr-realtime")
    }

    @Test
    func volcenginePlaceholderUsesRealtimeWebSocketEndpoint() {
        #expect(
            ASRBackend.remoteVolcengineASR.remoteBaseURLPlaceholder
                == "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"
        )
        #expect(ASRBackend.remoteVolcengineASR.remoteModelPlaceholder == "bigmodel")
        #expect(ASRBackend.remoteVolcengineASR.remoteAppIDPlaceholder == "1234567890")
    }
}
