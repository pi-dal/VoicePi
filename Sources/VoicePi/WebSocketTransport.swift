import Foundation

protocol WebSocketTransport: AnyObject {
    func sendText(_ text: String) async throws
    func sendBinary(_ data: Data) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(code: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

final class URLSessionWebSocketTransport: WebSocketTransport {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    func sendText(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func sendBinary(_ data: Data) async throws {
        try await task.send(.data(data))
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await task.receive()
    }

    func cancel(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        task.cancel(with: code, reason: reason)
    }
}

struct URLSessionWebSocketTransportFactory {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func makeTransport(request: URLRequest) -> WebSocketTransport {
        let task = session.webSocketTask(with: request)
        task.resume()
        return URLSessionWebSocketTransport(task: task)
    }
}
