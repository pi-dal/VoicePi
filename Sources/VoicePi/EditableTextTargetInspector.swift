import ApplicationServices
import Foundation

struct EditableTextTargetSnapshot: Equatable {
    let inspection: EditableTextTargetInspection
    let targetIdentifier: String?
    let textValue: String?
}

protocol EditableTextTargetInspecting {
    func inspectCurrentTarget() -> EditableTextTargetInspection
    func currentSnapshot() -> EditableTextTargetSnapshot
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
        currentSnapshot().inspection
    }

    func currentSnapshot() -> EditableTextTargetSnapshot {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementReference: CFTypeRef?

        let focusStatus = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementReference
        )

        guard focusStatus == .success, let focusedElementReference else {
            return EditableTextTargetSnapshot(
                inspection: .unavailable,
                targetIdentifier: nil,
                textValue: nil
            )
        }

        let focusedElement = unsafeBitCast(focusedElementReference, to: AXUIElement.self)
        let role = copyStringAttribute(kAXRoleAttribute, from: focusedElement)
        let editableAttribute = copyBoolAttribute("AXEditable", from: focusedElement)
        let valueAttributeSettable = isAttributeSettable(kAXValueAttribute, on: focusedElement)
        let inspection = EditableTextTargetClassifier.classify(
            role: role,
            editableAttribute: editableAttribute,
            valueAttributeSettable: valueAttributeSettable
        )
        let targetIdentifier = buildTargetIdentifier(for: focusedElement, role: role)
        let textValue = copyStringLikeAttribute(kAXValueAttribute, from: focusedElement)

        return EditableTextTargetSnapshot(
            inspection: inspection,
            targetIdentifier: targetIdentifier,
            textValue: textValue
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

    private func copyStringLikeAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let value else {
            return nil
        }

        if let stringValue = value as? String {
            return stringValue
        }

        if let attributedValue = value as? NSAttributedString {
            return attributedValue.string
        }

        if let numberValue = value as? NSNumber {
            return numberValue.stringValue
        }

        return nil
    }

    private func buildTargetIdentifier(for element: AXUIElement, role: String?) -> String? {
        let explicitIdentifier = copyStringAttribute("AXIdentifier", from: element)
            ?? copyStringAttribute("AXDOMIdentifier", from: element)

        var processID: pid_t = 0
        let processStatus = AXUIElementGetPid(element, &processID)
        let processComponent = processStatus == .success ? String(processID) : "unknown"

        if let explicitIdentifier = explicitIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitIdentifier.isEmpty
        {
            return "\(processComponent):\(explicitIdentifier)"
        }

        let roleComponent = role?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        let hashComponent = String(CFHash(element))
        return "\(processComponent):\(roleComponent):\(hashComponent)"
    }
}
