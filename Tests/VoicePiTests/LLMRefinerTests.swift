import Foundation
import Testing
@testable import VoicePi

@Suite(.serialized)
struct LLMRefinerTests {
    @Test
    func endpointBuilderNormalizesBareHostAndVersionedPaths() {
        #expect(LLMRefiner.chatCompletionsEndpoint(from: URL(string: "https://api.example.com")!).absoluteString == "https://api.example.com/v1/chat/completions")
        #expect(LLMRefiner.chatCompletionsEndpoint(from: URL(string: "https://api.example.com/v1")!).absoluteString == "https://api.example.com/v1/chat/completions")
        #expect(LLMRefiner.chatCompletionsEndpoint(from: URL(string: "https://api.example.com/chat/completions")!).absoluteString == "https://api.example.com/chat/completions")
    }

    @Test
    func sanitizeStripsCodeFenceAndStructuredWrapper() {
        #expect(LLMRefiner.sanitize(content: "```json\n{\"text\":\" refined \"}\n```", fallback: "fallback") == "refined")
    }

    @Test
    func sanitizeFallsBackWhenContentIsEmpty() {
        #expect(LLMRefiner.sanitize(content: "   ", fallback: "fallback") == "fallback")
    }

    @Test
    func refineBuildsChatCompletionRequest() async throws {
        let (session, capturedRequests) = makeSession()
        let refiner = LLMRefiner(session: session)
        let configuration = LLMRefinerConfiguration(
            baseURL: "api.example.com/v1",
            apiKey: "sk-test",
            model: "gpt-test"
        )

        LLMTestURLProtocol.shared.setHandler { request in
            capturedRequests.append(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = #"{"choices":[{"message":{"role":"assistant","content":"refined output"}}]}"#.data(using: .utf8)!
            return (response, data)
        }
        defer { LLMTestURLProtocol.shared.reset() }

        let result = try await refiner.refine(text: "raw input", configuration: configuration, targetLanguage: nil)

        #expect(result == "refined output")
        #expect(capturedRequests.snapshot.count == 1)

        let request = try #require(capturedRequests.snapshot.first)
        #expect(request.url?.absoluteString == "https://api.example.com/v1/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")

        let body = try #require(requestBody(from: request))
        let payload = try JSONDecoder().decode(LLMRefinerRequestPayload.self, from: body)
        #expect(payload.model == "gpt-test")
        #expect(payload.messages.count == 2)
        #expect(payload.messages[0].content.contains("Never rewrite, polish, summarize, rephrase, translate") == true)
        #expect(payload.messages[1].content == "raw input")
    }

    @Test
    func refineAddsTargetLanguageInstructionWhenRequested() async throws {
        let (session, capturedRequests) = makeSession()
        let refiner = LLMRefiner(session: session)
        let configuration = LLMRefinerConfiguration(
            baseURL: "https://api.example.com",
            apiKey: "sk-test",
            model: "gpt-test"
        )

        LLMTestURLProtocol.shared.setHandler { request in
            capturedRequests.append(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = #"{"choices":[{"message":{"role":"assistant","content":"translated output"}}]}"#.data(using: .utf8)!
            return (response, data)
        }
        defer { LLMTestURLProtocol.shared.reset() }

        let result = try await refiner.refine(
            text: "raw input",
            configuration: configuration,
            targetLanguage: .japanese
        )

        #expect(result == "translated output")

        let request = try #require(capturedRequests.snapshot.first)
        let body = try #require(requestBody(from: request))
        let payload = try JSONDecoder().decode(LLMRefinerRequestPayload.self, from: body)
        #expect(payload.messages[0].content.contains("Translate the final output into Japanese.") == true)
    }

    @Test
    func refineSurfacesAPIErrorMessage() async {
        let (session, _) = makeSession()
        let refiner = LLMRefiner(session: session)
        let configuration = LLMRefinerConfiguration(
            baseURL: "https://api.example.com",
            apiKey: "sk-test",
            model: "gpt-test"
        )

        LLMTestURLProtocol.shared.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = #"{"error":{"message":"bad token"}}"#.data(using: .utf8)!
            return (response, data)
        }
        defer { LLMTestURLProtocol.shared.reset() }

        await #expect(throws: LLMRefinerError.badStatusCode(401, "bad token")) {
            try await refiner.refine(text: "raw", configuration: configuration, targetLanguage: nil)
        }
    }

    private func makeSession() -> (URLSession, RequestCapture) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LLMTestURLProtocol.self]
        return (URLSession(configuration: configuration), RequestCapture())
    }

    private func requestBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 {
                break
            }
            data.append(buffer, count: read)
        }

        return data
    }
}

private final class LLMTestURLProtocol: URLProtocol, @unchecked Sendable {
    static let shared = LLMTestURLProtocol()

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
        LLMTestURLProtocol.shared.lock.lock()
        handler = LLMTestURLProtocol.shared.handler
        LLMTestURLProtocol.shared.lock.unlock()

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

private struct LLMRefinerRequestPayload: Decodable {
    struct Message: Decodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
}
