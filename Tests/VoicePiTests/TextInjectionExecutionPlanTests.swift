import Foundation
import Testing
@testable import VoicePi

struct TextInjectionExecutionPlanTests {
    @Test
    func durationMillisecondsUsesSharedRoundedConversion() {
        #expect(Duration.seconds(1.249).wholeMilliseconds == 1249)
        #expect(Duration.seconds(0.0004).wholeMilliseconds == 0)
    }

    @Test
    func defaultPlanTradesASmallAmountOfLatencyForASaferPasteWindowWithoutInputSourceSwitch() {
        let plan = TextInjectionExecutionPlan.make(
            needsInputSourceSwitch: false,
            timing: .default
        )

        #expect(plan.blockingLatencyMilliseconds >= 160)
        #expect(plan.blockingLatencyMilliseconds < 220)
    }

    @Test
    func switchingInputSourceAddsOnlySmallExtraBlockingLatency() {
        let baseline = TextInjectionExecutionPlan.make(
            needsInputSourceSwitch: false,
            timing: .default
        )
        let switched = TextInjectionExecutionPlan.make(
            needsInputSourceSwitch: true,
            timing: .default
        )

        #expect(switched.blockingLatencyMilliseconds > baseline.blockingLatencyMilliseconds)
        #expect(switched.blockingLatencyMilliseconds < 320)
    }

    @Test
    func defaultTimingKeepsClipboardAvailableLongerThanBlockingPasteWindow() {
        #expect(TextInjectionTiming.default.clipboardRestoreDelay.wholeMilliseconds >= 1_500)
        #expect(
            TextInjectionTiming.default.clipboardRestoreDelay.wholeMilliseconds
                > TextInjectionTiming.default.postPasteSettleDelay.wholeMilliseconds
        )
    }

    @Test
    func defaultTimingKeepsPrePasteReliabilityWindowsAboveMinimumFloors() {
        #expect(TextInjectionTiming.default.clipboardSettleDelay.wholeMilliseconds >= 50)
        #expect(TextInjectionTiming.default.keyPressInterval.wholeMilliseconds >= 20)
        #expect(TextInjectionTiming.default.postPasteSettleDelay.wholeMilliseconds >= 100)
    }

    @Test
    func defaultTimingKeepsCJKInputSourceSwitchingAboveMinimumFloors() {
        #expect(TextInjectionTiming.default.inputSourceSwitchSettleDelay.wholeMilliseconds >= 60)
        #expect(TextInjectionTiming.default.restoreInputSourceSettleDelay.wholeMilliseconds >= 40)
    }

    @Test
    func clipboardRestoreIsSkippedWhenClipboardChangedAfterInjection() {
        #expect(
            PasteboardRestoreDecision.shouldRestore(
                expectedInjectedChangeCount: 5,
                currentChangeCount: 5
            )
        )
        #expect(
            PasteboardRestoreDecision.shouldRestore(
                expectedInjectedChangeCount: 5,
                currentChangeCount: 6
            ) == false
        )
    }
}
