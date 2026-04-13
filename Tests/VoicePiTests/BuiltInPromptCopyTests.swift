import Foundation
import Testing
@testable import VoicePi

struct BuiltInPromptCopyTests {
    @Test
    func bundledMeetingNotesPresetEmphasizesGroundedStructure() throws {
        let preset = try loadResource(
            at: "Sources/VoicePi/PromptLibrary/profiles/meeting_notes.json",
            as: PromptPresetResource.self
        )

        #expect(preset.body.contains("Only include decisions, action items, open questions, dates, and owners when they are explicit in the transcript.") == true)
        #expect(preset.body.contains("If a detail is missing or uncertain, leave it as unspecified rather than filling it in.") == true)
        #expect(preset.body.contains("Do not invent conclusions, owners, deadlines, or implied decisions.") == true)
    }

    @Test
    func bundledSupportReplyPresetEmphasizesSafeCustomerFacingFidelity() throws {
        let preset = try loadResource(
            at: "Sources/VoicePi/PromptLibrary/profiles/support_reply.json",
            as: PromptPresetResource.self
        )

        #expect(preset.body.contains("Keep the original intent, tone direction, and stated constraints grounded in the transcript.") == true)
        #expect(preset.body.contains("Do not invent policy, compensation, timelines, investigation results, or commitments.") == true)
        #expect(preset.body.contains("If the transcript does not support a specific answer, use a cautious reply that does not add new facts.") == true)
    }

    @Test
    func bundledMarkdownFragmentAvoidsPreambleAndOverformatting() throws {
        let fragment = try loadResource(
            at: "Sources/VoicePi/PromptLibrary/fragments/output-markdown.json",
            as: PromptFragmentResource.self
        )

        #expect(fragment.body.contains("Return only the final Markdown output.") == true)
        #expect(fragment.body.contains("Do not add a preamble, explanation, or trailing commentary.") == true)
        #expect(fragment.body.contains("Keep the structure shallow and readable.") == true)
    }

    @Test
    func bundledStrictnessFragmentsKeepHardNoHallucinationBoundary() throws {
        let conservative = try loadResource(
            at: "Sources/VoicePi/PromptLibrary/fragments/strictness-conservative.json",
            as: PromptFragmentResource.self
        )
        let balanced = try loadResource(
            at: "Sources/VoicePi/PromptLibrary/fragments/strictness-balanced.json",
            as: PromptFragmentResource.self
        )
        let aggressive = try loadResource(
            at: "Sources/VoicePi/PromptLibrary/fragments/strictness-aggressive.json",
            as: PromptFragmentResource.self
        )

        #expect(conservative.body.contains("Prefer the smallest possible edits.") == true)
        #expect(conservative.body.contains("If something is uncertain, preserve the original meaning instead of resolving it.") == true)

        #expect(balanced.body.contains("You may improve structure and readability, but do not add new facts, policy, promises, dates, or ownership.") == true)
        #expect(balanced.body.contains("When information is incomplete, keep it explicitly incomplete.") == true)

        #expect(aggressive.body.contains("You may reorganize phrasing and formatting more assertively, but you must not change or add facts.") == true)
        #expect(aggressive.body.contains("Do not turn ambiguity into certainty.") == true)
    }

    private func loadResource<T: Decodable>(at relativePath: String, as type: T.Type) throws -> T {
        let resourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        let data = try Data(contentsOf: resourceURL)
        return try JSONDecoder().decode(type, from: data)
    }
}

private struct PromptPresetResource: Decodable {
    let body: String
}

private struct PromptFragmentResource: Decodable {
    let body: String
}
