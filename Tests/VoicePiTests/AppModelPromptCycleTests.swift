import Foundation
import Testing
@testable import VoicePi

@MainActor
struct AppModelPromptCycleTests {
    @Test
    func orderedPromptCyclePresetsUseBuiltInThenStarterThenSortedUserPresets() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.orderedPromptCyclePresetsUseBuiltInThenStarterThenSortedUserPresets.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let userZeta = PromptPreset(
            id: "user.zeta",
            title: "zeta",
            body: "zeta body",
            source: .user
        )
        let userAlpha = PromptPreset(
            id: "user.alpha",
            title: "Alpha",
            body: "alpha body",
            source: .user
        )
        model.promptWorkspace = .init(
            activeSelection: .builtInDefault,
            strictModeEnabled: true,
            userPresets: [userZeta, userAlpha]
        )

        let ordered = model.orderedPromptCyclePresets()
        let starterIDs = model.starterPromptPresets().map(\.id)

        #expect(ordered.first?.id == PromptPreset.builtInDefaultID)
        #expect(Array(ordered.dropFirst().prefix(starterIDs.count).map(\.id)) == starterIDs)
        #expect(Array(ordered.suffix(2).map(\.id)) == [userAlpha.id, userZeta.id])
    }

    @Test
    func nextPromptCycleSelectionWrapsFromLastBackToBuiltInDefault() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.nextPromptCycleSelectionWrapsFromLastBackToBuiltInDefault.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let ordered = model.orderedPromptCyclePresets()
        let lastPreset = try #require(ordered.last)

        let wrapped = model.nextPromptCycleSelection(from: .preset(lastPreset.id))
        #expect(wrapped == .builtInDefault)
    }

    @Test
    func cycleActivePromptSelectionUpdatesOnlyManualSelection() throws {
        let defaults = UserDefaults(suiteName: "VoicePiTests.cycleActivePromptSelectionUpdatesOnlyManualSelection.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let expectedNext = try #require(model.nextPromptCycleSelection(from: .builtInDefault))

        model.promptWorkspace = .init(
            activeSelection: .builtInDefault,
            strictModeEnabled: true,
            userPresets: [
                PromptPreset(
                    id: "user.bound",
                    title: "Bound Prompt",
                    body: "bound",
                    source: .user,
                    appBundleIDs: ["com.apple.Safari"]
                )
            ]
        )

        _ = model.cycleActivePromptSelection()

        #expect(model.promptWorkspace.activeSelection == expectedNext)
        #expect(model.promptWorkspace.strictModeEnabled)
        #expect(model.promptWorkspace.userPresets.count == 1)
    }

    @Test
    func explicitPromptResolutionBypassesStrictModeBindings() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.explicitPromptResolutionBypassesStrictModeBindings.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let boundPrompt = PromptPreset(
            id: "user.bound",
            title: "Bound Prompt",
            body: "bound body",
            source: .user,
            appBundleIDs: ["com.apple.Safari"]
        )
        model.promptWorkspace = .init(
            activeSelection: .builtInDefault,
            strictModeEnabled: true,
            userPresets: [boundPrompt]
        )

        let destination = PromptDestinationContext(appBundleID: "com.apple.Safari")
        let strictResolved = model.resolvedPromptPreset(for: .voicePi, destination: destination)
        let explicitDefault = model.resolvedPromptPresetForExplicitPresetID(PromptPreset.builtInDefaultID)

        #expect(strictResolved.title == "Bound Prompt")
        #expect(explicitDefault.title == PromptPreset.builtInDefault.title)
    }
}
