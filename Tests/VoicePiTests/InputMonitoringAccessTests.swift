import IOKit.hidsystem
import Testing
@testable import VoicePi

struct InputMonitoringAccessTests {
    @Test
    func authorizationStateMapsGrantedDeniedAndUnknown() {
        #expect(
            InputMonitoringAccess.authorizationState(checkAccess: { _ in kIOHIDAccessTypeGranted }) == .granted
        )
        #expect(
            InputMonitoringAccess.authorizationState(checkAccess: { _ in kIOHIDAccessTypeDenied }) == .denied
        )
        #expect(
            InputMonitoringAccess.authorizationState(checkAccess: { _ in kIOHIDAccessTypeUnknown }) == .unknown
        )
    }

    @Test
    func requestIfNeededOnlyPromptsWhenStateIsUnknown() {
        var requested = false

        let granted = InputMonitoringAccess.requestIfNeeded(
            checkAccess: { _ in kIOHIDAccessTypeGranted },
            requestAccess: { _ in
                requested = true
                return false
            }
        )
        #expect(granted)
        #expect(!requested)

        let denied = InputMonitoringAccess.requestIfNeeded(
            checkAccess: { _ in kIOHIDAccessTypeDenied },
            requestAccess: { _ in
                requested = true
                return true
            }
        )
        #expect(!denied)
        #expect(!requested)

        let unknown = InputMonitoringAccess.requestIfNeeded(
            checkAccess: { _ in kIOHIDAccessTypeUnknown },
            requestAccess: { requestType in
                requested = true
                return requestType == kIOHIDRequestTypeListenEvent
            }
        )
        #expect(unknown)
        #expect(requested)
    }
}
