import AppKit
import Testing
@testable import VoicePi

@MainActor
private final class ClipboardWriterSpy: ClipboardWriting {
    private(set) var writes: [String] = []

    func write(string: String) -> Bool {
        writes.append(string)
        return true
    }
}

@MainActor
struct ResultReviewPanelControllerTests {
    @Test
    func windowCanBecomeKeyForKeyboardShortcuts() {
        let controller = ResultReviewPanelController()

        let panel = controller.window

        #expect(panel is NSPanel)
        #expect(panel?.canBecomeKey == true)
        #expect(panel?.canBecomeMain == true)
    }

    @Test
    func copyActionsUsePromptAndOutputText() throws {
        let clipboardWriter = ClipboardWriterSpy()
        let controller = ResultReviewPanelController(clipboardWriter: clipboardWriter)
        let payload = try #require(ResultReviewPanelPayload(text: "Refined output", sourceText: "Captured prompt"))

        controller.show(payload: payload)
        defer { controller.hide() }

        #expect(controller.performPromptCopy())
        #expect(clipboardWriter.writes.last == "Captured prompt")
        #expect(controller.performCopy())
        #expect(clipboardWriter.writes.last == "Refined output")
    }

    @Test
    func promptCopyReturnsFalseWhenPromptMissing() throws {
        let clipboardWriter = ClipboardWriterSpy()
        let controller = ResultReviewPanelController(clipboardWriter: clipboardWriter)
        let payload = try #require(ResultReviewPanelPayload(text: "Refined output"))

        controller.show(payload: payload)
        defer { controller.hide() }

        #expect(!controller.performPromptCopy())
        #expect(clipboardWriter.writes.isEmpty)
    }
}
