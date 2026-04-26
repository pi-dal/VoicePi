import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import Foundation

struct RemoteASRConfiguration: Codable, Equatable {
    var baseURL: String
    var apiKey: String
    var model: String
    var prompt: String
    var volcengineAppID: String

    init(
        baseURL: String = "",
        apiKey: String = "",
        model: String = "",
        prompt: String = "",
        volcengineAppID: String = ""
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.prompt = prompt
        self.volcengineAppID = volcengineAppID
    }

    private enum CodingKeys: String, CodingKey {
        case baseURL
        case apiKey
        case model
        case prompt
        case volcengineAppID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        self.model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        self.prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        self.volcengineAppID = try container.decodeIfPresent(String.self, forKey: .volcengineAppID) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(apiKey, forKey: .apiKey)
        try container.encode(model, forKey: .model)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(volcengineAppID, forKey: .volcengineAppID)
    }

    var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func effectivePrompt(for backend: ASRBackend) -> String {
        let builtIn = Self.builtInPrompt(for: backend)
        let custom = trimmedPrompt

        if builtIn.isEmpty { return custom }
        if custom.isEmpty { return builtIn }

        return """
        \(builtIn)

        Additional user hints:
        \(custom)
        """
    }

    private static func builtInPrompt(for backend: ASRBackend) -> String {
        switch backend {
        case .remoteOpenAICompatible, .remoteAliyunASR, .remoteVolcengineASR:
            return """
            Built-in ASR bias rules:
            1. Keep transcription faithful, and only correct obvious recognition errors.
            2. Preserve mixed Chinese-English text, punctuation intent, and technical wording.
            3. When pronunciation is ambiguous, prefer common software terms and product names (for example: Python, JSON, JavaScript, TypeScript, OpenAI, GitHub, macOS, iOS, Aliyun, Volcengine).
            """
        case .appleSpeech:
            return ""
        }
    }

    var trimmedVolcengineAppID: String {
        volcengineAppID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isConfigured: Bool {
        !trimmedBaseURL.isEmpty &&
        !trimmedAPIKey.isEmpty &&
        !trimmedModel.isEmpty
    }

    func isConfigured(for backend: ASRBackend) -> Bool {
        switch backend {
        case .remoteVolcengineASR:
            return isConfigured && !trimmedVolcengineAppID.isEmpty
        case .remoteOpenAICompatible, .remoteAliyunASR:
            return isConfigured
        case .appleSpeech:
            return true
        }
    }

    var normalizedEndpoint: URL? {
        let raw = trimmedBaseURL
        guard !raw.isEmpty else { return nil }

        if let direct = URL(string: raw), direct.scheme != nil {
            return direct
        }

        return URL(string: "https://\(raw)")
    }

    var normalizedBaseURL: URL? {
        normalizedEndpoint
    }

    func validate() throws {
        guard isConfigured else {
            throw RemoteASRClientError.notConfigured
        }

        guard normalizedEndpoint != nil else {
            throw RemoteASRClientError.invalidBaseURL
        }
    }

    func validate(for backend: ASRBackend) throws {
        guard isConfigured(for: backend) else {
            throw RemoteASRClientError.notConfigured
        }

        guard normalizedEndpoint != nil else {
            throw RemoteASRClientError.invalidBaseURL
        }
    }
}

struct LLMConfiguration: Codable, Equatable {
    var baseURL: String
    var apiKey: String
    var model: String
    var refinementPrompt: String
    var enableThinking: Bool?

    init(
        baseURL: String = "",
        apiKey: String = "",
        model: String = "",
        refinementPrompt: String = "",
        enableThinking: Bool? = nil
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.refinementPrompt = refinementPrompt
        self.enableThinking = enableThinking
    }

    private enum CodingKeys: String, CodingKey {
        case baseURL
        case apiKey
        case model
        case refinementPrompt
        case enableThinking = "enable_thinking"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        refinementPrompt = try container.decodeIfPresent(String.self, forKey: .refinementPrompt) ?? ""
        enableThinking = try container.decodeIfPresent(Bool.self, forKey: .enableThinking)
    }

    var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedRefinementPrompt: String {
        refinementPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isConfigured: Bool {
        !trimmedBaseURL.isEmpty &&
        !trimmedAPIKey.isEmpty &&
        !trimmedModel.isEmpty
    }

    var normalizedEndpoint: URL? {
        let raw = trimmedBaseURL
        guard !raw.isEmpty else { return nil }

        if let direct = URL(string: raw), direct.scheme != nil {
            return direct
        }

        return URL(string: "https://\(raw)")
    }
}

enum OverlayPhase: Equatable {
    case hidden
    case recording
    case refining
}

struct OverlayState: Equatable {
    var phase: OverlayPhase
    var transcript: String
    var level: CGFloat

    init(
        phase: OverlayPhase = .hidden,
        transcript: String = "",
        level: CGFloat = 0
    ) {
        self.phase = phase
        self.transcript = transcript
        self.level = level
    }

    var isVisible: Bool {
        phase != .hidden
    }

    var statusText: String {
        switch phase {
        case .hidden:
            return ""
        case .recording:
            return transcript
        case .refining:
            return transcript.isEmpty ? "Refining..." : transcript
        }
    }
}

enum AuthorizationState: Equatable {
    case unknown
    case granted
    case denied
    case restricted
}

enum RecordingState: Equatable {
    case idle
    case recording
    case refining
}

enum AppErrorState: Equatable, Identifiable {
    case message(String)

    var id: String {
        switch self {
        case .message(let value):
            return value
        }
    }

    var text: String {
        switch self {
        case .message(let value):
            return value
        }
    }
}

