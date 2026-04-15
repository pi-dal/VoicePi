import Foundation

struct PostInjectionLearningLoopPolicy: Equatable {
    let idlePollingInterval: Duration
    let suggestionCooldownInterval: Duration

    static let `default` = PostInjectionLearningLoopPolicy(
        idlePollingInterval: .milliseconds(600),
        suggestionCooldownInterval: .milliseconds(250)
    )
}
