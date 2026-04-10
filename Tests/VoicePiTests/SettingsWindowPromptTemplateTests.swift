import Foundation
import Testing
@testable import VoicePi

struct SettingsWindowPromptTemplateTests {
    @Test
    @MainActor
    func promptEditorCopyAdaptsForNewPromptDraft() {
        let draft = SettingsWindowController.makeNewUserPromptDraft()

        #expect(SettingsWindowController.promptEditorSheetTitle(for: draft) == "New Prompt")
        #expect(SettingsWindowController.promptEditorPrimaryActionTitle(for: draft) == "Create Prompt")
    }

    @Test
    @MainActor
    func promptEditorCopyAdaptsForExistingPrompt() {
        let draft = PromptPreset(
            id: "user.reply",
            title: "Reply",
            body: "Keep this concise.",
            source: .user
        )

        #expect(SettingsWindowController.promptEditorSheetTitle(for: draft) == "Edit Prompt")
        #expect(SettingsWindowController.promptEditorPrimaryActionTitle(for: draft) == "Save Prompt")
    }

    @Test
    @MainActor
    func promptEditorBodyHintExplainsDefaultFallback() {
        #expect(
            SettingsWindowController.promptEditorBodyHintText
                == "Add the instructions VoicePi should apply here. Leave it empty to keep the default refinement rules and only use this prompt for bindings."
        )
    }

    @Test
    @MainActor
    func promptEditorExposesBindingActionBarCopy() {
        #expect(SettingsWindowController.promptBindingActionBarTitle == "Bindings")
        #expect(SettingsWindowController.promptBindingsButtonTitle == "Bindings")
        #expect(SettingsWindowController.captureFrontmostAppButtonTitle == "Capture Frontmost App")
        #expect(SettingsWindowController.captureCurrentWebsiteButtonTitle == "Capture Current Website")
    }

    @Test
    @MainActor
    func externalProcessorManagerCopyMatchesDesign() {
        #expect(SettingsWindowController.refinementProviderLabel == "Refinement Provider")
        #expect(SettingsWindowController.externalProcessorManagerSheetTitle == "Processors")
        #expect(SettingsWindowController.externalProcessorManagerManageButtonTitle == "Processors")
        #expect(SettingsWindowController.externalProcessorManagerAddProcessorButtonTitle == "+")
        #expect(SettingsWindowController.externalProcessorManagerAddArgumentButtonTitle == "+")
        #expect(
            SettingsWindowController.externalProcessorManagerEmptyStateText
                == "No processors configured yet. Click + to add one."
        )
    }

    @Test
    @MainActor
    func strictModeCopyMatchesDesign() {
        #expect(SettingsWindowController.strictModeToggleLabel == "Strict Mode")
        #expect(
            SettingsWindowController.strictModeHelpText
                == "When on, app bindings override the active prompt for matching apps. When off, VoicePi always uses the active prompt."
        )
        #expect(
            SettingsWindowController.strictModeSummaryText(enabled: true)
                == "Strict Mode on • Matching app bindings override Active Prompt"
        )
        #expect(
            SettingsWindowController.strictModeSummaryText(enabled: false)
                == "Strict Mode off • Always uses Active Prompt"
        )
    }

    @Test
    @MainActor
    func singleAppBindingConflictAlertUsesExplicitReassignmentCopy() {
        let content = SettingsWindowController.promptAppBindingConflictAlertContent(
            for: [
                .init(
                    appBundleID: "com.tinyspeck.slackmacgap",
                    owners: [.init(presetID: "user.reply", title: "Customer Reply")]
                )
            ],
            destinationPromptTitle: "Standup Notes"
        )

        #expect(
            content.messageText
                == "com.tinyspeck.slackmacgap is already bound to “Customer Reply”."
        )
        #expect(
            content.informativeText
                == "Do you want to unbind it there and bind it to “Standup Notes” instead?"
        )
    }

    @Test
    @MainActor
    func multipleAppBindingConflictsAreSummarizedInSingleAlert() {
        let content = SettingsWindowController.promptAppBindingConflictAlertContent(
            for: [
                .init(
                    appBundleID: "com.figma.desktop",
                    owners: [.init(presetID: "user.spec", title: "Design Specs")]
                ),
                .init(
                    appBundleID: "com.tinyspeck.slackmacgap",
                    owners: [.init(presetID: "user.reply", title: "Customer Reply")]
                )
            ],
            destinationPromptTitle: "Standup Notes"
        )

        #expect(content.messageText == "Some apps are already bound to other prompts.")
        #expect(content.informativeText.contains("com.figma.desktop → Design Specs"))
        #expect(content.informativeText.contains("com.tinyspeck.slackmacgap → Customer Reply"))
        #expect(content.informativeText.contains("Standup Notes"))
    }

    @Test
    @MainActor
    func bindingEntryActionMatchesPromptSourceRules() {
        #expect(SettingsWindowController.bindingEntryAction(for: .builtInDefault) == .createFromDefault)
        #expect(SettingsWindowController.bindingEntryAction(for: .starter) == .createFromStarter)
        #expect(SettingsWindowController.bindingEntryAction(for: .user) == .editUser)
    }

    @Test
    @MainActor
    func makeNewUserPromptDraftCreatesEmptyUserPromptWhenNoTemplateProvided() {
        let draft = SettingsWindowController.makeNewUserPromptDraft()
        #expect(draft.source == .user)
        #expect(draft.title == "New Prompt")
        #expect(draft.body.isEmpty)
        #expect(draft.appBundleIDs.isEmpty)
        #expect(draft.websiteHosts.isEmpty)
    }

    @Test
    @MainActor
    func makeNewUserPromptDraftCopiesTemplateBindingsAndBody() {
        let template = PromptPreset(
            id: "meeting_notes",
            title: "Meeting Notes",
            body: "Turn this into concise structured notes.",
            source: .starter,
            appBundleIDs: ["com.figma.desktop"],
            websiteHosts: ["mail.google.com"]
        )
        let draft = SettingsWindowController.makeNewUserPromptDraft(template: template)
        #expect(draft.source == .user)
        #expect(draft.title == "Meeting Notes Copy")
        #expect(draft.body == template.body)
        #expect(draft.appBundleIDs == ["com.figma.desktop"])
        #expect(draft.websiteHosts == ["mail.google.com"])
    }

    @Test
    @MainActor
    func makeNewUserPromptDraftPrefillsCapturedWebsiteBinding() {
        let draft = SettingsWindowController.makeNewUserPromptDraft(
            prefillingCapturedValue: "https://MAIL.google.com/inbox",
            kind: .websiteHost
        )

        #expect(draft.source == .user)
        #expect(draft.title == "New Prompt")
        #expect(draft.body.isEmpty)
        #expect(draft.appBundleIDs.isEmpty)
        #expect(draft.websiteHosts == ["mail.google.com"])
    }

    @Test
    @MainActor
    func makeNewUserPromptDraftPrefillsCapturedAppBinding() {
        let draft = SettingsWindowController.makeNewUserPromptDraft(
            prefillingCapturedValue: " COM.GOOGLE.CHROME ",
            kind: .appBundleID
        )

        #expect(draft.source == .user)
        #expect(draft.title == "New Prompt")
        #expect(draft.body.isEmpty)
        #expect(draft.appBundleIDs == ["com.google.chrome"])
        #expect(draft.websiteHosts.isEmpty)
    }

    @Test
    @MainActor
    func mergeBindingFieldTextNormalizesAndDeduplicatesAppBundleIDs() {
        let merged = SettingsWindowController.mergeBindingFieldText(
            existingText: "com.google.Chrome,  com.figma.Desktop",
            capturedRawValue: " COM.GOOGLE.CHROME ",
            kind: .appBundleID
        )

        #expect(merged == "com.google.chrome, com.figma.desktop")
    }

    @Test
    @MainActor
    func mergeBindingFieldTextNormalizesAndDeduplicatesWebsiteHosts() {
        let merged = SettingsWindowController.mergeBindingFieldText(
            existingText: "mail.google.com",
            capturedRawValue: "https://MAIL.google.com/inbox",
            kind: .websiteHost
        )

        #expect(merged == "mail.google.com")
    }

    @Test
    @MainActor
    func mergeBindingFieldTextAppendsNewCapturedWebsiteHost() {
        let merged = SettingsWindowController.mergeBindingFieldText(
            existingText: "trello.com",
            capturedRawValue: "https://app.notion.so/page",
            kind: .websiteHost
        )

        #expect(merged == "trello.com, app.notion.so")
    }

    @Test
    @MainActor
    func creatingUserPromptSelectsItImmediately() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.creatingUserPromptSelectsItImmediately.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        let preset = model.createUserPromptPreset(
            title: "Standup",
            body: "Format as a short standup update."
        )

        #expect(model.promptWorkspace.activeSelection == .preset(preset.id))
        #expect(model.promptWorkspace.userPresets == [preset])
        #expect(model.resolvedPromptPreset().title == "Standup")
        #expect(model.resolvedRefinementPrompt(for: .voicePi) == "Format as a short standup update.")
    }

    @Test
    @MainActor
    func duplicatePromptPresetCreatesEditableUserCopyOfStarterPrompt() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.duplicatePromptPresetCreatesEditableUserCopyOfStarterPrompt.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        let duplicated = try #require(model.duplicatePromptPreset(id: "meeting_notes"))

        #expect(duplicated.source == .user)
        #expect(duplicated.title == "Meeting Notes Copy")
        #expect(duplicated.body.contains("concise structured notes") == true)
        #expect(model.promptWorkspace.activeSelection == .preset(duplicated.id))
        #expect(model.promptWorkspace.userPresets == [duplicated])
    }

    @Test
    @MainActor
    func duplicatePromptPresetCreatesCopyOfUserPromptAndSelectsCopy() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.duplicatePromptPresetCreatesCopyOfUserPromptAndSelectsCopy.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let original = model.createUserPromptPreset(
            title: "Slack Reply",
            body: "Keep replies concise and friendly."
        )

        let duplicated = try #require(model.duplicatePromptPreset(id: original.id))

        #expect(duplicated.id != original.id)
        #expect(duplicated.source == .user)
        #expect(duplicated.title == "Slack Reply Copy")
        #expect(duplicated.body == "Keep replies concise and friendly.")
        #expect(model.promptWorkspace.activeSelection == .preset(duplicated.id))
        #expect(model.promptWorkspace.userPresets.count == 2)
    }

    @Test
    @MainActor
    func creatingUserPromptStoresBindings() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.creatingUserPromptStoresBindings.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        let preset = model.createUserPromptPreset(
            title: "Gmail Reply",
            body: "Draft a concise email response.",
            appBundleIDs: ["com.google.chrome"],
            websiteHosts: ["mail.google.com"]
        )

        #expect(preset.appBundleIDs == ["com.google.chrome"])
        #expect(preset.websiteHosts == ["mail.google.com"])
        #expect(model.promptWorkspace.userPresets == [preset])
    }

    @Test
    @MainActor
    func savingBoundPromptKeepsBuiltInDefaultActiveForAutomaticBindings() {
        let savedPreset = PromptPreset(
            id: "user.slack",
            title: "Slack Reply",
            body: "Keep Slack replies concise.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )

        let selection = SettingsWindowController.activeSelectionAfterSavingPromptEditor(
            previousSelection: .builtInDefault,
            savedPreset: savedPreset
        )

        #expect(selection == .builtInDefault)
    }

    @Test
    @MainActor
    func savingBoundPromptPreservesExistingManualSelection() {
        let savedPreset = PromptPreset(
            id: "user.slack",
            title: "Slack Reply",
            body: "Keep Slack replies concise.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )

        let selection = SettingsWindowController.activeSelectionAfterSavingPromptEditor(
            previousSelection: .preset("user.manual"),
            savedPreset: savedPreset
        )

        #expect(selection == .preset("user.manual"))
    }

    @Test
    @MainActor
    func savingUnboundPromptSelectsItImmediately() {
        let savedPreset = PromptPreset(
            id: "user.custom",
            title: "Custom",
            body: "Summarize tersely.",
            source: .user
        )

        let selection = SettingsWindowController.activeSelectionAfterSavingPromptEditor(
            previousSelection: .builtInDefault,
            savedPreset: savedPreset
        )

        #expect(selection == .preset(savedPreset.id))
    }

    @Test
    @MainActor
    func promptEditorSavePersistsWorkspaceImmediatelyAndAcrossReload() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.promptEditorSavePersistsWorkspaceImmediatelyAndAcrossReload.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        var promptWorkspaceDraft = PromptWorkspaceSettings(
            activeSelection: .builtInDefault,
            strictModeEnabled: false
        )
        let savedPreset = PromptPreset(
            id: "user.standup",
            title: "Standup",
            body: "Format this as a short standup update.",
            source: .user
        )

        let persisted = SettingsWindowController.persistPromptEditorSaveResult(
            model: model,
            promptWorkspaceDraft: &promptWorkspaceDraft,
            savedPreset: savedPreset,
            confirmedConflictReassignment: false
        )

        #expect(persisted)
        #expect(model.promptWorkspace == promptWorkspaceDraft)
        #expect(model.promptWorkspace.activeSelection == .preset(savedPreset.id))
        #expect(model.promptWorkspace.userPreset(id: savedPreset.id) == savedPreset)

        let reloaded = AppModel(defaults: defaults)
        #expect(reloaded.promptWorkspace == model.promptWorkspace)
        #expect(reloaded.promptWorkspace.userPreset(id: savedPreset.id) == savedPreset)
    }

    @Test
    @MainActor
    func promptEditorSaveDoesNotCommitUnrelatedLLMCredentials() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.promptEditorSaveDoesNotCommitUnrelatedLLMCredentials.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.saveLLMConfiguration(
            baseURL: "https://saved.example.com/v1",
            apiKey: "saved-key",
            model: "gpt-4o-mini"
        )
        let initialLLMConfiguration = model.llmConfiguration
        var promptWorkspaceDraft = model.promptWorkspace
        let savedPreset = PromptPreset(
            id: "user.custom",
            title: "Custom",
            body: "Summarize in plain language.",
            source: .user
        )

        let persisted = SettingsWindowController.persistPromptEditorSaveResult(
            model: model,
            promptWorkspaceDraft: &promptWorkspaceDraft,
            savedPreset: savedPreset,
            confirmedConflictReassignment: false
        )

        #expect(persisted)
        #expect(model.llmConfiguration == initialLLMConfiguration)
    }

    @Test
    @MainActor
    func promptEditorSavePreservesUnrelatedPromptWorkspaceDraftState() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.promptEditorSavePreservesUnrelatedPromptWorkspaceDraftState.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let pinnedPreset = PromptPreset(
            id: "user.pinned",
            title: "Pinned",
            body: "Keep this selected manually.",
            source: .user
        )
        var promptWorkspaceDraft = PromptWorkspaceSettings(
            activeSelection: .preset(pinnedPreset.id),
            strictModeEnabled: false,
            userPresets: [pinnedPreset]
        )
        let savedPreset = PromptPreset(
            id: "user.gmail",
            title: "Gmail Reply",
            body: "Draft a concise email response.",
            source: .user,
            websiteHosts: ["mail.google.com"]
        )

        let persisted = SettingsWindowController.persistPromptEditorSaveResult(
            model: model,
            promptWorkspaceDraft: &promptWorkspaceDraft,
            savedPreset: savedPreset,
            confirmedConflictReassignment: false
        )

        #expect(persisted)
        #expect(promptWorkspaceDraft.strictModeEnabled == false)
        #expect(promptWorkspaceDraft.activeSelection == .preset(pinnedPreset.id))
        #expect(promptWorkspaceDraft.userPreset(id: pinnedPreset.id) == pinnedPreset)
        #expect(promptWorkspaceDraft.userPreset(id: savedPreset.id) == savedPreset)
        #expect(model.promptWorkspace == promptWorkspaceDraft)
    }

    @Test
    @MainActor
    func promptEditorSavePersistenceKeepsBuiltInDefaultSelectedForBoundPrompt() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.promptEditorSavePersistenceKeepsBuiltInDefaultSelectedForBoundPrompt.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        var promptWorkspaceDraft = PromptWorkspaceSettings(activeSelection: .builtInDefault)
        let savedPreset = PromptPreset(
            id: "user.slack",
            title: "Slack Reply",
            body: "Keep Slack replies concise.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )

        let persisted = SettingsWindowController.persistPromptEditorSaveResult(
            model: model,
            promptWorkspaceDraft: &promptWorkspaceDraft,
            savedPreset: savedPreset,
            confirmedConflictReassignment: false
        )

        #expect(persisted)
        #expect(promptWorkspaceDraft.activeSelection == .builtInDefault)
        #expect(model.promptWorkspace.activeSelection == .builtInDefault)
    }

    @Test
    @MainActor
    func cancellingPromptEditorConflictReassignmentLeavesDraftAndModelUnchanged() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.cancellingPromptEditorConflictReassignmentLeavesDraftAndModelUnchanged.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let existing = PromptPreset(
            id: "user.customer-reply",
            title: "Customer Reply",
            body: "",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        model.promptWorkspace = PromptWorkspaceSettings(
            activeSelection: .preset(existing.id),
            strictModeEnabled: false,
            userPresets: [existing]
        )
        var promptWorkspaceDraft = PromptWorkspaceSettings(
            activeSelection: .preset(existing.id),
            strictModeEnabled: false,
            userPresets: [existing]
        )
        let edited = PromptPreset(
            id: "user.standup",
            title: "Standup Notes",
            body: "",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let initialDraft = promptWorkspaceDraft
        let initialModelWorkspace = model.promptWorkspace

        let persisted = SettingsWindowController.persistPromptEditorSaveResult(
            model: model,
            promptWorkspaceDraft: &promptWorkspaceDraft,
            savedPreset: edited,
            confirmedConflictReassignment: false
        )

        #expect(!persisted)
        #expect(promptWorkspaceDraft == initialDraft)
        #expect(model.promptWorkspace == initialModelWorkspace)
    }

    @Test
    @MainActor
    func duplicatePromptPresetPreservesBindings() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.duplicatePromptPresetPreservesBindings.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let original = model.createUserPromptPreset(
            title: "Support",
            body: "Reply like a support agent.",
            appBundleIDs: ["com.tinyspeck.slackmacgap"],
            websiteHosts: ["trello.com"]
        )

        let duplicated = try #require(model.duplicatePromptPreset(id: original.id))

        #expect(duplicated.appBundleIDs == ["com.tinyspeck.slackmacgap"])
        #expect(duplicated.websiteHosts == ["trello.com"])
    }

    @Test
    @MainActor
    func builtInDefaultSelectionLeavesNoEditableMiddleSection() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.builtInDefaultSelectionLeavesNoEditableMiddleSection.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        model.setActivePromptSelection(.builtInDefault)

        #expect(model.resolvedPromptPreset().title == "VoicePi Default")
        #expect(model.resolvedPromptPreset().source == .builtInDefault)
        #expect(model.resolvedRefinementPrompt(for: .voicePi) == nil)
    }

    @Test
    @MainActor
    func deletingActiveUserPromptFallsBackToDefault() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.deletingActiveUserPromptFallsBackToDefault.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let preset = model.createUserPromptPreset(
            title: "Custom",
            body: "Respond with a short summary."
        )

        model.deleteUserPromptPreset(id: preset.id)

        #expect(model.promptWorkspace.activeSelection == .builtInDefault)
        #expect(model.promptWorkspace.userPresets.isEmpty)
        #expect(model.resolvedPromptPreset().source == .builtInDefault)
    }

    @Test
    @MainActor
    func deletingNonUserPromptIDDoesNothing() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.deletingNonUserPromptIDDoesNothing.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.setActivePromptSelection(.preset("meeting_notes"))
        let initialWorkspace = model.promptWorkspace

        model.deleteUserPromptPreset(id: "meeting_notes")

        #expect(model.promptWorkspace == initialWorkspace)
        #expect(model.resolvedPromptPreset().title == "Meeting Notes")
        #expect(model.resolvedPromptPreset().source == .starter)
    }
}
