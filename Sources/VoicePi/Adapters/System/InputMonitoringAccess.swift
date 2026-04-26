import CoreGraphics
import Foundation
import IOKit.hidsystem

enum InputMonitoringAccess {
    typealias CheckAccess = (IOHIDRequestType) -> IOHIDAccessType
    typealias PreflightAccess = () -> Bool
    typealias RequestAccess = (IOHIDRequestType) -> Bool

    static func authorizationState(
        preflightAccess: PreflightAccess = CGPreflightListenEventAccess,
        checkAccess: CheckAccess = IOHIDCheckAccess
    ) -> AuthorizationState {
        if preflightAccess() {
            return .granted
        }

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
        preflightAccess: PreflightAccess = CGPreflightListenEventAccess,
        requestAccess: RequestAccess = IOHIDRequestAccess
    ) -> Bool {
        preflightAccess() || requestAccess(kIOHIDRequestTypeListenEvent)
    }
}
