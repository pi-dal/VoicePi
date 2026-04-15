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
    func defaultPlanKeepsBlockingLatencyWellBelowLegacyFloorWithoutInputSourceSwitch() {
        let plan = TextInjectionExecutionPlan.make(
            needsInputSourceSwitch: false,
            timing: .default
        )

        #expect(plan.blockingLatencyMilliseconds < 150)
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
        #expect(switched.blockingLatencyMilliseconds < 180)
    }
}
