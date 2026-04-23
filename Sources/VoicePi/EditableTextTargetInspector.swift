import AppKit
import ApplicationServices
import Foundation

struct EditableTextTargetSnapshot: Equatable {
    let inspection: EditableTextTargetInspection
    let targetIdentifier: String?
    let textValue: String?
    let selectedText: String?
    let selectedTextRange: NSRange?
    let selectedTextBoundsInScreen: CGRect?
    let canSetSelectedTextRange: Bool

    init(
        inspection: EditableTextTargetInspection,
        targetIdentifier: String?,
        textValue: String?,
        selectedText: String? = nil,
        selectedTextRange: NSRange? = nil,
        selectedTextBoundsInScreen: CGRect? = nil,
        canSetSelectedTextRange: Bool = false
    ) {
        self.inspection = inspection
        self.targetIdentifier = targetIdentifier
        self.textValue = textValue
        self.selectedText = selectedText
        self.selectedTextRange = selectedTextRange
        self.selectedTextBoundsInScreen = selectedTextBoundsInScreen
        self.canSetSelectedTextRange = canSetSelectedTextRange
    }
}

protocol EditableTextTargetInspecting {
    func inspectCurrentTarget() -> EditableTextTargetInspection
    func currentSnapshot() -> EditableTextTargetSnapshot
    func restoreSelectionRange(targetIdentifier: String?, range: NSRange) -> Bool
}

struct EditableTextTargetClassifier {
    static let editableRoles: Set<String> = [
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

    static func isPreferredEditableRole(_ role: String?) -> Bool {
        guard let role else { return false }
        return editableRoles.contains(role)
    }
}

struct EditableTextTargetFallbackCandidate: Equatable {
    let role: String?
    let editableAttribute: Bool?
    let valueAttributeSettable: Bool?
    let selectedTextRangeAttributeSettable: Bool?
    let depth: Int
}

enum EditableTextTargetFallbackResolver {
    static func bestCandidate(
        in candidates: [EditableTextTargetFallbackCandidate]
    ) -> EditableTextTargetFallbackCandidate? {
        candidates.max { lhs, rhs in
            compare(lhs, rhs) == .orderedAscending
        }
    }

    private static func compare(
        _ lhs: EditableTextTargetFallbackCandidate,
        _ rhs: EditableTextTargetFallbackCandidate
    ) -> ComparisonResult {
        let lhsScore = score(for: lhs)
        let rhsScore = score(for: rhs)

        if lhsScore != rhsScore {
            return lhsScore < rhsScore ? .orderedAscending : .orderedDescending
        }

        if lhs.depth != rhs.depth {
            return lhs.depth < rhs.depth ? .orderedAscending : .orderedDescending
        }

        return .orderedSame
    }

    private static func score(for candidate: EditableTextTargetFallbackCandidate) -> Int {
        var score = 0

        let inspection = EditableTextTargetClassifier.classify(
            role: candidate.role,
            editableAttribute: candidate.editableAttribute,
            valueAttributeSettable: candidate.valueAttributeSettable
        )

        switch inspection {
        case .editable:
            score += 1_000
        case .notEditable:
            score += 100
        case .unavailable:
            return 0
        }

        if EditableTextTargetClassifier.isPreferredEditableRole(candidate.role) {
            score += 300
        }
        if candidate.editableAttribute == true {
            score += 250
        }
        if candidate.valueAttributeSettable == true {
            score += 200
        }
        if candidate.selectedTextRangeAttributeSettable == true {
            score += 100
        }

        score += candidate.depth
        return score
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
                selectedTextBoundsInScreen: nil,
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
        let selectedTextRange = copySelectedTextRange(from: focusedElement)
        let selectedTextFromAttribute = copyStringLikeAttribute(
            kAXSelectedTextAttribute as String,
            from: focusedElement
        )
        let selectedTextRangeStrings = copySelectedTextRangeStrings(from: focusedElement)
        let selectedTextMarkerRangeText = copySelectedTextMarkerRangeText(around: focusedElement)
        let selectedChildrenText = copySelectedChildrenText(around: focusedElement)
        let selectedText = Self.selectedTextFromValue(
            textValue,
            range: selectedTextRange,
            preferredSelectedText: selectedTextFromAttribute,
            selectedTextRangeStrings: selectedTextRangeStrings,
            selectedChildrenText: selectedChildrenText,
            selectedTextMarkerRangeText: selectedTextMarkerRangeText
        )
        let selectedTextBoundsInScreen = selectedTextRange.flatMap {
            copyBounds(for: $0, from: focusedElement)
        }

        return EditableTextTargetSnapshot(
            inspection: inspection,
            targetIdentifier: targetIdentifier,
            textValue: textValue,
            selectedText: selectedText,
            selectedTextRange: selectedTextRange,
            selectedTextBoundsInScreen: selectedTextBoundsInScreen,
            canSetSelectedTextRange: selectedTextRangeSettable == true
        )
    }

    static func selectedTextFromValue(
        _ textValue: String?,
        range: NSRange?,
        preferredSelectedText: String? = nil,
        selectedTextRangeStrings: [String] = [],
        selectedChildrenText: [String] = [],
        selectedTextMarkerRangeText: String? = nil
    ) -> String? {
        if let preferredSelectedText, !preferredSelectedText.isEmpty {
            return preferredSelectedText
        }
        guard let textValue, let range, range.location >= 0, range.length > 0 else {
            if let selectedTextFromRanges = joinedSelectedChildrenText(selectedTextRangeStrings) {
                return selectedTextFromRanges
            }
            if let selectedTextMarkerRangeText = normalizedFallbackFragment(selectedTextMarkerRangeText) {
                return selectedTextMarkerRangeText
            }
            return joinedSelectedChildrenText(selectedChildrenText)
        }

        let nsText = textValue as NSString
        guard range.location <= nsText.length else {
            if let selectedTextFromRanges = joinedSelectedChildrenText(selectedTextRangeStrings) {
                return selectedTextFromRanges
            }
            if let selectedTextMarkerRangeText = normalizedFallbackFragment(selectedTextMarkerRangeText) {
                return selectedTextMarkerRangeText
            }
            return joinedSelectedChildrenText(selectedChildrenText)
        }
        guard range.location + range.length <= nsText.length else {
            if let selectedTextFromRanges = joinedSelectedChildrenText(selectedTextRangeStrings) {
                return selectedTextFromRanges
            }
            if let selectedTextMarkerRangeText = normalizedFallbackFragment(selectedTextMarkerRangeText) {
                return selectedTextMarkerRangeText
            }
            return joinedSelectedChildrenText(selectedChildrenText)
        }
        return nsText.substring(with: range)
    }

    private static func normalizedFallbackFragment(_ fragment: String?) -> String? {
        let trimmed = fragment?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func joinedSelectedChildrenText(_ fragments: [String]) -> String? {
        let cleanedFragments = fragments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanedFragments.isEmpty else {
            return nil
        }
        return cleanedFragments.joined(separator: "\n")
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

        if focusStatus == .success, let focusedElementReference {
            return unsafeBitCast(focusedElementReference, to: AXUIElement.self)
        }

        return fallbackFocusedElementFromFrontmostWindow()
    }

    private func fallbackFocusedElementFromFrontmostWindow() -> AXUIElement? {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let applicationElement = AXUIElementCreateApplication(frontmostApplication.processIdentifier)
        guard let windowElement =
            copyElementAttribute(kAXFocusedWindowAttribute as String, from: applicationElement)
            ?? copyElementAttribute(kAXMainWindowAttribute as String, from: applicationElement)
        else {
            return nil
        }

        return bestWritableDescendant(from: windowElement)
    }

    private func bestWritableDescendant(from rootElement: AXUIElement) -> AXUIElement? {
        let maxVisitedElements = 512
        var visitedCount = 0
        var queue: [(element: AXUIElement, depth: Int)] = [(rootElement, 0)]
        var bestMatch: (element: AXUIElement, candidate: EditableTextTargetFallbackCandidate)?

        while !queue.isEmpty, visitedCount < maxVisitedElements {
            let (element, depth) = queue.removeFirst()
            visitedCount += 1

            let candidate = EditableTextTargetFallbackCandidate(
                role: copyStringAttribute(kAXRoleAttribute as String, from: element),
                editableAttribute: copyBoolAttribute("AXEditable", from: element),
                valueAttributeSettable: isAttributeSettable(kAXValueAttribute, on: element),
                selectedTextRangeAttributeSettable: isAttributeSettable(
                    kAXSelectedTextRangeAttribute as String,
                    on: element
                ),
                depth: depth
            )

            if let resolvedBest = bestMatch?.candidate {
                if EditableTextTargetFallbackResolver.bestCandidate(
                    in: [resolvedBest, candidate]
                ) == candidate {
                    bestMatch = (element, candidate)
                }
            } else if EditableTextTargetFallbackResolver.bestCandidate(in: [candidate]) == candidate,
                      candidate.valueAttributeSettable == true || candidate.selectedTextRangeAttributeSettable == true {
                bestMatch = (element, candidate)
            }

            if let children = copyElementArrayAttribute(kAXChildrenAttribute as String, from: element) {
                for child in children {
                    queue.append((child, depth + 1))
                }
            }
        }

        return bestMatch?.element
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

    private func copyRawAttributeValue(_ attribute: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let value else {
            return nil
        }
        return value
    }

    private func copyElementAttribute(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let value else {
            return nil
        }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func copyElementArrayAttribute(_ attribute: String, from element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let value else {
            return nil
        }
        guard let values = value as? [Any] else {
            return nil
        }

        let elements = values.compactMap { item -> AXUIElement? in
            let raw = item as AnyObject
            guard CFGetTypeID(raw) == AXUIElementGetTypeID() else {
                return nil
            }
            return unsafeBitCast(raw, to: AXUIElement.self)
        }
        return elements.isEmpty ? nil : elements
    }

    private func copySelectedTextRangeStrings(from element: AXUIElement) -> [String] {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangesAttribute as CFString,
            &value
        )
        guard status == .success, let values = value as? [Any] else {
            return []
        }

        return values.compactMap { item in
            guard CFGetTypeID(item as CFTypeRef) == AXValueGetTypeID() else {
                return nil
            }
            let axValue = unsafeBitCast(item as CFTypeRef, to: AXValue.self)
            guard AXValueGetType(axValue) == .cfRange else {
                return nil
            }

            var range = CFRange()
            guard AXValueGetValue(axValue, .cfRange, &range) else {
                return nil
            }
            guard range.location >= 0, range.length > 0 else {
                return nil
            }

            var parameterRange = range
            guard let parameter = AXValueCreate(.cfRange, &parameterRange) else {
                return nil
            }

            var stringValue: CFTypeRef?
            let stringStatus = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXStringForRangeParameterizedAttribute as CFString,
                parameter,
                &stringValue
            )
            guard stringStatus == .success, let stringValue else {
                return nil
            }

            if let string = stringValue as? String {
                return string
            }
            if let attributedString = stringValue as? NSAttributedString {
                return attributedString.string
            }
            return nil
        }
    }

    private func copySelectedChildrenText(around element: AXUIElement, maxAncestorDepth: Int = 6) -> [String] {
        var currentElement: AXUIElement? = element
        var depth = 0

        while depth <= maxAncestorDepth, let resolvedElement = currentElement {
            let fragments = copySelectedChildrenText(from: resolvedElement)
            if !fragments.isEmpty {
                return fragments
            }

            currentElement = copyElementAttribute(kAXParentAttribute as String, from: resolvedElement)
            depth += 1
        }

        return []
    }

    private func copySelectedTextMarkerRangeText(
        around element: AXUIElement,
        maxAncestorDepth: Int = 6
    ) -> String? {
        var currentElement: AXUIElement? = element
        var depth = 0

        while depth <= maxAncestorDepth, let resolvedElement = currentElement {
            if let selectedText = copySelectedTextMarkerRangeText(from: resolvedElement) {
                return selectedText
            }

            currentElement = copyElementAttribute(kAXParentAttribute as String, from: resolvedElement)
            depth += 1
        }

        return nil
    }

    private func copySelectedTextMarkerRangeText(from element: AXUIElement) -> String? {
        guard let markerRange = copyRawAttributeValue("AXSelectedTextMarkerRange", from: element) else {
            return nil
        }

        if let stringValue = copyStringForTextMarkerRange(markerRange, from: element, attribute: "AXStringForTextMarkerRange") {
            return stringValue
        }

        return copyStringForTextMarkerRange(
            markerRange,
            from: element,
            attribute: "AXAttributedStringForTextMarkerRange"
        )
    }

    private func copyStringForTextMarkerRange(
        _ markerRange: CFTypeRef,
        from element: AXUIElement,
        attribute: String
    ) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            attribute as CFString,
            markerRange,
            &value
        )
        guard status == .success, let value else {
            return nil
        }

        if let stringValue = value as? String {
            return stringValue
        }

        if let attributedValue = value as? NSAttributedString {
            return attributedValue.string
        }

        return nil
    }

    private func copySelectedChildrenText(from element: AXUIElement) -> [String] {
        guard let selectedChildren = copyElementArrayAttribute("AXSelectedChildren", from: element) else {
            return []
        }

        return selectedChildren.flatMap { copyTextFragments(from: $0, depthRemaining: 3) }
    }

    private func copyTextFragments(from element: AXUIElement, depthRemaining: Int) -> [String] {
        if let selectedText = copyStringLikeAttribute(kAXSelectedTextAttribute as String, from: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !selectedText.isEmpty {
            return [selectedText]
        }

        if let valueText = copyStringLikeAttribute(kAXValueAttribute, from: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !valueText.isEmpty {
            return [valueText]
        }

        if let titleText = copyStringLikeAttribute(kAXTitleAttribute as String, from: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !titleText.isEmpty {
            return [titleText]
        }

        guard depthRemaining > 0,
              let children = copyElementArrayAttribute(kAXChildrenAttribute as String, from: element) else {
            return []
        }

        return children.flatMap { copyTextFragments(from: $0, depthRemaining: depthRemaining - 1) }
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

    private func copyBounds(for range: NSRange, from element: AXUIElement) -> CGRect? {
        guard range.location >= 0, range.length >= 0 else {
            return nil
        }

        var cfRange = CFRange(location: range.location, length: range.length)
        guard let parameter = AXValueCreate(.cfRange, &cfRange) else {
            return nil
        }

        var value: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            parameter,
            &value
        )
        guard status == .success, let value else {
            return nil
        }
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgRect else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect), !rect.isEmpty else {
            return nil
        }

        return rect
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
        let subroleComponent = copyStringAttribute(kAXSubroleAttribute as String, from: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let subroleComponent, !subroleComponent.isEmpty {
            return "\(processComponent):\(roleComponent):\(subroleComponent)"
        }
        return "\(processComponent):\(roleComponent)"
    }
}
