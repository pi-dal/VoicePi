import ApplicationServices
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
}
