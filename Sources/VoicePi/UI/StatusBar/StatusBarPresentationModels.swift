import AppKit
import Foundation

struct LanguageMenuItemPresentation: Equatable {
    let language: SupportedLanguage
    let isSelected: Bool
    let isEnabled: Bool
}

struct LanguageMenuPresentation: Equatable {
    let inputItems: [LanguageMenuItemPresentation]
    let outputItems: [LanguageMenuItemPresentation]
    let outputSummary: String
    let outputSelectionEnabled: Bool
    let effectiveOutputLanguage: SupportedLanguage

    @MainActor
    static func make(model: AppModel) -> LanguageMenuPresentation {
        let outputSelectionEnabled = model.postProcessingMode != .disabled
        let effectiveOutputLanguage = outputSelectionEnabled ? model.targetLanguage : model.selectedLanguage
        let outputItems: [LanguageMenuItemPresentation]
        let outputSummary: String

        if outputSelectionEnabled {
            outputItems = SupportedLanguage.allCases.map { language in
                LanguageMenuItemPresentation(
                    language: language,
                    isSelected: language == effectiveOutputLanguage,
                    isEnabled: true
                )
            }
            outputSummary = "Current Output: \(effectiveOutputLanguage.menuTitle)"
        } else {
            outputItems = []
            outputSummary = "Output unavailable while text processing is disabled"
        }

        return LanguageMenuPresentation(
            inputItems: SupportedLanguage.allCases.map { language in
                LanguageMenuItemPresentation(
                    language: language,
                    isSelected: language == model.selectedLanguage,
                    isEnabled: true
                )
            },
            outputItems: outputItems,
            outputSummary: outputSummary,
            outputSelectionEnabled: outputSelectionEnabled,
            effectiveOutputLanguage: effectiveOutputLanguage
        )
    }
}

struct StatusMenuPresentation: Equatable {
    let statusLine: String
    let languageLine: String
    let permissionsLine: String

    @MainActor
    static func make(
        model: AppModel,
        transientStatus: String?,
        isRecording: Bool
    ) -> StatusMenuPresentation {
        let languagePresentation = LanguageMenuPresentation.make(model: model)

        let statusText: String
        if let transientStatus, !transientStatus.isEmpty {
            statusText = compactStatusLine(transientStatus)
        } else if isRecording {
            statusText = "Recording…"
        } else if model.recordingState == .refining {
            statusText = "Refining…"
        } else {
            statusText = "Ready"
        }

        return StatusMenuPresentation(
            statusLine: statusText,
            languageLine: "Language: \(model.selectedLanguage.menuTitle) → \(languagePresentation.effectiveOutputLanguage.menuTitle)",
            permissionsLine: "Permissions: Mic \(symbol(for: model.microphoneAuthorization)) / Speech \(symbol(for: model.speechAuthorization)) / AX \(symbol(for: model.accessibilityAuthorization)) / IM \(symbol(for: model.inputMonitoringAuthorization))"
        )
    }

    private static func compactStatusLine(_ status: String) -> String {
        let normalized = status
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized {
        case AppController.shortcutMonitoringFailureMessage:
            return "Shortcut unavailable"
        case AppController.shortcutSuppressionWarningMessage:
            return "Listening only"
        default:
            break
        }

        if normalized.hasPrefix("Translation via "), normalized.contains(" failed") {
            return "Translation failed"
        }

        if normalized.contains("permission was not granted") {
            return "Permission denied"
        }

        if normalized.count > 44 {
            return String(normalized.prefix(43)) + "…"
        }

        return normalized
    }

    private static func symbol(for state: AuthorizationState) -> String {
        switch state {
        case .granted:
            return "✓"
        case .denied, .restricted:
            return "✗"
        case .unknown:
            return "…"
        }
    }
}

struct LLMSectionFeedback {
    static func message(
        mode: PostProcessingMode,
        provider: TranslationProvider,
        refinementProvider: RefinementProvider = .llm,
        externalProcessor: ExternalProcessorEntry? = nil,
        configuration: LLMConfiguration,
        selectedLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        appleTranslateSupported: Bool
    ) -> String {
        switch mode {
        case .disabled:
            return "Text processing is disabled. VoicePi will inject the transcript without additional refinement or translation."
        case .refinement:
            switch refinementProvider {
            case .llm:
                guard configuration.isConfigured else {
                    return "Refinement is selected, but API Base URL, API Key, and Model are still required."
                }

                if targetLanguage == selectedLanguage {
                    return "Refinement is active and will use the configured LLM provider."
                }

                return "Refinement is active. VoicePi will fold translation into the LLM prompt and target \(targetLanguage.recognitionDisplayName)."
            case .externalProcessor:
                guard let externalProcessor else {
                    return "Refinement is selected, but no processor is configured yet. Click Processors to add one."
                }

                return "Refinement is active and will use \(externalProcessor.name)."
            }
        case .translation:
            if provider == .appleTranslate {
                return "Translation is active and defaults to Apple Translate."
            }

            guard configuration.isConfigured else {
                if appleTranslateSupported {
                    return "LLM translation is selected, but the LLM configuration is incomplete. VoicePi will fall back to Apple Translate."
                }

                return "LLM translation is selected because Apple Translate is unavailable on this macOS version, but the LLM configuration is incomplete. Translation will not work until API Base URL, API Key, and Model are provided."
            }

            return "Translation is active and will use the configured LLM provider."
        }
    }
}

enum ASRBackendMode: String, CaseIterable {
    case local
    case remote

    var title: String {
        switch self {
        case .local:
            return "Local"
        case .remote:
            return "Remote"
        }
    }

    var subtitle: String {
        switch self {
        case .local:
            return "On-device"
        case .remote:
            return "Cloud"
        }
    }

    var description: String {
        switch self {
        case .local:
            return "Uses the built-in Apple Speech recognizer."
        case .remote:
            return "Routes transcription through a configurable cloud ASR provider."
        }
    }

    var iconSymbolName: String {
        switch self {
        case .local:
            return "desktopcomputer"
        case .remote:
            return "cloud"
        }
    }
}

enum RemoteASRProvider: String, CaseIterable {
    case openAICompatible = "OpenAI-Compatible"
    case aliyun = "Aliyun"
    case volcengine = "Volcengine"

    var backend: ASRBackend {
        switch self {
        case .openAICompatible:
            return .remoteOpenAICompatible
        case .aliyun:
            return .remoteAliyunASR
        case .volcengine:
            return .remoteVolcengineASR
        }
    }

    init?(backend: ASRBackend) {
        switch backend {
        case .remoteOpenAICompatible:
            self = .openAICompatible
        case .remoteAliyunASR:
            self = .aliyun
        case .remoteVolcengineASR:
            self = .volcengine
        case .appleSpeech:
            return nil
        }
    }
}
