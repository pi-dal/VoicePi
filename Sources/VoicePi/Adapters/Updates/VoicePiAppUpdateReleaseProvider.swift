import AppUpdater
import Foundation

struct VoicePiAppUpdateReleaseProvider: ReleaseProvider {
    private let githubProvider: GithubReleaseProvider
    private let session: URLSession

    init(
        githubProvider: GithubReleaseProvider = .init(),
        session: URLSession = .shared
    ) {
        self.githubProvider = githubProvider
        self.session = session
    }

    func fetchReleases(owner: String, repo: String, proxy: URLRequestProxy?) async throws -> [Release] {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AppUpdateError.invalidResponse
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode([GitHubReleasePayload].self, from: data)
        let adapted = payload.map { $0.appUpdaterPayload() }
        let encoded = try JSONEncoder().encode(adapted)
        return try decoder.decode([Release].self, from: encoded)
    }

    func download(
        asset: Release.Asset,
        to saveLocation: URL,
        proxy: URLRequestProxy?
    ) async throws -> AsyncThrowingStream<DownloadingState, Error> {
        try await githubProvider.download(asset: asset, to: saveLocation, proxy: proxy)
    }

    func fetchAssetData(asset: Release.Asset, proxy: URLRequestProxy?) async throws -> Data {
        try await githubProvider.fetchAssetData(asset: asset, proxy: proxy)
    }
}

private struct GitHubReleasePayload: Codable {
    let tagName: String
    let prerelease: Bool
    let assets: [GitHubReleaseAssetPayload]
    let body: String
    let name: String
    let htmlURL: String

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case prerelease
        case assets
        case body
        case name
        case htmlURL = "html_url"
    }

    func appUpdaterPayload() -> GitHubReleasePayload {
        let normalizedVersion = tagName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)

        return GitHubReleasePayload(
            tagName: tagName,
            prerelease: prerelease,
            assets: assets.map { $0.appUpdaterPayload(version: normalizedVersion) },
            body: body,
            name: name,
            htmlURL: htmlURL
        )
    }
}

private struct GitHubReleaseAssetPayload: Codable {
    let name: String
    let browserDownloadURL: String
    let contentType: String

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case contentType = "content_type"
    }

    func appUpdaterPayload(version: String) -> GitHubReleaseAssetPayload {
        guard name == "VoicePi-macOS.zip" else {
            return self
        }

        return GitHubReleaseAssetPayload(
            name: ReleaseAssetNaming.zipAssetName(version: version),
            browserDownloadURL: browserDownloadURL,
            contentType: contentType
        )
    }
}
