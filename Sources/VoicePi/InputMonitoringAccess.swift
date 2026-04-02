import Foundation
import IOKit.hidsystem

enum InputMonitoringAccess {
    typealias CheckAccess = (IOHIDRequestType) -> IOHIDAccessType
    typealias RequestAccess = (IOHIDRequestType) -> Bool

    static func authorizationState(
        checkAccess: CheckAccess = IOHIDCheckAccess
    ) -> AuthorizationState {
        switch checkAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return .granted
        case kIOHIDAccessTypeDenied:
            return .denied
        case kIOHIDAccessTypeUnknown:
            return .unknown
        default:
            return .unknown
        }
    }

    static func requestIfNeeded(
        checkAccess: CheckAccess = IOHIDCheckAccess,
        requestAccess: RequestAccess = IOHIDRequestAccess
    ) -> Bool {
        switch authorizationState(checkAccess: checkAccess) {
        case .granted:
            return true
        case .denied, .restricted:
            return false
        case .unknown:
            return requestAccess(kIOHIDRequestTypeListenEvent)
        }
    }
}
