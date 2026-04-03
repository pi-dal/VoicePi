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
        var requestedType: IOHIDRequestType?

        let granted = InputMonitoringAccess.requestIfNeeded(
            preflightAccess: { true },
            requestAccess: { requestType in
                requested = true
                requestedType = requestType
                return false
            }
        )
        #expect(granted)
        #expect(!requested)
        #expect(requestedType == nil)

        let prompted = InputMonitoringAccess.requestIfNeeded(
            preflightAccess: { false },
            requestAccess: { requestType in
                requested = true
                requestedType = requestType
                return true
            }
        )
        #expect(prompted)
        #expect(requested)
        #expect(requestedType == kIOHIDRequestTypeListenEvent)
    }
}
