import Foundation

typealias LLMRefinerConfiguration = LLMConfiguration

enum LLMRefinerError: LocalizedError, Equatable {
    case notConfigured
    case invalidBaseURL
    case invalidHTTPResponse
    case badStatusCode(Int, String?)
    case emptyResponse
    case invalidStructuredResponse

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
        case .invalidStructuredResponse:
            return "The API returned an invalid structured completion."
        }
    }
}

enum LLMRefinerPromptMode: Equatable {
    case refinement
    case translation
}

enum LLMRefinerOutputContract: Equatable {
    case plainText
    case jsonText
}

final class LLMRefiner {
    static let conservativeSystemPromptPrefix = """
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
    """

    static let conservativeSystemPromptSuffix = """
    8. Return only the final corrected text.
    9. Do not wrap the result in quotes, markdown, JSON, or explanations.

    Output the minimally edited version of the input.
    """

    static let translationSystemPromptPrefix = """
    You are translating automatic speech recognition output.

    Your behavior must be extremely conservative.

    Rules:
    1. Only fix obvious speech recognition mistakes before translating.
    2. Preserve the original meaning, tone, order, formatting intent, punctuation intent, and technical terms when they are already correct.
    3. Do not add explanations, markdown, JSON, quotes, or commentary.
    """

    static let structuredTranslationSystemPromptPrefix = """
    You are translating automatic speech recognition output.

    Your behavior must be extremely conservative.

    Rules:
    1. Only fix obvious speech recognition mistakes before translating.
    2. Preserve the original meaning, tone, order, formatting intent, punctuation intent, and technical terms when they are already correct.
    3. Do not add explanations, markdown, quotes, or commentary.
    """

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func refine(
        text: String,
        configuration: LLMRefinerConfiguration,
        mode: LLMRefinerPromptMode = .refinement,
        targetLanguage: SupportedLanguage? = nil
    ) async throws -> String {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return text }
        guard configuration.isConfigured else { throw LLMRefinerError.notConfigured }
        guard let baseURL = configuration.normalizedEndpoint else {
            throw LLMRefinerError.invalidBaseURL
        }

        let endpoint = Self.chatCompletionsEndpoint(from: baseURL)
        let outputContract = Self.outputContract(
            mode: mode,
            targetLanguage: targetLanguage,
            refinementPrompt: configuration.trimmedRefinementPrompt
        )

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
            responseFormat: outputContract.responseFormat,
            messages: [
                .init(
                    role: "system",
                    content: Self.systemPrompt(
                        mode: mode,
                        targetLanguage: targetLanguage,
                        refinementPrompt: configuration.trimmedRefinementPrompt
                    )
                ),
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

        let sanitized = try Self.sanitize(
            content: content,
            fallback: text,
            outputContract: outputContract
        )
        return sanitized.isEmpty ? text : sanitized
    }

    func testConnection(configuration: LLMRefinerConfiguration) async throws -> String {
        try await refine(
            text: "测试 Python 和 JSON mixed speech input",
            configuration: configuration,
            mode: .refinement,
            targetLanguage: nil
        )
    }

    static func systemPrompt(
        mode: LLMRefinerPromptMode,
        targetLanguage: SupportedLanguage?,
        refinementPrompt: String
    ) -> String {
        switch mode {
        case .refinement:
            return refinementSystemPrompt(
                targetLanguage: targetLanguage,
                refinementPrompt: refinementPrompt
            )
        case .translation:
            return translationSystemPrompt(targetLanguage: targetLanguage)
        }
    }

    private static func refinementSystemPrompt(
        targetLanguage: SupportedLanguage?,
        refinementPrompt: String
    ) -> String {
        let outputContract = outputContract(
            mode: .refinement,
            targetLanguage: targetLanguage,
            refinementPrompt: refinementPrompt
        )

        guard let targetLanguage else {
            return joinPromptSections(
                conservativeSystemPromptPrefix,
                customRefinementPromptSection(refinementPrompt),
                outputInstructions(
                    for: outputContract,
                    targetLanguage: nil
                )
            )
        }

        return joinPromptSections(
            outputContract == .jsonText ? structuredTranslationSystemPromptPrefix : translationSystemPromptPrefix,
            customRefinementPromptSection(refinementPrompt),
            outputInstructions(
                for: outputContract,
                targetLanguage: targetLanguage
            )
        )
    }

    private static func translationSystemPrompt(targetLanguage: SupportedLanguage?) -> String {
        guard let targetLanguage else {
            return joinPromptSections(
                conservativeSystemPromptPrefix,
                conservativeSystemPromptSuffix
            )
        }

        return joinPromptSections(
            translationSystemPromptPrefix,
            translationSystemPromptSuffix(targetLanguage: targetLanguage)
        )
    }

    private static func customRefinementPromptSection(_ refinementPrompt: String) -> String? {
        let trimmed = refinementPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return """
        Additional user requirements:
        \(trimmed)
        """
    }

    private static func outputContract(
        mode: LLMRefinerPromptMode,
        targetLanguage: SupportedLanguage?,
        refinementPrompt: String
    ) -> LLMRefinerOutputContract {
        guard mode == .refinement else {
            return .plainText
        }

        let normalized = refinementPrompt.lowercased()
        let requestsJSON = normalized.contains("json")
        let specifiesTextSchema = normalized.contains("\"text\"") || normalized.contains("`text`")
        let referencesSchema = normalized.contains("schema") || normalized.contains("valid json only")

        guard requestsJSON, specifiesTextSchema, referencesSchema else {
            return .plainText
        }

        _ = targetLanguage
        return .jsonText
    }

    private static func outputInstructions(
        for outputContract: LLMRefinerOutputContract,
        targetLanguage: SupportedLanguage?
    ) -> String {
        switch outputContract {
        case .plainText:
            if let targetLanguage {
                return translationSystemPromptSuffix(targetLanguage: targetLanguage)
            }
            return conservativeSystemPromptSuffix
        case .jsonText:
            if let targetLanguage {
                return jsonTranslationSystemPromptSuffix(targetLanguage: targetLanguage)
            }
            return jsonRefinementSystemPromptSuffix
        }
    }

    private static func translationSystemPromptSuffix(targetLanguage: SupportedLanguage) -> String {
        """
        4. Translate the entire final output into \(targetLanguage.recognitionDisplayName).
        5. If some parts are already in \(targetLanguage.recognitionDisplayName), keep them natural and consistent with the final translated output.
        6. Output only the final translated text in \(targetLanguage.recognitionDisplayName).
        """
    }

    private static let jsonRefinementSystemPromptSuffix = """
    8. Return valid JSON only.
    9. Use exactly this schema: { "text": string }.
    10. The `text` value must contain only the minimally edited final output.
    11. Do not include extra keys such as `input`, `target`, `source`, `language`, `summary`, or `notes`.
    """

    private static func jsonTranslationSystemPromptSuffix(targetLanguage: SupportedLanguage) -> String {
        """
        4. Translate the entire final output into \(targetLanguage.recognitionDisplayName).
        5. If some parts are already in \(targetLanguage.recognitionDisplayName), keep them natural and consistent with the final translated output.
        6. Return valid JSON only.
        7. Use exactly this schema: { "text": string }.
        8. The `text` value must contain only the final translated text in \(targetLanguage.recognitionDisplayName).
        9. Do not include source text, input text, target text, language labels, or extra keys such as `input`, `target`, `source`, `summary`, or `notes`.
        """
    }

    private static func joinPromptSections(_ sections: String?...) -> String {
        sections
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
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

    static func sanitize(
        content: String,
        fallback: String,
        outputContract: LLMRefinerOutputContract = .plainText
    ) throws -> String {
        var value = stripThinkBlocks(from: content)
            .trimmingCharacters(in: .whitespacesAndNewlines)

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

        if outputContract == .jsonText {
            throw LLMRefinerError.invalidStructuredResponse
        }

        return value
    }

    private static func stripThinkBlocks(from value: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: #"<think\b[^>]*>[\s\S]*?</think>"#,
            options: [.caseInsensitive]
        ) else {
            return value
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.stringByReplacingMatches(
            in: value,
            options: [],
            range: range,
            withTemplate: ""
        )
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
    struct ResponseFormat: Encodable {
        let type: String

        static let jsonObject = ResponseFormat(type: "json_object")
    }

    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let temperature: Double
    let responseFormat: ResponseFormat?
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case temperature
        case responseFormat = "response_format"
        case messages
    }
}

private extension LLMRefinerOutputContract {
    var responseFormat: ChatCompletionsRequest.ResponseFormat? {
        switch self {
        case .plainText:
            return nil
        case .jsonText:
            return .jsonObject
        }
    }
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
