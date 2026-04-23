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
#if canImport(Translation) && canImport(_Translation_SwiftUI)
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

    @Test
    func longTextSplitsIntoSentenceBoundariesBeforeTranslation() {
        let segments = AppleTranslateService.translationSegments(
            for: "Aaa bbb ccc. Ddd eee fff. Ggg hhh iii.",
            maxSegmentLength: 12
        )

        #expect(
            segments == [
                .init(text: "Aaa bbb ccc.", separatorAfter: " "),
                .init(text: "Ddd eee fff.", separatorAfter: " "),
                .init(text: "Ggg hhh iii.", separatorAfter: "")
            ]
        )
    }

    @Test
    func paragraphBoundariesArePreservedWhenChunkingLongText() {
        let segments = AppleTranslateService.translationSegments(
            for: "Short one.\n\nShort two.",
            maxSegmentLength: 10
        )

        #expect(
            segments == [
                .init(text: "Short one.", separatorAfter: "\n\n"),
                .init(text: "Short two.", separatorAfter: "")
            ]
        )
    }
}
