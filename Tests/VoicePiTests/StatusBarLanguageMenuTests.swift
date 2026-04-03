import AppKit
import Foundation
import Testing
@testable import VoicePi

struct StatusBarLanguageMenuTests {
    @Test
    @MainActor
    func menuIncludesDirectCheckForUpdatesAction() {
        #expect(
            StatusBarController.primaryMenuActionTitles == [
                "Language",
                "Text Processing",
                "Check for Updates…",
                "Settings…",
                "Quit VoicePi"
            ]
        )
    }

    @Test
    @MainActor
    func outputLanguageStaysSelectableWhenRefinementModeIsOn() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.outputLanguageStaysSelectableWhenRefinementModeIsOn.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.selectedLanguage = .english
        model.setTargetLanguage(.japanese)
        model.setPostProcessingMode(.refinement)

        let presentation = LanguageMenuPresentation.make(model: model)

        #expect(presentation.outputSelectionEnabled)
        #expect(presentation.effectiveOutputLanguage == .japanese)
        #expect(presentation.outputSummary == "Current Output: \(SupportedLanguage.japanese.menuTitle)")
        #expect(presentation.outputItems.filter { $0.isSelected }.map { $0.language } == [SupportedLanguage.japanese])
        #expect(presentation.outputItems.allSatisfy { $0.isEnabled })
    }

    @Test
    @MainActor
    func outputLanguageBecomesSelectableWhenTranslateModeIsOn() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.outputLanguageBecomesSelectableWhenTranslateModeIsOn.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.selectedLanguage = .english
        model.setTargetLanguage(.japanese)
        model.setPostProcessingMode(.translation)

        let presentation = LanguageMenuPresentation.make(model: model)

        #expect(presentation.outputSelectionEnabled)
        #expect(presentation.effectiveOutputLanguage == .japanese)
        #expect(presentation.outputSummary == "Current Output: \(SupportedLanguage.japanese.menuTitle)")
        #expect(presentation.outputItems.filter { $0.isSelected }.map { $0.language } == [SupportedLanguage.japanese])
        #expect(presentation.outputItems.allSatisfy { $0.isEnabled })
    }

    @Test
    @MainActor
    func selectingOutputLanguageUpdatesTargetLanguageWhenRefinementModeIsOn() {
        _ = NSApplication.shared
        let defaults = UserDefaults(suiteName: "VoicePiTests.selectingOutputLanguageUpdatesTargetLanguageWhenRefinementModeIsOn.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.selectedLanguage = .english
        model.setTargetLanguage(.japanese)
        model.setPostProcessingMode(.refinement)

        let controller = StatusBarController(model: model)
        let item = NSMenuItem()
        item.representedObject = SupportedLanguage.korean.rawValue

        _ = controller.perform(NSSelectorFromString("selectOutputLanguage:"), with: item)

        #expect(model.targetLanguage == .korean)
    }

    @Test
    @MainActor
    func outputLanguageIsUnavailableWhenTextProcessingIsDisabled() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.outputLanguageIsUnavailableWhenTextProcessingIsDisabled.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.selectedLanguage = .english
        model.setTargetLanguage(.japanese)
        model.setPostProcessingMode(.disabled)

        let presentation = LanguageMenuPresentation.make(model: model)

        #expect(presentation.outputSelectionEnabled == false)
        #expect(presentation.effectiveOutputLanguage == .english)
        #expect(presentation.outputSummary == "Output unavailable while text processing is disabled")
        #expect(presentation.outputItems.isEmpty)
    }
}
