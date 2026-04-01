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
        configuration: RemoteASRConfiguration
    ) async throws -> String {
        guard configuration.isConfigured else {
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

        let endpoint = Self.transcriptionsEndpoint(from: baseURL)
        let boundary = "VoicePiBoundary-\(UUID().uuidString)"

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
            prompt: configuration.trimmedPrompt
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteASRClientError.invalidHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(RemoteASRErrorEnvelope.self, from: data)
            throw RemoteASRClientError.badStatusCode(
                httpResponse.statusCode,
                apiError?.error.message
            )
        }

        return try Self.parseTranscriptionResponse(data)
    }

    func testConnection(
        with configuration: RemoteASRConfiguration
    ) async throws -> String {
        guard configuration.isConfigured else {
            throw RemoteASRClientError.notConfigured
        }

        guard let baseURL = configuration.normalizedEndpoint else {
            throw RemoteASRClientError.invalidBaseURL
        }

        var request = URLRequest(url: Self.transcriptionsEndpoint(from: baseURL))
        request.httpMethod = "HEAD"
        request.timeoutInterval = 20
        request.setValue("Bearer \(configuration.trimmedAPIKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteASRClientError.invalidHTTPResponse
        }

        if [200, 401, 403, 404, 405].contains(httpResponse.statusCode) {
            return "Remote ASR endpoint responded with HTTP \(httpResponse.statusCode)."
        }

        throw RemoteASRClientError.badStatusCode(httpResponse.statusCode, nil)
    }

    static func transcriptionsEndpoint(from baseURL: URL) -> URL {
        let value = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if value.hasSuffix("/v1/audio/transcriptions") || value.hasSuffix("/audio/transcriptions") {
            return URL(string: value)!
        }

        if value.hasSuffix("/v1") {
            return URL(string: value + "/audio/transcriptions")!
        }

        return URL(string: value + "/v1/audio/transcriptions")!
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
        let message: String
    }

    let error: RemoteASRError
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
