import Foundation
import Testing
@testable import VoicePi

struct TextInjectionExecutionPlanTests {
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
