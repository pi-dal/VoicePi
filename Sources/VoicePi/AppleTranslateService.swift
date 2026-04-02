import Foundation

enum AppleTranslateServiceError: LocalizedError, Equatable {
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Apple Translate is not available in this build yet."
        }
    }
}

final class AppleTranslateService: TranscriptTranslating {
    static var isSupported: Bool {
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }

    func translate(
        text: String,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage
    ) async throws -> String {
        throw AppleTranslateServiceError.unsupported
    }
}
