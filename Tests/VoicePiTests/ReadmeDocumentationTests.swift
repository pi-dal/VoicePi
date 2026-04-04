import Foundation
import Testing

struct ReadmeDocumentationTests {
    @Test
    func readmeDocumentsPromptWorkspaceConfiguration() throws {
        let readmeURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("README.md")
        let readme = try String(contentsOf: readmeURL, encoding: .utf8)

        #expect(readme.contains("## Prompt Workspace"))
        #expect(readme.contains("Active Prompt"))
        #expect(readme.contains("Prompt Name"))
        #expect(readme.contains("Prompt Body"))
        #expect(readme.contains("App Bundle IDs"))
        #expect(readme.contains("Website Hosts"))
        #expect(readme.contains("New"))
        #expect(readme.contains("Duplicate"))
        #expect(readme.contains("Delete"))
        #expect(readme.contains("Refinement mode"))
        #expect(readme.contains("VoicePi Default"))
    }
}
