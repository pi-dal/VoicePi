import Foundation
import Testing
@testable import VoicePi

struct PromptProfileRegistryTests {
    @Test
    func bundledLibraryLoadsVoicePiPolicyAndProfiles() throws {
        let library = try PromptLibrary.loadBundled()

        let policy = try #require(library.policy(for: .voicePi))
        #expect(policy.appID == .voicePi)
        #expect(policy.allowedProfileIDs.contains("meeting_notes"))
        #expect(policy.allowedProfileIDs.contains("json_output"))

        let profile = try #require(library.profile(id: "meeting_notes"))
        #expect(profile.title == "Meeting Notes")
        #expect(profile.optionGroupIDs == ["output_format", "strictness"])
    }

    @Test
    func resolverUsesGlobalProfileWhenAppOverrideInherits() throws {
        let library = try PromptLibrary.loadBundled()
        let resolved = try PromptResolver.resolve(
            appID: .voicePi,
            globalSelection: .profile("meeting_notes", optionSelections: ["output_format": ["markdown"]]),
            appSelection: .inherit,
            library: library,
            legacyCustomPrompt: ""
        )

        #expect(resolved.source == .globalDefault)
        #expect(resolved.middleSection?.contains("concise structured notes") == true)
        #expect(resolved.middleSection?.contains("Markdown") == true)
    }

    @Test
    func resolverUsesExplicitNoneToBypassGlobalProfile() throws {
        let library = try PromptLibrary.loadBundled()
        let resolved = try PromptResolver.resolve(
            appID: .voicePi,
            globalSelection: .profile("meeting_notes"),
            appSelection: .none,
            library: library,
            legacyCustomPrompt: ""
        )

        #expect(resolved.source == .appOverride)
        #expect(resolved.middleSection == nil)
    }

    @Test
    func resolverRejectsProfilesOutsideAppPolicy() throws {
        let bundled = try PromptLibrary.loadBundled()
        let restrictedPolicy = PromptAppPolicy(
            appID: .voicePi,
            title: "VoicePi",
            allowedProfileIDs: ["json_output"],
            defaultProfileID: nil,
            visibleOptionGroupIDs: ["strictness"]
        )
        let library = PromptLibrary(
            optionGroups: bundled.optionGroups,
            profiles: bundled.profiles,
            fragments: bundled.fragments,
            appPolicies: [.voicePi: restrictedPolicy]
        )

        #expect(throws: PromptLibraryError.disallowedProfile("meeting_notes", .voicePi)) {
            try PromptResolver.resolve(
                appID: .voicePi,
                globalSelection: .profile("meeting_notes"),
                appSelection: .inherit,
                library: library,
                legacyCustomPrompt: ""
            )
        }
    }

    @Test
    func promptTemplateFormStateUsesGlobalProfileWhenAppInherits() throws {
        var state = PromptTemplateFormState(
            globalSelection: .profile("meeting_notes"),
            appSelection: .inherit
        )

        let target = try #require(state.editableTarget)
        #expect(target.scope == .globalDefault)
        #expect(target.selection.profileID == "meeting_notes")

        state.setSelectedOption("markdown", for: "output_format", in: target.scope)
        #expect(state.globalSelection.optionSelections["output_format"] == ["markdown"])
        #expect(state.appSelection.optionSelections["output_format"] == nil)
    }

    @Test
    func promptTemplateFormStateUsesAppOverrideProfileWhenPresent() throws {
        var state = PromptTemplateFormState(
            globalSelection: .profile("meeting_notes"),
            appSelection: .profile("json_output")
        )

        let target = try #require(state.editableTarget)
        #expect(target.scope == .appOverride)
        #expect(target.selection.profileID == "json_output")

        state.setSelectedOption("json", for: "output_format", in: target.scope)
        #expect(state.appSelection.optionSelections["output_format"] == ["json"])
        #expect(state.globalSelection.optionSelections["output_format"] == nil)
    }

    @Test
    func resolverNormalizesSingleSelectOptionGroupsToOneFragment() throws {
        let library = try PromptLibrary.loadBundled()
        let resolved = try PromptResolver.resolve(
            appID: .voicePi,
            globalSelection: .profile(
                "meeting_notes",
                optionSelections: ["output_format": ["markdown", "json"]]
            ),
            appSelection: .inherit,
            library: library,
            legacyCustomPrompt: ""
        )

        #expect(resolved.middleSection?.contains("Format the final output as Markdown") == true)
        #expect(resolved.middleSection?.contains("Return valid JSON only.") == false)
    }
}
