import AppKit
import Carbon
import Foundation

struct InputSourceSnapshot {
    let source: TISInputSource
    let sourceID: String?
    let languages: [String]
    let category: String?
    let isCJK: Bool
}

struct TextInjectionRecord: Equatable {
    let text: String
    let injectedAt: Date
}

enum TextInjectorError: LocalizedError {
    case clipboardUnavailable
    case eventSourceUnavailable
    case asciiInputSourceUnavailable
    case inputSourceSwitchFailed
    case restoreInputSourceFailed

    var errorDescription: String? {
        switch self {
        case .clipboardUnavailable:
            return "The system pasteboard is unavailable."
        case .eventSourceUnavailable:
            return "Unable to create a keyboard event source."
        case .asciiInputSourceUnavailable:
            return "Unable to find an ASCII keyboard input source."
        case .inputSourceSwitchFailed:
            return "Unable to switch to an ASCII input source before pasting."
        case .restoreInputSourceFailed:
            return "Unable to restore the previous input source after pasting."
        }
    }
}

@MainActor
final class TextInjector {
    static let shared = TextInjector()

    private let pasteboard = NSPasteboard.general

    private init() {}

    nonisolated static func performOnMainThread<T: Sendable>(
        _ operation: @MainActor @Sendable () throws -> T
    ) async throws -> T {
        try await MainActor.run {
            try operation()
        }
    }

    func inject(text: String) async throws {
        _ = try await injectAndRecord(text: text)
    }

    func injectAndRecord(
        text: String,
        now: @autoclosure () -> Date = Date()
    ) async throws -> TextInjectionRecord {
        let trimmed = text.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else {
            return TextInjectionRecord(text: "", injectedAt: now())
        }

        try await performInjection(text: text)
        return TextInjectionRecord(text: trimmed, injectedAt: now())
    }

    private func performInjection(text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else { return }

        let originalPasteboard = capturePasteboardItems()
        let originalInputSource = currentInputSourceSnapshot()

        var switchedToASCII = false

        do {
            if let originalInputSource, originalInputSource.isCJK {
                switchedToASCII = try switchToASCIIInputSource()
                try await Task.sleep(for: .milliseconds(90))
            }

            try setClipboard(text: text)
            try await Task.sleep(for: .milliseconds(40))

            try simulateCommandV()
            try await Task.sleep(for: .milliseconds(220))

            restorePasteboardItems(originalPasteboard)

            if switchedToASCII {
                try await Task.sleep(for: .milliseconds(120))
                try restoreInputSource(originalInputSource)
            }
        } catch {
            restorePasteboardItems(originalPasteboard)

            if switchedToASCII {
                _ = try? restoreInputSource(originalInputSource)
            }

            throw error
        }
    }

    // MARK: - Pasteboard

    private func capturePasteboardItems() -> [NSPasteboardItem]? {
        pasteboard.pasteboardItems?.compactMap { item in
            let copy = NSPasteboardItem()
            var copiedAnyType = false

            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                    copiedAnyType = true
                } else if let string = item.string(forType: type) {
                    copy.setString(string, forType: type)
                    copiedAnyType = true
                } else if let propertyList = item.propertyList(forType: type) {
                    copy.setPropertyList(propertyList, forType: type)
                    copiedAnyType = true
                }
            }

            return copiedAnyType ? copy : nil
        }
    }

    private func restorePasteboardItems(_ items: [NSPasteboardItem]?) {
        pasteboard.clearContents()
        guard let items, !items.isEmpty else { return }
        _ = pasteboard.writeObjects(items)
    }

    private func setClipboard(text: String) throws {
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            throw TextInjectorError.clipboardUnavailable
        }
    }

    // MARK: - Input Source

    private func currentInputSourceSnapshot() -> InputSourceSnapshot? {
        guard let unmanagedSource = TISCopyCurrentKeyboardInputSource() else {
            return nil
        }

        let source = unmanagedSource.takeRetainedValue()
        let sourceID = propertyString(for: source, key: kTISPropertyInputSourceID)
        let languages = propertyStrings(for: source, key: kTISPropertyInputSourceLanguages)
        let category = propertyString(for: source, key: kTISPropertyInputSourceCategory)

        return InputSourceSnapshot(
            source: source,
            sourceID: sourceID,
            languages: languages,
            category: category,
            isCJK: TextInjectorSupport.isLikelyCJKInputSource(
                id: sourceID,
                languages: languages,
                category: category
            )
        )
    }

    private func switchToASCIIInputSource() throws -> Bool {
        let asciiSource = try findASCIIInputSource()
        let status = TISSelectInputSource(asciiSource)

        guard status == noErr else {
            throw TextInjectorError.inputSourceSwitchFailed
        }

        return true
    }

    @discardableResult
    private func restoreInputSource(_ snapshot: InputSourceSnapshot?) throws -> Bool {
        guard let snapshot else { return false }

        let status = TISSelectInputSource(snapshot.source)
        guard status == noErr else {
            throw TextInjectorError.restoreInputSourceFailed
        }

        return true
    }

    private func findASCIIInputSource() throws -> TISInputSource {
        let preferredIDs = [
            "com.apple.keylayout.ABC",
            "com.apple.keylayout.US"
        ]

        for sourceID in preferredIDs {
            if let source = findInputSource(byID: sourceID) {
                return source
            }
        }

        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceIsSelectCapable as String: true
        ] as CFDictionary

        guard
            let unmanagedList = TISCreateInputSourceList(filter, false),
            let sources = unmanagedList.takeRetainedValue() as? [TISInputSource]
        else {
            throw TextInjectorError.asciiInputSourceUnavailable
        }

        if let source = sources.first(where: { source in
            let sourceID = propertyString(for: source, key: kTISPropertyInputSourceID)
            let languages = propertyStrings(for: source, key: kTISPropertyInputSourceLanguages)
            let category = propertyString(for: source, key: kTISPropertyInputSourceCategory)
            let isASCII = propertyBool(for: source, key: kTISPropertyInputSourceIsASCIICapable)

            return isASCII && !TextInjectorSupport.isLikelyCJKInputSource(
                id: sourceID,
                languages: languages,
                category: category
            )
        }) {
            return source
        }

        throw TextInjectorError.asciiInputSourceUnavailable
    }

    private func findInputSource(byID sourceID: String) -> TISInputSource? {
        let filter = [
            kTISPropertyInputSourceID as String: sourceID,
            kTISPropertyInputSourceIsSelectCapable as String: true
        ] as CFDictionary

        guard
            let unmanagedList = TISCreateInputSourceList(filter, false),
            let sources = unmanagedList.takeRetainedValue() as? [TISInputSource]
        else {
            return nil
        }

        return sources.first
    }

    private func propertyString(for source: TISInputSource, key: CFString) -> String? {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return nil
        }

        return unsafeBitCast(value, to: AnyObject.self) as? String
    }

    private func propertyStrings(for source: TISInputSource, key: CFString) -> [String] {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return []
        }

        return (unsafeBitCast(value, to: AnyObject.self) as? [String]) ?? []
    }

    private func propertyBool(for source: TISInputSource, key: CFString) -> Bool {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return false
        }

        if let boolValue = unsafeBitCast(value, to: AnyObject.self) as? Bool {
            return boolValue
        }

        return false
    }

    // MARK: - Keyboard Events

    private func simulateCommandV() throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw TextInjectorError.eventSourceUnavailable
        }

        let keyCode: CGKeyCode = 9 // ANSI V

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            throw TextInjectorError.eventSourceUnavailable
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.025)
        keyUp.post(tap: .cghidEventTap)
    }
}
