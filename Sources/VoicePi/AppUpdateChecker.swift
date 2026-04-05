import Foundation

struct AppVersion: Comparable, Equatable, Sendable {
    let components: [Int]

    init?(_ rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)

        guard !normalized.isEmpty else {
            return nil
        }

        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            return nil
        }

        var parsed: [Int] = []
        parsed.reserveCapacity(parts.count)

        for part in parts {
            guard let value = Int(part) else {
                return nil
            }
            parsed.append(value)
        }

        var normalizedComponents = parsed
        while normalizedComponents.count > 1, normalizedComponents.last == 0 {
            normalizedComponents.removeLast()
        }

        components = normalizedComponents
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

struct AppUpdateRelease: Equatable, Sendable {
    let version: String
    let releasePageURL: URL
    let assetURL: URL
    let notes: String
}

enum AppInstallationSource: Equatable, Sendable {
    case homebrewManaged
    case directDownload
    case unknown
}

enum AppUpdateDelivery: Equatable, Sendable {
    case homebrew
    case inAppInstaller
}

enum AppUpdateCheckResult: Equatable, Sendable {
    case upToDate(currentVersion: String)
    case updateAvailable(AppUpdateRelease)
}

enum UpdateCheckTrigger {
    case automatic
    case manual
}

enum AppUpdateError: LocalizedError {
    case invalidCurrentVersion(String)
    case invalidReleaseVersion(String)
    case invalidResponse
    case missingReleasePageURL
    case missingZipAsset

    var errorDescription: String? {
        switch self {
        case .invalidCurrentVersion(let version):
            return "The current app version is invalid: \(version)"
        case .invalidReleaseVersion(let version):
            return "The latest release version is invalid: \(version)"
        case .invalidResponse:
            return "GitHub returned an invalid update response."
        case .missingReleasePageURL:
            return "The latest release is missing its release page URL."
        case .missingZipAsset:
            return "The latest release does not include a VoicePi zip asset."
        }
    }
}

enum HomebrewUpdateInstructions {
    static let readmeInstallURL = "https://github.com/pi-dal/VoicePi#install-with-homebrew"
    static let tapCommand = "brew tap pi-dal/voicepi https://github.com/pi-dal/VoicePi"
    static let installCommand = "brew install --cask pi-dal/voicepi/voicepi"
    static let upgradeCommand = "brew upgrade --cask pi-dal/voicepi/voicepi"

    static let combinedCommands =
        """
        \(tapCommand)
        \(installCommand)

        # If VoicePi is already installed with Homebrew:
        \(upgradeCommand)
        """
}

struct AppUpdatePromptContent: Equatable {
    let messageText: String
    let informativeText: String
    let statusText: String
}

enum ReleaseAssetNaming {
    static func zipAssetName(version: String, appName: String = "VoicePi") -> String {
        "\(appName)-\(version).zip"
    }
}

enum AppUpdateCopy {
    static func promptContent(
        for release: AppUpdateRelease,
        delivery: AppUpdateDelivery
    ) -> AppUpdatePromptContent {
        let notes = release.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesSection = notes.isEmpty ? "" : "\n\nRelease notes:\n\(notes)"
        switch delivery {
        case .homebrew:
            return AppUpdatePromptContent(
                messageText: "VoicePi \(release.version) Is Available",
                informativeText:
                    """
                    A newer VoicePi release is available on GitHub.

                    Homebrew is the recommended installation and update path:
                    Guide: \(HomebrewUpdateInstructions.readmeInstallURL)
                    \(HomebrewUpdateInstructions.tapCommand)
                    \(HomebrewUpdateInstructions.installCommand)

                    If you already installed VoicePi with Homebrew:
                    \(HomebrewUpdateInstructions.upgradeCommand)\(notesSection)
                    """,
                statusText: "Update available: VoicePi \(release.version)"
            )
        case .inAppInstaller:
            return AppUpdatePromptContent(
                messageText: "VoicePi \(release.version) Is Available",
                informativeText:
                    """
                    A newer VoicePi release is available on GitHub.

                    VoicePi can download and install this update automatically for direct-download installs.
                    If you prefer the manual route, you can still open the release page and install it yourself.\(notesSection)
                    """,
                statusText: "Update available: VoicePi \(release.version)"
            )
        }
    }

    static func statusText(for result: AppUpdateCheckResult) -> String {
        switch result {
        case .upToDate(let currentVersion):
            return "VoicePi \(currentVersion) is up to date."
        case .updateAvailable(let release):
            return "Update available: VoicePi \(release.version)"
        }
    }

    static func upToDatePromptContent(currentVersion: String) -> AppUpdatePromptContent {
        AppUpdatePromptContent(
            messageText: "VoicePi \(currentVersion) Is Up to Date",
            informativeText:
                """
                You already have the latest published version of VoicePi.

                Homebrew install and upgrade guide:
                \(HomebrewUpdateInstructions.readmeInstallURL)
                """,
            statusText: "VoicePi \(currentVersion) is up to date."
        )
    }

    static func failurePromptContent(message: String) -> AppUpdatePromptContent {
        AppUpdatePromptContent(
            messageText: "Update Check Failed",
            informativeText:
                """
                VoicePi could not confirm the latest version right now.

                \(message)

                Homebrew install and upgrade guide:
                \(HomebrewUpdateInstructions.readmeInstallURL)
                """,
            statusText: message
        )
    }
}

final class GitHubReleaseUpdateChecker {
    private let session: URLSession
    private let repository: String

    init(session: URLSession = .shared, repository: String = "pi-dal/VoicePi") {
        self.session = session
        self.repository = repository
    }

    func checkForUpdates(currentVersion: String) async throws -> AppUpdateCheckResult {
        guard let currentVersion = AppVersion(currentVersion) else {
            throw AppUpdateError.invalidCurrentVersion(currentVersion)
        }

        let release = try await fetchLatestRelease()
        guard let releaseVersion = AppVersion(release.tagName) else {
            throw AppUpdateError.invalidReleaseVersion(release.tagName)
        }

        let normalizedReleaseVersion = release.tagName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)

        guard releaseVersion > currentVersion else {
            return .upToDate(currentVersion: currentVersionString(from: currentVersion))
        }

        guard let releasePageURL = URL(string: release.htmlURL), !release.htmlURL.isEmpty else {
            throw AppUpdateError.missingReleasePageURL
        }

        let expectedAssetName = ReleaseAssetNaming.zipAssetName(version: normalizedReleaseVersion)
        guard let asset = release.assets.first(where: { $0.name == expectedAssetName }) ??
            release.assets.first(where: { $0.name == "VoicePi-macOS.zip" }) ??
            release.assets.first(where: { $0.name.hasSuffix(".zip") }),
            let assetURL = URL(string: asset.browserDownloadURL) else {
            throw AppUpdateError.missingZipAsset
        }

        return .updateAvailable(
            AppUpdateRelease(
                version: normalizedReleaseVersion,
                releasePageURL: releasePageURL,
                assetURL: assetURL,
                notes: release.body
            )
        )
    }

    private func fetchLatestRelease() async throws -> GitHubLatestRelease {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw AppUpdateError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AppUpdateError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GitHubLatestRelease.self, from: data)
    }

    private func currentVersionString(from version: AppVersion) -> String {
        version.components.map(String.init).joined(separator: ".")
    }
}

private struct GitHubLatestRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let body: String
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
