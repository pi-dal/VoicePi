import Testing
@testable import VoicePi

@Suite
struct AppControllerUpdateDeliveryTests {
    @Test
    @MainActor
    func homebrewManagedInstallsPreferHomebrewFlow() {
        #expect(
            AppController.updateDelivery(
                for: .homebrewManaged
            ) == .homebrew
        )
    }

    @Test
    @MainActor
    func nonHomebrewInstallsPreferInAppFlow() {
        #expect(
            AppController.updateDelivery(
                for: .directDownload
            ) == .inAppInstaller
        )
        #expect(
            AppController.updateDelivery(
                for: .unknown
            ) == .inAppInstaller
        )
    }
}
