import Foundation
import Testing
@testable import VoicePi

@Suite(.serialized)
struct AppUpdateCheckerTests {
    @Test
    func semanticVersionsCompareNumerically() throws {
        let v1100 = try #require(AppVersion("1.10.0"))
        let v129 = try #require(AppVersion("1.2.9"))
        let v20 = try #require(AppVersion("2.0"))
        let v1999999 = try #require(AppVersion("1.999.999"))
        let v120 = try #require(AppVersion("1.2.0"))
        let v12 = try #require(AppVersion("1.2"))

        #expect(v1100 > v129)
        #expect(v20 > v1999999)
        #expect(v120 == v12)
    }

    @Test
    func checkForUpdatesReturnsNewerPublishedRelease() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppUpdateTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let checker = GitHubReleaseUpdateChecker(session: session, repository: "pi-dal/VoicePi")

        let capturedRequests = RequestCapture()
        AppUpdateTestURLProtocol.shared.setHandler { request in
            capturedRequests.append(request)
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(
                """
                {
                  "tag_name": "v1.4.0",
                  "html_url": "https://github.com/pi-dal/VoicePi/releases/tag/v1.4.0",
                  "body": "Bug fixes and polish",
                  "draft": false,
                  "prerelease": false,
                  "assets": [
                    {
                      "name": "VoicePi-macOS.zip",
                      "browser_download_url": "https://github.com/pi-dal/VoicePi/releases/download/v1.4.0/VoicePi-macOS.zip"
                    }
                  ]
                }
                """.utf8
            )
            return (response, data)
        }
        defer { AppUpdateTestURLProtocol.shared.reset() }

        let result = try await checker.checkForUpdates(currentVersion: "1.3.0")

        #expect(
            result == .updateAvailable(
                .init(
                    version: "1.4.0",
                    releasePageURL: URL(string: "https://github.com/pi-dal/VoicePi/releases/tag/v1.4.0")!,
                    assetURL: URL(string: "https://github.com/pi-dal/VoicePi/releases/download/v1.4.0/VoicePi-macOS.zip")!,
                    notes: "Bug fixes and polish"
                )
            )
        )
        let request = try #require(capturedRequests.snapshot.first)
        #expect(request.url?.absoluteString == "https://api.github.com/repos/pi-dal/VoicePi/releases/latest")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
    }

    @Test
    func checkForUpdatesReturnsUpToDateWhenReleaseIsNotNewer() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppUpdateTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let checker = GitHubReleaseUpdateChecker(session: session, repository: "pi-dal/VoicePi")

        AppUpdateTestURLProtocol.shared.setHandler { request in
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(
                """
                {
                  "tag_name": "v1.2.3",
                  "html_url": "https://github.com/pi-dal/VoicePi/releases/tag/v1.2.3",
                  "body": "Current release",
                  "draft": false,
                  "prerelease": false,
                  "assets": []
                }
                """.utf8
            )
            return (response, data)
        }
        defer { AppUpdateTestURLProtocol.shared.reset() }

        let result = try await checker.checkForUpdates(currentVersion: "1.2.3")

        #expect(result == .upToDate(currentVersion: "1.2.3"))
    }

    @Test
    func homebrewInstructionsIncludeTapInstallAndUpgradeCommands() {
        let instructions = HomebrewUpdateInstructions.combinedCommands

        #expect(instructions.contains("brew tap pi-dal/voicepi https://github.com/pi-dal/VoicePi"))
        #expect(instructions.contains("brew install --cask pi-dal/voicepi/voicepi"))
        #expect(instructions.contains("brew upgrade --cask pi-dal/voicepi/voicepi"))
    }

    @Test
    func promptContentLinksToHomebrewReadmeSection() {
        let content = AppUpdateCopy.promptContent(
            for: .init(
                version: "1.4.0",
                releasePageURL: URL(string: "https://github.com/pi-dal/VoicePi/releases/tag/v1.4.0")!,
                assetURL: URL(string: "https://github.com/pi-dal/VoicePi/releases/download/v1.4.0/VoicePi-macOS.zip")!,
                notes: "Bug fixes"
            )
        )

        #expect(content.informativeText.contains("https://github.com/pi-dal/VoicePi#install-with-homebrew"))
    }
}

private final class AppUpdateTestURLProtocol: URLProtocol, @unchecked Sendable {
    static let shared = AppUpdateTestURLProtocol()

    private let lock = NSLock()
    private var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    func setHandler(
        _ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func reset() {
        lock.lock()
        handler = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
        AppUpdateTestURLProtocol.shared.lock.lock()
        handler = AppUpdateTestURLProtocol.shared.handler
        AppUpdateTestURLProtocol.shared.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
