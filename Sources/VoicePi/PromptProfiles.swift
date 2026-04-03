import Foundation

enum PromptAppID: String, Codable, CaseIterable {
    case voicePi = "com.pi-dal.voicepi"

    var resourceName: String {
        switch self {
        case .voicePi:
            return "voicepi"
        }
    }
}

enum PromptSelectionMode: String, Codable, Equatable {
    case inherit
    case none
    case profile
    case legacyCustom
}

struct PromptSelection: Codable, Equatable {
    var mode: PromptSelectionMode
    var profileID: String?
    var optionSelections: [String: [String]]

    init(
        mode: PromptSelectionMode,
        profileID: String? = nil,
        optionSelections: [String: [String]] = [:]
    ) {
        self.mode = mode
        self.profileID = profileID
        self.optionSelections = optionSelections
    }

    static var inherit: Self {
        .init(mode: .inherit)
    }

    static var none: Self {
        .init(mode: .none)
    }

    static func profile(
        _ id: String,
        optionSelections: [String: [String]] = [:]
    ) -> Self {
        .init(mode: .profile, profileID: id, optionSelections: optionSelections)
    }

    static var legacyCustom: Self {
        .init(mode: .legacyCustom)
    }
}

struct PromptSettings: Codable, Equatable {
    var defaultSelection: PromptSelection
    var appSelections: [String: PromptSelection]

    init(
        defaultSelection: PromptSelection = .none,
        appSelections: [String: PromptSelection] = [:]
    ) {
        self.defaultSelection = defaultSelection
        self.appSelections = appSelections
    }

    func selection(for appID: PromptAppID) -> PromptSelection? {
        appSelections[appID.rawValue]
    }

    mutating func setSelection(_ selection: PromptSelection, for appID: PromptAppID) {
        if selection.mode == .inherit {
            appSelections.removeValue(forKey: appID.rawValue)
        } else {
            appSelections[appID.rawValue] = selection
        }
    }
}

enum PromptOptionSelectionKind: String, Codable, Equatable {
    case single
    case multi
}

struct PromptOption: Codable, Equatable {
    let id: String
    let title: String
    let fragmentID: String?
}

struct PromptOptionGroup: Codable, Equatable {
    let id: String
    let title: String
    let selection: PromptOptionSelectionKind
    let options: [PromptOption]
}

struct PromptProfile: Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let body: String
    let optionGroupIDs: [String]
}

struct PromptFragment: Codable, Equatable {
    let id: String
    let title: String?
    let body: String
}

struct PromptAppPolicy: Codable, Equatable {
    let appID: PromptAppID
    let title: String
    let allowedProfileIDs: [String]
    let defaultProfileID: String?
    let visibleOptionGroupIDs: [String]
}

enum PromptTemplateScope: Equatable, Hashable {
    case globalDefault
    case appOverride
}

struct PromptTemplateFormState: Equatable {
    var globalSelection: PromptSelection
    var appSelection: PromptSelection

    var editableTarget: (scope: PromptTemplateScope, selection: PromptSelection)? {
        switch appSelection.mode {
        case .profile:
            return (.appOverride, appSelection)
        case .inherit:
            guard globalSelection.mode == .profile else { return nil }
            return (.globalDefault, globalSelection)
        case .none, .legacyCustom:
            return nil
        }
    }

    mutating func updateSelection(_ selection: PromptSelection, for scope: PromptTemplateScope) {
        switch scope {
        case .globalDefault:
            globalSelection = selection
        case .appOverride:
            appSelection = selection
        }
    }

    func selection(for scope: PromptTemplateScope) -> PromptSelection {
        switch scope {
        case .globalDefault:
            return globalSelection
        case .appOverride:
            return appSelection
        }
    }

    mutating func setSelectedOption(
        _ optionID: String,
        for groupID: String,
        in scope: PromptTemplateScope
    ) {
        switch scope {
        case .globalDefault:
            guard globalSelection.mode == .profile else { return }
            globalSelection.optionSelections[groupID] = [optionID]
        case .appOverride:
            guard appSelection.mode == .profile else { return }
            appSelection.optionSelections[groupID] = [optionID]
        }
    }
}

struct PromptLibrary: Equatable {
    let optionGroups: [String: PromptOptionGroup]
    let profiles: [String: PromptProfile]
    let fragments: [String: PromptFragment]
    let appPolicies: [PromptAppID: PromptAppPolicy]

    func policy(for appID: PromptAppID) -> PromptAppPolicy? {
        appPolicies[appID]
    }

    func profile(id: String) -> PromptProfile? {
        profiles[id]
    }

    func fragment(id: String) -> PromptFragment? {
        fragments[id]
    }

    static func loadBundled(bundle: Bundle = .module) throws -> PromptLibrary {
        let decoder = JSONDecoder()

        let registry = try decoder.decode(
            PromptRegistryFile.self,
            from: loadResource(
                named: "registry",
                extension: "json",
                bundle: bundle
            )
        )

        let profiles = try registry.profileIDs.map {
            try decoder.decode(
                PromptProfile.self,
                from: loadResource(named: $0, extension: "json", bundle: bundle)
            )
        }
        let fragments = try registry.fragmentIDs.map {
            try decoder.decode(
                PromptFragment.self,
                from: loadResource(named: $0, extension: "json", bundle: bundle)
            )
        }
        let appPolicies = try PromptAppID.allCases.map {
            try decoder.decode(
                PromptAppPolicy.self,
                from: loadResource(named: $0.resourceName, extension: "json", bundle: bundle)
            )
        }

        return PromptLibrary(
            optionGroups: Dictionary(uniqueKeysWithValues: registry.optionGroups.map { ($0.id, $0) }),
            profiles: Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) }),
            fragments: Dictionary(uniqueKeysWithValues: fragments.map { ($0.id, $0) }),
            appPolicies: Dictionary(uniqueKeysWithValues: appPolicies.map { ($0.appID, $0) })
        )
    }

    private static func loadResource(
        named name: String,
        extension ext: String,
        bundle: Bundle
    ) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw PromptLibraryError.missingResource("\(name).\(ext)")
        }

        return try Data(contentsOf: url)
    }
}

enum PromptSelectionSource: Equatable {
    case appOverride
    case globalDefault
    case none
}

struct ResolvedPromptSelection: Equatable {
    let source: PromptSelectionSource
    let title: String?
    let middleSection: String?
}

enum PromptResolutionDiagnosticError: Equatable {
    case library(PromptLibraryError)
    case unknown(String)

    var diagnosticDescription: String {
        switch self {
        case .library(let error):
            return error.diagnosticDescription
        case .unknown(let message):
            return "Prompt template resolution failed: \(message)"
        }
    }
}

struct PromptResolutionDiagnostics: Equatable {
    let resolvedSelection: ResolvedPromptSelection?
    let error: PromptResolutionDiagnosticError?
}

enum PromptLibraryError: Error, Equatable {
    case missingResource(String)
    case missingPolicy(PromptAppID)
    case disallowedProfile(String, PromptAppID)
    case missingProfile(String)
    case missingOptionGroup(String)
    case invalidOption(groupID: String, optionID: String)
    case missingFragment(String)

    var diagnosticDescription: String {
        switch self {
        case .missingResource(let resourceName):
            return "Prompt library resource '\(resourceName)' is missing."
        case .missingPolicy(let appID):
            return "Prompt policy for app '\(appID.rawValue)' is missing."
        case .disallowedProfile(let profileID, let appID):
            return "Prompt profile '\(profileID)' is not allowed for app '\(appID.rawValue)'."
        case .missingProfile(let profileID):
            return "Prompt profile '\(profileID)' could not be found."
        case .missingOptionGroup(let groupID):
            return "Prompt option group '\(groupID)' could not be found."
        case .invalidOption(let groupID, let optionID):
            return "Prompt option '\(optionID)' is not valid for option group '\(groupID)'."
        case .missingFragment(let fragmentID):
            return "Prompt fragment '\(fragmentID)' could not be found."
        }
    }
}

enum PromptResolver {
    static func resolve(
        appID: PromptAppID,
        globalSelection: PromptSelection,
        appSelection: PromptSelection,
        library: PromptLibrary,
        legacyCustomPrompt: String
    ) throws -> ResolvedPromptSelection {
        guard let policy = library.policy(for: appID) else {
            throw PromptLibraryError.missingPolicy(appID)
        }

        switch appSelection.mode {
        case .profile:
            return try resolveProfileSelection(
                appSelection,
                source: .appOverride,
                library: library,
                policy: policy
            )
        case .none:
            return .init(source: .appOverride, title: nil, middleSection: nil)
        case .legacyCustom:
            let trimmed = legacyCustomPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            return .init(
                source: .appOverride,
                title: trimmed.isEmpty ? nil : "Legacy Custom",
                middleSection: trimmed.isEmpty ? nil : trimmed
            )
        case .inherit:
            return try resolveGlobalSelection(globalSelection, library: library, policy: policy)
        }
    }

    private static func resolveGlobalSelection(
        _ selection: PromptSelection,
        library: PromptLibrary,
        policy: PromptAppPolicy
    ) throws -> ResolvedPromptSelection {
        switch selection.mode {
        case .profile:
            return try resolveProfileSelection(
                selection,
                source: .globalDefault,
                library: library,
                policy: policy
            )
        case .none, .inherit:
            return .init(source: .none, title: nil, middleSection: nil)
        case .legacyCustom:
            return .init(source: .globalDefault, title: "Legacy Custom", middleSection: nil)
        }
    }

    private static func resolveProfileSelection(
        _ selection: PromptSelection,
        source: PromptSelectionSource,
        library: PromptLibrary,
        policy: PromptAppPolicy
    ) throws -> ResolvedPromptSelection {
        guard let profileID = selection.profileID else {
            return .init(source: source, title: nil, middleSection: nil)
        }
        guard policy.allowedProfileIDs.contains(profileID) else {
            throw PromptLibraryError.disallowedProfile(profileID, policy.appID)
        }
        guard let profile = library.profile(id: profileID) else {
            throw PromptLibraryError.missingProfile(profileID)
        }

        var sections = [profile.body.trimmingCharacters(in: .whitespacesAndNewlines)]

        for groupID in profile.optionGroupIDs where policy.visibleOptionGroupIDs.contains(groupID) {
            guard let group = library.optionGroups[groupID] else {
                throw PromptLibraryError.missingOptionGroup(groupID)
            }

            let selectedOptionIDs = selection.optionSelections[groupID] ?? []
            for optionID in selectedOptionIDs {
                guard let option = group.options.first(where: { $0.id == optionID }) else {
                    throw PromptLibraryError.invalidOption(groupID: groupID, optionID: optionID)
                }
                guard let fragmentID = option.fragmentID else {
                    continue
                }
                guard let fragment = library.fragment(id: fragmentID) else {
                    throw PromptLibraryError.missingFragment(fragmentID)
                }
                sections.append(fragment.body.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        let middleSection = sections
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        return .init(
            source: source,
            title: profile.title,
            middleSection: middleSection.isEmpty ? nil : middleSection
        )
    }
}

private struct PromptRegistryFile: Decodable {
    let profileIDs: [String]
    let fragmentIDs: [String]
    let optionGroups: [PromptOptionGroup]
}
