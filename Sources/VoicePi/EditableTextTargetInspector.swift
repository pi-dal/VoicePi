import ApplicationServices
import Foundation

protocol EditableTextTargetInspecting {
    func inspectCurrentTarget() -> EditableTextTargetInspection
}

struct EditableTextTargetClassifier {
    private static let editableRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        "AXSearchField"
    ]

    static func classify(
        role: String?,
        editableAttribute: Bool?,
        valueAttributeSettable: Bool?
    ) -> EditableTextTargetInspection {
        if editableAttribute == true {
            return .editable
        }

        if valueAttributeSettable == true {
            return .editable
        }

        if let role, editableRoles.contains(role), editableAttribute != false {
            return .editable
        }

        if role != nil || editableAttribute != nil || valueAttributeSettable != nil {
            return .notEditable
        }

        return .unavailable
    }
}

struct EditableTextTargetInspector: EditableTextTargetInspecting {
    func inspectCurrentTarget() -> EditableTextTargetInspection {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementReference: CFTypeRef?

        let focusStatus = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementReference
        )

        guard focusStatus == .success, let focusedElementReference else {
            return .unavailable
        }

        let focusedElement = unsafeBitCast(focusedElementReference, to: AXUIElement.self)
        let role = copyStringAttribute(kAXRoleAttribute, from: focusedElement)
        let editableAttribute = copyBoolAttribute("AXEditable", from: focusedElement)
        let valueAttributeSettable = isAttributeSettable(kAXValueAttribute, on: focusedElement)

        return EditableTextTargetClassifier.classify(
            role: role,
            editableAttribute: editableAttribute,
            valueAttributeSettable: valueAttributeSettable
        )
    }

    private func copyStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success else {
            return nil
        }

        return value as? String
    }

    private func copyBoolAttribute(_ attribute: String, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success else {
            return nil
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        return nil
    }

    private func isAttributeSettable(_ attribute: String, on element: AXUIElement) -> Bool? {
        var isSettable = DarwinBoolean(false)
        let status = AXUIElementIsAttributeSettable(element, attribute as CFString, &isSettable)
        guard status == .success else {
            return nil
        }

        return isSettable.boolValue
    }
}
