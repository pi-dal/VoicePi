import Foundation
import Testing
@testable import VoicePi

struct JSONPromptPresetTests {
    @Test
    func bundledJSONOutputPresetUsesSingleTextSchema() throws {
        let resourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/VoicePi/PromptLibrary/profiles/json_output.json")
        let data = try Data(contentsOf: resourceURL)
        let preset = try JSONDecoder().decode(PromptPresetResource.self, from: data)

        #expect(preset.body.contains("Return valid JSON only.") == true)
        #expect(preset.body.contains(#"Use exactly this schema: { "text": string }."#) == true)
        #expect(preset.body.contains("Always return a single JSON object, even when no edits are needed.") == true)
        #expect(preset.body.contains("Do not wrap the JSON object in markdown, code fences, quotes, or explanations.") == true)
        #expect(preset.body.contains("Do not include extra keys such as `input`, `target`, `source`, or `language`.") == true)
    }
}

private struct PromptPresetResource: Decodable {
    let body: String
}
