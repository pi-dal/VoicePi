import Foundation

struct TextInjectionTiming: Equatable {
    let inputSourceSwitchSettleDelay: Duration
    let clipboardSettleDelay: Duration
    let keyPressInterval: Duration
    let postPasteSettleDelay: Duration
    let restoreInputSourceSettleDelay: Duration

    static let `default` = TextInjectionTiming(
        inputSourceSwitchSettleDelay: .milliseconds(30),
        clipboardSettleDelay: .milliseconds(10),
        keyPressInterval: .milliseconds(8),
        postPasteSettleDelay: .milliseconds(60),
        restoreInputSourceSettleDelay: .milliseconds(20)
    )
}

struct TextInjectionExecutionPlan: Equatable {
    let needsInputSourceSwitch: Bool
    let timing: TextInjectionTiming

    static func make(
        needsInputSourceSwitch: Bool,
        timing: TextInjectionTiming = .default
    ) -> TextInjectionExecutionPlan {
        TextInjectionExecutionPlan(
            needsInputSourceSwitch: needsInputSourceSwitch,
            timing: timing
        )
    }

    var blockingLatencyMilliseconds: Int {
        var total = durationMilliseconds(timing.clipboardSettleDelay)
            + durationMilliseconds(timing.keyPressInterval)
            + durationMilliseconds(timing.postPasteSettleDelay)

        if needsInputSourceSwitch {
            total += durationMilliseconds(timing.inputSourceSwitchSettleDelay)
            total += durationMilliseconds(timing.restoreInputSourceSettleDelay)
        }

        return total
    }

    private func durationMilliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        let secondsMilliseconds = components.seconds * 1_000
        let attosecondsMilliseconds = components.attoseconds / 1_000_000_000_000_000
        return Int(secondsMilliseconds + attosecondsMilliseconds)
    }
}
