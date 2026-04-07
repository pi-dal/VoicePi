import Foundation

enum PromptBindingKind: Equatable {
    case appBundleID
    case websiteHost
}

enum PromptBindingTarget: Equatable {
    case activeSelection
    case preset(String)
    case newPrompt
}

enum PromptBindingSaveStatus: Equatable {
    case added(String)
    case alreadyPresent(String)
}

struct PromptBindingSaveResult: Equatable {
    let preset: PromptPreset
    let status: PromptBindingSaveStatus
}

struct PromptBindingQuickTarget: Equatable {
    let title: String
    let target: PromptBindingTarget
}

enum PromptBindingActions {
    static func normalizedCapturedValue(
        _ rawValue: String?,
        kind: PromptBindingKind
    ) -> String? {
        switch kind {
        case .appBundleID:
            return PromptDestinationContext.normalizedAppBundleID(rawValue)
        case .websiteHost:
            return PromptDestinationContext.normalizedWebsiteHost(rawValue)
        }
    }

    static func mergeBindingValues(
        existingValues: [String],
        capturedRawValue: String?,
        kind: PromptBindingKind
    ) -> [String] {
        var merged: [String] = []
        var seen: Set<String> = []

        for value in existingValues {
            let normalized = normalizedCapturedValue(value, kind: kind) ?? value
            guard seen.insert(normalized).inserted else { continue }
            merged.append(normalized)
        }

        if let captured = normalizedCapturedValue(capturedRawValue, kind: kind),
           seen.insert(captured).inserted {
            merged.append(captured)
        }

        return merged
    }

    @MainActor
    static func apply(
        capturedRawValue: String?,
        kind: PromptBindingKind,
        target: PromptBindingTarget,
        model: AppModel
    ) -> PromptBindingSaveResult? {
        guard let captured = normalizedCapturedValue(capturedRawValue, kind: kind) else {
            return nil
        }

        guard var preset = editablePreset(for: target, model: model) else {
            return nil
        }

        let existingValues = bindingValues(for: preset, kind: kind)
        let mergedValues = mergeBindingValues(
            existingValues: existingValues,
            capturedRawValue: captured,
            kind: kind
        )
        let status: PromptBindingSaveStatus = existingValues.contains(captured)
            ? .alreadyPresent(captured)
            : .added(captured)

        switch kind {
        case .appBundleID:
            preset.appBundleIDs = mergedValues
        case .websiteHost:
            preset.websiteHosts = mergedValues
        }

        model.saveUserPromptPreset(preset)
        model.setActivePromptSelection(.preset(preset.id))

        return PromptBindingSaveResult(
            preset: preset,
            status: status
        )
    }

    @MainActor
    static func pickerTargets(model: AppModel) -> [PromptBindingQuickTarget] {
        var targets: [PromptBindingQuickTarget] = [
            .init(
                title: "Bind to Active Prompt (\(model.resolvedPromptPreset().title))",
                target: .activeSelection
            )
        ]

        let activeEquivalentPresetID: String = {
            switch model.promptWorkspace.activeSelection.mode {
            case .builtInDefault:
                return PromptPreset.builtInDefaultID
            case .preset:
                return model.promptWorkspace.activeSelection.presetID ?? PromptPreset.builtInDefaultID
            }
        }()

        let remainingPresets = ([PromptPreset.builtInDefault] + model.starterPromptPresets() + model.promptWorkspace.userPresets)
            .filter { $0.id != activeEquivalentPresetID }
            .sorted {
                $0.resolvedTitle.localizedCaseInsensitiveCompare($1.resolvedTitle) == .orderedAscending
            }
            .map {
                PromptBindingQuickTarget(
                    title: "Bind to \($0.resolvedTitle)",
                    target: .preset($0.id)
                )
            }

        targets.append(contentsOf: remainingPresets)
        return targets
    }

    @MainActor
    private static func editablePreset(
        for target: PromptBindingTarget,
        model: AppModel
    ) -> PromptPreset? {
        switch target {
        case .activeSelection:
            switch model.promptWorkspace.activeSelection.mode {
            case .builtInDefault:
                return model.createUserPromptPreset()
            case .preset:
                guard let presetID = model.promptWorkspace.activeSelection.presetID else {
                    return model.createUserPromptPreset()
                }
                return editablePreset(for: .preset(presetID), model: model)
            }
        case .preset(let presetID):
            guard let preset = model.promptPreset(id: presetID) else { return nil }
            switch preset.source {
            case .user:
                return preset
            case .starter:
                return model.duplicatePromptPreset(id: presetID)
            case .builtInDefault:
                return model.createUserPromptPreset()
            }
        case .newPrompt:
            return model.createUserPromptPreset()
        }
    }

    private static func bindingValues(
        for preset: PromptPreset,
        kind: PromptBindingKind
    ) -> [String] {
        switch kind {
        case .appBundleID:
            return preset.appBundleIDs
        case .websiteHost:
            return preset.websiteHosts
        }
    }
}
