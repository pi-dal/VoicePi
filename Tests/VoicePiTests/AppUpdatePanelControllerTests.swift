import AppKit
import Foundation
import Testing
@testable import VoicePi

struct AppUpdatePanelControllerTests {
    @Test
    @MainActor
    func updatePanelLaysOutReleaseNotesWithVisibleTextWidth() throws {
        _ = NSApplication.shared
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.updatePanelLaysOutReleaseNotesWithVisibleTextWidth.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        let controller = StatusBarController(model: model)
        let presentation = AppUpdatePanelPresentation(
            title: "VoicePi 1.3.2 Is Available",
            summary: "A newer version is ready to install.",
            statusText: "Direct Install",
            sourceText: "Install source: Direct download",
            strategyText: "VoicePi can download and replace the app in place.",
            releaseNotes: """
            ## Highlights
            - Fixes the packaged-app startup crash.
            - Improves update reliability.
            """,
            primaryAction: .init(title: "Install Update", role: .install, isEnabled: true),
            secondaryAction: .init(title: "View Release", role: .openRelease, isEnabled: true),
            tertiaryAction: .init(title: "Later", role: .dismiss, isEnabled: true),
            progress: nil
        )

        controller.presentUpdatePanel(presentation) { _ in }

        let panelController = try #require(
            reflectedChild(named: "updatePanelController", in: controller) as? NSWindowController
        )
        let window = try #require(panelController.window)
        _ = window.contentView
        window.contentView?.layoutSubtreeIfNeeded()

        let releaseNotesTextView = try #require(
            reflectedChild(named: "releaseNotesTextView", in: panelController) as? NSTextView
        )

        #expect(releaseNotesTextView.string.contains("packaged-app startup crash"))
        #expect(releaseNotesTextView.frame.width > 0)
    }

    @Test
    @MainActor
    func updatePanelRendersMarkdownReleaseNotesIntoReadableText() throws {
        _ = NSApplication.shared
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.updatePanelRendersMarkdownReleaseNotesIntoReadableText.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        let controller = StatusBarController(model: model)
        let presentation = AppUpdatePanelPresentation(
            title: "VoicePi 1.3.2 Is Available",
            summary: "A newer version is ready to install.",
            statusText: "Direct Install",
            sourceText: "Install source: Direct download",
            strategyText: "VoicePi can download and replace the app in place.",
            releaseNotes: """
            ## Highlights

            - Fixes the packaged-app startup crash.
            - Improves update reliability.
            """,
            primaryAction: .init(title: "Install Update", role: .install, isEnabled: true),
            secondaryAction: .init(title: "View Release", role: .openRelease, isEnabled: true),
            tertiaryAction: .init(title: "Later", role: .dismiss, isEnabled: true),
            progress: nil
        )

        controller.presentUpdatePanel(presentation) { _ in }

        let panelController = try #require(
            reflectedChild(named: "updatePanelController", in: controller) as? NSWindowController
        )
        let window = try #require(panelController.window)
        _ = window.contentView
        window.contentView?.layoutSubtreeIfNeeded()

        let releaseNotesTextView = try #require(
            reflectedChild(named: "releaseNotesTextView", in: panelController) as? NSTextView
        )

        #expect(releaseNotesTextView.string.contains("## Highlights") == false)
        #expect(releaseNotesTextView.string.contains("- Fixes the packaged-app startup crash.") == false)
        #expect(releaseNotesTextView.string.contains("•\tFixes the packaged-app startup crash."))
    }
}

private func reflectedChild(named name: String, in value: Any) -> Any? {
    Mirror(reflecting: value).children.first { $0.label == name }?.value
}
