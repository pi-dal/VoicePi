import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

@MainActor
extension AppController {
    func testLLMConfiguration(_ configuration: LLMConfiguration) async -> Result<String, Error> {
        let refinerConfiguration = LLMRefinerConfiguration(
            baseURL: configuration.baseURL,
            apiKey: configuration.apiKey,
            model: configuration.model,
            refinementPrompt: configuration.refinementPrompt
        )

        do {
            let response = try await llmRefiner.testConnection(configuration: refinerConfiguration)
            return .success(response)
        } catch {
            return .failure(error)
        }
    }

    func testRemoteASRConfiguration(
        _ configuration: RemoteASRConfiguration,
        backend: ASRBackend
    ) async -> Result<String, Error> {
        do {
            try configuration.validate(for: backend)
            let response = try await remoteASRClient.testConnection(backend: backend, with: configuration)
            return .success(response)
        } catch {
            return .failure(error)
        }
    }

    func currentAppVersion() -> String {
        SettingsPresentation.aboutPresentation(infoDictionary: Bundle.main.infoDictionary).version
    }

    func checkForUpdates(trigger: UpdateCheckTrigger) async -> String {
        let source = await refreshInstallationSource()
        applyUpdateExperience(.checking(source: source))

        do {
            let result = try await updateChecker.checkForUpdates(currentVersion: currentAppVersion())
            let statusText = AppUpdateCopy.statusText(for: result)

            switch result {
            case .updateAvailable(let release):
                let delivery = Self.updateDelivery(for: source)
                let phase = AppUpdateExperiencePhase.updateAvailable(
                    release: release,
                    delivery: delivery,
                    source: source
                )
                applyUpdateExperience(
                    phase,
                    presentPanel: Self.shouldPresentUpdatePrompt(
                        trigger: trigger,
                        availableVersion: release.version,
                        lastPromptedVersion: appDefaults.string(forKey: Self.lastPromptedUpdateVersionKey)
                    )
                )
                if Self.shouldPresentUpdatePrompt(
                    trigger: trigger,
                    availableVersion: release.version,
                    lastPromptedVersion: appDefaults.string(forKey: Self.lastPromptedUpdateVersionKey)
                ) {
                    appDefaults.set(release.version, forKey: Self.lastPromptedUpdateVersionKey)
                }
            case .upToDate(let currentVersion):
                applyUpdateExperience(
                    .upToDate(currentVersion: currentVersion, source: source),
                    presentPanel: Self.shouldPresentManualUpdateResultDialog(trigger: trigger, result: result)
                )
            }

            return statusText
        } catch {
            let message = "Update check failed: \(error.localizedDescription)"
            if trigger == .manual {
                applyUpdateExperience(
                    .failed(
                        message: message,
                        delivery: Self.updateDelivery(for: source),
                        source: source,
                        release: currentUpdateRelease()
                    ),
                    presentPanel: true
                )
            } else {
                applyUpdateExperience(.idle(source: source))
            }

            switch trigger {
            case .automatic:
                return "Automatic update check unavailable."
            case .manual:
                return message
            }
        }
    }

    func installDirectUpdate(for release: AppUpdateRelease) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let source = self.installationSource

            do {
                self.applyUpdateExperience(
                    .downloading(release: release, source: source, progress: 0),
                    presentPanel: true
                )
                try await self.installDirectUpdate(release: release, source: source)
            } catch {
                self.applyUpdateExperience(
                    .failed(
                        message: "Automatic install failed: \(error.localizedDescription)",
                        delivery: .inAppInstaller,
                        source: source,
                        release: release
                    ),
                    presentPanel: true
                )
            }
        }
    }

    func installDirectUpdate(release: AppUpdateRelease, source: AppInstallationSource) async throws {
        let updater = AppUpdater(
            owner: "pi-dal",
            repo: "VoicePi",
            releasePrefix: "VoicePi",
            interval: 365 * 24 * 60 * 60,
            provider: VoicePiAppUpdateReleaseProvider()
        )
        activeDirectUpdateInstaller = updater
        let stateObserver = updater.$state.sink { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleUpdaterState(state, release: release, source: source)
            }
        }

        defer {
            stateObserver.cancel()
            activeDirectUpdateInstaller = nil
        }

        try await updater.checkThrowing()

        let downloadedBundle = try await downloadedBundle(from: updater)
        applyUpdateExperience(.installing(release: release, source: source), presentPanel: true)
        try updater.installThrowing(downloadedBundle)
    }

    func downloadedBundle(from updater: AppUpdater) async throws -> Bundle {
        for _ in 0..<Self.directUpdateDownloadPollMaxAttempts {
            let currentState = await MainActor.run(body: { updater.state })
            if case .downloaded(_, _, let bundle) = currentState {
                return bundle
            }

            try await Task.sleep(nanoseconds: Self.directUpdateDownloadPollIntervalNanoseconds)
        }

        throw AppUpdateInstallError.downloadedBundleMissing
    }

    func refreshInstallationSource(forceRefresh: Bool = false) async -> AppInstallationSource {
        if forceRefresh || installationSource == .unknown {
            installationSource = await homebrewInstallationDetector.detectInstallationSource()
        }
        return installationSource
    }

    func applyUpdateExperience(_ phase: AppUpdateExperiencePhase, presentPanel: Bool = false) {
        updateExperiencePhase = phase

        let handler = makeUpdateExperienceActionHandler(for: phase)
        let card = AppUpdateExperience.cardPresentation(for: phase)
        statusBarController?.setAboutUpdateExperience(
            card,
            primaryAction: { handler(card.primaryAction.role) },
            secondaryAction: card.secondaryAction.map { secondary in
                { handler(secondary.role) }
            }
        )
        statusBarController?.setTransientStatus(transientStatusText(for: phase))

        if presentPanel, let panel = AppUpdateExperience.panelPresentation(for: phase) {
            statusBarController?.presentUpdatePanel(panel, actionHandler: handler)
        } else if case .idle = phase {
            statusBarController?.dismissUpdatePanel()
        }
    }

    func makeUpdateExperienceActionHandler(
        for phase: AppUpdateExperiencePhase
    ) -> (AppUpdateActionRole) -> Void {
        { [weak self] role in
            guard let self else { return }

            switch role {
            case .check:
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    _ = await self.checkForUpdates(trigger: .manual)
                }
            case .install:
                if case .updateAvailable(let release, let delivery, _) = phase, delivery == .inAppInstaller {
                    self.installDirectUpdate(for: release)
                }
            case .openRelease:
                if let release = self.release(from: phase) {
                    NSWorkspace.shared.open(release.releasePageURL)
                    self.statusBarController?.setTransientStatus("Opened VoicePi release page")
                }
            case .copyHomebrew:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(HomebrewUpdateInstructions.combinedCommands, forType: .string)
                self.statusBarController?.setTransientStatus("Copied Homebrew update commands")
            case .openHomebrewGuide:
                if let url = URL(string: HomebrewUpdateInstructions.readmeInstallURL) {
                    NSWorkspace.shared.open(url)
                    self.statusBarController?.setTransientStatus("Opened Homebrew install guide")
                }
            case .retry:
                if case let .failed(_, delivery, _, release) = phase,
                   delivery == .inAppInstaller,
                   let release {
                    self.installDirectUpdate(for: release)
                } else {
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        _ = await self.checkForUpdates(trigger: .manual)
                    }
                }
            case .dismiss, .acknowledge:
                self.statusBarController?.dismissUpdatePanel()
            }
        }
    }

    func release(from phase: AppUpdateExperiencePhase) -> AppUpdateRelease? {
        switch phase {
        case .updateAvailable(let release, _, _):
            return release
        case .downloading(let release, _, _):
            return release
        case .installing(let release, _):
            return release
        case .failed(_, _, _, let release):
            return release
        case .idle, .checking, .upToDate:
            return nil
        }
    }

    func currentUpdateRelease() -> AppUpdateRelease? {
        release(from: updateExperiencePhase)
    }

    func transientStatusText(for phase: AppUpdateExperiencePhase) -> String? {
        switch phase {
        case .idle:
            return nil
        case .checking:
            return "Checking GitHub Releases…"
        case .updateAvailable(let release, _, _):
            return "Update available: VoicePi \(release.version)"
        case .downloading(let release, _, _):
            return "Downloading VoicePi \(release.version)…"
        case .installing:
            return "Installing VoicePi update…"
        case .upToDate(let currentVersion, _):
            return "VoicePi \(currentVersion) is up to date."
        case .failed(let message, _, _, _):
            return message
        }
    }

    func handleUpdaterState(
        _ state: AppUpdater.UpdateState,
        release: AppUpdateRelease,
        source: AppInstallationSource
    ) {
        switch state {
        case .downloading(_, _, let fraction):
            applyUpdateExperience(
                .downloading(release: release, source: source, progress: fraction),
                presentPanel: true
            )
        case .downloaded:
            applyUpdateExperience(.installing(release: release, source: source), presentPanel: true)
        case .none, .newVersionDetected:
            break
        }
    }

}
