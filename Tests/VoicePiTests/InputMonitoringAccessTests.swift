import IOKit.hidsystem
import Testing
@testable import VoicePi

struct InputMonitoringAccessTests {
    @Test
    func authorizationStateMapsGrantedDeniedAndUnknown() {
        #expect(
            InputMonitoringAccess.authorizationState(
                preflightAccess: { true },
                checkAccess: { _ in kIOHIDAccessTypeUnknown }
            ) == .granted
        )
        #expect(
            InputMonitoringAccess.authorizationState(
                preflightAccess: { false },
                checkAccess: { _ in kIOHIDAccessTypeDenied }
            ) == .denied
        )
        #expect(
            InputMonitoringAccess.authorizationState(
                preflightAccess: { false },
                checkAccess: { _ in kIOHIDAccessTypeUnknown }
            ) == .unknown
        )
    }

    @Test
    func requestIfNeededOnlyPromptsWhenPreflightFails() {
        var requested = false

        let granted = InputMonitoringAccess.requestIfNeeded(
            preflightAccess: { true },
            requestAccess: {
                requested = true
                return false
            }
        )
        #expect(granted)
        #expect(!requested)

        let prompted = InputMonitoringAccess.requestIfNeeded(
            preflightAccess: { false },
            requestAccess: {
                requested = true
                return true
            }
        )
        #expect(prompted)
        #expect(requested)
    }
}
