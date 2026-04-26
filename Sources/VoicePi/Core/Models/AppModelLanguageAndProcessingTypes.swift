import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable, Codable {
    case simplifiedChinese = "zh-CN"
    case traditionalChinese = "zh-TW"
    case english = "en-US"
    case japanese = "ja-JP"
    case korean = "ko-KR"

    var id: String { rawValue }

    var localeIdentifier: String {
        rawValue
    }

    var menuTitle: String {
        switch self {
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        }
    }

    var recognitionDisplayName: String {
        switch self {
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .traditionalChinese:
            return "Traditional Chinese"
        case .english:
            return "English"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        }
    }

    static let `default`: SupportedLanguage = .simplifiedChinese
}

enum ASRBackend: String, CaseIterable, Identifiable, Codable {
    case appleSpeech
    case remoteOpenAICompatible
    case remoteAliyunASR
    case remoteVolcengineASR

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleSpeech:
            return "Apple Speech"
        case .remoteOpenAICompatible:
            return "Remote OpenAI-Compatible ASR"
        case .remoteAliyunASR:
            return "Aliyun ASR"
        case .remoteVolcengineASR:
            return "Volcengine ASR"
        }
    }

    var shortDescription: String {
        switch self {
        case .appleSpeech:
            return "Uses the built-in Apple Speech recognizer."
        case .remoteOpenAICompatible:
            return "Uploads recorded audio to an OpenAI-compatible remote transcription endpoint."
        case .remoteAliyunASR:
            return "Streams realtime audio to an Aliyun ASR WebSocket endpoint."
        case .remoteVolcengineASR:
            return "Streams realtime audio to a Volcengine ASR WebSocket endpoint."
        }
    }

    var isRemoteBackend: Bool {
        switch self {
        case .appleSpeech:
            return false
        case .remoteOpenAICompatible, .remoteAliyunASR, .remoteVolcengineASR:
            return true
        }
    }

    var remoteStatusText: String {
        switch self {
        case .appleSpeech:
            return "Apple Speech…"
        case .remoteOpenAICompatible:
            return "Remote ASR…"
        case .remoteAliyunASR:
            return "Aliyun ASR…"
        case .remoteVolcengineASR:
            return "Volcengine ASR…"
        }
    }

    var remoteBaseURLPlaceholder: String {
        switch self {
        case .appleSpeech, .remoteOpenAICompatible:
            return "https://api.example.com/v1"
        case .remoteAliyunASR:
            return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .remoteVolcengineASR:
            return "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"
        }
    }

    var remoteModelPlaceholder: String {
        switch self {
        case .appleSpeech, .remoteOpenAICompatible:
            return "gpt-4o-mini-transcribe"
        case .remoteAliyunASR:
            return "fun-asr-realtime"
        case .remoteVolcengineASR:
            return "bigmodel"
        }
    }

    var remoteAppIDPlaceholder: String {
        switch self {
        case .remoteVolcengineASR:
            return "1234567890"
        default:
            return ""
        }
    }

    static let `default`: ASRBackend = .appleSpeech

    var usesRealtimeStreaming: Bool {
        switch self {
        case .remoteAliyunASR, .remoteVolcengineASR:
            return true
        case .appleSpeech, .remoteOpenAICompatible:
            return false
        }
    }

    var speechRecorderMode: SpeechRecorderMode {
        switch self {
        case .appleSpeech:
            return .appleSpeechStreaming
        case .remoteOpenAICompatible, .remoteAliyunASR, .remoteVolcengineASR:
            return .captureOnly
        }
    }

    var recorderMode: SpeechRecorderMode {
        speechRecorderMode
    }
}

enum PostProcessingMode: String, CaseIterable, Identifiable, Codable {
    case disabled
    case refinement
    case translation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .refinement:
            return "Refinement"
        case .translation:
            return "Translate"
        }
    }

    var next: PostProcessingMode {
        switch self {
        case .disabled:
            return .refinement
        case .refinement:
            return .translation
        case .translation:
            return .disabled
        }
    }
}

enum TranslationProvider: String, CaseIterable, Identifiable, Codable {
    case appleTranslate
    case llm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleTranslate:
            return "Apple Translate"
        case .llm:
            return "LLM"
        }
    }

    static func availableProviders(appleTranslateSupported: Bool) -> [TranslationProvider] {
        appleTranslateSupported ? [.appleTranslate, .llm] : [.llm]
    }

    static func sanitized(
        _ selected: TranslationProvider,
        appleTranslateSupported: Bool
    ) -> TranslationProvider {
        let available = availableProviders(appleTranslateSupported: appleTranslateSupported)
        return available.contains(selected) ? selected : available[0]
    }

    static func displayProvider(
        mode: PostProcessingMode,
        storedProvider: TranslationProvider,
        appleTranslateSupported: Bool
    ) -> TranslationProvider {
        switch mode {
        case .refinement:
            return .llm
        case .translation:
            return sanitized(storedProvider, appleTranslateSupported: appleTranslateSupported)
        case .disabled:
            return sanitized(storedProvider, appleTranslateSupported: appleTranslateSupported)
        }
    }
}

enum RefinementProvider: String, CaseIterable, Identifiable, Codable {
    case llm
    case externalProcessor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .llm:
            return "LLM"
        case .externalProcessor:
            return "External Processor"
        }
    }
}

enum ExternalProcessorKind: String, CaseIterable, Identifiable, Codable {
    case almaCLI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .almaCLI:
            return "Alma CLI"
        }
    }
}

