import Foundation
import Testing
@testable import VoicePi

struct ExternalProcessorSourceSnapshotSupportTests {
    @Test
    func captureBuildsSnapshotForEditableSelection() throws {
        let snapshot = EditableTextTargetSnapshot(
            inspection: .editable,
            targetIdentifier: " 123:AXTextArea ",
            textValue: "irrelevant",
            selectedText: "  Selected source context  ",
            selectedTextRange: NSRange(location: 5, length: 8)
        )

        let captured = try #require(
            ExternalProcessorSourceSnapshotSupport.capture(
                from: snapshot,
                sourceApplicationBundleID: " com.apple.TextEdit "
            )
        )

        #expect(captured.text == "Selected source context")
        #expect(captured.previewText == "Selected source context")
        #expect(captured.sourceApplicationBundleID == "com.apple.TextEdit")
        #expect(captured.targetIdentifier == "123:AXTextArea")
    }

    @Test
    func captureBuildsSnapshotForNonEditableSelectionWhenSelectedTextExists() throws {
        let snapshot = EditableTextTargetSnapshot(
            inspection: .notEditable,
            targetIdentifier: "article-1",
            textValue: "Full article",
            selectedText: "Quoted paragraph",
            selectedTextRange: NSRange(location: 12, length: 16)
        )

        let captured = try #require(
            ExternalProcessorSourceSnapshotSupport.capture(
                from: snapshot,
                sourceApplicationBundleID: "com.apple.Safari"
            )
        )

        #expect(captured.text == "Quoted paragraph")
        #expect(captured.previewText == "Quoted paragraph")
        #expect(captured.sourceApplicationBundleID == "com.apple.Safari")
        #expect(captured.targetIdentifier == "article-1")
    }

    @Test
    func captureBuildsSnapshotWithoutSelectedRangeWhenSelectedTextExists() throws {
        let snapshot = EditableTextTargetSnapshot(
            inspection: .unavailable,
            targetIdentifier: "viewer-1",
            textValue: nil,
            selectedText: "Captured from AXSelectedText",
            selectedTextRange: nil
        )

        let captured = try #require(
            ExternalProcessorSourceSnapshotSupport.capture(
                from: snapshot,
                sourceApplicationBundleID: "com.apple.Preview"
            )
        )

        #expect(captured.text == "Captured from AXSelectedText")
        #expect(captured.previewText == "Captured from AXSelectedText")
        #expect(captured.sourceApplicationBundleID == "com.apple.Preview")
        #expect(captured.targetIdentifier == "viewer-1")
    }

    @Test
    func captureReturnsNilForMissingOrInvalidSelection() {
        let nonEditableSnapshot = EditableTextTargetSnapshot(
            inspection: .notEditable,
            targetIdentifier: "target-1",
            textValue: "text",
            selectedText: nil,
            selectedTextRange: NSRange(location: 0, length: 8)
        )
        let emptySelectionSnapshot = EditableTextTargetSnapshot(
            inspection: .editable,
            targetIdentifier: "target-2",
            textValue: "text",
            selectedText: " \n\t ",
            selectedTextRange: NSRange(location: 0, length: 0)
        )

        #expect(
            ExternalProcessorSourceSnapshotSupport.capture(
                from: nonEditableSnapshot,
                sourceApplicationBundleID: "com.apple.TextEdit"
            ) == nil
        )
        #expect(
            ExternalProcessorSourceSnapshotSupport.capture(
                from: emptySelectionSnapshot,
                sourceApplicationBundleID: "com.apple.TextEdit"
            ) == nil
        )
    }

    @Test
    func previewTextCollapsesWhitespaceAndTruncatesDeterministically() {
        #expect(
            ExternalProcessorSourceSnapshotSupport.previewText(
                from: "One\n\tTwo   Three"
            ) == "One Two Three"
        )
        #expect(
            ExternalProcessorSourceSnapshotSupport.previewText(
                from: "ABCDEFGHIJK",
                characterLimit: 5
            ) == "ABCDE…"
        )
    }

    @Test
    func sourceContractBlockTruncatesAndAnnotatesWhenNeeded() {
        let sourceSnapshot = CapturedSourceSnapshot(
            text: "abcdefghij",
            previewText: "abcdefghij",
            sourceApplicationBundleID: nil,
            targetIdentifier: nil
        )

        let truncatedBlock = ExternalProcessorSourceSnapshotSupport.sourceContractBlock(
            for: sourceSnapshot,
            promptCharacterLimit: 5
        )
        let fullBlock = ExternalProcessorSourceSnapshotSupport.sourceContractBlock(
            for: sourceSnapshot,
            promptCharacterLimit: 20
        )

        #expect(truncatedBlock.contains("Source was truncated to fit processor limits."))
        #expect(truncatedBlock.contains("<Source>\nabcde\n</Source>"))
        #expect(!fullBlock.contains("Source was truncated to fit processor limits."))
        #expect(fullBlock.contains("<Source>\nabcdefghij\n</Source>"))
    }
}
