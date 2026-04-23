import ApplicationServices
import Foundation
import Testing
@testable import VoicePi

struct EditableTextTargetInspectorTests {
    @Test
    func editableTextFieldRoleIsRecognizedAsEditable() {
        #expect(
            EditableTextTargetClassifier.classify(
                role: kAXTextFieldRole as String,
                editableAttribute: nil,
                valueAttributeSettable: true
            ) == .editable
        )
    }

    @Test
    func explicitEditableWebAreaIsRecognizedAsEditable() {
        #expect(
            EditableTextTargetClassifier.classify(
                role: "AXWebArea",
                editableAttribute: true,
                valueAttributeSettable: false
            ) == .editable
        )
    }

    @Test
    func plainWebAreaWithoutEditableSignalIsNotEditable() {
        #expect(
            EditableTextTargetClassifier.classify(
                role: "AXWebArea",
                editableAttribute: nil,
                valueAttributeSettable: false
            ) == .notEditable
        )
    }

    @Test
    func buttonRoleIsNotEditable() {
        #expect(
            EditableTextTargetClassifier.classify(
                role: kAXButtonRole as String,
                editableAttribute: false,
                valueAttributeSettable: false
            ) == .notEditable
        )
    }

    @Test
    func missingMetadataIsUnavailable() {
        #expect(
            EditableTextTargetClassifier.classify(
                role: nil,
                editableAttribute: nil,
                valueAttributeSettable: nil
            ) == .unavailable
        )
    }

    @Test
    func selectedTextFromValuePrefersProvidedSelectedText() {
        let selected = EditableTextTargetInspector.selectedTextFromValue(
            "Hello VoicePi",
            range: NSRange(location: 6, length: 7),
            preferredSelectedText: "VoicePi"
        )
        #expect(selected == "VoicePi")
    }

    @Test
    func selectedTextFromValueExtractsSubstringWhenSelectionAttributeIsUnavailable() {
        let selected = EditableTextTargetInspector.selectedTextFromValue(
            "Hello VoicePi",
            range: NSRange(location: 6, length: 7),
            preferredSelectedText: nil
        )
        #expect(selected == "VoicePi")
    }

    @Test
    func selectedTextFromValueIgnoresInvalidRanges() {
        let selected = EditableTextTargetInspector.selectedTextFromValue(
            "Hello",
            range: NSRange(location: 3, length: 99),
            preferredSelectedText: nil
        )
        #expect(selected == nil)
    }

    @Test
    func selectedTextFromValueFallsBackToSelectedChildrenText() {
        let selected = EditableTextTargetInspector.selectedTextFromValue(
            nil,
            range: nil,
            preferredSelectedText: nil,
            selectedTextRangeStrings: [],
            selectedChildrenText: [
                " First selected line ",
                "",
                "Second selected line"
            ]
        )
        #expect(selected == "First selected line\nSecond selected line")
    }

    @Test
    func selectedTextFromValueFallsBackToSelectedTextRangesText() {
        let selected = EditableTextTargetInspector.selectedTextFromValue(
            nil,
            range: nil,
            preferredSelectedText: nil,
            selectedTextRangeStrings: [
                " First selected paragraph ",
                "",
                "Second selected paragraph"
            ],
            selectedChildrenText: []
        )
        #expect(selected == "First selected paragraph\nSecond selected paragraph")
    }

    @Test
    func selectedTextFromValueFallsBackToSelectedTextMarkerRangeText() {
        let selected = EditableTextTargetInspector.selectedTextFromValue(
            nil,
            range: nil,
            preferredSelectedText: nil,
            selectedTextRangeStrings: [],
            selectedChildrenText: [],
            selectedTextMarkerRangeText: " Selected PDF paragraph "
        )
        #expect(selected == "Selected PDF paragraph")
    }

    @Test
    func fallbackResolverPicksDeepestWritableGroupWhenFocusedElementIsUnavailable() {
        let candidates: [EditableTextTargetFallbackCandidate] = [
            .init(
                role: "AXWindow",
                editableAttribute: nil,
                valueAttributeSettable: false,
                selectedTextRangeAttributeSettable: false,
                depth: 0
            ),
            .init(
                role: "AXGroup",
                editableAttribute: nil,
                valueAttributeSettable: true,
                selectedTextRangeAttributeSettable: true,
                depth: 2
            ),
            .init(
                role: "AXGroup",
                editableAttribute: nil,
                valueAttributeSettable: true,
                selectedTextRangeAttributeSettable: true,
                depth: 6
            )
        ]

        #expect(
            EditableTextTargetFallbackResolver.bestCandidate(in: candidates)?.depth == 6
        )
    }

    @Test
    func fallbackResolverPrefersEditableTextRoleOverWritableGenericGroup() {
        let candidates: [EditableTextTargetFallbackCandidate] = [
            .init(
                role: "AXGroup",
                editableAttribute: nil,
                valueAttributeSettable: true,
                selectedTextRangeAttributeSettable: true,
                depth: 5
            ),
            .init(
                role: kAXTextAreaRole as String,
                editableAttribute: true,
                valueAttributeSettable: true,
                selectedTextRangeAttributeSettable: true,
                depth: 3
            )
        ]

        #expect(
            EditableTextTargetFallbackResolver.bestCandidate(in: candidates)?.role == kAXTextAreaRole as String
        )
    }
}
