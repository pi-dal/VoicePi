import Foundation
import Testing
@testable import VoicePi

struct AppUpdateExperienceTests {
    @Test
    func directInstallAvailablePresentationOffersInAppInstall() {
        let release = AppUpdateRelease(
            version: "1.4.0",
            releasePageURL: URL(string: "https://github.com/pi-dal/VoicePi/releases/tag/v1.4.0")!,
            assetURL: URL(string: "https://github.com/pi-dal/VoicePi/releases/download/v1.4.0/VoicePi-1.4.0.zip")!,
            notes: "Bug fixes and polish"
        )

        let panel = AppUpdateExperience.panelPresentation(
            for: .updateAvailable(
                release: release,
                delivery: .inAppInstaller,
                source: .directDownload
            )
        )

        #expect(panel?.title == "VoicePi 1.4.0 Is Available")
        #expect(panel?.primaryAction.title == "Install Update")
        #expect(panel?.primaryAction.role == .install)
        #expect(panel?.secondaryAction?.title == "View Release")
        #expect(panel?.statusText == "Direct Install")
        #expect(panel?.strategyText == "VoicePi can download and replace the app in place.")
    }

    @Test
    func homebrewAvailablePresentationKeepsHomebrewPath() {
        let release = AppUpdateRelease(
            version: "1.4.0",
            releasePageURL: URL(string: "https://github.com/pi-dal/VoicePi/releases/tag/v1.4.0")!,
            assetURL: URL(string: "https://github.com/pi-dal/VoicePi/releases/download/v1.4.0/VoicePi-1.4.0.zip")!,
            notes: "Bug fixes and polish"
        )

        let panel = AppUpdateExperience.panelPresentation(
            for: .updateAvailable(
                release: release,
                delivery: .homebrew,
                source: .homebrewManaged
            )
        )

        #expect(panel?.primaryAction.title == "Copy Homebrew Commands")
        #expect(panel?.primaryAction.role == .copyHomebrew)
        #expect(panel?.secondaryAction?.title == "Open Homebrew Guide")
        #expect(panel?.statusText == "Homebrew Managed")
        #expect(panel?.strategyText == "Updates stay on the Homebrew path to preserve package-manager ownership.")
    }

    @Test
    func downloadingPresentationExposesProgress() {
        let release = AppUpdateRelease(
            version: "1.4.0",
            releasePageURL: URL(string: "https://github.com/pi-dal/VoicePi/releases/tag/v1.4.0")!,
            assetURL: URL(string: "https://github.com/pi-dal/VoicePi/releases/download/v1.4.0/VoicePi-1.4.0.zip")!,
            notes: "Bug fixes and polish"
        )

        let panel = AppUpdateExperience.panelPresentation(
            for: .downloading(
                release: release,
                source: .directDownload,
                progress: 0.42
            )
        )

        #expect(panel?.progress?.fraction == 0.42)
        #expect(panel?.progress?.label == "Downloading 42%")
        #expect(panel?.primaryAction.title == "Downloading…")
        #expect(panel?.primaryAction.isEnabled == false)
    }

    @Test
    func aboutCardPresentationShowsSourceAndMethod() {
        let card = AppUpdateExperience.cardPresentation(
            for: .idle(source: .directDownload)
        )

        #expect(card.title == "Update Experience")
        #expect(card.statusText == "Direct Install")
        #expect(card.sourceText == "Install source: Direct download")
        #expect(card.strategyText == "VoicePi can download and replace the app in place.")
        #expect(card.primaryAction.title == "Check for Updates")
    }
}
