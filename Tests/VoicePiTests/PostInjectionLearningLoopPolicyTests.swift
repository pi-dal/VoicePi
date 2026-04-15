import Foundation
import Testing
@testable import VoicePi

struct PostInjectionLearningLoopPolicyTests {
    @Test
    func defaultPolicyUsesRelaxedPollingInterval() {
        #expect(PostInjectionLearningLoopPolicy.default.idlePollingInterval == .milliseconds(600))
        #expect(PostInjectionLearningLoopPolicy.default.suggestionCooldownInterval == .milliseconds(250))
    }
}
