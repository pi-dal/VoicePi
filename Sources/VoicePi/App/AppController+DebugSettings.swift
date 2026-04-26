import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

extension AppController {
    static func debugSettingsCaptureConfiguration(
        from environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DebugSettingsCaptureConfiguration? {
        guard let rawSection = environment["VOICEPI_DEBUG_SETTINGS_SECTION"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return nil
        }

        let section: SettingsSection?
        switch rawSection {
        case "home":
            section = .home
        case "permissions":
            section = .permissions
        case "library", "dictionary":
            section = .dictionary
        case "history":
            section = .history
        case "asr":
            section = .asr
        case "text", "llm":
            section = .llm
        case "processors", "external-processors", "external_processors":
            section = .externalProcessors
        case "about":
            section = .about
        default:
            section = nil
        }

        guard let section else {
            return nil
        }

        let interfaceTheme = environment["VOICEPI_DEBUG_INTERFACE_THEME"]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .flatMap(InterfaceTheme.init(rawValue:))

        let scrollPosition: DebugSettingsCaptureConfiguration.ScrollPosition
        switch environment["VOICEPI_DEBUG_SETTINGS_SCROLL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
        case "bottom":
            scrollPosition = .bottom
        default:
            scrollPosition = .top
        }

        return DebugSettingsCaptureConfiguration(
            section: section,
            interfaceTheme: interfaceTheme,
            scrollPosition: scrollPosition
        )
    }

}
