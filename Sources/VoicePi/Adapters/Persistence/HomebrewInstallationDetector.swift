import Foundation

struct HomebrewInstallationDetector {
    private static let brewExecutableCandidates = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew"
    ]

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func detectInstallationSource(bundleURL: URL = Bundle.main.bundleURL) async -> AppInstallationSource {
        let resolvedBundlePath = bundleURL.resolvingSymlinksInPath().path.lowercased()
        if resolvedBundlePath.contains("/caskroom/voicepi/") {
            return .homebrewManaged
        }

        guard let brewExecutablePath = Self.brewExecutableCandidates.first(where: fileManager.isExecutableFile(atPath:)) else {
            return .directDownload
        }

        guard let exitCode = await runHomebrewList(using: brewExecutablePath) else {
            return .unknown
        }

        switch exitCode {
        case 0:
            return .homebrewManaged
        case 1:
            return .directDownload
        default:
            return .unknown
        }
    }

    private func runHomebrewList(using brewExecutablePath: String) async -> Int32? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brewExecutablePath)
            process.arguments = ["list", "--cask", "voicepi"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
