import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import Foundation

@MainActor
extension AppModel {
    func starterPromptPresets() -> [PromptPreset] {
        cachedPromptLibrary?.starterPresets ?? []
    }

    func promptPreset(id: String) -> PromptPreset? {
        if id == PromptPreset.builtInDefaultID {
            return PromptPreset.builtInDefault
        }

        if let userPreset = promptWorkspace.userPreset(id: id) {
            return userPreset
        }

        return starterPromptPresets().first(where: { $0.id == id })
    }

    func orderedPromptCyclePresets() -> [PromptPreset] {
        [PromptPreset.builtInDefault]
            + starterPromptPresets()
            + promptWorkspace.userPresets.sorted(by: {
                $0.resolvedTitle.localizedCaseInsensitiveCompare($1.resolvedTitle) == .orderedAscending
            })
    }

    func nextPromptCycleSelection(from selection: PromptActiveSelection? = nil) -> PromptActiveSelection? {
        let orderedPresets = orderedPromptCyclePresets()
        guard !orderedPresets.isEmpty else { return nil }

        let activeSelection = selection ?? promptWorkspace.activeSelection
        let activePresetID = AppModel.presetID(for: activeSelection)
        let currentIndex = orderedPresets.firstIndex(where: { $0.id == activePresetID }) ?? 0
        let nextIndex = (currentIndex + 1) % orderedPresets.count
        let nextPresetID = orderedPresets[nextIndex].id
        return AppModel.selection(forPromptPresetID: nextPresetID)
    }

    @discardableResult
    func cycleActivePromptSelection() -> ResolvedPromptPreset? {
        guard let nextSelection = nextPromptCycleSelection() else { return nil }
        setActivePromptSelection(nextSelection)
        return resolvedPromptPresetForExplicitPresetID(AppModel.presetID(for: nextSelection))
    }

    func resolvedPromptPresetForExplicitPresetID(_ presetID: String) -> ResolvedPromptPreset {
        let normalizedID = presetID.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveID = normalizedID.isEmpty ? PromptPreset.builtInDefaultID : normalizedID
        let preset = promptPreset(id: effectiveID) ?? PromptPreset.builtInDefault
        return AppModel.makeResolvedPromptPreset(from: preset)
    }

    func setActivePromptSelection(_ selection: PromptActiveSelection) {
        var next = promptWorkspace
        next.activeSelection = selection
        promptWorkspace = next
    }

    func setPromptStrictModeEnabled(_ enabled: Bool) {
        var next = promptWorkspace
        next.strictModeEnabled = enabled
        promptWorkspace = next
    }

    func saveUserPromptPreset(
        _ preset: PromptPreset,
        reassigningConflictingAppBindings: Bool = false
    ) {
        var next = promptWorkspace
        if reassigningConflictingAppBindings {
            next.reassignConflictingAppBindings(for: preset)
        }
        next.saveUserPreset(preset)
        promptWorkspace = next
    }

    func createUserPromptPreset(
        title: String = "New Prompt",
        body: String = "",
        appBundleIDs: [String] = [],
        websiteHosts: [String] = []
    ) -> PromptPreset {
        let preset = PromptPreset(
            id: "user.\(UUID().uuidString.lowercased())",
            title: title,
            body: body,
            source: .user,
            appBundleIDs: appBundleIDs,
            websiteHosts: websiteHosts
        )
        saveUserPromptPreset(preset)
        setActivePromptSelection(.preset(preset.id))
        return preset
    }

    func duplicatePromptPreset(id: String) -> PromptPreset? {
        guard let sourcePreset = promptPreset(id: id) else { return nil }

        let duplicate = PromptPreset(
            id: "user.\(UUID().uuidString.lowercased())",
            title: "\(sourcePreset.resolvedTitle) Copy",
            body: sourcePreset.body,
            source: .user,
            appBundleIDs: sourcePreset.appBundleIDs,
            websiteHosts: sourcePreset.websiteHosts
        )
        saveUserPromptPreset(duplicate)
        setActivePromptSelection(.preset(duplicate.id))
        return duplicate
    }

    func deleteUserPromptPreset(id: String) {
        var next = promptWorkspace
        next.deleteUserPreset(id: id)
        promptWorkspace = next
    }

    func resolvedPromptPreset(
        for appID: PromptAppID = .voicePi,
        destination: PromptDestinationContext? = nil
    ) -> ResolvedPromptPreset {
        _ = appID
        let library = cachedPromptLibrary ?? PromptLibrary(
            optionGroups: [:],
            profiles: [:],
            fragments: [:],
            appPolicies: [:]
        )

        return PromptWorkspaceResolver.resolve(
            workspace: promptWorkspace,
            destination: destination,
            library: library
        )
    }

    func resolvedRefinementPrompt(
        for appID: PromptAppID = .voicePi,
        destination: PromptDestinationContext? = nil
    ) -> String? {
        resolvedPromptPreset(for: appID, destination: destination).middleSection
    }

    func setPostProcessingMode(_ mode: PostProcessingMode) {
        postProcessingMode = mode
    }

    func setTranslationProvider(_ provider: TranslationProvider) {
        translationProvider = provider
    }

    func setRefinementProvider(_ provider: RefinementProvider) {
        refinementProvider = provider
    }

    func setExternalProcessorEntries(_ entries: [ExternalProcessorEntry]) {
        externalProcessorEntries = entries
    }

    func setSelectedExternalProcessorEntryID(_ id: UUID?) {
        selectedExternalProcessorEntryID = id
    }

    func selectedExternalProcessorEntry() -> ExternalProcessorEntry? {
        if let selectedExternalProcessorEntryID,
           let selected = externalProcessorEntries.first(where: {
               $0.id == selectedExternalProcessorEntryID && $0.isEnabled
           }) {
            return selected
        }

        return externalProcessorEntries.first(where: \.isEnabled)
    }

    func setTargetLanguage(_ language: SupportedLanguage) {
        targetLanguage = language
    }

    func modeDisplayTitle(for mode: PostProcessingMode) -> String {
        if mode == .refinement {
            let promptTitle = resolvedPromptPreset().title
            return "\(mode.title) (\(promptTitle))"
        }
        return mode.title
    }

    func effectiveTranslationProvider(appleTranslateSupported: Bool) -> TranslationProvider {
        TranslationProvider.sanitized(
            translationProvider,
            appleTranslateSupported: appleTranslateSupported
        )
    }

    func setMicrophoneAuthorization(_ state: AuthorizationState) {
        microphoneAuthorization = state
    }

    func setSpeechAuthorization(_ state: AuthorizationState) {
        speechAuthorization = state
    }

    func setAccessibilityAuthorization(_ state: AuthorizationState) {
        accessibilityAuthorization = state
    }

    func setInputMonitoringAuthorization(_ state: AuthorizationState) {
        inputMonitoringAuthorization = state
    }

    func setActivationShortcut(_ shortcut: ActivationShortcut) {
        activationShortcut = shortcut
    }

    func setModeCycleShortcut(_ shortcut: ActivationShortcut) {
        modeCycleShortcut = shortcut
    }

    func setCancelShortcut(_ shortcut: ActivationShortcut) {
        cancelShortcut = shortcut
    }

    func setProcessorShortcut(_ shortcut: ActivationShortcut) {
        processorShortcut = shortcut
    }

    func setPromptCycleShortcut(_ shortcut: ActivationShortcut) {
        promptCycleShortcut = shortcut
    }

    func cyclePostProcessingMode() {
        postProcessingMode = postProcessingMode.next
    }

    func saveRemoteASRConfiguration(
        baseURL: String,
        apiKey: String,
        model: String,
        prompt: String,
        volcengineAppID: String = ""
    ) {
        remoteASRConfiguration = RemoteASRConfiguration(
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            prompt: prompt,
            volcengineAppID: volcengineAppID
        )
    }

    func setASRBackend(_ backend: ASRBackend) {
        asrBackend = backend
    }
}
