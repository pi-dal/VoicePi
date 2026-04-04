import Foundation
import Testing

struct InfoPlistTests {
    @Test
    func infoPlistDeclaresAppleEventsUsageDescription() throws {
        let infoURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("VoicePi")
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoURL)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        let info = plist as? [String: Any]
        let description = info?["NSAppleEventsUsageDescription"] as? String

        #expect(description != nil)
        #expect((description ?? "").isEmpty == false)
    }
}
