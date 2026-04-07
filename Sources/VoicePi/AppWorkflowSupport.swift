import Foundation

protocol RemoteASRServing {
    func transcribe(
        audioFileURL: URL,
        language: SupportedLanguage,
        backend: ASRBackend,
        configuration: RemoteASRConfiguration
    ) async throws -> String
}

protocol TranscriptRefining {
    func refine(
        text: String,
        configuration: LLMRefinerConfiguration,
        mode: LLMRefinerPromptMode,
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
        guard backend.isRemoteBackend else {
            return localFallback
        }

        guard configuration.isConfigured(for: backend) else {
            let requiredFields = remoteConfigurationRequirements(for: backend)
            await MainActor.run {
                onError("Remote ASR is selected, but \(requiredFields) are not fully configured.")
            }
            return localFallback
        }

        guard let audioURL else {
            await MainActor.run {
                onError("Remote ASR could not find the recorded audio file.")
            }
            return localFallback
        }

        await MainActor.run {
            onPresentation(.transcribing(overlayTranscript: "Transcribing...", statusText: backend.remoteStatusText))
        }

        do {
            let transcript = try await remoteASR.transcribe(
                audioFileURL: audioURL,
                language: language,
                backend: backend,
                configuration: configuration
            )
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? localFallback : trimmed
        } catch {
            await MainActor.run {
                onError("Remote ASR failed: \(error.localizedDescription)")
            }
            return localFallback
        }
    }

    static func postProcessIfNeeded(
        _ text: String,
        mode: PostProcessingMode,
        translationProvider: TranslationProvider,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        configuration: LLMConfiguration,
        refinementPromptTitle: String? = nil,
        resolvedRefinementPrompt: String?,
        refiner: TranscriptRefining,
        translator: TranscriptTranslating,
        onPresentation: (AppWorkflowPresentation) -> Void,
        onError: (String) -> Void
    ) async -> String {
        switch mode {
        case .disabled:
            return text
        case .refinement:
            guard configuration.isConfigured else {
                return text
            }

            let refinementStatusText = refinementStatusText(promptTitle: refinementPromptTitle)

            let refinerConfiguration = LLMRefinerConfiguration(
                baseURL: configuration.baseURL,
                apiKey: configuration.apiKey,
                model: configuration.model,
                refinementPrompt: resolvedRefinementPrompt ?? ""
            )

            await MainActor.run {
                onPresentation(
                    .refining(
                        overlayTranscript: refinementStatusText,
                        statusText: refinementStatusText
                    )
                )
            }

            do {
                let effectiveTargetLanguage = targetLanguage == sourceLanguage ? nil : targetLanguage
                let refined = try await refiner.refine(
                    text: text,
                    configuration: refinerConfiguration,
                    mode: .refinement,
                    targetLanguage: effectiveTargetLanguage
                )
                let trimmed = refined.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? text : trimmed
            } catch {
                await MainActor.run {
                    onError("LLM refinement failed: \(error.localizedDescription)")
                }
                return text
            }
        case .translation:
            guard targetLanguage != sourceLanguage else {
                return text
            }

            let refinerConfiguration = LLMRefinerConfiguration(
                baseURL: configuration.baseURL,
                apiKey: configuration.apiKey,
                model: configuration.model,
                refinementPrompt: ""
            )

            await MainActor.run {
                onPresentation(.refining(overlayTranscript: "Translating...", statusText: "Translating…"))
            }

            switch translationProvider {
            case .llm:
                guard configuration.isConfigured else {
                    await MainActor.run {
                        onError("LLM translation is selected, but LLM is not fully configured.")
                    }
                    return text
                }

                do {
                    let translated = try await refiner.refine(
                        text: text,
                        configuration: refinerConfiguration,
                        mode: .translation,
                        targetLanguage: targetLanguage
                    )
                    let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? text : trimmed
                } catch {
                    await MainActor.run {
                        onError("LLM translation failed: \(error.localizedDescription)")
                    }
                    return text
                }
            case .appleTranslate:
                do {
                    let translated = try await translator.translate(
                        text: text,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage
                    )
                    let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? text : trimmed
                } catch {
                    await MainActor.run {
                        onError("Translation via \(translationProvider.title) failed: \(error.localizedDescription)")
                    }
                    return text
                }
            }
        }
    }

    static func preparationFailureMessage(
        permissions: RecordingPreparationPermissions,
        backend: ASRBackend,
        remoteConfigurationReady: Bool
    ) -> String? {
        if !permissions.microphoneGranted {
            return "Microphone permission was not granted."
        }

        if backend == .appleSpeech && !permissions.speechGranted {
            return "Speech Recognition permission was not granted."
        }

        if backend.isRemoteBackend && !remoteConfigurationReady {
            return "Remote ASR is selected, but its configuration is incomplete."
        }

        return nil
    }

    private static func remoteConfigurationRequirements(for backend: ASRBackend) -> String {
        switch backend {
        case .remoteVolcengineASR:
            return "API Base URL, API Key, Model, and Volcengine AppID"
        case .remoteOpenAICompatible, .remoteAliyunASR, .appleSpeech:
            return "API Base URL, API Key, and Model"
        }
    }

    private static func refinementStatusText(promptTitle: String?) -> String {
        let trimmed = promptTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Refining…" : "Refining with \(trimmed)"
    }
}
