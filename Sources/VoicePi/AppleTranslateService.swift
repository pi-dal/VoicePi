import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(Translation)
import Translation
#endif

enum AppleTranslateServiceError: LocalizedError, Equatable {
    case unsupported
    case modelsNotInstalled
    case busy

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Apple Translate is not available on this macOS version."
        case .modelsNotInstalled:
            return "Apple Translate requires the language pair to be downloaded first in System Settings > General > Language & Region > Translation Languages."
        case .busy:
            return "Apple Translate is already handling another request."
        }
    }
}

final class AppleTranslateService: TranscriptTranslating {
    static var isSupported: Bool {
        isSupported(operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion)
    }

    static func isSupported(operatingSystemVersion: OperatingSystemVersion) -> Bool {
        guard canUseTranslationFramework else {
            return false
        }

        return operatingSystemVersion.majorVersion >= 15
    }

#if canImport(Translation)
    @available(macOS 15.0, *)
    static func canTranslateImmediately(for status: LanguageAvailability.Status) -> Bool {
        switch status {
        case .installed:
            return true
        case .supported:
            return false
        case .unsupported:
            return false
        @unknown default:
            return false
        }
    }
#endif

    func translate(
        text: String,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage
    ) async throws -> String {
#if canImport(AppKit) && canImport(SwiftUI) && canImport(Translation)
        guard Self.isSupported else {
            throw AppleTranslateServiceError.unsupported
        }

        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            return text
        }

        guard #available(macOS 15.0, *) else {
            throw AppleTranslateServiceError.unsupported
        }

        let source = sourceLanguage.translationLocaleLanguage
        let target = targetLanguage.translationLocaleLanguage
        let availability = LanguageAvailability()
        let status = await availability.status(from: source, to: target)

        guard Self.canTranslateImmediately(for: status) else {
            throw AppleTranslateServiceError.modelsNotInstalled
        }

        let translated = try await AppleTranslationBridge.shared.translate(
            text: input,
            source: source,
            target: target
        )
        let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? text : trimmed
#else
        throw AppleTranslateServiceError.unsupported
#endif
    }

#if canImport(AppKit) && canImport(SwiftUI) && canImport(Translation)
    private static let canUseTranslationFramework = true
#else
    private static let canUseTranslationFramework = false
#endif
}

private extension SupportedLanguage {
    var translationLocaleLanguage: Locale.Language {
        Locale.Language(identifier: rawValue)
    }
}

#if canImport(AppKit) && canImport(SwiftUI) && canImport(Translation)
@available(macOS 15.0, *)
@MainActor
private final class AppleTranslationBridge {
    static let shared = AppleTranslationBridge()

    private let driver = AppleTranslationDriver()
    private let hostingController: NSHostingController<AppleTranslationHostView>
    private let window: NSWindow

    private init() {
        let hostView = AppleTranslationHostView(driver: driver)
        hostingController = NSHostingController(rootView: hostView)
        _ = hostingController.view

        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.setContentSize(NSSize(width: 1, height: 1))
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFrontRegardless()
        self.window = window
    }

    func translate(
        text: String,
        source: Locale.Language,
        target: Locale.Language
    ) async throws -> String {
        try await driver.translate(
            text: text,
            source: source,
            target: target
        )
    }
}

@available(macOS 15.0, *)
@MainActor
private final class AppleTranslationDriver: ObservableObject {
    struct Request {
        let id: UUID
        let text: String
        let source: Locale.Language
        let target: Locale.Language
    }

    @Published var configuration: TranslationSession.Configuration?

    private var pendingRequest: Request?
    private var continuation: CheckedContinuation<String, Error>?

    func translate(
        text: String,
        source: Locale.Language,
        target: Locale.Language
    ) async throws -> String {
        guard continuation == nil else {
            throw AppleTranslateServiceError.busy
        }

        let request = Request(
            id: UUID(),
            text: text,
            source: source,
            target: target
        )
        pendingRequest = request

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            if let configuration,
               configuration.source == source,
               configuration.target == target {
                var updated = configuration
                updated.invalidate()
                self.configuration = updated
            } else {
                self.configuration = .init(source: source, target: target)
            }
        }
    }

    func performTranslation(using session: TranslationSession) async {
        guard let request = pendingRequest else {
            return
        }

        do {
            let response = try await session.translate(request.text)
            complete(requestID: request.id, result: .success(response.targetText))
        } catch {
            complete(requestID: request.id, result: .failure(error))
        }
    }

    private func complete(
        requestID: UUID,
        result: Result<String, Error>
    ) {
        guard pendingRequest?.id == requestID else {
            return
        }

        pendingRequest = nil
        configuration = nil

        let continuation = self.continuation
        self.continuation = nil

        switch result {
        case .success(let text):
            continuation?.resume(returning: text)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}

@available(macOS 15.0, *)
private struct AppleTranslationHostView: View {
    @ObservedObject var driver: AppleTranslationDriver

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(driver.configuration) { session in
                await driver.performTranslation(using: session)
            }
    }
}
#endif
