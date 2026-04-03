import Foundation
import Testing

struct ReadmeDocumentationTests {
    @Test
    func readmeDocumentsPromptTemplateConfiguration() throws {
        let readmeURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("README.md")
        let readme = try String(contentsOf: readmeURL, encoding: .utf8)

        #expect(readme.contains("## Prompt Templates"))
        #expect(readme.contains("Default Prompt Template"))
        #expect(readme.contains("VoicePi Override"))
        #expect(readme.contains("Template Options"))
        #expect(readme.contains("Refinement mode"))
    }
}
