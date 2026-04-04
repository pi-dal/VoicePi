import AppKit
import Foundation
import Testing
@testable import VoicePi

struct SettingsWindowPromptTemplateTests {
    @Test
    @MainActor
    func promptTemplatePopupsUseExplicitDarkTextInLightTheme() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.promptTemplatePopupsUseExplicitDarkTextInLightTheme.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.interfaceTheme = .light
        model.setPostProcessingMode(.refinement)
        model.promptSettings.defaultSelection = .profile("meeting_notes")

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.showWindow(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let popup = try #require(findPopup(in: controller.window?.contentView, titled: "Default Prompt Template"))
        let selectedTitleColor = try #require(colorAttribute(from: popup.attributedTitle))
        let menuItemColor = try #require(colorAttribute(from: popup.item(at: 0)?.attributedTitle))
        let expectedColor = NSColor(calibratedWhite: 0.22, alpha: 1)

        #expect(selectedTitleColor.isApproximatelyEqual(to: expectedColor))
        #expect(menuItemColor.isApproximatelyEqual(to: expectedColor))
    }

    @Test
    @MainActor
    func savingAppSpecificPromptOptionsDoesNotMutateGlobalDefaultSelection() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.savingAppSpecificPromptOptionsDoesNotMutateGlobalDefaultSelection.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.setPostProcessingMode(.refinement)
        model.promptSettings.defaultSelection = .profile(
            "meeting_notes",
            optionSelections: ["output_format": ["markdown"]]
        )
        model.setPromptSelection(
            .profile("support_reply", optionSelections: ["output_format": ["plain_text"]]),
            for: .voicePi
        )

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let outputFormatPopup = try #require(findPopup(in: controller.window?.contentView, titled: "Output Format"))
        try selectPopupItem(named: "JSON", in: outputFormatPopup)
        savePromptSettings(in: controller)

        #expect(
            model.promptSettings.defaultSelection == .profile(
                "meeting_notes",
                optionSelections: ["output_format": ["markdown"]]
            )
        )
        #expect(
            model.promptSelection(for: .voicePi) == .profile(
                "support_reply",
                optionSelections: ["output_format": ["json"]]
            )
        )
    }

    @Test
    @MainActor
    func switchingVoicePiOverrideToInheritAndBackPreservesAppSpecificPromptOptions() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.switchingVoicePiOverrideToInheritAndBackPreservesAppSpecificPromptOptions.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.setPostProcessingMode(.refinement)
        model.promptSettings.defaultSelection = .profile(
            "meeting_notes",
            optionSelections: ["output_format": ["markdown"]]
        )
        model.setPromptSelection(
            .profile("support_reply", optionSelections: ["output_format": ["json"]]),
            for: .voicePi
        )

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let overridePopup = try #require(findPopup(in: controller.window?.contentView, titled: "VoicePi Override"))
        try selectPopupItem(named: "Inherit Global Default", in: overridePopup)
        try selectPopupItem(named: "Support Reply", in: overridePopup)
        savePromptSettings(in: controller)

        #expect(
            model.promptSelection(for: .voicePi) == .profile(
                "support_reply",
                optionSelections: ["output_format": ["json"]]
            )
        )
    }

    @Test
    @MainActor
    func savingGlobalDefaultChangesPreservesLegacyCustomOverride() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.savingGlobalDefaultChangesPreservesLegacyCustomOverride.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.setPostProcessingMode(.refinement)
        model.saveLLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "sk",
            model: "gpt",
            refinementPrompt: "Use markdown bullets."
        )
        model.promptSettings = .init(
            defaultSelection: .none,
            appSelections: [PromptAppID.voicePi.rawValue: .legacyCustom]
        )

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let defaultPopup = try #require(findPopup(in: controller.window?.contentView, titled: "Default Prompt Template"))
        try selectPopupItem(named: "Meeting Notes", in: defaultPopup)
        savePromptSettings(in: controller)

        #expect(model.promptSelection(for: .voicePi).mode == .legacyCustom)
        #expect(model.promptSettings.defaultSelection.profileID == "meeting_notes")
    }

}

@MainActor
private func savePromptSettings(in controller: SettingsWindowController) {
    _ = controller.perform(NSSelectorFromString("saveConfiguration"))
}

@MainActor
private func selectPopupItem(named title: String, in popup: NSPopUpButton) throws {
    let index = popup.indexOfItem(withTitle: title)
    #expect(index >= 0)
    popup.selectItem(at: index)

    if let action = popup.action {
        NSApp.sendAction(action, to: popup.target, from: popup)
    }
}

private func findPopup(in root: NSView?, titled title: String) -> NSPopUpButton? {
    findPreferenceControl(in: root, titled: title, as: NSPopUpButton.self)
}

private func colorAttribute(from title: NSAttributedString?) -> NSColor? {
    guard let title, title.length > 0 else { return nil }
    return title.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
}

private func findPreferenceControl<T: NSView>(in root: NSView?, titled title: String, as type: T.Type) -> T? {
    guard let root else { return nil }

    for row in allSubviews(of: root).compactMap({ $0 as? NSStackView }) {
        let labels = row.arrangedSubviews.compactMap { $0 as? NSTextField }
        guard labels.contains(where: { $0.stringValue == title }) else { continue }

        for arranged in row.arrangedSubviews {
            if let control = arranged as? T {
                return control
            }
            if let nested = findSubview(in: arranged, ofType: T.self) {
                return nested
            }
        }
    }

    return nil
}

private func findSubview<T: NSView>(
    in root: NSView?,
    ofType type: T.Type,
    where predicate: ((T) -> Bool)? = nil
) -> T? {
    guard let root else { return nil }
    if let match = root as? T, predicate?(match) ?? true {
        return match
    }

    for subview in root.subviews {
        if let match = findSubview(in: subview, ofType: type, where: predicate) {
            return match
        }
    }

    return nil
}

private func allSubviews(of root: NSView) -> [NSView] {
    [root] + root.subviews.flatMap(allSubviews(of:))
}

private extension NSColor {
    func isApproximatelyEqual(to other: NSColor, tolerance: CGFloat = 0.002) -> Bool {
        guard
            let lhs = usingColorSpace(.deviceRGB),
            let rhs = other.usingColorSpace(.deviceRGB)
        else {
            return false
        }

        return abs(lhs.redComponent - rhs.redComponent) <= tolerance &&
            abs(lhs.greenComponent - rhs.greenComponent) <= tolerance &&
            abs(lhs.blueComponent - rhs.blueComponent) <= tolerance &&
            abs(lhs.alphaComponent - rhs.alphaComponent) <= tolerance
    }
}
