import Foundation

extension Duration {
    var wholeMilliseconds: Int {
        let components = components
        let secondsMilliseconds = components.seconds * 1_000
        let attosecondsMilliseconds = components.attoseconds / 1_000_000_000_000_000
        return Int(secondsMilliseconds + attosecondsMilliseconds)
    }
}

struct TextInjectionTiming: Equatable {
    let inputSourceSwitchSettleDelay: Duration
    let clipboardSettleDelay: Duration
    let keyPressInterval: Duration
    let postPasteSettleDelay: Duration
    let clipboardRestoreDelay: Duration
    let restoreInputSourceSettleDelay: Duration

    static let `default` = TextInjectionTiming(
        inputSourceSwitchSettleDelay: .milliseconds(30),
        clipboardSettleDelay: .milliseconds(10),
        keyPressInterval: .milliseconds(8),
        postPasteSettleDelay: .milliseconds(60),
        clipboardRestoreDelay: .milliseconds(220),
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
        var total = timing.clipboardSettleDelay.wholeMilliseconds
            + timing.keyPressInterval.wholeMilliseconds
            + timing.postPasteSettleDelay.wholeMilliseconds

        if needsInputSourceSwitch {
            total += timing.inputSourceSwitchSettleDelay.wholeMilliseconds
            total += timing.restoreInputSourceSettleDelay.wholeMilliseconds
        }

        return total
    }
}
