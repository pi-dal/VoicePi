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
    struct TranslationSegment: Equatable {
        let text: String
        let separatorAfter: String
    }

    static var isSupported: Bool {
        isSupported(operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion)
    }

    static func translationSegments(
        for text: String,
        maxSegmentLength: Int = 1_200
    ) -> [TranslationSegment] {
        let segmentLength = max(1, maxSegmentLength)
        let paragraphUnits = translationUnits(in: text, option: .byParagraphs)
        return packedSegments(from: paragraphUnits, maxSegmentLength: segmentLength)
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
            segments: Self.translationSegments(for: input),
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

    private struct TranslationUnit {
        let text: String
        let separatorAfter: String
    }

    private static func packedSegments(
        from units: [TranslationUnit],
        maxSegmentLength: Int
    ) -> [TranslationSegment] {
        guard !units.isEmpty else {
            return []
        }

        var segments: [TranslationSegment] = []
        var currentText = ""
        var currentSeparator = ""

        for unit in units {
            guard !unit.text.isEmpty else {
                currentSeparator += unit.separatorAfter
                continue
            }

            if unit.text.count > maxSegmentLength {
                if !currentText.isEmpty {
                    segments.append(.init(text: currentText, separatorAfter: currentSeparator))
                    currentText = ""
                    currentSeparator = ""
                }
                segments.append(contentsOf: splitOversizedUnit(unit, maxSegmentLength: maxSegmentLength))
                continue
            }

            if currentText.isEmpty {
                currentText = unit.text
                currentSeparator = unit.separatorAfter
                continue
            }

            let candidateText = currentText + currentSeparator + unit.text
            if candidateText.count <= maxSegmentLength {
                currentText = candidateText
                currentSeparator = unit.separatorAfter
            } else {
                segments.append(.init(text: currentText, separatorAfter: currentSeparator))
                currentText = unit.text
                currentSeparator = unit.separatorAfter
            }
        }

        if !currentText.isEmpty {
            segments.append(.init(text: currentText, separatorAfter: currentSeparator))
        }

        return segments
    }

    private static func splitOversizedUnit(
        _ unit: TranslationUnit,
        maxSegmentLength: Int
    ) -> [TranslationSegment] {
        let sentenceUnits = translationUnits(in: unit.text, option: .bySentences)
        if sentenceUnits.count > 1 {
            var segments = packedSegments(from: sentenceUnits, maxSegmentLength: maxSegmentLength)
            guard !segments.isEmpty else {
                return [.init(text: unit.text, separatorAfter: unit.separatorAfter)]
            }

            let lastIndex = segments.index(before: segments.endIndex)
            segments[lastIndex] = .init(
                text: segments[lastIndex].text,
                separatorAfter: unit.separatorAfter
            )
            return segments
        }

        return hardWrappedSegments(for: unit, maxSegmentLength: maxSegmentLength)
    }

    private static func hardWrappedSegments(
        for unit: TranslationUnit,
        maxSegmentLength: Int
    ) -> [TranslationSegment] {
        let characters = Array(unit.text)
        guard !characters.isEmpty else {
            return [.init(text: "", separatorAfter: unit.separatorAfter)]
        }

        var segments: [TranslationSegment] = []
        var cursor = 0

        while cursor < characters.count {
            let remaining = characters.count - cursor
            if remaining <= maxSegmentLength {
                segments.append(
                    .init(
                        text: String(characters[cursor..<characters.count]),
                        separatorAfter: unit.separatorAfter
                    )
                )
                break
            }

            let searchEnd = min(cursor + maxSegmentLength, characters.count)
            var whitespaceIndex: Int?
            var index = searchEnd - 1
            while index >= cursor {
                if characters[index].isWhitespace {
                    whitespaceIndex = index
                    break
                }
                index -= 1
            }

            if let whitespaceIndex, whitespaceIndex > cursor {
                let chunk = String(characters[cursor..<whitespaceIndex])
                var nextCursor = whitespaceIndex
                var separator = ""
                while nextCursor < characters.count, characters[nextCursor].isWhitespace {
                    separator.append(characters[nextCursor])
                    nextCursor += 1
                }
                segments.append(.init(text: chunk, separatorAfter: separator))
                cursor = nextCursor
            } else {
                segments.append(
                    .init(
                        text: String(characters[cursor..<searchEnd]),
                        separatorAfter: ""
                    )
                )
                cursor = searchEnd
            }
        }

        return segments
    }

    private static func translationUnits(
        in text: String,
        option: NSString.EnumerationOptions
    ) -> [TranslationUnit] {
        guard !text.isEmpty else {
            return []
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var units: [TranslationUnit] = []

        nsText.enumerateSubstrings(
            in: fullRange,
            options: [option, .substringNotRequired]
        ) { _, substringRange, enclosingRange, _ in
            let content = nsText.substring(with: substringRange)
            let separatorLocation = substringRange.location + substringRange.length
            let separatorLength = enclosingRange.location + enclosingRange.length - separatorLocation
            var separatorAfter = separatorLength > 0
                ? nsText.substring(with: NSRange(location: separatorLocation, length: separatorLength))
                : ""
            var contentEnd = content.endIndex
            while contentEnd > content.startIndex {
                let previousIndex = content.index(before: contentEnd)
                guard content[previousIndex].isWhitespace else {
                    break
                }
                contentEnd = previousIndex
            }
            let trimmedContent = String(content[..<contentEnd])

            if contentEnd < content.endIndex {
                separatorAfter = String(content[contentEnd...]) + separatorAfter
            }

            units.append(.init(text: trimmedContent, separatorAfter: separatorAfter))
        }

        return units.isEmpty ? [.init(text: text, separatorAfter: "")] : units
    }
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
        segments: [AppleTranslateService.TranslationSegment],
        source: Locale.Language,
        target: Locale.Language
    ) async throws -> String {
        try await driver.translate(
            segments: segments,
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
        let segments: [AppleTranslateService.TranslationSegment]
        let source: Locale.Language
        let target: Locale.Language
    }

    @Published var configuration: TranslationSession.Configuration?

    private var pendingRequest: Request?
    private var continuation: CheckedContinuation<String, Error>?

    func translate(
        segments: [AppleTranslateService.TranslationSegment],
        source: Locale.Language,
        target: Locale.Language
    ) async throws -> String {
        guard continuation == nil else {
            throw AppleTranslateServiceError.busy
        }

        let request = Request(
            id: UUID(),
            segments: segments,
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
            var translatedText = ""
            for segment in request.segments {
                let response = try await session.translate(segment.text)
                translatedText += response.targetText
                translatedText += segment.separatorAfter
            }
            complete(requestID: request.id, result: .success(translatedText))
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
