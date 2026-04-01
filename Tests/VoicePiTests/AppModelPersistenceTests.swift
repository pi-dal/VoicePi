import Foundation
import Testing
@testable import VoicePi

struct AppModelPersistenceTests {
    @Test
    @MainActor
    func llmAndRemoteConfigurationsPersistAcrossReloads() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.llmAndRemoteConfigurationsPersistAcrossReloads.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        model.llmEnabled = true
        model.saveLLMConfiguration(baseURL: "https://llm.example.com", apiKey: "llm-key", model: "gpt-4o-mini")
        model.setASRBackend(.remoteOpenAICompatible)
        model.saveRemoteASRConfiguration(baseURL: "https://asr.example.com", apiKey: "asr-key", model: "whisper", prompt: "Prefer punctuation")
        model.setActivationShortcut(ActivationShortcut(keyCodes: [0, 1], modifierFlagsRawValue: 0))

        let reloaded = AppModel(defaults: defaults)

        #expect(reloaded.llmEnabled)
        #expect(reloaded.llmConfiguration == .init(baseURL: "https://llm.example.com", apiKey: "llm-key", model: "gpt-4o-mini"))
        #expect(reloaded.asrBackend == .remoteOpenAICompatible)
        #expect(reloaded.remoteASRConfiguration == .init(baseURL: "https://asr.example.com", apiKey: "asr-key", model: "whisper", prompt: "Prefer punctuation"))
        #expect(reloaded.activationShortcut == ActivationShortcut(keyCodes: [0, 1], modifierFlagsRawValue: 0))
    }

    @Test
    @MainActor
    func readinessFlagsReflectCurrentConfiguration() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.readinessFlagsReflectCurrentConfiguration.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        #expect(model.isLLMReady == false)
        #expect(model.isRemoteASRReady == false)

        model.llmEnabled = true
        model.saveLLMConfiguration(baseURL: "https://llm.example.com", apiKey: "llm-key", model: "gpt")
        model.setASRBackend(.remoteOpenAICompatible)
        model.saveRemoteASRConfiguration(baseURL: "https://asr.example.com", apiKey: "asr-key", model: "whisper", prompt: "")

        #expect(model.isLLMReady)
        #expect(model.isRemoteASRReady)
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
}
