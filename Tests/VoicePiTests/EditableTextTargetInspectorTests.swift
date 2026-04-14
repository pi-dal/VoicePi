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
}
