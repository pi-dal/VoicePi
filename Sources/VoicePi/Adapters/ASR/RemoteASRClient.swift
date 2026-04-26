import Foundation

enum RemoteASRClientError: LocalizedError, Equatable {
    case notConfigured
    case invalidBaseURL
    case invalidAudioFile
    case invalidHTTPResponse
    case badStatusCode(Int, String?)
    case emptyTranscription
    case unsupportedBackend

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Remote ASR is not fully configured."
        case .invalidBaseURL:
            return "The remote ASR API Base URL is invalid."
        case .invalidAudioFile:
            return "The recorded audio file could not be read."
        case .invalidHTTPResponse:
            return "The remote ASR API returned an invalid response."
        case .badStatusCode(let code, let message):
            if let message, !message.isEmpty {
                return "Remote ASR request failed with status \(code): \(message)"
            }
            return "Remote ASR request failed with status \(code)."
        case .emptyTranscription:
            return "The remote ASR API returned an empty transcription."
        case .unsupportedBackend:
            return "The selected ASR backend is not a remote backend."
        }
    }
}

final class RemoteASRClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func transcribe(
        audioFileURL: URL,
        language: SupportedLanguage,
        backend: ASRBackend,
        configuration: RemoteASRConfiguration
    ) async throws -> String {
        guard backend.isRemoteBackend else {
            throw RemoteASRClientError.unsupportedBackend
        }

        guard configuration.isConfigured(for: backend) else {
            throw RemoteASRClientError.notConfigured
        }

        guard let baseURL = configuration.normalizedEndpoint else {
            throw RemoteASRClientError.invalidBaseURL
        }

        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioFileURL)
        } catch {
            throw RemoteASRClientError.invalidAudioFile
        }

        let endpoints = Self.transcriptionsEndpoints(from: baseURL, backend: backend)
        let boundary = "VoicePiBoundary-\(UUID().uuidString)"
        var lastStatusCode: Int?
        var lastErrorMessage: String?

        for (index, endpoint) in endpoints.enumerated() {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 120
            request.setValue("Bearer \(configuration.trimmedAPIKey)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            request.httpBody = try Self.makeMultipartBody(
                boundary: boundary,
                fileData: audioData,
                fileURL: audioFileURL,
                model: configuration.trimmedModel,
                languageCode: language.remoteASRLanguageCode,
                prompt: configuration.effectivePrompt(for: backend)
            )

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RemoteASRClientError.invalidHTTPResponse
            }

            if (200...299).contains(httpResponse.statusCode) {
                return try Self.parseTranscriptionResponse(data)
            }

            let errorMessage = Self.parseAPIErrorMessage(from: data)
            lastStatusCode = httpResponse.statusCode
            lastErrorMessage = errorMessage

            let canRetryAliyun404 = backend == .remoteAliyunASR &&
                httpResponse.statusCode == 404 &&
                index < endpoints.count - 1
            if canRetryAliyun404 {
                continue
            }

            throw RemoteASRClientError.badStatusCode(httpResponse.statusCode, errorMessage)
        }

        throw RemoteASRClientError.badStatusCode(lastStatusCode ?? 404, lastErrorMessage)
    }

    func testConnection(
        backend: ASRBackend,
        with configuration: RemoteASRConfiguration
    ) async throws -> String {
        guard backend.isRemoteBackend else {
            throw RemoteASRClientError.unsupportedBackend
        }

        guard configuration.isConfigured(for: backend) else {
            throw RemoteASRClientError.notConfigured
        }

        guard let baseURL = configuration.normalizedEndpoint else {
            throw RemoteASRClientError.invalidBaseURL
        }

        if backend.usesRealtimeStreaming {
            let request = try Self.makeRealtimeProbeRequest(
                from: baseURL,
                backend: backend,
                configuration: configuration
            )
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RemoteASRClientError.invalidHTTPResponse
            }

            if Self.acceptedProbeStatusCodes(for: backend).contains(httpResponse.statusCode) {
                return "Remote ASR endpoint responded with HTTP \(httpResponse.statusCode)."
            }
            throw RemoteASRClientError.badStatusCode(httpResponse.statusCode, nil)
        }

        let endpoints = Self.transcriptionsEndpoints(from: baseURL, backend: backend)
        var lastRetryableStatus: Int?

        for (index, endpoint) in endpoints.enumerated() {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 20
            request.setValue("Bearer \(configuration.trimmedAPIKey)", forHTTPHeaderField: "Authorization")

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RemoteASRClientError.invalidHTTPResponse
            }

            if Self.acceptedProbeStatusCodes(for: backend).contains(httpResponse.statusCode) {
                let canRetryAliyun404 = backend == .remoteAliyunASR &&
                    httpResponse.statusCode == 404 &&
                    index < endpoints.count - 1
                if canRetryAliyun404 {
                    lastRetryableStatus = httpResponse.statusCode
                    continue
                }
                return "Remote ASR endpoint responded with HTTP \(httpResponse.statusCode)."
            }

            throw RemoteASRClientError.badStatusCode(httpResponse.statusCode, nil)
        }

        if let status = lastRetryableStatus {
            return "Remote ASR endpoint responded with HTTP \(status)."
        }

        throw RemoteASRClientError.badStatusCode(404, nil)
    }

    static func transcriptionsEndpoint(from baseURL: URL) -> URL {
        transcriptionsEndpoint(from: baseURL, backend: .remoteOpenAICompatible)
    }

    static func transcriptionsEndpoint(from baseURL: URL, backend: ASRBackend) -> URL {
        transcriptionsEndpoints(from: baseURL, backend: backend).first!
    }

    static func transcriptionsEndpoints(from baseURL: URL, backend: ASRBackend) -> [URL] {
        let value = normalizedBaseURL(baseURL)

        switch backend {
        case .appleSpeech, .remoteOpenAICompatible:
            return [openAICompatibleEndpoint(from: value)]
        case .remoteAliyunASR:
            return aliyunEndpoints(from: value)
        case .remoteVolcengineASR:
            return [volcengineEndpoint(from: value)]
        }
    }

    private static func normalizedBaseURL(_ baseURL: URL) -> String {
        baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func openAICompatibleEndpoint(from value: String) -> URL {
        if value.hasSuffix("/v1/audio/transcriptions") || value.hasSuffix("/audio/transcriptions") {
            return URL(string: value)!
        }

        if value.hasSuffix("/v1") {
            return URL(string: value + "/audio/transcriptions")!
        }

        return URL(string: value + "/v1/audio/transcriptions")!
    }

    private static func aliyunEndpoint(from value: String) -> URL {
        let normalizedSchemeValue = value.replacingOccurrences(
            of: #"^wss?://"#,
            with: "https://",
            options: .regularExpression
        )

        if normalizedSchemeValue.contains("/api-ws/v1/inference") {
            let compatibleModeBase = normalizedSchemeValue.replacingOccurrences(
                of: "/api-ws/v1/inference",
                with: "/compatible-mode/v1"
            )
            return aliyunEndpoint(from: compatibleModeBase)
        }

        if
            normalizedSchemeValue.hasSuffix("/compatible-mode/v1/audio/transcriptions") ||
            normalizedSchemeValue.hasSuffix("/api/v1/services/audio/asr/transcription") ||
            normalizedSchemeValue.hasSuffix("/v1/audio/transcriptions")
        {
            return URL(string: normalizedSchemeValue)!
        }

        if normalizedSchemeValue.hasSuffix("/compatible-mode/v1") {
            return URL(string: normalizedSchemeValue + "/audio/transcriptions")!
        }

        if normalizedSchemeValue.hasSuffix("/api/v1/services/audio/asr") {
            return URL(string: normalizedSchemeValue + "/transcription")!
        }

        if normalizedSchemeValue.hasSuffix("/api/v1") {
            return URL(string: normalizedSchemeValue + "/services/audio/asr/transcription")!
        }

        if normalizedSchemeValue.hasSuffix("/v1") {
            return URL(string: normalizedSchemeValue + "/audio/transcriptions")!
        }

        return URL(string: normalizedSchemeValue + "/compatible-mode/v1/audio/transcriptions")!
    }

    private static func aliyunEndpoints(from value: String) -> [URL] {
        let primary = aliyunEndpoint(from: value)
        var endpoints: [URL] = [primary]
        var seen = Set([primary.absoluteString])

        func append(_ rawURL: String?) {
            guard
                let rawURL,
                let parsed = URL(string: rawURL),
                !seen.contains(parsed.absoluteString)
            else {
                return
            }
            seen.insert(parsed.absoluteString)
            endpoints.append(parsed)
        }

        guard let origin = origin(from: primary.absoluteString) else {
            return endpoints
        }

        if primary.absoluteString.contains("/compatible-mode/v1/audio/transcriptions") {
            append("\(origin)/api/v1/services/audio/asr/transcription")
        } else if primary.absoluteString.contains("/api/v1/services/audio/asr/transcription") {
            append("\(origin)/compatible-mode/v1/audio/transcriptions")
        } else {
            append("\(origin)/compatible-mode/v1/audio/transcriptions")
            append("\(origin)/api/v1/services/audio/asr/transcription")
        }

        return endpoints
    }

    private static func origin(from value: String) -> String? {
        guard
            let components = URLComponents(string: value),
            let scheme = components.scheme,
            let host = components.host
        else {
            return nil
        }

        if let port = components.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    private static func volcengineEndpoint(from value: String) -> URL {
        if value.hasSuffix("/api/v3/audio/transcriptions") || value.hasSuffix("/audio/transcriptions") {
            return URL(string: value)!
        }

        if value.hasSuffix("/api/v3") {
            return URL(string: value + "/audio/transcriptions")!
        }

        return URL(string: value + "/api/v3/audio/transcriptions")!
    }

    private static func acceptedProbeStatusCodes(for backend: ASRBackend) -> Set<Int> {
        if backend.usesRealtimeStreaming {
            return [200, 400, 401, 403, 404, 405, 426]
        }
        return [200, 401, 403, 404, 405]
    }

    private static func makeRealtimeProbeRequest(
        from baseURL: URL,
        backend: ASRBackend,
        configuration: RemoteASRConfiguration
    ) throws -> URLRequest {
        let websocketURL: URL
        var headers: [String: String] = [:]

        switch backend {
        case .remoteAliyunASR:
            websocketURL = try AliyunRealtimeProtocol.normalizeWebSocketEndpoint(from: baseURL.absoluteString)
            headers = AliyunRealtimeProtocol.makeHandshakeHeaders(
                apiKey: configuration.trimmedAPIKey,
                workspace: nil
            )
        case .remoteVolcengineASR:
            websocketURL = try VolcengineRealtimeProtocol.normalizeWebSocketEndpoint(from: baseURL.absoluteString)
            headers = try VolcengineRealtimeProtocol.makeHandshakeHeaders(
                configuration: configuration,
                requestID: UUID().uuidString
            )
        case .appleSpeech, .remoteOpenAICompatible:
            throw RemoteASRClientError.unsupportedBackend
        }

        var request = URLRequest(url: try httpProbeURL(from: websocketURL))
        request.httpMethod = "HEAD"
        request.timeoutInterval = 20
        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }
        return request
    }

    private static func httpProbeURL(from websocketURL: URL) throws -> URL {
        guard var components = URLComponents(url: websocketURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased()
        else {
            throw RemoteASRClientError.invalidBaseURL
        }

        switch scheme {
        case "wss":
            components.scheme = "https"
        case "ws":
            components.scheme = "http"
        case "https", "http":
            break
        default:
            throw RemoteASRClientError.invalidBaseURL
        }

        guard let probeURL = components.url else {
            throw RemoteASRClientError.invalidBaseURL
        }
        return probeURL
    }

    static func makeMultipartBody(
        boundary: String,
        fileData: Data,
        fileURL: URL,
        model: String,
        languageCode: String,
        prompt: String
    ) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        func append(_ string: String) {
            body.append(Data(string.utf8))
        }

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"model\"\(lineBreak)\(lineBreak)")
        append("\(model)\(lineBreak)")

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"language\"\(lineBreak)\(lineBreak)")
        append("\(languageCode)\(lineBreak)")

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"response_format\"\(lineBreak)\(lineBreak)")
        append("json\(lineBreak)")

        if !prompt.isEmpty {
            append("--\(boundary)\(lineBreak)")
            append("Content-Disposition: form-data; name=\"prompt\"\(lineBreak)\(lineBreak)")
            append("\(prompt)\(lineBreak)")
        }

        let filename = fileURL.lastPathComponent.isEmpty ? "voicepi-audio.m4a" : fileURL.lastPathComponent
        let mimeType = mimeType(for: fileURL.pathExtension)

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(lineBreak)")
        append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
        body.append(fileData)
        append(lineBreak)

        append("--\(boundary)--\(lineBreak)")
        return body
    }

    static func parseTranscriptionResponse(_ data: Data) throws -> String {
        if let verbose = try? JSONDecoder().decode(RemoteASRVerboseResponse.self, from: data) {
            let text = verbose.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw RemoteASRClientError.emptyTranscription }
            return text
        }

        if let simple = try? JSONDecoder().decode(RemoteASRTextResponse.self, from: data) {
            let text = simple.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw RemoteASRClientError.emptyTranscription }
            return text
        }

        if let extracted = extractCandidateText(from: data) {
            return extracted
        }

        if
            let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty,
            raw.first != "{",
            raw.first != "["
        {
            return raw
        }

        throw RemoteASRClientError.emptyTranscription
    }

    private static func parseAPIErrorMessage(from data: Data) -> String? {
        if let envelope = try? JSONDecoder().decode(RemoteASRErrorEnvelope.self, from: data) {
            if
                let errorMessage = envelope.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
                !errorMessage.isEmpty
            {
                return errorMessage
            }
            if
                let envelopeMessage = envelope.message?.trimmingCharacters(in: .whitespacesAndNewlines),
                !envelopeMessage.isEmpty
            {
                return envelopeMessage
            }
        }

        return extractStringValue(
            from: (try? JSONSerialization.jsonObject(with: data)) as Any,
            keys: ["message", "msg", "error_message"]
        )
    }

    private static func extractCandidateText(from data: Data) -> String? {
        extractStringValue(
            from: (try? JSONSerialization.jsonObject(with: data)) as Any,
            keys: ["text", "transcript", "transcription"]
        )
    }

    private static func extractStringValue(from object: Any, keys: Set<String>) -> String? {
        switch object {
        case let value as String:
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed

        case let dictionary as [String: Any]:
            for key in keys {
                if let direct = dictionary[key] as? String {
                    let trimmed = direct.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }

            for value in dictionary.values {
                if let nested = extractStringValue(from: value, keys: keys) {
                    return nested
                }
            }
            return nil

        case let array as [Any]:
            for item in array {
                if let nested = extractStringValue(from: item, keys: keys) {
                    return nested
                }
            }
            return nil

        default:
            return nil
        }
    }

    private static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "m4a":
            return "audio/m4a"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "caf":
            return "audio/x-caf"
        case "mp4":
            return "audio/mp4"
        default:
            return "application/octet-stream"
        }
    }
}

private struct RemoteASRTextResponse: Decodable {
    let text: String
}

private struct RemoteASRVerboseResponse: Decodable {
    let text: String
}

private struct RemoteASRErrorEnvelope: Decodable {
    struct RemoteASRError: Decodable {
        let message: String?
    }

    let error: RemoteASRError?
    let message: String?
}

extension SupportedLanguage {
    var remoteASRLanguageCode: String {
        switch self {
        case .simplifiedChinese:
            return "zh"
        case .traditionalChinese:
            return "zh"
        case .english:
            return "en"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        }
    }
}
