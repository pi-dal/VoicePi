import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import Foundation

extension AppModel {
    static func migratePromptWorkspace(
        defaults: UserDefaults,
        decoder: JSONDecoder,
        initialLLMConfiguration: LLMConfiguration
    ) -> PromptWorkspaceSettings {
        if
            let data = defaults.data(forKey: Keys.promptSettings),
            let decoded = try? decoder.decode(PromptSettings.self, from: data),
            let library = try? PromptLibrary.loadBundled(),
            let resolved = try? PromptResolver.resolve(
                appID: .voicePi,
                globalSelection: decoded.defaultSelection,
                appSelection: decoded.selection(for: .voicePi) ?? .inherit,
                library: library,
                legacyCustomPrompt: initialLLMConfiguration.refinementPrompt
            ),
            let middleSection = resolved.middleSection,
            !middleSection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            let imported = PromptPreset(
                id: "user.imported.\(UUID().uuidString.lowercased())",
                title: resolved.title ?? "Imported Prompt",
                body: middleSection,
                source: .user
            )
            return .init(
                activeSelection: .preset(imported.id),
                userPresets: [imported]
            )
        }

        if !initialLLMConfiguration.trimmedRefinementPrompt.isEmpty {
            let imported = PromptPreset(
                id: "user.imported.\(UUID().uuidString.lowercased())",
                title: "Imported Prompt",
                body: initialLLMConfiguration.trimmedRefinementPrompt,
                source: .user
            )
            return .init(
                activeSelection: .preset(imported.id),
                userPresets: [imported]
            )
        }

        return .init()
    }

    static func defaultActivationShortcut(defaults: UserDefaults) -> ActivationShortcut {
        if hasExistingInstallationState(defaults: defaults) {
            return .legacyDefault
        }

        return .default
    }

    static let defaultCancelShortcut = ActivationShortcut(
        keyCodes: [47],
        modifierFlagsRawValue: NSEvent.ModifierFlags.control.intersection(.deviceIndependentFlagsMask).rawValue
    )

    private static func hasExistingInstallationState(defaults: UserDefaults) -> Bool {
        let legacyAndCurrentKeys = [
            Keys.selectedLanguage,
            Keys.llmEnabled,
            Keys.llmConfig,
            Keys.promptSettings,
            Keys.promptWorkspace,
            Keys.postProcessingMode,
            Keys.translationProvider,
            Keys.refinementProvider,
            Keys.externalProcessorEntries,
            Keys.selectedExternalProcessorEntryID,
            Keys.targetLanguage,
            Keys.modeCycleShortcut,
            Keys.cancelShortcut,
            Keys.processorShortcut,
            Keys.promptCycleShortcut,
            Keys.asrBackend,
            Keys.remoteASRConfig,
            Keys.interfaceTheme
        ]

        return legacyAndCurrentKeys.contains { defaults.object(forKey: $0) != nil }
    }

    static func presetID(for selection: PromptActiveSelection) -> String {
        switch selection.mode {
        case .builtInDefault:
            return PromptPreset.builtInDefaultID
        case .preset:
            return selection.presetID ?? PromptPreset.builtInDefaultID
        }
    }

    static func selection(forPromptPresetID presetID: String) -> PromptActiveSelection {
        if presetID == PromptPreset.builtInDefaultID {
            return .builtInDefault
        }
        return .preset(presetID)
    }

    static func makeResolvedPromptPreset(from preset: PromptPreset) -> ResolvedPromptPreset {
        let middleSection = preset.trimmedBody.isEmpty ? nil : preset.trimmedBody
        let source: ResolvedPromptPresetSource
        switch preset.source {
        case .builtInDefault:
            source = .builtInDefault
        case .starter:
            source = .starter
        case .user:
            source = .user
        }

        return .init(
            presetID: preset.id,
            title: preset.resolvedTitle,
            middleSection: middleSection,
            source: source
        )
    }
}
