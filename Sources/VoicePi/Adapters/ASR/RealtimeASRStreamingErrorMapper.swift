import Foundation

enum RealtimeASRStreamingErrorMapper {
    static func mapConnectError(_ error: Error) -> RemoteASRStreamingError {
        if let asrError = error as? RemoteASRStreamingError {
            return asrError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            switch code {
            case .userAuthenticationRequired, .userCancelledAuthentication:
                return .authenticationFailed
            case .cancelled:
                return .cancelled
            default:
                return .connectFailed(nsError.localizedDescription)
            }
        }

        let lowered = error.localizedDescription.lowercased()
        if lowered.contains("401")
            || lowered.contains("403")
            || lowered.contains("unauthorized")
            || lowered.contains("forbidden")
        {
            return .authenticationFailed
        }

        return .connectFailed(error.localizedDescription)
    }
}
