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
    func manualPresetSelectionOverridesMatchingAutomaticBinding() throws {
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

        #expect(resolved.title == "Pinned")
        #expect(resolved.middleSection == "Always use this while pinned.")
        #expect(resolved.source == .user)
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
}
