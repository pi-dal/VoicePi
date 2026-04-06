import Foundation
import Testing
@testable import VoicePi

@Suite(.serialized)
struct RemoteASRClientTests {
    @Test
    func transcriptionsEndpointNormalizesBareHostAndVersionedPaths() {
        #expect(RemoteASRClient.transcriptionsEndpoint(from: URL(string: "https://api.example.com")!).absoluteString == "https://api.example.com/v1/audio/transcriptions")
        #expect(RemoteASRClient.transcriptionsEndpoint(from: URL(string: "https://api.example.com/v1")!).absoluteString == "https://api.example.com/v1/audio/transcriptions")
        #expect(RemoteASRClient.transcriptionsEndpoint(from: URL(string: "https://api.example.com/audio/transcriptions")!).absoluteString == "https://api.example.com/audio/transcriptions")
        #expect(
            RemoteASRClient.transcriptionsEndpoint(
                from: URL(string: "https://dashscope.aliyuncs.com")!,
                backend: .remoteAliyunASR
            ).absoluteString == "https://dashscope.aliyuncs.com/compatible-mode/v1/audio/transcriptions"
        )
        #expect(
            RemoteASRClient.transcriptionsEndpoint(
                from: URL(string: "https://dashscope.aliyuncs.com/api/v1")!,
                backend: .remoteAliyunASR
            ).absoluteString == "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription"
        )
        #expect(
            RemoteASRClient.transcriptionsEndpoint(
                from: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!,
                backend: .remoteAliyunASR
            ).absoluteString == "https://dashscope.aliyuncs.com/compatible-mode/v1/audio/transcriptions"
        )
        #expect(
            RemoteASRClient.transcriptionsEndpoint(
                from: URL(string: "wss://dashscope.aliyuncs.com/api-ws/v1/inference")!,
                backend: .remoteAliyunASR
            ).absoluteString == "https://dashscope.aliyuncs.com/compatible-mode/v1/audio/transcriptions"
        )
        #expect(
            RemoteASRClient.transcriptionsEndpoint(
                from: URL(string: "https://ark.cn-beijing.volces.com/api/v3")!,
                backend: .remoteVolcengineASR
            ).absoluteString == "https://ark.cn-beijing.volces.com/api/v3/audio/transcriptions"
        )
    }

    @Test
    func aliyunEndpointsIncludeCompatibleAndServiceFallbacks() {
        #expect(
            RemoteASRClient.transcriptionsEndpoints(
                from: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!,
                backend: .remoteAliyunASR
            ).map(\.absoluteString) == [
                "https://dashscope.aliyuncs.com/compatible-mode/v1/audio/transcriptions",
                "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription"
            ]
        )

        #expect(
            RemoteASRClient.transcriptionsEndpoints(
                from: URL(string: "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription")!,
                backend: .remoteAliyunASR
            ).map(\.absoluteString) == [
                "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription",
                "https://dashscope.aliyuncs.com/compatible-mode/v1/audio/transcriptions"
            ]
        )
    }

    @Test
    func multipartBodyIncludesRequiredFieldsAndOptionalPrompt() throws {
        let body = try RemoteASRClient.makeMultipartBody(
            boundary: "VoicePiBoundary",
            fileData: Data("audio".utf8),
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            model: "whisper-test",
            languageCode: "en",
            prompt: "Prefer punctuation"
        )

        let text = String(decoding: body, as: UTF8.self)
        #expect(text.contains("name=\"model\""))
        #expect(text.contains("whisper-test"))
        #expect(text.contains("name=\"language\""))
        #expect(text.contains("en"))
        #expect(text.contains("name=\"prompt\""))
        #expect(text.contains("Prefer punctuation"))
        #expect(text.contains("filename=\"test.m4a\""))
        #expect(text.contains("Content-Type: audio/m4a"))
    }

    @Test
    func multipartBodyOmitsPromptWhenEmpty() throws {
        let body = try RemoteASRClient.makeMultipartBody(
            boundary: "VoicePiBoundary",
            fileData: Data("audio".utf8),
            fileURL: URL(fileURLWithPath: "/tmp/test.wav"),
            model: "whisper-test",
            languageCode: "zh",
            prompt: ""
        )

        let text = String(decoding: body, as: UTF8.self)
        #expect(text.contains("name=\"prompt\"") == false)
        #expect(text.contains("Content-Type: audio/wav"))
    }

    @Test
    func parseResponseAcceptsJsonAndRawText() throws {
        let json = #"{"text":" hello "}"#.data(using: .utf8)!
        #expect(try RemoteASRClient.parseTranscriptionResponse(json) == "hello")

        let nested = #"{"output":{"transcription":" nested "}}"#.data(using: .utf8)!
        #expect(try RemoteASRClient.parseTranscriptionResponse(nested) == "nested")

        let raw = Data("direct text".utf8)
        #expect(try RemoteASRClient.parseTranscriptionResponse(raw) == "direct text")
    }

    @Test
    func parseResponseRejectsEmptyPayload() {
        #expect(throws: RemoteASRClientError.emptyTranscription) {
            _ = try RemoteASRClient.parseTranscriptionResponse(#"{"text":"   "}"#.data(using: .utf8)!)
        }
    }

    @Test
    func transcribeBuildsMultipartRequestAndParsesResponse() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteASRTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = RemoteASRClient(session: session)

        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("voicepi-remote-asr-test.m4a")
        try Data("audio".utf8).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let capturedRequests = RequestCapture()
        RemoteASRTestURLProtocol.shared.setHandler { request in
            capturedRequests.append(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = #"{"text":"transcribed"}"#.data(using: .utf8)!
            return (response, data)
        }
        defer { RemoteASRTestURLProtocol.shared.reset() }

        let result = try await client.transcribe(
            audioFileURL: audioURL,
            language: .english,
            backend: .remoteOpenAICompatible,
            configuration: RemoteASRConfiguration(
                baseURL: "api.example.com/v1",
                apiKey: "sk-test",
                model: "whisper-large",
                prompt: ""
            )
        )

        #expect(result == "transcribed")
        let request = try #require(capturedRequests.snapshot.first)
        #expect(request.url?.absoluteString == "https://api.example.com/v1/audio/transcriptions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data; boundary=") == true)
    }

    @Test
    func testConnectionNormalizesAliyunRealtimeWSSBaseURL() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteASRTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = RemoteASRClient(session: session)

        let capturedRequests = RequestCapture()
        RemoteASRTestURLProtocol.shared.setHandler { request in
            capturedRequests.append(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 405,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        defer { RemoteASRTestURLProtocol.shared.reset() }

        let result = try await client.testConnection(
            backend: .remoteAliyunASR,
            with: .init(
                baseURL: "wss://dashscope.aliyuncs.com/compatible-mode/v1",
                apiKey: "sk-test",
                model: "fun-asr-realtime",
                prompt: ""
            )
        )

        #expect(result == "Remote ASR endpoint responded with HTTP 405.")
        let request = try #require(capturedRequests.snapshot.first)
        #expect(request.httpMethod == "HEAD")
        #expect(request.url?.absoluteString == "https://dashscope.aliyuncs.com/api-ws/v1/inference")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "bearer sk-test")
    }

    @Test
    func testConnectionNormalizesVolcengineRealtimeWSSBaseURL() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteASRTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = RemoteASRClient(session: session)

        let capturedRequests = RequestCapture()
        RemoteASRTestURLProtocol.shared.setHandler { request in
            capturedRequests.append(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        defer { RemoteASRTestURLProtocol.shared.reset() }

        let result = try await client.testConnection(
            backend: .remoteVolcengineASR,
            with: .init(
                baseURL: "wss://openspeech.bytedance.com/api/v3/audio/transcriptions",
                apiKey: "ak-test",
                model: "bigmodel",
                prompt: "",
                volcengineAppID: "app-test"
            )
        )

        #expect(result == "Remote ASR endpoint responded with HTTP 401.")
        let request = try #require(capturedRequests.snapshot.first)
        #expect(request.httpMethod == "HEAD")
        #expect(request.url?.absoluteString == "https://openspeech.bytedance.com/api/v3/sauc/bigmodel")
        #expect(request.value(forHTTPHeaderField: "X-Api-App-Key") == "app-test")
        #expect(request.value(forHTTPHeaderField: "X-Api-Access-Key") == "ak-test")
        #expect(request.value(forHTTPHeaderField: "X-Api-Resource-Id") == "bigmodel")
    }

    @Test
    func transcribeRejectsLocalAppleSpeechBackend() async {
        let client = RemoteASRClient(session: .shared)
        let configuration = RemoteASRConfiguration(
            baseURL: "https://api.example.com",
            apiKey: "sk-test",
            model: "whisper"
        )

        await #expect(throws: RemoteASRClientError.unsupportedBackend) {
            _ = try await client.transcribe(
                audioFileURL: URL(fileURLWithPath: "/tmp/voicepi-audio.m4a"),
                language: .english,
                backend: .appleSpeech,
                configuration: configuration
            )
        }
    }
}

private final class RemoteASRTestURLProtocol: URLProtocol, @unchecked Sendable {
    static let shared = RemoteASRTestURLProtocol()

    private let lock = NSLock()
    private var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    func setHandler(
        _ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func reset() {
        lock.lock()
        handler = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
        RemoteASRTestURLProtocol.shared.lock.lock()
        handler = RemoteASRTestURLProtocol.shared.handler
        RemoteASRTestURLProtocol.shared.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
