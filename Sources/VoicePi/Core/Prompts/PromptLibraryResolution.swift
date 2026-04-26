import AppKit
import Foundation

struct PromptLibrary: Equatable {
    static let bundledResourceBundleName = "VoicePi_VoicePi"

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

    var starterPresets: [PromptPreset] {
        profiles.values
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map {
                PromptPreset(
                    id: $0.id,
                    title: $0.title,
                    body: $0.body,
                    source: .starter
                )
            }
    }

    static func loadBundled(bundle: Bundle? = nil) throws -> PromptLibrary {
        let resourceContainer = try resolveBundledResourceContainer(from: bundle)
        let decoder = JSONDecoder()

        let registry = try decoder.decode(
            PromptRegistryFile.self,
            from: loadResource(
                named: "registry",
                extension: "json",
                container: resourceContainer
            )
        )

        let profiles = try registry.profileIDs.map {
            try decoder.decode(
                PromptProfile.self,
                from: loadResource(named: $0, extension: "json", container: resourceContainer)
            )
        }
        let fragments = try registry.fragmentIDs.map {
            try decoder.decode(
                PromptFragment.self,
                from: loadResource(named: $0, extension: "json", container: resourceContainer)
            )
        }
        let appPolicies = try PromptAppID.allCases.map {
            try decoder.decode(
                PromptAppPolicy.self,
                from: loadResource(named: $0.resourceName, extension: "json", container: resourceContainer)
            )
        }

        return PromptLibrary(
            optionGroups: Dictionary(uniqueKeysWithValues: registry.optionGroups.map { ($0.id, $0) }),
            profiles: Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) }),
            fragments: Dictionary(uniqueKeysWithValues: fragments.map { ($0.id, $0) }),
            appPolicies: Dictionary(uniqueKeysWithValues: appPolicies.map { ($0.appID, $0) })
        )
    }

    private static func resolveBundledResourceContainer(from bundle: Bundle?) throws -> PromptResourceContainer {
        if let bundle {
            if bundle.url(forResource: "registry", withExtension: "json") != nil {
                return .bundle(bundle)
            }

            if let resourceDirectory = findBundledResourceDirectory(near: [bundle]) {
                return .directory(resourceDirectory)
            }
        }

        if let resourceDirectory = findBundledResourceDirectory(near: [Bundle.main]) {
            return .directory(resourceDirectory)
        }

        throw PromptLibraryError.missingResourceBundle("\(bundledResourceBundleName).bundle")
    }

    private static func findBundledResourceDirectory(near hostBundles: [Bundle]) -> URL? {
        var seenPaths: Set<String> = []

        for hostBundle in hostBundles {
            for candidateURL in bundledResourceBundleCandidateURLs(near: hostBundle) {
                let candidatePath = candidateURL.standardizedFileURL.path
                guard seenPaths.insert(candidatePath).inserted else { continue }
                let registryURL = candidateURL.appendingPathComponent("registry.json")
                guard FileManager.default.fileExists(atPath: registryURL.path) else { continue }
                return candidateURL
            }
        }

        if let buildDirectoryResource = findBundledResourceDirectoryInBuildProducts() {
            return buildDirectoryResource
        }

        return nil
    }

    private static func bundledResourceBundleCandidateURLs(near hostBundle: Bundle) -> [URL] {
        let bundleDirectoryName = "\(bundledResourceBundleName).bundle"
        var urls: [URL] = []
        var seenPaths: Set<String> = []

        func append(_ url: URL?) {
            guard let url else { return }
            let path = url.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else { return }
            urls.append(url)
        }

        append(hostBundle.resourceURL?.appendingPathComponent(bundleDirectoryName, isDirectory: true))
        append(hostBundle.bundleURL.appendingPathComponent(bundleDirectoryName, isDirectory: true))
        append(hostBundle.bundleURL.deletingLastPathComponent().appendingPathComponent(bundleDirectoryName, isDirectory: true))
        append(hostBundle.executableURL?.deletingLastPathComponent().appendingPathComponent(bundleDirectoryName, isDirectory: true))

        return urls
    }

    private static func findBundledResourceDirectoryInBuildProducts() -> URL? {
        let fileManager = FileManager.default
        let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)

        guard fileManager.fileExists(atPath: currentDirectoryURL.appendingPathComponent("Package.swift").path) else {
            return nil
        }

        let buildDirectoryURL = currentDirectoryURL.appendingPathComponent(".build", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: buildDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let bundleDirectoryName = "\(bundledResourceBundleName).bundle"
        for case let candidateURL as URL in enumerator {
            guard candidateURL.lastPathComponent == bundleDirectoryName else { continue }
            let registryURL = candidateURL.appendingPathComponent("registry.json")
            guard fileManager.fileExists(atPath: registryURL.path) else { continue }
            return candidateURL
        }

        return nil
    }

    private static func loadResource(
        named name: String,
        extension ext: String,
        container: PromptResourceContainer
    ) throws -> Data {
        guard let url = container.url(forResource: name, withExtension: ext) else {
            throw PromptLibraryError.missingResource("\(name).\(ext)")
        }

        return try Data(contentsOf: url)
    }
}

private enum PromptResourceContainer {
    case bundle(Bundle)
    case directory(URL)

    func url(forResource name: String, withExtension ext: String) -> URL? {
        switch self {
        case .bundle(let bundle):
            return bundle.url(forResource: name, withExtension: ext)
        case .directory(let directoryURL):
            let resourceURL = directoryURL.appendingPathComponent("\(name).\(ext)")
            guard FileManager.default.fileExists(atPath: resourceURL.path) else { return nil }
            return resourceURL
        }
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
    case missingResourceBundle(String)
    case missingResource(String)
    case missingPolicy(PromptAppID)
    case disallowedProfile(String, PromptAppID)
    case missingProfile(String)
    case missingOptionGroup(String)
    case invalidOption(groupID: String, optionID: String)
    case missingFragment(String)

    var diagnosticDescription: String {
        switch self {
        case .missingResourceBundle(let bundleName):
            return "Prompt library bundle '\(bundleName)' is missing."
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
            let normalizedOptionIDs: [String]
            switch group.selection {
            case .single:
                normalizedOptionIDs = Array(selectedOptionIDs.prefix(1))
            case .multi:
                normalizedOptionIDs = selectedOptionIDs
            }

            for optionID in normalizedOptionIDs {
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
