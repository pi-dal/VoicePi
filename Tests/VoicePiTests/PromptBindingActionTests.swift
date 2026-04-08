import Foundation
import Testing
@testable import VoicePi

struct PromptBindingActionTests {
    @Test
    @MainActor
    func bindingToUserPromptAppendsNormalizedWebsiteHost() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.bindingToUserPromptAppendsNormalizedWebsiteHost.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let prompt = model.createUserPromptPreset(
            title: "Gmail Reply",
            body: "Draft a concise email response."
        )

        let result = try #require(
            PromptBindingActions.apply(
                capturedRawValue: "https://MAIL.google.com/inbox",
                kind: .websiteHost,
                target: .preset(prompt.id),
                model: model
            )
        )

        #expect(result.preset.id == prompt.id)
        #expect(result.preset.websiteHosts == ["mail.google.com"])
        #expect(result.status == .added("mail.google.com"))
        #expect(model.promptWorkspace.userPresets == [result.preset])
        #expect(model.promptWorkspace.activeSelection == .preset(prompt.id))
    }

    @Test
    @MainActor
    func bindingToUserPromptDoesNotAppendDuplicateWebsiteHostTwice() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.bindingToUserPromptDoesNotAppendDuplicateWebsiteHostTwice.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let prompt = model.createUserPromptPreset(
            title: "Gmail Reply",
            body: "Draft a concise email response.",
            websiteHosts: ["mail.google.com"]
        )

        let result = try #require(
            PromptBindingActions.apply(
                capturedRawValue: "mail.google.com",
                kind: .websiteHost,
                target: .preset(prompt.id),
                model: model
            )
        )

        #expect(result.preset.websiteHosts == ["mail.google.com"])
        #expect(result.status == .alreadyPresent("mail.google.com"))
        #expect(model.promptWorkspace.userPresets == [result.preset])
    }

    @Test
    @MainActor
    func bindingToStarterPromptCreatesEditableCopyBeforeAppendingAppBundleID() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.bindingToStarterPromptCreatesEditableCopyBeforeAppendingAppBundleID.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        let result = try #require(
            PromptBindingActions.apply(
                capturedRawValue: " COM.GOOGLE.CHROME ",
                kind: .appBundleID,
                target: .preset("meeting_notes"),
                model: model
            )
        )

        #expect(result.preset.source == .user)
        #expect(result.preset.title == "Meeting Notes Copy")
        #expect(result.preset.appBundleIDs == ["com.google.chrome"])
        #expect(result.status == .added("com.google.chrome"))
        #expect(model.promptWorkspace.activeSelection == .preset(result.preset.id))
        #expect(model.promptWorkspace.userPresets == [result.preset])
    }

    @Test
    @MainActor
    func bindingToBuiltInDefaultCreatesNewUserPromptBeforeAppendingWebsiteHost() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.bindingToBuiltInDefaultCreatesNewUserPromptBeforeAppendingWebsiteHost.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)

        let result = try #require(
            PromptBindingActions.apply(
                capturedRawValue: "https://app.notion.so/page",
                kind: .websiteHost,
                target: .activeSelection,
                model: model
            )
        )

        #expect(result.preset.source == .user)
        #expect(result.preset.title == "New Prompt")
        #expect(result.preset.websiteHosts == ["app.notion.so"])
        #expect(result.status == .added("app.notion.so"))
        #expect(model.promptWorkspace.activeSelection == .preset(result.preset.id))
        #expect(model.promptWorkspace.userPresets == [result.preset])
    }

    @Test
    @MainActor
    func bindingAppBundleIDDraftReportsConflictsBeforeSaving() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.bindingAppBundleIDDraftReportsConflictsBeforeSaving.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let existing = model.createUserPromptPreset(
            title: "Customer Reply",
            body: "",
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let target = model.createUserPromptPreset(
            title: "Standup Notes",
            body: ""
        )

        let draft = try #require(
            PromptBindingActions.prepareSave(
                capturedRawValue: "com.tinyspeck.slackmacgap",
                kind: .appBundleID,
                target: .preset(target.id),
                model: model
            )
        )

        #expect(draft.preset.id == target.id)
        #expect(draft.preset.appBundleIDs == ["com.tinyspeck.slackmacgap"])
        #expect(draft.status == .added("com.tinyspeck.slackmacgap"))
        #expect(draft.conflicts == [
            .init(
                appBundleID: "com.tinyspeck.slackmacgap",
                owners: [
                    .init(
                        presetID: existing.id,
                        title: existing.resolvedTitle
                    )
                ]
            )
        ])
        #expect(model.promptWorkspace.userPreset(id: existing.id)?.appBundleIDs == ["com.tinyspeck.slackmacgap"])
        #expect(model.promptWorkspace.userPreset(id: target.id)?.appBundleIDs.isEmpty == true)
    }

    @Test
    @MainActor
    func savingPreparedAppBundleIDBindingCanReassignExistingOwnerAfterConfirmation() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.savingPreparedAppBundleIDBindingCanReassignExistingOwnerAfterConfirmation.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let existing = model.createUserPromptPreset(
            title: "Customer Reply",
            body: "",
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let target = model.createUserPromptPreset(
            title: "Standup Notes",
            body: ""
        )

        let draft = try #require(
            PromptBindingActions.prepareSave(
                capturedRawValue: "com.tinyspeck.slackmacgap",
                kind: .appBundleID,
                target: .preset(target.id),
                model: model
            )
        )

        let result = PromptBindingActions.commitPreparedSave(
            draft,
            model: model,
            reassigningConflictingAppBindings: true
        )

        #expect(result.preset.id == target.id)
        #expect(result.preset.appBundleIDs == ["com.tinyspeck.slackmacgap"])
        #expect(model.promptWorkspace.userPreset(id: existing.id)?.appBundleIDs.isEmpty == true)
    }

    @Test
    @MainActor
    func pickerTargetsPreferActivePromptAndThenListRemainingPrompts() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.pickerTargetsPreferActivePromptAndThenListRemainingPrompts.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let alpha = model.createUserPromptPreset(title: "Alpha", body: "")
        let zebra = model.createUserPromptPreset(title: "Zebra", body: "")
        model.setActivePromptSelection(.preset(zebra.id))

        let targets = PromptBindingActions.pickerTargets(model: model)

        #expect(targets.first == .init(title: "Bind to Active Prompt (Zebra)", target: .activeSelection))
        #expect(targets.contains(.init(title: "Bind to VoicePi Default", target: .preset(PromptPreset.builtInDefaultID))))
        #expect(targets.contains(.init(title: "Bind to Meeting Notes", target: .preset("meeting_notes"))))
        #expect(targets.contains(.init(title: "Bind to Alpha", target: .preset(alpha.id))))
    }
}
