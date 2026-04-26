import Foundation

enum PromptPresetSource: String, Codable, Equatable {
    case builtInDefault
    case starter
    case user
}
struct PromptPreset: Codable, Equatable, Identifiable {
    static let builtInDefaultID = "voicepi.default"

    let id: String
    var title: String
    var body: String
    let source: PromptPresetSource
    var appBundleIDs: [String]
    var websiteHosts: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case source
        case appBundleIDs
        case websiteHosts
    }

    init(
        id: String,
        title: String,
        body: String,
        source: PromptPresetSource,
        appBundleIDs: [String] = [],
        websiteHosts: [String] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.source = source
        self.appBundleIDs = Self.normalizedUniqueValues(appBundleIDs)
        self.websiteHosts = Self.normalizedWebsiteHosts(websiteHosts)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.body = try container.decode(String.self, forKey: .body)
        self.source = try container.decode(PromptPresetSource.self, forKey: .source)
        self.appBundleIDs = Self.normalizedUniqueValues(
            try container.decodeIfPresent([String].self, forKey: .appBundleIDs) ?? []
        )
        self.websiteHosts = Self.normalizedWebsiteHosts(
            try container.decodeIfPresent([String].self, forKey: .websiteHosts) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(source, forKey: .source)
        try container.encode(Self.normalizedUniqueValues(appBundleIDs), forKey: .appBundleIDs)
        try container.encode(Self.normalizedWebsiteHosts(websiteHosts), forKey: .websiteHosts)
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var resolvedTitle: String {
        let trimmed = trimmedTitle
        return trimmed.isEmpty ? "Untitled Prompt" : trimmed
    }

    var isEditable: Bool {
        source == .user
    }

    func matches(destination: PromptDestinationContext?) -> Bool {
        guard let destination else { return false }

        if matchesAppBundleID(destination.appBundleID) {
            return true
        }

        return matchesWebsiteHost(destination.websiteHost)
    }

    func matchesAppBundleID(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return appBundleIDs.contains(bundleID)
    }

    func matchesWebsiteHost(_ host: String?) -> Bool {
        guard let host else { return false }
        return websiteHosts.contains(where: { Self.websiteHost($0, matches: host) })
    }

    static var builtInDefault: Self {
        .init(
            id: builtInDefaultID,
            title: "VoicePi Default",
            body: "",
            source: .builtInDefault
        )
    }

    private static func normalizedUniqueValues(_ values: [String]) -> [String] {
        var normalized: [String] = []
        var seen: Set<String> = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            normalized.append(trimmed)
        }

        return normalized
    }

    private static func normalizedWebsiteHosts(_ values: [String]) -> [String] {
        normalizedUniqueValues(values.compactMap(PromptDestinationContext.normalizedWebsiteHost))
    }

    private static func websiteHost(_ pattern: String, matches host: String) -> Bool {
        if pattern.hasPrefix("*.") {
            let suffix = String(pattern.dropFirst(1))
            let bareDomain = String(pattern.dropFirst(2))
            return host.hasSuffix(suffix) && host != bareDomain
        }

        return host == pattern
    }
}

enum PromptActiveSelectionMode: String, Codable, Equatable {
    case builtInDefault
    case preset
}

struct PromptActiveSelection: Codable, Equatable {
    var mode: PromptActiveSelectionMode
    var presetID: String?

    init(
        mode: PromptActiveSelectionMode,
        presetID: String? = nil
    ) {
        self.mode = mode
        self.presetID = presetID
    }

    static var builtInDefault: Self {
        .init(mode: .builtInDefault)
    }

    static func preset(_ id: String) -> Self {
        .init(mode: .preset, presetID: id)
    }
}

struct PromptWorkspaceSettings: Codable, Equatable {
    var activeSelection: PromptActiveSelection
    var strictModeEnabled: Bool
    var userPresets: [PromptPreset]

    enum CodingKeys: String, CodingKey {
        case activeSelection
        case strictModeEnabled
        case userPresets
    }

    init(
        activeSelection: PromptActiveSelection = .builtInDefault,
        strictModeEnabled: Bool = true,
        userPresets: [PromptPreset] = []
    ) {
        self.activeSelection = activeSelection
        self.strictModeEnabled = strictModeEnabled
        self.userPresets = userPresets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.activeSelection = try container.decodeIfPresent(
            PromptActiveSelection.self,
            forKey: .activeSelection
        ) ?? .builtInDefault
        self.strictModeEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .strictModeEnabled
        ) ?? true
        self.userPresets = try container.decodeIfPresent(
            [PromptPreset].self,
            forKey: .userPresets
        ) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activeSelection, forKey: .activeSelection)
        try container.encode(strictModeEnabled, forKey: .strictModeEnabled)
        try container.encode(userPresets, forKey: .userPresets)
    }

    func userPreset(id: String) -> PromptPreset? {
        userPresets.first(where: { $0.id == id })
    }

    mutating func saveUserPreset(_ preset: PromptPreset) {
        guard preset.source == .user else { return }
        if let index = userPresets.firstIndex(where: { $0.id == preset.id }) {
            userPresets[index] = preset
        } else {
            userPresets.append(preset)
        }
    }

    mutating func deleteUserPreset(id: String) {
        let removedUserPreset = userPresets.contains(where: { $0.id == id })
        userPresets.removeAll(where: { $0.id == id })
        if removedUserPreset && activeSelection == .preset(id) {
            activeSelection = .builtInDefault
        }
    }

    func appBindingConflicts(for preset: PromptPreset) -> [PromptAppBindingConflict] {
        let targetBundleIDs = Set(preset.appBundleIDs)
        guard !targetBundleIDs.isEmpty else { return [] }

        var conflictsByBundleID: [String: [PromptAppBindingConflictOwner]] = [:]
        for ownerPreset in userPresets where ownerPreset.id != preset.id {
            for bundleID in ownerPreset.appBundleIDs where targetBundleIDs.contains(bundleID) {
                conflictsByBundleID[bundleID, default: []].append(
                    .init(presetID: ownerPreset.id, title: ownerPreset.resolvedTitle)
                )
            }
        }

        return conflictsByBundleID.keys.sorted().map { bundleID in
            let owners = (conflictsByBundleID[bundleID] ?? []).sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return .init(appBundleID: bundleID, owners: owners)
        }
    }

    mutating func reassignConflictingAppBindings(for preset: PromptPreset) {
        let targetBundleIDs = Set(preset.appBundleIDs)
        guard !targetBundleIDs.isEmpty else { return }

        for index in userPresets.indices {
            guard userPresets[index].id != preset.id else { continue }
            userPresets[index].appBundleIDs.removeAll(where: { targetBundleIDs.contains($0) })
        }
    }
}

struct PromptAppBindingConflictOwner: Equatable {
    let presetID: String
    let title: String
}

struct PromptAppBindingConflict: Equatable {
    let appBundleID: String
    let owners: [PromptAppBindingConflictOwner]
}

enum ResolvedPromptPresetSource: Equatable {
    case builtInDefault
    case starter
    case user
}

struct ResolvedPromptPreset: Equatable {
    let presetID: String?
    let title: String
    let middleSection: String?
    let source: ResolvedPromptPresetSource
}

enum PromptWorkspaceResolver {
    static func resolve(
        workspace: PromptWorkspaceSettings,
        destination: PromptDestinationContext? = nil,
        library: PromptLibrary
    ) -> ResolvedPromptPreset {
        if workspace.strictModeEnabled {
            if let appBundleID = destination?.appBundleID,
               let appBoundPreset = workspace.userPresets.last(where: { $0.matchesAppBundleID(appBundleID) }) {
                return resolvedPreset(from: appBoundPreset)
            }

            if let websiteHost = destination?.websiteHost,
               let websiteBoundPreset = workspace.userPresets.last(where: {
                   $0.matchesWebsiteHost(websiteHost)
               }) {
                return resolvedPreset(from: websiteBoundPreset)
            }
        }

        switch workspace.activeSelection.mode {
        case .builtInDefault:
            return resolvedPreset(from: PromptPreset.builtInDefault)
        case .preset:
            guard
                let presetID = workspace.activeSelection.presetID,
                let preset = resolvePreset(
                    id: presetID,
                    userPresets: workspace.userPresets,
                    starterPresets: library.starterPresets
                )
            else {
                return resolvedPreset(from: PromptPreset.builtInDefault)
            }
            return resolvedPreset(from: preset)
        }
    }

    private static func resolvePreset(
        id: String,
        userPresets: [PromptPreset],
        starterPresets: [PromptPreset]
    ) -> PromptPreset? {
        if let userPreset = userPresets.first(where: { $0.id == id }) {
            return userPreset
        }

        return starterPresets.first(where: { $0.id == id })
    }

    private static func resolvedPreset(from preset: PromptPreset) -> ResolvedPromptPreset {
        let middleSection = preset.trimmedBody.isEmpty ? nil : preset.trimmedBody

        return .init(
            presetID: preset.id,
            title: preset.resolvedTitle,
            middleSection: middleSection,
            source: resolvedSource(for: preset.source)
        )
    }

    private static func resolvedSource(for source: PromptPresetSource) -> ResolvedPromptPresetSource {
        switch source {
        case .builtInDefault:
            return .builtInDefault
        case .starter:
            return .starter
        case .user:
            return .user
        }
    }
}

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
