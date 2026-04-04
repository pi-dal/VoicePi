import Foundation
import Testing
@testable import VoicePi

struct PromptDestinationContextTests {
    @Test
    func normalizedAppBundleIDTrimsAndLowercases() {
        let raw = "  COM.Tinyspeck.SlackMacGap "
        #expect(
            PromptDestinationContext.normalizedAppBundleID(raw)
                == "com.tinyspeck.slackmacgap"
        )
    }

    @Test
    func normalizedWebsiteHostHandlesURLsAndPlainHosts() {
        #expect(
            PromptDestinationContext.normalizedWebsiteHost("https://mail.google.com/a/example")
                == "mail.google.com"
        )
        #expect(
            PromptDestinationContext.normalizedWebsiteHost("MAIL.Google.com")
                == "mail.google.com"
        )
        #expect(
            PromptDestinationContext.normalizedWebsiteHost("trello.com")
                == "trello.com"
        )
        #expect(
            PromptDestinationContext.normalizedWebsiteHost("  *.notion.so  ")
                == "*.notion.so"
        )
    }

    @Test
    func promptPresetMatchesBrowserHostWildcard() {
        let preset = PromptPreset(
            id: "user.notion",
            title: "Notion Reply",
            body: "Use quick notetaking style.",
            source: .user,
            websiteHosts: ["*.notion.so"]
        )
        let destination = PromptDestinationContext(
            appBundleID: "com.google.Chrome",
            websiteHost: "app.notion.so"
        )

        #expect(preset.matches(destination: destination))
    }

    @Test
    func promptPresetMatchesAppBundleID() {
        let preset = PromptPreset(
            id: "user.slack",
            title: "Slack Reply",
            body: "Short Slack tone.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let destination = PromptDestinationContext(appBundleID: "COM.TINYSPECK.SLACKMACGAP")

        #expect(preset.matches(destination: destination))
    }
}
