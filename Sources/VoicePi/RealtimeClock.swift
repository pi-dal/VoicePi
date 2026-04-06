import Foundation

protocol RealtimeClock: Sendable {
    func sleep(seconds: Double) async throws
}

struct SystemRealtimeClock: RealtimeClock {
    func sleep(seconds: Double) async throws {
        let clamped = max(0, seconds)
        try await Task.sleep(nanoseconds: UInt64(clamped * 1_000_000_000))
    }
}
