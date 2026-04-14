import AppKit
import Foundation
import Testing
@testable import VoicePi

struct AppModelPersistenceTests {
    @Test
    @MainActor
    func legacyDefaultsFallBackToLLMRefinementProvider() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.legacyDefaultsFallBackToLLMRefinementProvider.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        #expect(model.refinementProvider == .llm)
        #expect(model.selectedExternalProcessorEntryID == nil)
        #expect(model.externalProcessorEntries.isEmpty)
        #expect(model.processorShortcut.isEmpty)
        #expect(model.promptCycleShortcut.isEmpty)
    }

    @Test
    @MainActor
    func externalProcessorSettingsPersistAcrossReloads() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.externalProcessorSettingsPersistAcrossReloads.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let primaryEntry = ExternalProcessorEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Alma CLI",
            kind: .almaCLI,
            executablePath: "/Users/pi-dal/.local/bin/alma",
            additionalArguments: [
                ExternalProcessorArgument(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    value: "--raw"
                ),
                ExternalProcessorArgument(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    value: "--no-stream"
                )
            ],
            isEnabled: true
        )
        let secondaryEntry = ExternalProcessorEntry(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "Alma CLI Backup",
            kind: .almaCLI,
            executablePath: "/opt/homebrew/bin/alma",
            additionalArguments: [
                ExternalProcessorArgument(
                    id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                    value: "-m"
                ),
                ExternalProcessorArgument(
                    id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                    value: "anthropic:claude"
                )
            ],
            isEnabled: false
        )

        model.refinementProvider = .externalProcessor
        model.externalProcessorEntries = [primaryEntry, secondaryEntry]
        model.selectedExternalProcessorEntryID = secondaryEntry.id

        let reloaded = AppModel(defaults: defaults)

        #expect(reloaded.refinementProvider == .externalProcessor)
        #expect(reloaded.selectedExternalProcessorEntryID == secondaryEntry.id)
        #expect(reloaded.externalProcessorEntries == [primaryEntry, secondaryEntry])
    }

    @Test
    @MainActor
    func selectedExternalProcessorSkipsDisabledEntries() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.selectedExternalProcessorSkipsDisabledEntries.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let disabledEntry = ExternalProcessorEntry(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            name: "Disabled Alma",
            kind: .almaCLI,
            executablePath: "alma",
            isEnabled: false
        )
        let enabledEntry = ExternalProcessorEntry(
            id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            name: "Enabled Alma",
            kind: .almaCLI,
            executablePath: "alma",
            isEnabled: true
        )

        model.externalProcessorEntries = [disabledEntry, enabledEntry]
        model.selectedExternalProcessorEntryID = disabledEntry.id

        #expect(model.selectedExternalProcessorEntry() == enabledEntry)
    }

    @Test
    @MainActor
    func postProcessingRemoteConfigurationAndPromptWorkspacePersistAcrossReloads() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.postProcessingAndRemoteConfigurationsPersistAcrossReloads.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let customPrompt = PromptPreset(
            id: "user-release-notes",
            title: "Release Notes",
            body: "Write concise release notes with short bullet points.",
            source: .user
        )

        model.setPostProcessingMode(.refinement)
        model.setTranslationProvider(.llm)
        model.setTargetLanguage(.japanese)
        model.promptWorkspace = .init(
            activeSelection: .preset(customPrompt.id),
            userPresets: [customPrompt]
        )
        model.saveLLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "llm-key",
            model: "gpt-4o-mini",
            refinementPrompt: ""
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
        model.setProcessorShortcut(
            ActivationShortcut(
                keyCodes: [35],
                modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .shift]).intersection(.deviceIndependentFlagsMask).rawValue
            )
        )
        model.setPromptCycleShortcut(
            ActivationShortcut(
                keyCodes: [31],
                modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
            )
        )

        let reloaded = AppModel(defaults: defaults)

        #expect(reloaded.postProcessingMode == .refinement)
        #expect(reloaded.translationProvider == .llm)
        #expect(reloaded.targetLanguage == .japanese)
        #expect(reloaded.promptWorkspace.activeSelection == .preset("user-release-notes"))
        #expect(reloaded.promptWorkspace.userPresets == [customPrompt])
        #expect(reloaded.resolvedPromptPreset().title == "Release Notes")
        #expect(reloaded.resolvedRefinementPrompt(for: .voicePi) == "Write concise release notes with short bullet points.")
        #expect(
            reloaded.llmConfiguration == .init(
                baseURL: "https://llm.example.com",
                apiKey: "llm-key",
                model: "gpt-4o-mini",
                refinementPrompt: ""
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
        #expect(
            reloaded.processorShortcut == ActivationShortcut(
                keyCodes: [35],
                modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .shift]).intersection(.deviceIndependentFlagsMask).rawValue
            )
        )
        #expect(
            reloaded.promptCycleShortcut == ActivationShortcut(
                keyCodes: [31],
                modifierFlagsRawValue: NSEvent.ModifierFlags([.command, .option]).intersection(.deviceIndependentFlagsMask).rawValue
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
    func volcengineRemoteASRReadinessRequiresAppID() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.volcengineRemoteASRReadinessRequiresAppID.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        model.setASRBackend(.remoteVolcengineASR)
        model.saveRemoteASRConfiguration(
            baseURL: "https://openspeech.bytedance.com/api/v3/sauc/bigmodel",
            apiKey: "ak-test",
            model: "bigmodel",
            prompt: "",
            volcengineAppID: ""
        )
        #expect(model.isRemoteASRReady == false)

        model.saveRemoteASRConfiguration(
            baseURL: "https://openspeech.bytedance.com/api/v3/sauc/bigmodel",
            apiKey: "ak-test",
            model: "bigmodel",
            prompt: "",
            volcengineAppID: "app-test"
        )
        #expect(model.isRemoteASRReady)
        #expect(model.remoteASRConfiguration.volcengineAppID == "app-test")
    }

    @Test
    @MainActor
    func legacyRefinementPromptMigratesToImportedUserPreset() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.legacyRefinementPromptMigratesToImportedUserPreset.\(UUID().uuidString)")!
        let legacyConfiguration = LLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "llm-key",
            model: "gpt",
            refinementPrompt: "Use markdown bullets."
        )
        let data = try! JSONEncoder().encode(legacyConfiguration)
        defaults.set(data, forKey: AppModel.Keys.llmConfig)

        let model = AppModel(defaults: defaults)

        #expect(model.promptWorkspace.activeSelection.mode == .preset)
        #expect(model.promptWorkspace.userPresets.count == 1)
        #expect(model.promptWorkspace.userPresets[0].title == "Imported Prompt")
        #expect(model.promptWorkspace.userPresets[0].body == "Use markdown bullets.")
        #expect(model.resolvedPromptPreset().source == .user)
        #expect(model.resolvedRefinementPrompt(for: .voicePi) == "Use markdown bullets.")
    }

    @Test
    @MainActor
    func emptyLegacyRefinementPromptDefaultsToBuiltInPrompt() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.emptyLegacyRefinementPromptDefaultsToBuiltInPrompt.\(UUID().uuidString)")!
        let legacyConfiguration = LLMConfiguration(
            baseURL: "https://llm.example.com",
            apiKey: "llm-key",
            model: "gpt",
            refinementPrompt: ""
        )
        let data = try! JSONEncoder().encode(legacyConfiguration)
        defaults.set(data, forKey: AppModel.Keys.llmConfig)

        let model = AppModel(defaults: defaults)

        #expect(model.promptWorkspace.activeSelection == .builtInDefault)
        #expect(model.promptWorkspace.userPresets.isEmpty)
        #expect(model.resolvedPromptPreset().source == .builtInDefault)
        #expect(model.resolvedRefinementPrompt(for: .voicePi) == nil)
    }

    @Test
    @MainActor
    func legacyPromptSettingsProfileSelectionMigratesToImportedUserPreset() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.legacyPromptSettingsProfileSelectionMigratesToImportedUserPreset.\(UUID().uuidString)")!
        let settings = PromptSettings(
            defaultSelection: .profile(
                "meeting_notes",
                optionSelections: ["output_format": ["markdown"]]
            ),
            appSelections: [PromptAppID.voicePi.rawValue: .inherit]
        )
        defaults.set(try JSONEncoder().encode(settings), forKey: AppModel.Keys.promptSettings)

        let model = AppModel(defaults: defaults)

        #expect(model.promptWorkspace.activeSelection.mode == .preset)
        #expect(model.promptWorkspace.userPresets.count == 1)
        #expect(model.promptWorkspace.userPresets[0].title == "Meeting Notes")
        #expect(model.promptWorkspace.userPresets[0].body.contains("concise structured meeting notes") == true)
        #expect(model.promptWorkspace.userPresets[0].body.contains("Markdown") == true)
        #expect(model.resolvedPromptPreset().source == .user)
    }

    @Test
    @MainActor
    func deletingActiveUserPresetFallsBackToBuiltInDefault() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.deletingActiveUserPresetFallsBackToBuiltInDefault.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let customPrompt = PromptPreset(
            id: "user-standup",
            title: "Standup",
            body: "Format as a short daily standup update.",
            source: .user
        )

        model.promptWorkspace = .init(
            activeSelection: .preset(customPrompt.id),
            userPresets: [customPrompt]
        )

        model.deleteUserPromptPreset(id: customPrompt.id)

        #expect(model.promptWorkspace.activeSelection == .builtInDefault)
        #expect(model.promptWorkspace.userPresets.isEmpty)
        #expect(model.resolvedPromptPreset().source == .builtInDefault)
        #expect(model.resolvedRefinementPrompt(for: .voicePi) == nil)
    }

    @Test
    @MainActor
    func promptBindingsPersistAcrossReloads() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.promptBindingsPersistAcrossReloads.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let slackPrompt = PromptPreset(
            id: "user-slack",
            title: "Slack Reply",
            body: "Respond like a concise Slack reply.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let gmailPrompt = PromptPreset(
            id: "user-gmail",
            title: "Gmail Reply",
            body: "Respond as a polished email draft.",
            source: .user,
            websiteHosts: ["mail.google.com"]
        )

        model.promptWorkspace = .init(
            activeSelection: .builtInDefault,
            userPresets: [slackPrompt, gmailPrompt]
        )

        let reloaded = AppModel(defaults: defaults)

        #expect(reloaded.promptWorkspace.userPresets == [slackPrompt, gmailPrompt])
        #expect(
            reloaded.resolvedPromptPreset(
                destination: .init(appBundleID: "com.tinyspeck.slackmacgap")
            ).title == "Slack Reply"
        )
        #expect(
            reloaded.resolvedPromptPreset(
                destination: .init(appBundleID: "com.google.Chrome", websiteHost: "mail.google.com")
            ).title == "Gmail Reply"
        )
    }

    @Test
    @MainActor
    func strictModeSettingPersistsAcrossReloads() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.strictModeSettingPersistsAcrossReloads.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        var workspace = model.promptWorkspace
        workspace.strictModeEnabled = false
        model.promptWorkspace = workspace

        let reloaded = AppModel(defaults: defaults)

        #expect(reloaded.promptWorkspace.strictModeEnabled == false)
    }

    @Test
    @MainActor
    func savingBoundPromptsFromDefaultKeepsAutomaticBindingsWorkingAcrossReloads() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.savingBoundPromptsFromDefaultKeepsAutomaticBindingsWorkingAcrossReloads.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let slackPrompt = PromptPreset(
            id: "user-slack",
            title: "Slack Reply",
            body: "Respond like a concise Slack reply.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let figmaPrompt = PromptPreset(
            id: "user-figma",
            title: "Figma Spec",
            body: "Turn this into a terse product spec.",
            source: .user,
            appBundleIDs: ["com.figma.Desktop"]
        )

        var workspace = PromptWorkspaceSettings()
        workspace.saveUserPreset(slackPrompt)
        workspace.activeSelection = SettingsWindowController.activeSelectionAfterSavingPromptEditor(
            previousSelection: workspace.activeSelection,
            savedPreset: slackPrompt
        )
        workspace.saveUserPreset(figmaPrompt)
        workspace.activeSelection = SettingsWindowController.activeSelectionAfterSavingPromptEditor(
            previousSelection: workspace.activeSelection,
            savedPreset: figmaPrompt
        )

        model.promptWorkspace = workspace

        let reloaded = AppModel(defaults: defaults)

        #expect(reloaded.promptWorkspace.activeSelection == .builtInDefault)
        #expect(
            reloaded.resolvedPromptPreset(
                destination: .init(appBundleID: "com.tinyspeck.slackmacgap")
            ).title == "Slack Reply"
        )
        #expect(
            reloaded.resolvedPromptPreset(
                destination: .init(appBundleID: "com.figma.Desktop")
            ).title == "Figma Spec"
        )
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
        #expect(model.promptCycleShortcut.isEmpty)
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

    @Test
    @MainActor
    func freshInstallPersistsStandardDefaultActivationShortcutAcrossReloads() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.freshInstallPersistsStandardDefaultActivationShortcutAcrossReloads.\(UUID().uuidString)")!
        let initial = AppModel(defaults: defaults)
        let reloaded = AppModel(defaults: defaults)

        #expect(initial.activationShortcut.isRegisteredHotkeyCompatible)
        #expect(reloaded.activationShortcut == initial.activationShortcut)
        #expect(reloaded.activationShortcut.requiresInputMonitoring == false)
        #expect(defaults.data(forKey: AppModel.Keys.activationShortcut) != nil)
    }

    @Test
    @MainActor
    func activationShortcutFallsBackToLegacyDefaultForExistingInstallWithoutSavedShortcut() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.activationShortcutFallsBackToLegacyDefaultForExistingInstallWithoutSavedShortcut.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.english.rawValue, forKey: AppModel.Keys.selectedLanguage)

        let model = AppModel(defaults: defaults)

        #expect(model.activationShortcut.menuTitle == "Option + Fn")
        #expect(model.activationShortcut.isModifierOnly)
        #expect(model.activationShortcut.requiresInputMonitoring)
    }
}
