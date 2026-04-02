import Foundation

struct LLMRefinerConfiguration: Codable, Equatable {
    var baseURL: String
    var apiKey: String
    var model: String

    init(
        baseURL: String = "",
        apiKey: String = "",
        model: String = ""
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
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

    var isConfigured: Bool {
        !trimmedBaseURL.isEmpty &&
        !trimmedAPIKey.isEmpty &&
        !trimmedModel.isEmpty
    }

    var normalizedBaseURL: URL? {
        let value = trimmedBaseURL
        guard !value.isEmpty else { return nil }

        if let direct = URL(string: value), direct.scheme != nil {
            return direct
        }

        return URL(string: "https://\(value)")
    }
}

enum LLMRefinerError: LocalizedError, Equatable {
    case notConfigured
    case invalidBaseURL
    case invalidHTTPResponse
    case badStatusCode(Int, String?)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LLM refinement is enabled but not fully configured."
        case .invalidBaseURL:
            return "The API Base URL is invalid."
        case .invalidHTTPResponse:
            return "The API returned an invalid response."
        case .badStatusCode(let code, let message):
            if let message, !message.isEmpty {
                return "The API request failed with status \(code): \(message)"
            }
            return "The API request failed with status \(code)."
        case .emptyResponse:
            return "The API returned an empty completion."
        }
    }
}

final class LLMRefiner {
    static let conservativeSystemPrompt = """
    You are refining automatic speech recognition output.

    Your behavior must be extremely conservative.

    Rules:
    1. Only fix obvious speech recognition mistakes.
    2. Never rewrite, polish, summarize, rephrase, translate, censor, or remove content that already appears correct.
    3. Preserve the original meaning, wording, tone, order, formatting intent, punctuation intent, and mixed-language structure.
    4. If the input already looks correct, return it exactly as-is.
    5. For mixed Chinese-English text, keep both languages intact.
    6. Only correct technical terms when the intended term is obvious, such as:
       - 配森 -> Python
       - 杰森 -> JSON
    7. Only correct Chinese homophone mistakes when confidence is very high.
    8. Return only the final corrected text.
    9. Do not wrap the result in quotes, markdown, JSON, or explanations.

    Output the minimally edited version of the input.
    """

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func refine(
        text: String,
        configuration: LLMRefinerConfiguration,
        targetLanguage: SupportedLanguage? = nil
    ) async throws -> String {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return text }
        guard configuration.isConfigured else { throw LLMRefinerError.notConfigured }
        guard let baseURL = configuration.normalizedBaseURL else {
            throw LLMRefinerError.invalidBaseURL
        }

        let endpoint = Self.chatCompletionsEndpoint(from: baseURL)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Bearer \(configuration.trimmedAPIKey)",
            forHTTPHeaderField: "Authorization"
        )

        let payload = ChatCompletionsRequest(
            model: configuration.trimmedModel,
            temperature: 0,
            messages: [
                .init(role: "system", content: Self.systemPrompt(targetLanguage: targetLanguage)),
                .init(role: "user", content: input)
            ]
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMRefinerError.invalidHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw LLMRefinerError.badStatusCode(
                httpResponse.statusCode,
                apiError?.error.message
            )
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw LLMRefinerError.emptyResponse
        }

        let sanitized = Self.sanitize(content: content, fallback: text)
        return sanitized.isEmpty ? text : sanitized
    }

    func testConnection(configuration: LLMRefinerConfiguration) async throws -> String {
        try await refine(
            text: "测试 Python 和 JSON mixed speech input",
            configuration: configuration,
            targetLanguage: nil
        )
    }

    static func systemPrompt(targetLanguage: SupportedLanguage?) -> String {
        guard let targetLanguage else {
            return conservativeSystemPrompt
        }

        return """
        \(conservativeSystemPrompt)

        Additional rule:
        10. Translate the final output into \(targetLanguage.recognitionDisplayName). Keep the meaning exact and stay just as conservative about corrections before translating.
        """
    }

    static func chatCompletionsEndpoint(from baseURL: URL) -> URL {
        let value = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if value.hasSuffix("/v1/chat/completions") || value.hasSuffix("/chat/completions") {
            return URL(string: value)!
        }

        if value.hasSuffix("/v1") {
            return URL(string: value + "/chat/completions")!
        }

        return URL(string: value + "/v1/chat/completions")!
    }

    static func sanitize(content: String, fallback: String) -> String {
        var value = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.hasPrefix("```") {
            value = stripCodeFence(value)
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.isEmpty {
            return fallback
        }

        if let wrapped = try? JSONDecoder().decode(StructuredTextResponse.self, from: Data(value.utf8)) {
            let candidate = wrapped.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return candidate.isEmpty ? fallback : candidate
        }

        return value
    }

    private static func stripCodeFence(_ value: String) -> String {
        var lines = value.components(separatedBy: .newlines)
        if lines.first?.hasPrefix("```") == true {
            lines.removeFirst()
        }
        if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }
}

private struct ChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let temperature: Double
    let messages: [Message]
}

private struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String?
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}

private struct StructuredTextResponse: Decodable {
    let text: String
}
