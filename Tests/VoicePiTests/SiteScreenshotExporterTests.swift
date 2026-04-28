import AppKit
import Foundation
import Testing
@testable import VoicePi

@MainActor
struct SiteScreenshotExporterTests {
    @Test
    func exportGalleryAssetsWritesExpectedFilesForBothThemes() throws {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicepi-site-screenshots-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let manifest = try SiteScreenshotExporter().exportGalleryAssets(to: outputDirectory)

        let expectedSizes: [String: CGSize] = [
            "mode-switch-sunny.png": CGSize(width: 944, height: 272),
            "mode-switch-moon.png": CGSize(width: 944, height: 272),
            "recording-sunny.png": CGSize(width: 560, height: 112),
            "recording-moon.png": CGSize(width: 560, height: 112),
            "settings-home-sunny.png": CGSize(width: 3000, height: 2000),
            "settings-home-moon.png": CGSize(width: 3000, height: 2000)
        ]

        #expect(Set(manifest.map(\.filename)) == Set(expectedSizes.keys))

        for asset in manifest {
            let imageURL = outputDirectory.appendingPathComponent(asset.filename)
            #expect(FileManager.default.fileExists(atPath: imageURL.path))

            let data = try Data(contentsOf: imageURL)
            let bitmap = try #require(NSBitmapImageRep(data: data))
            #expect(bitmap.pixelsWide == Int(expectedSizes[asset.filename]?.width ?? 0))
            #expect(bitmap.pixelsHigh == Int(expectedSizes[asset.filename]?.height ?? 0))
        }
    }
}
