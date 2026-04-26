import Foundation
import Testing

struct TextInjectorPostingStrategyTests {
    @Test
    func textInjectorUsesPrivateEventSourceAndSessionTapForSyntheticPaste() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let injectorSourceURL = repositoryRoot
            .appending(path: "Sources/VoicePi/Adapters/System/TextInjector.swift")
        let injectorSource = try String(contentsOf: injectorSourceURL, encoding: .utf8)

        #expect(injectorSource.contains("stateID: .privateState"))
        #expect(injectorSource.contains("post(tap: .cgSessionEventTap)"))
        #expect(injectorSource.contains("setLocalEventsFilterDuringSuppressionState"))
        #expect(injectorSource.contains("stateID: .hidSystemState") == false)
        #expect(injectorSource.contains("post(tap: .cghidEventTap)") == false)
    }
}
