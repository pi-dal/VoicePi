import Foundation
import Testing
@testable import VoicePi

struct PromptWorkspaceTests {
    @Test
    func promptWorkspaceTestsDoNotDependOnAppKitWindowControls() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("SettingsWindowPromptTemplateTests.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        #expect(source.contains("import AppKit") == false)
        #expect(source.contains("NSPopUpButton") == false)
        #expect(source.contains("NSWindow") == false)
        #expect(source.contains("NSView") == false)
        #expect(source.contains("contentView") == false)
        #expect(source.contains("showWindow(") == false)
        #expect(source.contains("beginSheet(") == false)
        #expect(source.contains("attachedSheet") == false)
        #expect(source.contains("NSSelectorFromString(\"saveConfiguration\")") == false)
        #expect(source.contains("NSApp.sendAction") == false)
    }

    @Test
    func bundledLibraryLoadsStarterPresets() throws {
        let library = try PromptLibrary.loadBundled()

        let titles = library.starterPresets.map(\.title)
        #expect(titles.contains("Meeting Notes"))
        #expect(titles.contains("JSON Output"))
        #expect(titles.contains("Support Reply"))
    }

    @Test
    func workspaceResolverUsesBuiltInDefaultWhenSelectionIsDefault() throws {
        let library = try PromptLibrary.loadBundled()
        let resolved = PromptWorkspaceResolver.resolve(
            workspace: .init(),
            library: library
        )

        #expect(resolved.title == "VoicePi Default")
        #expect(resolved.middleSection == nil)
        #expect(resolved.source == .builtInDefault)
    }

    @Test
    func workspaceResolverUsesSelectedUserPreset() throws {
        let library = try PromptLibrary.loadBundled()
        let custom = PromptPreset(
            id: "user.custom",
            title: "Custom",
            body: "Respond with a terse changelog.",
            source: .user
        )
        let workspace = PromptWorkspaceSettings(
            activeSelection: .preset(custom.id),
            userPresets: [custom]
        )

        let resolved = PromptWorkspaceResolver.resolve(
            workspace: workspace,
            library: library
        )

        #expect(resolved.title == "Custom")
        #expect(resolved.middleSection == "Respond with a terse changelog.")
        #expect(resolved.source == .user)
    }

    @Test
    func workspaceResolverUsesBoundUserPresetForMatchingAppWhenDefaultSelected() throws {
        let library = try PromptLibrary.loadBundled()
        let bound = PromptPreset(
            id: "user.slack",
            title: "Slack Reply",
            body: "Respond like a concise Slack reply.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let workspace = PromptWorkspaceSettings(
            activeSelection: .builtInDefault,
            userPresets: [bound]
        )

        let resolved = PromptWorkspaceResolver.resolve(
            workspace: workspace,
            destination: .init(appBundleID: "com.tinyspeck.slackmacgap"),
            library: library
        )

        #expect(resolved.title == "Slack Reply")
        #expect(resolved.middleSection == "Respond like a concise Slack reply.")
        #expect(resolved.source == .user)
    }

    @Test
    func workspaceResolverUsesBoundUserPresetForMatchingWebsiteWhenDefaultSelected() throws {
        let library = try PromptLibrary.loadBundled()
        let bound = PromptPreset(
            id: "user.gmail",
            title: "Gmail Reply",
            body: "Respond as a direct email draft.",
            source: .user,
            websiteHosts: ["mail.google.com"]
        )
        let workspace = PromptWorkspaceSettings(
            activeSelection: .builtInDefault,
            userPresets: [bound]
        )

        let resolved = PromptWorkspaceResolver.resolve(
            workspace: workspace,
            destination: .init(appBundleID: "com.google.Chrome", websiteHost: "mail.google.com"),
            library: library
        )

        #expect(resolved.title == "Gmail Reply")
        #expect(resolved.middleSection == "Respond as a direct email draft.")
        #expect(resolved.source == .user)
    }

    @Test
    func matchingAutomaticBindingOverridesManualPresetSelection() throws {
        let library = try PromptLibrary.loadBundled()
        let manual = PromptPreset(
            id: "user.manual",
            title: "Pinned",
            body: "Always use this while pinned.",
            source: .user
        )
        let bound = PromptPreset(
            id: "user.slack",
            title: "Slack Reply",
            body: "Respond like a concise Slack reply.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let workspace = PromptWorkspaceSettings(
            activeSelection: .preset(manual.id),
            userPresets: [manual, bound]
        )

        let resolved = PromptWorkspaceResolver.resolve(
            workspace: workspace,
            destination: .init(appBundleID: "com.tinyspeck.slackmacgap"),
            library: library
        )

        #expect(resolved.title == "Slack Reply")
        #expect(resolved.middleSection == "Respond like a concise Slack reply.")
        #expect(resolved.source == .user)
    }

    @Test
    func manualPresetSelectionStillAppliesWhenNoAutomaticBindingMatches() throws {
        let library = try PromptLibrary.loadBundled()
        let manual = PromptPreset(
            id: "user.manual",
            title: "Pinned",
            body: "Always use this while pinned.",
            source: .user
        )
        let bound = PromptPreset(
            id: "user.slack",
            title: "Slack Reply",
            body: "Respond like a concise Slack reply.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let workspace = PromptWorkspaceSettings(
            activeSelection: .preset(manual.id),
            userPresets: [manual, bound]
        )

        let resolved = PromptWorkspaceResolver.resolve(
            workspace: workspace,
            destination: .init(appBundleID: "com.figma.Desktop"),
            library: library
        )

        #expect(resolved.title == "Pinned")
        #expect(resolved.middleSection == "Always use this while pinned.")
        #expect(resolved.source == .user)
    }

    @Test
    func latestMatchingAutomaticBindingWinsWhenMultiplePromptsTargetSameApp() throws {
        let library = try PromptLibrary.loadBundled()
        let original = PromptPreset(
            id: "user.original",
            title: "Original",
            body: "Use the original prompt.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let replacement = PromptPreset(
            id: "user.replacement",
            title: "Replacement",
            body: "Use the replacement prompt.",
            source: .user,
            appBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        let workspace = PromptWorkspaceSettings(
            activeSelection: .builtInDefault,
            userPresets: [original, replacement]
        )

        let resolved = PromptWorkspaceResolver.resolve(
            workspace: workspace,
            destination: .init(appBundleID: "com.tinyspeck.slackmacgap"),
            library: library
        )

        #expect(resolved.title == "Replacement")
        #expect(resolved.middleSection == "Use the replacement prompt.")
    }

    @Test
    func deletingActiveUserPresetFallsBackToBuiltInDefault() {
        var workspace = PromptWorkspaceSettings(
            activeSelection: .preset("user.custom"),
            userPresets: [
                .init(
                    id: "user.custom",
                    title: "Custom",
                    body: "Body",
                    source: .user
                )
            ]
        )

        workspace.deleteUserPreset(id: "user.custom")

        #expect(workspace.activeSelection == .builtInDefault)
        #expect(workspace.userPresets.isEmpty)
    }

    @Test
    func bundledLibraryLoadsWhenPassedPackagedAppBundle() throws {
        let fixture = try PromptLibraryHostBundleFixture(resourceBundleLocation: .contentsResources)

        let library = try PromptLibrary.loadBundled(bundle: fixture.hostBundle)

        #expect(library.profile(id: "fixture.profile")?.title == "Fixture Profile")
    }

    @Test
    func bundledLibraryLoadsWhenPassedHostBundleWithExecutableSiblingResources() throws {
        let fixture = try PromptLibraryHostBundleFixture(resourceBundleLocation: .executableSibling)

        let library = try PromptLibrary.loadBundled(bundle: fixture.hostBundle)

        #expect(library.profile(id: "fixture.profile")?.title == "Fixture Profile")
    }

    @Test
    func bundledLibraryDefaultLookupIgnoresTemporaryHostBundleFixtures() throws {
        _ = try PromptLibraryHostBundleFixture(resourceBundleLocation: .contentsResources)

        let library = try PromptLibrary.loadBundled()

        #expect(library.profile(id: "meeting_notes")?.title == "Meeting Notes")
        #expect(library.profile(id: "fixture.profile") == nil)
    }
}

private struct PromptLibraryHostBundleFixture {
    enum ResourceBundleLocation {
        case contentsResources
        case executableSibling
    }

    let rootURL: URL
    let hostBundle: Bundle

    init(resourceBundleLocation: ResourceBundleLocation) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        self.rootURL = rootURL

        let appURL = rootURL.appendingPathComponent("VoicePi.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)

        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleExecutable</key>
            <string>VoicePi</string>
            <key>CFBundleIdentifier</key>
            <string>com.voicepi.fixture</string>
            <key>CFBundleName</key>
            <string>VoicePi</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
        </dict>
        </plist>
        """
        try plist.write(
            to: contentsURL.appendingPathComponent("Info.plist"),
            atomically: true,
            encoding: .utf8
        )
        try Data().write(to: macOSURL.appendingPathComponent("VoicePi"))

        let resourceBundleBaseURL: URL
        switch resourceBundleLocation {
        case .contentsResources:
            resourceBundleBaseURL = resourcesURL
        case .executableSibling:
            resourceBundleBaseURL = macOSURL
        }

        let promptBundleURL = resourceBundleBaseURL
            .appendingPathComponent("VoicePi_VoicePi.bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: promptBundleURL, withIntermediateDirectories: true)

        let registry = """
        {
          "profileIDs": ["fixture.profile"],
          "fragmentIDs": [],
          "optionGroups": []
        }
        """
        try registry.write(
            to: promptBundleURL.appendingPathComponent("registry.json"),
            atomically: true,
            encoding: .utf8
        )

        let profile = """
        {
          "id": "fixture.profile",
          "title": "Fixture Profile",
          "description": "Fixture description",
          "body": "Fixture body",
          "optionGroupIDs": []
        }
        """
        try profile.write(
            to: promptBundleURL.appendingPathComponent("fixture.profile.json"),
            atomically: true,
            encoding: .utf8
        )

        let policy = """
        {
          "appID": "com.pi-dal.voicepi",
          "title": "VoicePi",
          "allowedProfileIDs": ["fixture.profile"],
          "defaultProfileID": "fixture.profile",
          "visibleOptionGroupIDs": []
        }
        """
        try policy.write(
            to: promptBundleURL.appendingPathComponent("voicepi.json"),
            atomically: true,
            encoding: .utf8
        )

        guard let hostBundle = Bundle(url: appURL) else {
            throw FixtureError.failedToOpenHostBundle(appURL.path)
        }
        self.hostBundle = hostBundle
    }

    private enum FixtureError: Error {
        case failedToOpenHostBundle(String)
    }
}
