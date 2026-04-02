import Foundation
import Testing
@testable import VoicePi

struct StatusBarLanguageMenuTests {
    @Test
    @MainActor
    func outputLanguageFollowsInputWhenTranslateModeIsOff() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.outputLanguageFollowsInputWhenTranslateModeIsOff.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.selectedLanguage = .english
        model.setTargetLanguage(.japanese)
        model.setPostProcessingMode(.refinement)

        let presentation = LanguageMenuPresentation.make(model: model)

        #expect(presentation.outputSelectionEnabled == false)
        #expect(presentation.effectiveOutputLanguage == .english)
        #expect(presentation.outputSummary == "Follow Input: \(SupportedLanguage.english.menuTitle)")
        #expect(presentation.outputItems.filter { $0.isSelected }.map { $0.language } == [SupportedLanguage.english])
        #expect(presentation.outputItems.allSatisfy { $0.isEnabled == false })
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
}
