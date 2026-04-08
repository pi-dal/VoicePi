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
    func remoteVolcengineTranscriptUsesProviderSpecificStatusText() async {
        let remote = RemoteASRStub(result: .success("volc transcript"))
        var presentations: [AppWorkflowPresentation] = []

        let transcript = await AppWorkflowSupport.resolveTranscriptAfterRecording(
            backend: .remoteVolcengineASR,
            localFallback: "local",
            audioURL: URL(fileURLWithPath: "/tmp/audio.m4a"),
            language: .english,
            configuration: .init(
                baseURL: "https://ark.cn-beijing.volces.com/api/v3",
                apiKey: "ak",
                model: "ep-test",
                prompt: "",
                volcengineAppID: "app-test"
            ),
            remoteASR: remote,
            onPresentation: { presentations.append($0) },
            onError: { _ in }
        )

        #expect(transcript == "volc transcript")
        #expect(presentations == [.transcribing(overlayTranscript: "Transcribing...", statusText: "Volcengine ASR…")])
        #expect(remote.calls == 1)
    }

    @Test
    func postProcessingReturnsOriginalTextWhenDisabled() async {
        let refiner = RefinerStub(result: .success("refined"))
        let translator = TranslatorStub(result: .success("translated"))

        let text = await AppWorkflowSupport.postProcessIfNeeded(
            "original",
            mode: .disabled,
            translationProvider: .appleTranslate,
            sourceLanguage: .english,
            targetLanguage: .english,
            configuration: .init(),
            resolvedRefinementPrompt: nil,
            refiner: refiner,
            translator: translator,
            onPresentation: { _ in },
            onError: { _ in }
        )

        #expect(text == "original")
        #expect(refiner.calls == 0)
        #expect(translator.calls == 0)
    }

    @Test
    func refinementIncorporatesTargetLanguageIntoLLMPath() async {
        let refiner = RefinerStub(result: .success("日本語の出力"))
        let translator = TranslatorStub(result: .success("translated"))
        var presentations: [AppWorkflowPresentation] = []
        let dictionaryEntries = [
            DictionaryEntry(canonical: "PostgreSQL", aliases: ["postgre"], isEnabled: true)
        ]

        let text = await AppWorkflowSupport.postProcessIfNeeded(
            "original",
            mode: .refinement,
            translationProvider: .appleTranslate,
            sourceLanguage: .english,
            targetLanguage: .japanese,
            configuration: .init(
                baseURL: "https://api.example.com",
                apiKey: "sk",
                model: "gpt",
                refinementPrompt: "legacy freeform prompt"
            ),
            refinementPromptTitle: "Slack Reply",
            resolvedRefinementPrompt: "Format the output as concise release notes.",
            dictionaryEntries: dictionaryEntries,
            refiner: refiner,
            translator: translator,
            onPresentation: { presentations.append($0) },
            onError: { _ in }
        )

        #expect(text == "日本語の出力")
        #expect(
            presentations == [.refining(
                overlayTranscript: "Refining with Slack Reply",
                statusText: "Refining with Slack Reply"
            )]
        )
        #expect(refiner.calls == 1)
        #expect(refiner.lastTargetLanguage == .japanese)
        #expect(refiner.lastMode == .refinement)
        #expect(refiner.lastRefinementPrompt == "Format the output as concise release notes.")
        #expect(refiner.lastDictionaryEntries == dictionaryEntries)
        #expect(translator.calls == 0)
    }

    @Test
    func postProcessingPresentationCallbacksRunOnMainThread() async {
        let refiner = RefinerStub(result: .success("translated"))
        let translator = TranslatorStub(result: .success("unused"))
        let callbackThreadRecorder = ThreadRecorder()

        let text = await Task.detached {
            await AppWorkflowSupport.postProcessIfNeeded(
                "original",
                mode: .translation,
                translationProvider: .llm,
                sourceLanguage: .english,
                targetLanguage: .japanese,
                configuration: .init(baseURL: "https://api.example.com", apiKey: "sk", model: "gpt"),
                resolvedRefinementPrompt: nil,
                refiner: refiner,
                translator: translator,
                onPresentation: { _ in
                    callbackThreadRecorder.record(Thread.isMainThread)
                },
                onError: { _ in }
            )
        }.value

        #expect(text == "translated")
        #expect(callbackThreadRecorder.value == true)
    }

    @Test
    func translateModeDefaultsToAppleTranslateWhenLLMProviderIsNotExplicitlySelected() async {
        let refiner = RefinerStub(result: .success("llm"))
        let translator = TranslatorStub(result: .success("translated"))

        let text = await AppWorkflowSupport.postProcessIfNeeded(
            "original",
            mode: .translation,
            translationProvider: .appleTranslate,
            sourceLanguage: .english,
            targetLanguage: .japanese,
            configuration: .init(baseURL: "https://api.example.com", apiKey: "sk", model: "gpt"),
            resolvedRefinementPrompt: nil,
            refiner: refiner,
            translator: translator,
            onPresentation: { _ in },
            onError: { _ in }
        )

        #expect(text == "translated")
        #expect(refiner.calls == 0)
        #expect(translator.calls == 1)
        #expect(translator.lastTargetLanguage == .japanese)
    }

    @Test
    func llmTranslationPathUsesTranslationPromptModeInsteadOfRefinementPromptMode() async {
        let refiner = RefinerStub(result: .success("translated"))
        let translator = TranslatorStub(result: .success("unused"))

        let text = await AppWorkflowSupport.postProcessIfNeeded(
            "original",
            mode: .translation,
            translationProvider: .llm,
            sourceLanguage: .english,
            targetLanguage: .japanese,
            configuration: .init(
                baseURL: "https://api.example.com",
                apiKey: "sk",
                model: "gpt",
                refinementPrompt: "legacy old prompt"
            ),
            resolvedRefinementPrompt: "Respond with XML.",
            refiner: refiner,
            translator: translator,
            onPresentation: { _ in },
            onError: { _ in }
        )

        #expect(text == "translated")
        #expect(refiner.calls == 1)
        #expect(refiner.lastMode == .translation)
        #expect(refiner.lastRefinementPrompt == "")
        #expect(refiner.lastDictionaryEntries.isEmpty)
        #expect(translator.calls == 0)
    }

    @Test
    func translationReturnsOriginalTextWhenLLMProviderLacksConfiguration() async {
        let refiner = RefinerStub(result: .success("llm"))
        let translator = TranslatorStub(result: .success("apple"))
        var errors: [String] = []

        let text = await AppWorkflowSupport.postProcessIfNeeded(
            "original",
            mode: .translation,
            translationProvider: .llm,
            sourceLanguage: .english,
            targetLanguage: .japanese,
            configuration: .init(),
            resolvedRefinementPrompt: nil,
            refiner: refiner,
            translator: translator,
            onPresentation: { _ in },
            onError: { errors.append($0) }
        )

        #expect(text == "original")
        #expect(errors == ["LLM translation is selected, but LLM is not fully configured."])
        #expect(refiner.calls == 0)
        #expect(translator.calls == 0)
    }

    @Test
    func refinementReturnsOriginalTextWhenRefinerFails() async {
        let refiner = RefinerStub(result: .failure(AppWorkflowTestError.sample))
        let translator = TranslatorStub(result: .success("translated"))
        var errors: [String] = []

        let text = await AppWorkflowSupport.postProcessIfNeeded(
            "original",
            mode: .refinement,
            translationProvider: .appleTranslate,
            sourceLanguage: .english,
            targetLanguage: .english,
            configuration: .init(baseURL: "https://api.example.com", apiKey: "sk", model: "gpt"),
            resolvedRefinementPrompt: nil,
            refiner: refiner,
            translator: translator,
            onPresentation: { _ in },
            onError: { errors.append($0) }
        )

        #expect(text == "original")
        #expect(errors == ["LLM refinement failed: sample"])
        #expect(refiner.calls == 1)
        #expect(translator.calls == 0)
    }

    @Test
    func preparationFailureMessageRespectsPermissionAndBackendOrdering() {
        #expect(
            AppWorkflowSupport.preparationFailureMessage(
                permissions: .init(accessibilityGranted: false, microphoneGranted: true, speechGranted: true),
                backend: .appleSpeech,
                remoteConfigurationReady: true
            ) == nil
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
        backend: ASRBackend,
        configuration: RemoteASRConfiguration
    ) async throws -> String {
        calls += 1
        return try result.get()
    }
}

private final class RefinerStub: TranscriptRefining, @unchecked Sendable {
    var result: Result<String, Error>
    private(set) var calls = 0
    private(set) var lastMode: LLMRefinerPromptMode?
    private(set) var lastTargetLanguage: SupportedLanguage?
    private(set) var lastRefinementPrompt: String?
    private(set) var lastDictionaryEntries: [DictionaryEntry] = []

    init(result: Result<String, Error>) {
        self.result = result
    }

    func refine(
        text: String,
        configuration: LLMRefinerConfiguration,
        mode: LLMRefinerPromptMode,
        targetLanguage: SupportedLanguage?,
        dictionaryEntries: [DictionaryEntry]
    ) async throws -> String {
        calls += 1
        lastMode = mode
        lastTargetLanguage = targetLanguage
        lastRefinementPrompt = configuration.refinementPrompt
        lastDictionaryEntries = dictionaryEntries
        return try result.get()
    }
}

private final class TranslatorStub: TranscriptTranslating, @unchecked Sendable {
    var result: Result<String, Error>
    private(set) var calls = 0
    private(set) var lastSourceLanguage: SupportedLanguage?
    private(set) var lastTargetLanguage: SupportedLanguage?

    init(result: Result<String, Error>) {
        self.result = result
    }

    func translate(
        text: String,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage
    ) async throws -> String {
        calls += 1
        lastSourceLanguage = sourceLanguage
        lastTargetLanguage = targetLanguage
        return try result.get()
    }
}

private final class ThreadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Bool?

    func record(_ value: Bool) {
        lock.lock()
        storedValue = value
        lock.unlock()
    }

    var value: Bool? {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }
}
