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
        configuration: LLMRefinerConfiguration
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

    static func refineIfNeeded(
        _ text: String,
        llmEnabled: Bool,
        configuration: LLMConfiguration,
        refiner: TranscriptRefining,
        onPresentation: (AppWorkflowPresentation) -> Void,
        onError: (String) -> Void
    ) async -> String {
        guard llmEnabled && configuration.isConfigured else {
            return text
        }

        onPresentation(.refining(overlayTranscript: "Refining...", statusText: "Refining…"))

        let refinerConfiguration = LLMRefinerConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model
        )

        do {
            let refined = try await refiner.refine(text: text, configuration: refinerConfiguration)
            let trimmed = refined.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? text : trimmed
        } catch {
            onError("LLM refinement failed: \(error.localizedDescription)")
            return text
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
