import Foundation

final class RequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }

    var snapshot: [URLRequest] {
        lock.lock()
        let current = requests
        lock.unlock()
        return current
    }
}
