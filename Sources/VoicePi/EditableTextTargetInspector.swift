import ApplicationServices
import Foundation

struct EditableTextTargetSnapshot: Equatable {
    let inspection: EditableTextTargetInspection
    let targetIdentifier: String?
    let textValue: String?
    let selectedText: String?
    let selectedTextRange: NSRange?
    let canSetSelectedTextRange: Bool

    init(
        inspection: EditableTextTargetInspection,
        targetIdentifier: String?,
        textValue: String?,
        selectedText: String? = nil,
        selectedTextRange: NSRange? = nil,
        canSetSelectedTextRange: Bool = false
    ) {
        self.inspection = inspection
        self.targetIdentifier = targetIdentifier
        self.textValue = textValue
        self.selectedText = selectedText
        self.selectedTextRange = selectedTextRange
        self.canSetSelectedTextRange = canSetSelectedTextRange
    }
}

protocol EditableTextTargetInspecting {
    func inspectCurrentTarget() -> EditableTextTargetInspection
    func currentSnapshot() -> EditableTextTargetSnapshot
    func restoreSelectionRange(targetIdentifier: String?, range: NSRange) -> Bool
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
        guard let focusedElement = focusedElement() else {
            return EditableTextTargetSnapshot(
                inspection: .unavailable,
                targetIdentifier: nil,
                textValue: nil,
                selectedText: nil,
                selectedTextRange: nil,
                canSetSelectedTextRange: false
            )
        }

        let role = copyStringAttribute(kAXRoleAttribute, from: focusedElement)
        let editableAttribute = copyBoolAttribute("AXEditable", from: focusedElement)
        let valueAttributeSettable = isAttributeSettable(kAXValueAttribute, on: focusedElement)
        let selectedTextRangeSettable = isAttributeSettable(
            kAXSelectedTextRangeAttribute as String,
            on: focusedElement
        )
        let inspection = EditableTextTargetClassifier.classify(
            role: role,
            editableAttribute: editableAttribute,
            valueAttributeSettable: valueAttributeSettable
        )
        let targetIdentifier = buildTargetIdentifier(for: focusedElement, role: role)
        let textValue = copyStringLikeAttribute(kAXValueAttribute, from: focusedElement)
        let selectedText = copyStringLikeAttribute(kAXSelectedTextAttribute as String, from: focusedElement)
        let selectedTextRange = copySelectedTextRange(from: focusedElement)

        return EditableTextTargetSnapshot(
            inspection: inspection,
            targetIdentifier: targetIdentifier,
            textValue: textValue,
            selectedText: selectedText,
            selectedTextRange: selectedTextRange,
            canSetSelectedTextRange: selectedTextRangeSettable == true
        )
    }

    func restoreSelectionRange(targetIdentifier: String?, range: NSRange) -> Bool {
        guard let focusedElement = focusedElement() else {
            return false
        }
        let role = copyStringAttribute(kAXRoleAttribute, from: focusedElement)
        let currentTargetIdentifier = buildTargetIdentifier(for: focusedElement, role: role)
        if let targetIdentifier, currentTargetIdentifier != targetIdentifier {
            return false
        }

        guard range.location >= 0, range.length >= 0 else {
            return false
        }
        guard isAttributeSettable(kAXSelectedTextRangeAttribute as String, on: focusedElement) == true else {
            return false
        }

        var cfRange = CFRange(location: range.location, length: range.length)
        guard let value = AXValueCreate(.cfRange, &cfRange) else {
            return false
        }

        let status = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            value
        )
        return status == .success
    }

    private func focusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementReference: CFTypeRef?

        let focusStatus = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementReference
        )

        guard focusStatus == .success, let focusedElementReference else {
            return nil
        }

        return unsafeBitCast(focusedElementReference, to: AXUIElement.self)
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

    private func copySelectedTextRange(from element: AXUIElement) -> NSRange? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        )
        guard status == .success, let value else {
            return nil
        }
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }
        guard range.location >= 0, range.length >= 0 else {
            return nil
        }

        return NSRange(location: range.location, length: range.length)
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
