import Foundation
import Testing
@testable import VoicePi

struct AppWorkflowSupportTests {
    @Test
    func remoteTranscriptFallsBackWhenConfigurationIsIncomplete() async {
        let remote = RemoteASRStub(result: .success("remote"))
        var errors: [String] = []

        let transcript = await AppWorkflowSupport.resolveTranscriptAfterRecording(
            backend: .remoteOpenAICompatible,
            localFallback: "local",
            audioURL: URL(fileURLWithPath: "/tmp/audio.m4a"),
            language: .english,
            configuration: .init(),
            remoteASR: remote,
            onPresentation: { _ in },
            onError: { errors.append($0) }
        )

        #expect(transcript == "local")
        #expect(errors == ["Remote ASR is selected, but API Base URL, API Key, and Model are not fully configured."])
        #expect(remote.calls == 0)
    }

    @Test
    func remoteTranscriptFallsBackWhenRemoteReturnsEmptyText() async {
        let remote = RemoteASRStub(result: .success("   "))
        var presentations: [AppWorkflowPresentation] = []

        let transcript = await AppWorkflowSupport.resolveTranscriptAfterRecording(
            backend: .remoteOpenAICompatible,
            localFallback: "local",
            audioURL: URL(fileURLWithPath: "/tmp/audio.m4a"),
            language: .english,
            configuration: .init(baseURL: "https://api.example.com", apiKey: "sk", model: "whisper"),
            remoteASR: remote,
            onPresentation: { presentations.append($0) },
            onError: { _ in }
        )

        #expect(transcript == "local")
        #expect(presentations == [.transcribing(overlayTranscript: "Transcribing...", statusText: "Remote ASR…")])
        #expect(remote.calls == 1)
    }

    @Test
    func refineReturnsOriginalTextWhenDisabled() async {
        let refiner = RefinerStub(result: .success("refined"))

        let text = await AppWorkflowSupport.refineIfNeeded(
            "original",
            llmEnabled: false,
            configuration: .init(),
            refiner: refiner,
            onPresentation: { _ in },
            onError: { _ in }
        )

        #expect(text == "original")
        #expect(refiner.calls == 0)
    }

    @Test
    func refineReturnsOriginalTextWhenRefinerFails() async {
        let refiner = RefinerStub(result: .failure(AppWorkflowTestError.sample))
        var errors: [String] = []

        let text = await AppWorkflowSupport.refineIfNeeded(
            "original",
            llmEnabled: true,
            configuration: .init(baseURL: "https://api.example.com", apiKey: "sk", model: "gpt"),
            refiner: refiner,
            onPresentation: { _ in },
            onError: { errors.append($0) }
        )

        #expect(text == "original")
        #expect(errors == ["LLM refinement failed: sample"])
        #expect(refiner.calls == 1)
    }

    @Test
    func preparationFailureMessageRespectsPermissionAndBackendOrdering() {
        #expect(
            AppWorkflowSupport.preparationFailureMessage(
                permissions: .init(accessibilityGranted: false, microphoneGranted: true, speechGranted: true),
                backend: .appleSpeech,
                remoteConfigurationReady: true
            ) == "Accessibility permission is required for global key monitoring and paste injection."
        )
        #expect(
            AppWorkflowSupport.preparationFailureMessage(
                permissions: .init(accessibilityGranted: true, microphoneGranted: false, speechGranted: true),
                backend: .appleSpeech,
                remoteConfigurationReady: true
            ) == "Microphone permission was not granted."
        )
        #expect(
            AppWorkflowSupport.preparationFailureMessage(
                permissions: .init(accessibilityGranted: true, microphoneGranted: true, speechGranted: false),
                backend: .appleSpeech,
                remoteConfigurationReady: true
            ) == "Speech Recognition permission was not granted."
        )
        #expect(
            AppWorkflowSupport.preparationFailureMessage(
                permissions: .init(accessibilityGranted: true, microphoneGranted: true, speechGranted: true),
                backend: .remoteOpenAICompatible,
                remoteConfigurationReady: false
            ) == "Remote ASR is selected, but its configuration is incomplete."
        )
    }
}

private enum AppWorkflowTestError: LocalizedError {
    case sample

    var errorDescription: String? {
        "sample"
    }
}

private final class RemoteASRStub: RemoteASRServing, @unchecked Sendable {
    var result: Result<String, Error>
    private(set) var calls = 0

    init(result: Result<String, Error>) {
        self.result = result
    }

    func transcribe(
        audioFileURL: URL,
        language: SupportedLanguage,
        configuration: RemoteASRConfiguration
    ) async throws -> String {
        calls += 1
        return try result.get()
    }
}

private final class RefinerStub: TranscriptRefining, @unchecked Sendable {
    var result: Result<String, Error>
    private(set) var calls = 0

    init(result: Result<String, Error>) {
        self.result = result
    }

    func refine(
        text: String,
        configuration: LLMRefinerConfiguration
    ) async throws -> String {
        calls += 1
        return try result.get()
    }
}
