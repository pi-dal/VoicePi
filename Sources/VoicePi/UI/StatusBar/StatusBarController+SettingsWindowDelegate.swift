import Foundation

@MainActor
extension StatusBarController: SettingsWindowControllerDelegate {
    func settingsWindowControllerDidRequestStartRecording(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestStartRecording(self)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSave configuration: LLMConfiguration
    ) {
        refreshLLMMenuState()
        refreshStatusSummary()
        delegate?.statusBarController(self, didSave: configuration)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateActivationShortcut shortcut: ActivationShortcut
    ) {
        shortcutMenuItem?.title = shortcutMenuTitle()
        refreshAll()
        delegate?.statusBarController(self, didUpdateActivationShortcut: shortcut)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateCancelShortcut shortcut: ActivationShortcut
    ) {
        refreshAll()
        delegate?.statusBarController(self, didUpdateCancelShortcut: shortcut)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateModeCycleShortcut shortcut: ActivationShortcut
    ) {
        refreshAll()
        delegate?.statusBarController(self, didUpdateModeCycleShortcut: shortcut)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdatePromptCycleShortcut shortcut: ActivationShortcut
    ) {
        refreshAll()
        delegate?.statusBarController(self, didUpdatePromptCycleShortcut: shortcut)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didUpdateProcessorShortcut shortcut: ActivationShortcut
    ) {
        refreshAll()
        delegate?.statusBarController(self, didUpdateProcessorShortcut: shortcut)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSaveRemoteASRConfiguration configuration: RemoteASRConfiguration
    ) {
        refreshAll()
        delegate?.statusBarController(self, didSaveRemoteASRConfiguration: configuration)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSelectASRBackend backend: ASRBackend
    ) {
        refreshAll()
        delegate?.statusBarController(self, didSelectASRBackend: backend)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didSelect language: SupportedLanguage
    ) {
        refreshAll()
        delegate?.statusBarController(self, didSelect: language)
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestTest configuration: LLMConfiguration
    ) async -> Result<String, Error> {
        await delegate?.statusBarController(self, didRequestTest: configuration)
            ?? .failure(NSError(
                domain: "VoicePi.StatusBarController",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No test handler is available."]
            ))
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didRequestRemoteASRTest configuration: RemoteASRConfiguration
    ) async -> Result<String, Error> {
        await delegate?.statusBarController(self, didRequestRemoteASRTest: configuration)
            ?? .failure(NSError(
                domain: "VoicePi.StatusBarController",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No remote ASR test handler is available."]
            ))
    }

    func settingsWindowControllerDidRequestOpenMicrophoneSettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenMicrophoneSettings(self)
    }

    func settingsWindowControllerDidRequestOpenSpeechSettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenSpeechSettings(self)
    }

    func settingsWindowControllerDidRequestOpenAccessibilitySettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenAccessibilitySettings(self)
    }

    func settingsWindowControllerDidRequestOpenInputMonitoringSettings(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestOpenInputMonitoringSettings(self)
    }

    func settingsWindowControllerDidRequestPromptAccessibilityPermission(_ controller: SettingsWindowController) {
        delegate?.statusBarControllerDidRequestPromptAccessibilityPermission(self)
    }

    func settingsWindowControllerDidRequestRefreshPermissions(_ controller: SettingsWindowController) async {
        await delegate?.statusBarControllerDidRequestRefreshPermissions(self)
        refreshAll()
    }

    func settingsWindowControllerDidRequestCheckForUpdates(_ controller: SettingsWindowController) async -> String {
        await delegate?.statusBarControllerDidRequestCheckForUpdates(self)
            ?? "No update handler is available."
    }
}
