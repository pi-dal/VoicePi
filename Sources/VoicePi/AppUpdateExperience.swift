import Foundation

enum AppUpdateActionRole: Equatable {
    case check
    case install
    case openRelease
    case copyHomebrew
    case openHomebrewGuide
    case retry
    case dismiss
    case acknowledge
}

struct AppUpdateActionPresentation: Equatable {
    let title: String
    let role: AppUpdateActionRole
    let isEnabled: Bool
}

struct AppUpdateProgressPresentation: Equatable {
    let label: String
    let fraction: Double?
    let isIndeterminate: Bool
}

struct AppUpdateCardPresentation: Equatable {
    let title: String
    let summary: String
    let statusText: String
    let sourceText: String
    let strategyText: String
    let primaryAction: AppUpdateActionPresentation
    let secondaryAction: AppUpdateActionPresentation?
    let progress: AppUpdateProgressPresentation?
}

struct AppUpdatePanelPresentation: Equatable {
    let title: String
    let summary: String
    let statusText: String
    let sourceText: String
    let strategyText: String
    let releaseNotes: String?
    let primaryAction: AppUpdateActionPresentation
    let secondaryAction: AppUpdateActionPresentation?
    let tertiaryAction: AppUpdateActionPresentation?
    let progress: AppUpdateProgressPresentation?
}

enum AppUpdateExperiencePhase: Equatable {
    case idle(source: AppInstallationSource)
    case checking(source: AppInstallationSource)
    case updateAvailable(release: AppUpdateRelease, delivery: AppUpdateDelivery, source: AppInstallationSource)
    case downloading(release: AppUpdateRelease, source: AppInstallationSource, progress: Double)
    case installing(release: AppUpdateRelease, source: AppInstallationSource)
    case upToDate(currentVersion: String, source: AppInstallationSource)
    case failed(message: String, delivery: AppUpdateDelivery, source: AppInstallationSource, release: AppUpdateRelease?)
}

enum AppUpdateExperience {
    static func cardPresentation(for phase: AppUpdateExperiencePhase) -> AppUpdateCardPresentation {
        switch phase {
        case .idle(let source):
            return AppUpdateCardPresentation(
                title: "Update Experience",
                summary: "VoicePi checks GitHub Releases and uses the right update path for this install.",
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: updateDelivery(for: source)),
                primaryAction: .init(title: "Check for Updates", role: .check, isEnabled: true),
                secondaryAction: nil,
                progress: nil
            )
        case .checking(let source):
            return AppUpdateCardPresentation(
                title: "Update Experience",
                summary: "Checking the latest published VoicePi release on GitHub.",
                statusText: "Checking",
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: updateDelivery(for: source)),
                primaryAction: .init(title: "Checking…", role: .check, isEnabled: false),
                secondaryAction: nil,
                progress: .init(label: "Contacting GitHub Releases", fraction: nil, isIndeterminate: true)
            )
        case .updateAvailable(let release, let delivery, let source):
            return AppUpdateCardPresentation(
                title: "VoicePi \(release.version) Is Available",
                summary: availableSummary(for: delivery),
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: delivery),
                primaryAction: primaryAction(for: delivery),
                secondaryAction: secondaryAction(for: delivery),
                progress: nil
            )
        case .downloading(let release, let source, let progress):
            let percentage = max(0, min(100, Int((progress * 100).rounded())))
            return AppUpdateCardPresentation(
                title: "Updating to VoicePi \(release.version)",
                summary: "VoicePi is downloading the new version in the background.",
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: .inAppInstaller),
                primaryAction: .init(title: "Downloading…", role: .install, isEnabled: false),
                secondaryAction: .init(title: "View Release", role: .openRelease, isEnabled: true),
                progress: .init(label: "Downloading \(percentage)%", fraction: progress, isIndeterminate: false)
            )
        case .installing(let release, let source):
            return AppUpdateCardPresentation(
                title: "Updating to VoicePi \(release.version)",
                summary: "VoicePi is replacing the current app and preparing to relaunch.",
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: .inAppInstaller),
                primaryAction: .init(title: "Installing…", role: .install, isEnabled: false),
                secondaryAction: nil,
                progress: .init(label: "Installing update", fraction: nil, isIndeterminate: true)
            )
        case .upToDate(let currentVersion, let source):
            return AppUpdateCardPresentation(
                title: "VoicePi \(currentVersion) Is Up to Date",
                summary: "You already have the latest published version of VoicePi.",
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: updateDelivery(for: source)),
                primaryAction: .init(title: "Check Again", role: .check, isEnabled: true),
                secondaryAction: nil,
                progress: nil
            )
        case .failed(let message, let delivery, let source, _):
            return AppUpdateCardPresentation(
                title: "Update Failed",
                summary: message,
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: delivery),
                primaryAction: .init(title: "Retry", role: .retry, isEnabled: true),
                secondaryAction: nil,
                progress: nil
            )
        }
    }

    static func panelPresentation(for phase: AppUpdateExperiencePhase) -> AppUpdatePanelPresentation? {
        switch phase {
        case .idle, .checking:
            return nil
        case .updateAvailable(let release, let delivery, let source):
            return AppUpdatePanelPresentation(
                title: "VoicePi \(release.version) Is Available",
                summary: availableSummary(for: delivery),
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: delivery),
                releaseNotes: cleanedNotes(release.notes),
                primaryAction: primaryAction(for: delivery),
                secondaryAction: secondaryAction(for: delivery),
                tertiaryAction: .init(title: "Later", role: .dismiss, isEnabled: true),
                progress: nil
            )
        case .downloading(let release, let source, let progress):
            let percentage = max(0, min(100, Int((progress * 100).rounded())))
            return AppUpdatePanelPresentation(
                title: "Updating to VoicePi \(release.version)",
                summary: "VoicePi is downloading the new version for this direct install.",
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: .inAppInstaller),
                releaseNotes: cleanedNotes(release.notes),
                primaryAction: .init(title: "Downloading…", role: .install, isEnabled: false),
                secondaryAction: .init(title: "View Release", role: .openRelease, isEnabled: true),
                tertiaryAction: .init(title: "Close", role: .dismiss, isEnabled: true),
                progress: .init(label: "Downloading \(percentage)%", fraction: progress, isIndeterminate: false)
            )
        case .installing(let release, let source):
            return AppUpdatePanelPresentation(
                title: "Installing VoicePi \(release.version)",
                summary: "VoicePi is replacing the current app and will relaunch when it finishes.",
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: .inAppInstaller),
                releaseNotes: cleanedNotes(release.notes),
                primaryAction: .init(title: "Installing…", role: .install, isEnabled: false),
                secondaryAction: nil,
                tertiaryAction: .init(title: "Close", role: .dismiss, isEnabled: true),
                progress: .init(label: "Installing update", fraction: nil, isIndeterminate: true)
            )
        case .upToDate(let currentVersion, let source):
            return AppUpdatePanelPresentation(
                title: "VoicePi \(currentVersion) Is Up to Date",
                summary: "You already have the latest published version of VoicePi.",
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: updateDelivery(for: source)),
                releaseNotes: nil,
                primaryAction: .init(title: "OK", role: .acknowledge, isEnabled: true),
                secondaryAction: source == .homebrewManaged
                    ? .init(title: "Open Homebrew Guide", role: .openHomebrewGuide, isEnabled: true)
                    : nil,
                tertiaryAction: nil,
                progress: nil
            )
        case .failed(let message, let delivery, let source, let release):
            return AppUpdatePanelPresentation(
                title: "Update Failed",
                summary: message,
                statusText: sourceStatusText(source),
                sourceText: sourceDescription(source),
                strategyText: strategyText(for: delivery),
                releaseNotes: release.flatMap { cleanedNotes($0.notes) },
                primaryAction: .init(title: "Retry", role: .retry, isEnabled: true),
                secondaryAction: failureSecondaryAction(for: delivery, release: release),
                tertiaryAction: .init(title: "Close", role: .dismiss, isEnabled: true),
                progress: nil
            )
        }
    }

    private static func primaryAction(for delivery: AppUpdateDelivery) -> AppUpdateActionPresentation {
        switch delivery {
        case .homebrew:
            return .init(title: "Copy Homebrew Commands", role: .copyHomebrew, isEnabled: true)
        case .inAppInstaller:
            return .init(title: "Install Update", role: .install, isEnabled: true)
        }
    }

    private static func secondaryAction(for delivery: AppUpdateDelivery) -> AppUpdateActionPresentation {
        switch delivery {
        case .homebrew:
            return .init(title: "Open Homebrew Guide", role: .openHomebrewGuide, isEnabled: true)
        case .inAppInstaller:
            return .init(title: "View Release", role: .openRelease, isEnabled: true)
        }
    }

    private static func failureSecondaryAction(
        for delivery: AppUpdateDelivery,
        release: AppUpdateRelease?
    ) -> AppUpdateActionPresentation? {
        switch delivery {
        case .homebrew:
            return .init(title: "Open Homebrew Guide", role: .openHomebrewGuide, isEnabled: true)
        case .inAppInstaller:
            return release == nil ? nil : .init(title: "View Release", role: .openRelease, isEnabled: true)
        }
    }

    private static func availableSummary(for delivery: AppUpdateDelivery) -> String {
        switch delivery {
        case .homebrew:
            return "This copy is managed by Homebrew, so VoicePi keeps the upgrade flow on the Homebrew path."
        case .inAppInstaller:
            return "This copy was installed directly, so VoicePi can download and install the update for you."
        }
    }

    private static func sourceStatusText(_ source: AppInstallationSource) -> String {
        switch source {
        case .homebrewManaged:
            return "Homebrew Managed"
        case .directDownload:
            return "Direct Install"
        case .unknown:
            return "Install Source Unknown"
        }
    }

    private static func sourceDescription(_ source: AppInstallationSource) -> String {
        switch source {
        case .homebrewManaged:
            return "Install source: Homebrew"
        case .directDownload:
            return "Install source: Direct download"
        case .unknown:
            return "Install source: Unknown"
        }
    }

    private static func strategyText(for delivery: AppUpdateDelivery) -> String {
        switch delivery {
        case .homebrew:
            return "Updates stay on the Homebrew path to preserve package-manager ownership."
        case .inAppInstaller:
            return "VoicePi can download and replace the app in place."
        }
    }

    private static func updateDelivery(for source: AppInstallationSource) -> AppUpdateDelivery {
        switch source {
        case .homebrewManaged:
            return .homebrew
        case .directDownload, .unknown:
            return .inAppInstaller
        }
    }

    private static func cleanedNotes(_ notes: String) -> String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
