import AppKit
import Foundation
import Testing
@testable import VoicePi

struct AppUpdateReleaseNotesRendererTests {
    @Test
    func rendererConvertsMarkdownAndAppendsLinkReferences() {
        let rendered = AppUpdateReleaseNotesRenderer.attributedString(
            from: """
            ## Highlights

            - Added [docs](https://example.com/docs)
            - See https://example.com/changelog
            """
        )

        let text = rendered.string
        #expect(text.contains("## Highlights") == false)
        #expect(text.contains("[docs](https://example.com/docs)") == false)
        #expect(text.contains("•\tAdded docs"))
        #expect(text.contains("Links"))
        #expect(text.contains("1.\thttps://example.com/docs"))
        #expect(text.contains("2.\thttps://example.com/changelog"))
    }

    @Test
    func rendererDeduplicatesLinkReferencesAndKeepsThemClickable() throws {
        let rendered = AppUpdateReleaseNotesRenderer.attributedString(
            from: """
            - [Release](https://example.com/release)
            - Repeat https://example.com/release
            """
        )

        let text = rendered.string
        #expect(text.contains("1.\thttps://example.com/release"))
        #expect(text.contains("2.\thttps://example.com/release") == false)

        let lineRange = (text as NSString).range(of: "1.\thttps://example.com/release")
        #expect(lineRange.location != NSNotFound)
        let urlLocation = try #require(
            lineRange.location != NSNotFound
                ? lineRange.location + "1.\t".count
                : nil
        )
        let link = try #require(rendered.attribute(.link, at: urlLocation, effectiveRange: nil) as? URL)
        #expect(link.absoluteString == "https://example.com/release")
    }
}
