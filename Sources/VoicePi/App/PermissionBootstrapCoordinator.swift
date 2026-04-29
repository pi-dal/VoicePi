import AppUpdater
import Combine
import Foundation

@MainActor
final class PermissionBootstrapCoordinator {
    weak var appController: AppController?

    init() {}

    func configure(with appController: AppController) {
        self.appController = appController
    }

    var accessibilityAuthorizationFollowUpTask: Task<Void, Never>? {
        get { appController?.accessibilityAuthorizationFollowUpTask }
        set {
            guard let appController else { return }
            appController.accessibilityAuthorizationFollowUpTask = newValue
        }
    }

    var inputMonitoringAuthorizationFollowUpTask: Task<Void, Never>? {
        get { appController?.inputMonitoringAuthorizationFollowUpTask }
        set {
            guard let appController else { return }
            appController.inputMonitoringAuthorizationFollowUpTask = newValue
        }
    }

    var installationSource: AppInstallationSource {
        get { appController?.installationSource ?? .unknown }
        set {
            guard let appController else { return }
            appController.installationSource = newValue
        }
    }

    var activeDirectUpdateInstaller: AppUpdater? {
        get { appController?.activeDirectUpdateInstaller }
        set {
            guard let appController else { return }
            appController.activeDirectUpdateInstaller = newValue
        }
    }

    var updateExperiencePhase: AppUpdateExperiencePhase {
        get { appController?.updateExperiencePhase ?? .idle(source: .unknown) }
        set {
            guard let appController else { return }
            appController.updateExperiencePhase = newValue
        }
    }

    var startupHotkeyBootstrapTask: Task<Void, Never>? {
        get { appController?.startupHotkeyBootstrapTask }
        set {
            guard let appController else { return }
            appController.startupHotkeyBootstrapTask = newValue
        }
    }
}
