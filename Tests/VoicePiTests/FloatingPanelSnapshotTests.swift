import AppKit
import Foundation
import Testing
@testable import VoicePi

struct FloatingPanelSnapshotTests {
    @Test
    @MainActor
    func exportsModeSwitchSnapshotWhenPathIsProvided() throws {
        let processInfo = ProcessInfo.processInfo
        guard let outputPath = processInfo.environment["VOICEPI_MODE_SWITCH_SNAPSHOT_PATH"] else {
            return
        }

        let theme = processInfo.environment["VOICEPI_MODE_SWITCH_SNAPSHOT_THEME"] == "light"
            ? InterfaceTheme.light
            : InterfaceTheme.dark

        let controller = FloatingPanelController()
        controller.applyInterfaceTheme(theme)
        controller.showModeSwitch(
            modeTitle: PostProcessingMode.translation.title,
            refinementPromptTitle: "Meeting Notes",
            autoHideDelayNanoseconds: nil
        )

        guard
            let window = controller.window,
            let contentView = window.contentView
        else {
            Issue.record("Floating panel window was not created.")
            return
        }

        contentView.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        let bounds = contentView.bounds
        guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            Issue.record("Failed to allocate bitmap representation for floating panel.")
            return
        }

        contentView.cacheDisplay(in: bounds, to: rep)

        guard let data = rep.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to encode floating panel snapshot as PNG.")
            return
        }

        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL)

        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        controller.hide()
    }
}
