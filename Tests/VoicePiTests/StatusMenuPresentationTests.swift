import Foundation
import Testing
@testable import VoicePi

struct StatusMenuPresentationTests {
    @Test
    @MainActor
    func statusMenuPresentationSplitsStatusLanguageAndPermissionsIntoSeparateLines() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.statusMenuPresentationSplitsStatusLanguageAndPermissionsIntoSeparateLines.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.selectedLanguage = .simplifiedChinese
        model.setTargetLanguage(.english)
        model.setPostProcessingMode(.translation)
        model.setMicrophoneAuthorization(.granted)
        model.setSpeechAuthorization(.granted)
        model.setAccessibilityAuthorization(.denied)
        model.setInputMonitoringAuthorization(.denied)

        let presentation = StatusMenuPresentation.make(
            model: model,
            transientStatus: "Global shortcut monitoring is unavailable.",
            isRecording: false
        )

        #expect(presentation.statusLine == "Global shortcut monitoring is unavailable.")
        #expect(presentation.languageLine == "Language: 简体中文 → English")
        #expect(presentation.permissionsLine == "Permissions: Mic ✓ / Speech ✓ / AX ✗ / IM ✗")
    }

    @Test
    @MainActor
    func statusMenuPresentationFallsBackToReadyWhenNoTransientStatusExists() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.statusMenuPresentationFallsBackToReadyWhenNoTransientStatusExists.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        let presentation = StatusMenuPresentation.make(
            model: model,
            transientStatus: nil,
            isRecording: false
        )

        #expect(presentation.statusLine == "Ready")
    }

    @Test
    @MainActor
    func statusMenuPresentationCompactsKnownAndLongErrorMessages() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.statusMenuPresentationCompactsKnownAndLongErrorMessages.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        let shortcutPresentation = StatusMenuPresentation.make(
            model: model,
            transientStatus: AppController.shortcutMonitoringFailureMessage,
            isRecording: false
        )
        #expect(shortcutPresentation.statusLine == "Shortcut unavailable")

        let accessibilityPresentation = StatusMenuPresentation.make(
            model: model,
            transientStatus: AppController.shortcutSuppressionWarningMessage,
            isRecording: false
        )
        #expect(accessibilityPresentation.statusLine == "Listening only")

        let translationPresentation = StatusMenuPresentation.make(
            model: model,
            transientStatus: "Translation via LLM failed: timeout while contacting upstream provider",
            isRecording: false
        )
        #expect(translationPresentation.statusLine == "Translation failed")

        let longPresentation = StatusMenuPresentation.make(
            model: model,
            transientStatus: "This is a very long status line that should be truncated before it stretches the menu too much.",
            isRecording: false
        )
        #expect(longPresentation.statusLine == "This is a very long status line that should…")
    }
}
