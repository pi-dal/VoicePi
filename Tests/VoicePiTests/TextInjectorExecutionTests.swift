import Foundation
import Testing
@testable import VoicePi

struct TextInjectorExecutionTests {
    @Test
    func runsCriticalInputSourceWorkOnMainThread() async throws {
        let isMainThread = try await TextInjector.performOnMainThread {
            Thread.isMainThread
        }

        #expect(isMainThread)
    }
}
