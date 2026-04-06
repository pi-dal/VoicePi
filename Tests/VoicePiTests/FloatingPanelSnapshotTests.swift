import AppKit
import Foundation
import Testing
@testable import VoicePi

struct FloatingPanelSnapshotTests {
    @Test
    @MainActor
    func exportsConfiguredSnapshotWhenPathIsProvided() throws {
        let processInfo = ProcessInfo.processInfo
        guard let outputPath = processInfo.environment["VOICEPI_SNAPSHOT_PATH"] else {
            return
        }

        let theme = processInfo.environment["VOICEPI_SNAPSHOT_THEME"] == "light"
            ? InterfaceTheme.light
            : InterfaceTheme.dark
        let snapshotKind = processInfo.environment["VOICEPI_SNAPSHOT_KIND"] ?? "mode-switch"

        let contentView: NSView

        switch snapshotKind {
        case "recording":
            let controller = FloatingPanelController()
            controller.applyInterfaceTheme(theme)
            controller.showRecording(transcript: "")
            controller.updateLive(transcript: "VoicePi captures speech and pastes it back into the active app.", level: 0.52)

            guard
                let window = controller.window,
                let view = window.contentView
            else {
                Issue.record("Recording floating panel window was not created.")
                return
            }

            view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            contentView = view
            controller.hide()

        case "settings-home", "settings-about":
            let defaults = UserDefaults(suiteName: "VoicePiTests.snapshot.\(UUID().uuidString)")!
            let model = AppModel(defaults: defaults)
            model.interfaceTheme = theme
            model.microphoneAuthorization = .granted
            model.speechAuthorization = .granted
            model.accessibilityAuthorization = .granted
            model.inputMonitoringAuthorization = .unknown

            let controller = SettingsWindowController(model: model, delegate: nil)
            let section: SettingsSection = snapshotKind == "settings-about" ? .about : .home
            controller.show(section: section)

            guard
                let window = controller.window,
                let view = window.contentView
            else {
                Issue.record("Settings window was not created.")
                return
            }

            view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            contentView = view

        default:
            let controller = FloatingPanelController()
            controller.applyInterfaceTheme(theme)
            controller.showModeSwitch(
                modeTitle: PostProcessingMode.translation.title,
                refinementPromptTitle: "Meeting Notes",
                autoHideDelayNanoseconds: nil
            )

            guard
                let window = controller.window,
                let view = window.contentView
            else {
                Issue.record("Mode-switch floating panel window was not created.")
                return
            }

            view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            contentView = view
            controller.hide()
        }

        let bounds = contentView.bounds
        guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            Issue.record("Failed to allocate bitmap representation for snapshot export.")
            return
        }

        contentView.cacheDisplay(in: bounds, to: rep)

        guard let data = rep.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to encode snapshot as PNG.")
            return
        }

        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL)

        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }
}
