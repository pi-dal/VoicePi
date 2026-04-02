import Foundation
import Testing
@testable import VoicePi

struct AppleTranslateServiceTests {
    @Test
    func supportRequiresTranslationFrameworkAndMacOS15OrLater() {
        #expect(
            AppleTranslateService.isSupported(
                operatingSystemVersion: .init(majorVersion: 14, minorVersion: 6, patchVersion: 0)
            ) == false
        )
#if canImport(Translation)
        #expect(
            AppleTranslateService.isSupported(
                operatingSystemVersion: .init(majorVersion: 15, minorVersion: 0, patchVersion: 0)
            ) == true
        )
        #expect(
            AppleTranslateService.isSupported(
                operatingSystemVersion: .init(majorVersion: 16, minorVersion: 0, patchVersion: 0)
            ) == true
        )
#else
        #expect(
            AppleTranslateService.isSupported(
                operatingSystemVersion: .init(majorVersion: 15, minorVersion: 0, patchVersion: 0)
            ) == false
        )
        #expect(
            AppleTranslateService.isSupported(
                operatingSystemVersion: .init(majorVersion: 16, minorVersion: 0, patchVersion: 0)
            ) == false
        )
#endif
    }

    @Test
    @available(macOS 15.0, *)
    func immediateTranslationRequiresInstalledLanguagePair() {
        #expect(AppleTranslateService.canTranslateImmediately(for: .installed) == true)
        #expect(AppleTranslateService.canTranslateImmediately(for: .supported) == false)
        #expect(AppleTranslateService.canTranslateImmediately(for: .unsupported) == false)
    }
}
