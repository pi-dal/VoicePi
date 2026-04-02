import Foundation

protocol RemoteASRServing {
    func transcribe(
        audioFileURL: URL,
        language: SupportedLanguage,
        configuration: RemoteASRConfiguration
    ) async throws -> String
}

protocol TranscriptRefining {
    func refine(
        text: String,
        configuration: LLMRefinerConfiguration,
        targetLanguage: SupportedLanguage?
    ) async throws -> String
}

protocol TranscriptTranslating {
    func translate(
        text: String,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage
    ) async throws -> String
}

extension RemoteASRClient: RemoteASRServing {}
extension LLMRefiner: TranscriptRefining {}

struct RecordingPreparationPermissions: Equatable {
    let accessibilityGranted: Bool
    let microphoneGranted: Bool
    let speechGranted: Bool
}

enum AppWorkflowPresentation: Equatable {
    case transcribing(overlayTranscript: String, statusText: String)
    case refining(overlayTranscript: String, statusText: String)
}

enum AppWorkflowSupport {
    static func resolveTranscriptAfterRecording(
        backend: ASRBackend,
        localFallback: String,
        audioURL: URL?,
        language: SupportedLanguage,
        configuration: RemoteASRConfiguration,
        remoteASR: RemoteASRServing,
        onPresentation: (AppWorkflowPresentation) -> Void,
        onError: (String) -> Void
    ) async -> String {
        switch backend {
        case .appleSpeech:
            return localFallback

        case .remoteOpenAICompatible:
            guard configuration.isConfigured else {
                onError("Remote ASR is selected, but API Base URL, API Key, and Model are not fully configured.")
                return localFallback
            }

            guard let audioURL else {
                onError("Remote ASR could not find the recorded audio file.")
                return localFallback
            }

            onPresentation(.transcribing(overlayTranscript: "Transcribing...", statusText: "Remote ASR…"))

            do {
                let transcript = try await remoteASR.transcribe(
                    audioFileURL: audioURL,
                    language: language,
                    configuration: configuration
                )
                let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? localFallback : trimmed
            } catch {
                onError("Remote ASR failed: \(error.localizedDescription)")
                return localFallback
            }
        }
    }

    static func postProcessIfNeeded(
        _ text: String,
        mode: PostProcessingMode,
        translationProvider: TranslationProvider,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        configuration: LLMConfiguration,
        refiner: TranscriptRefining,
        translator: TranscriptTranslating,
        onPresentation: (AppWorkflowPresentation) -> Void,
        onError: (String) -> Void
    ) async -> String {
        guard mode != .disabled else {
            return text
        }

        let refinerConfiguration = LLMRefinerConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model
        )

        switch mode {
        case .disabled:
            return text
        case .refinement:
            guard configuration.isConfigured else {
                return text
            }

            onPresentation(.refining(overlayTranscript: "Refining...", statusText: "Refining…"))

            do {
                let effectiveTargetLanguage = targetLanguage == sourceLanguage ? nil : targetLanguage
                let refined = try await refiner.refine(
                    text: text,
                    configuration: refinerConfiguration,
                    targetLanguage: effectiveTargetLanguage
                )
                let trimmed = refined.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? text : trimmed
            } catch {
                onError("LLM refinement failed: \(error.localizedDescription)")
                return text
            }
        case .translation:
            guard targetLanguage != sourceLanguage else {
                return text
            }

            onPresentation(.refining(overlayTranscript: "Translating...", statusText: "Translating…"))

            if translationProvider == .llm && configuration.isConfigured {
                do {
                    let translated = try await refiner.refine(
                        text: text,
                        configuration: refinerConfiguration,
                        targetLanguage: targetLanguage
                    )
                    let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? text : trimmed
                } catch {
                    onError("LLM translation failed: \(error.localizedDescription)")
                    return text
                }
            }

            do {
                let translated = try await translator.translate(
                    text: text,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
                let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? text : trimmed
            } catch {
                onError("Apple Translate failed: \(error.localizedDescription)")
                return text
            }
        }
    }

    static func preparationFailureMessage(
        permissions: RecordingPreparationPermissions,
        backend: ASRBackend,
        remoteConfigurationReady: Bool
    ) -> String? {
        if !permissions.accessibilityGranted {
            return "Accessibility permission is required for global key monitoring and paste injection."
        }

        if !permissions.microphoneGranted {
            return "Microphone permission was not granted."
        }

        if backend == .appleSpeech && !permissions.speechGranted {
            return "Speech Recognition permission was not granted."
        }

        if backend == .remoteOpenAICompatible && !remoteConfigurationReady {
            return "Remote ASR is selected, but its configuration is incomplete."
        }

        return nil
    }
}
