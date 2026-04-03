import AppKit
import Foundation
import Testing
@testable import VoicePi

struct AppModelPersistenceTests {
    @Test
    @MainActor
    func postProcessingAndRemoteConfigurationsPersistAcrossReloads() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.postProcessingAndRemoteConfigurationsPersistAcrossReloads.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        model.setPostProcessingMode(.refinement)
        model.setTranslationProvider(.llm)
        model.setTargetLanguage(.japanese)
        model.promptSettings.defaultSelection = .profile(
            "meeting_notes",
            optionSelections: ["output_format": ["markdown"]]
        )
        model.setPromptSelection(
            .none,
            for: .voicePi
        )
        model.saveLLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "llm-key",
            model: "gpt-4o-mini",
            refinementPrompt: "Return a markdown checklist."
        )
        model.setASRBackend(.remoteOpenAICompatible)
        model.saveRemoteASRConfiguration(baseURL: "https://asr.example.com", apiKey: "asr-key", model: "whisper", prompt: "Prefer punctuation")
        model.setActivationShortcut(ActivationShortcut(keyCodes: [0, 1], modifierFlagsRawValue: 0))
        model.setModeCycleShortcut(
            ActivationShortcut(
                keyCodes: [49],
                modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .shift]).intersection(.deviceIndependentFlagsMask).rawValue
            )
        )

        let reloaded = AppModel(defaults: defaults)

        #expect(reloaded.postProcessingMode == .refinement)
        #expect(reloaded.translationProvider == .llm)
        #expect(reloaded.targetLanguage == .japanese)
        #expect(
            reloaded.promptSettings.defaultSelection == .profile(
                "meeting_notes",
                optionSelections: ["output_format": ["markdown"]]
            )
        )
        #expect(reloaded.promptSelection(for: .voicePi) == .none)
        #expect(
            reloaded.llmConfiguration == .init(
                baseURL: "https://llm.example.com",
                apiKey: "llm-key",
                model: "gpt-4o-mini",
                refinementPrompt: "Return a markdown checklist."
            )
        )
        #expect(reloaded.asrBackend == .remoteOpenAICompatible)
        #expect(reloaded.remoteASRConfiguration == .init(baseURL: "https://asr.example.com", apiKey: "asr-key", model: "whisper", prompt: "Prefer punctuation"))
        #expect(reloaded.activationShortcut == ActivationShortcut(keyCodes: [0, 1], modifierFlagsRawValue: 0))
        #expect(
            reloaded.modeCycleShortcut == ActivationShortcut(
                keyCodes: [49],
                modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .shift]).intersection(.deviceIndependentFlagsMask).rawValue
            )
        )
    }

    @Test
    @MainActor
    func readinessFlagsReflectCurrentConfiguration() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.readinessFlagsReflectCurrentConfiguration.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        #expect(model.isLLMReady == false)
        #expect(model.isRemoteASRReady == false)

        model.setPostProcessingMode(.translation)
        model.setTranslationProvider(.appleTranslate)
        model.saveLLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "llm-key",
            model: "gpt",
            refinementPrompt: "Use sentence case."
        )
        model.setASRBackend(.remoteOpenAICompatible)
        model.saveRemoteASRConfiguration(baseURL: "https://asr.example.com", apiKey: "asr-key", model: "whisper", prompt: "")

        #expect(model.isLLMReady)
        #expect(model.isRemoteASRReady)
        #expect(model.translationProvider == .appleTranslate)
    }

    @Test
    @MainActor
    func legacyRefinementPromptMigratesToLegacyCustomSelection() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.legacyRefinementPromptMigratesToLegacyCustomSelection.\(UUID().uuidString)")!
        let legacyConfiguration = LLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "llm-key",
            model: "gpt",
            refinementPrompt: "Use markdown bullets."
        )
        let data = try! JSONEncoder().encode(legacyConfiguration)
        defaults.set(data, forKey: AppModel.Keys.llmConfig)

        let model = AppModel(defaults: defaults)

        #expect(model.promptSelection(for: .voicePi).mode == .legacyCustom)
        #expect(model.resolvedRefinementPrompt(for: .voicePi)?.contains("Use markdown bullets.") == true)
    }

    @Test
    @MainActor
    func emptyLegacyRefinementPromptDefaultsToInherit() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.emptyLegacyRefinementPromptDefaultsToInherit.\(UUID().uuidString)")!
        let legacyConfiguration = LLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "llm-key",
            model: "gpt",
            refinementPrompt: ""
        )
        let data = try! JSONEncoder().encode(legacyConfiguration)
        defaults.set(data, forKey: AppModel.Keys.llmConfig)

        let model = AppModel(defaults: defaults)

        #expect(model.promptSelection(for: .voicePi) == .inherit)
        #expect(model.resolvedRefinementPrompt(for: .voicePi) == nil)
    }

    @Test
    @MainActor
    func promptResolutionDiagnosticsExposeResolverFailureWhileRemainingFailClosed() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.promptResolutionDiagnosticsExposeResolverFailureWhileRemainingFailClosed.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.promptSettings.defaultSelection = .profile("unsupported_profile")
        model.setPromptSelection(.inherit, for: .voicePi)

        let diagnostics = model.promptResolutionDiagnostics(for: .voicePi)

        #expect(diagnostics.resolvedSelection == nil)
        #expect(diagnostics.error == .library(.disallowedProfile("unsupported_profile", .voicePi)))
        #expect(model.resolvedPromptSelection(for: .voicePi) == nil)
        #expect(model.resolvedRefinementPrompt(for: .voicePi) == nil)
    }

    @Test
    func translationProviderAvailabilityHidesAppleTranslateWhenUnsupported() {
        #expect(TranslationProvider.availableProviders(appleTranslateSupported: true) == [.appleTranslate, .llm])
        #expect(TranslationProvider.availableProviders(appleTranslateSupported: false) == [.llm])
    }

    @Test
    @MainActor
    func effectiveTranslationProviderFallsBackWhenPersistedProviderIsUnavailable() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.effectiveTranslationProviderFallsBackWhenPersistedProviderIsUnavailable.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        model.setPostProcessingMode(.translation)
        model.setTranslationProvider(.appleTranslate)

        #expect(model.effectiveTranslationProvider(appleTranslateSupported: true) == .appleTranslate)
        #expect(model.effectiveTranslationProvider(appleTranslateSupported: false) == .llm)
    }

    @Test
    @MainActor
    func overlayUpdatesClampLevelAndResetState() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.overlayUpdatesClampLevelAndResetState.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        model.updateOverlayRecording(transcript: "hello", level: 5)
        #expect(model.overlayState == .init(phase: .recording, transcript: "hello", level: 1))
        #expect(model.recordingState == .recording)
        #expect(model.overlayState.statusText == "hello")

        model.updateOverlayRefining()
        #expect(model.overlayState == .init(phase: .refining, transcript: "Refining...", level: 1))
        #expect(model.recordingState == .refining)
        #expect(model.overlayState.statusText == "Refining...")

        model.hideOverlay()
        #expect(model.overlayState == .init())
        #expect(model.recordingState == .idle)
    }

    @Test
    @MainActor
    func modeCycleShortcutDefaultsToNotSetAndCyclesDisabledRefinementTranslation() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.modeCycleShortcutDefaultsToNotSetAndCyclesDisabledRefinementTranslation.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        #expect(model.modeCycleShortcut.isEmpty)
        #expect(model.postProcessingMode == .disabled)

        model.cyclePostProcessingMode()
        #expect(model.postProcessingMode == .refinement)

        model.cyclePostProcessingMode()
        #expect(model.postProcessingMode == .translation)

        model.cyclePostProcessingMode()
        #expect(model.postProcessingMode == .disabled)
    }

    @Test
    @MainActor
    func activationShortcutDefaultsToAStandardRegisteredHotkey() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.activationShortcutDefaultsToAStandardRegisteredHotkey.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        #expect(model.activationShortcut.isRegisteredHotkeyCompatible)
        #expect(model.activationShortcut.requiresInputMonitoring == false)
    }
}
