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
