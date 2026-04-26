import AppKit
import AppUpdater
import AVFoundation
import ApplicationServices
import Combine
import Foundation
import Speech

extension AppController {
    struct HotkeyMonitorPlan: Equatable {
        let strategy: HotkeyMonitorStrategy?
        let statusMessage: String?
    }

    enum HotkeyMonitorStrategy: Equatable {
        case registeredHotkey
        case eventTap(ShortcutMonitorMode)
    }

    enum PermissionSettingsDestination {
        case accessibility
        case microphone
        case speech
        case inputMonitoring
    }

    struct PermissionSettingsPrompt: Equatable {
        let messageText: String
        let informativeText: String
        let settingsURL: String
    }

    struct MediaPermissionPrePrompt: Equatable {
        let messageText: String
        let informativeText: String
        let continueTitle: String
    }

    struct LaunchPermissionPlan: Equatable {
        let requestMediaPermissions: Bool
        let promptAccessibility: Bool
        let requestInputMonitoringPermission: Bool
        let useSystemAccessibilityPrompt: Bool
    }

    enum PermissionPromptSource {
        case accessibilityFollowUp
        case launchFollowUp
        case manualSettingsButton
    }

    enum PermissionSettingsTransitionStyle: Equatable {
        case customPrompt
        case permissionFlow
    }

    enum PermissionGuidanceFlowDestination: Equatable {
        case accessibility
        case inputMonitoring
    }

    enum MediaPermissionTransitionStyle: Equatable {
        case customPrePromptThenSystemRequest
        case customSettingsPrompt
    }

    enum PermissionRefreshStep: Equatable {
        case mediaPermissions
        case accessibility
        case inputMonitoring
    }

    enum InputMonitoringLaunchAction: Equatable {
        case none
        case requestSystemPrompt
        case openSettingsPrompt
    }

    enum PressAction: Equatable {
        case startRecording
        case startSelectionRewrite
        case stopRecording
        case cancelProcessing
        case ignore
    }

    enum ModeCycleInteractionStyle: Equatable {
        case modifierHeldSession
        case holdRepeat
    }

    enum RecordingWorkflowOverride: Equatable {
        case externalProcessorShortcut

        var postProcessingMode: PostProcessingMode {
            switch self {
            case .externalProcessorShortcut:
                return .refinement
            }
        }

        var refinementProvider: RefinementProvider {
            switch self {
            case .externalProcessorShortcut:
                return .externalProcessor
            }
        }
    }

    enum ProcessorShortcutPressAction: Equatable {
        case startProcessorCapture(RecordingWorkflowOverride)
        case stopRecording
        case cancelProcessing
        case ignore
    }

    enum EscapeCancelAction: Equatable {
        case cancelStartup
        case cancelRecording
        case cancelProcessing
        case ignore
    }

    enum RefiningPresentationMode: Equatable {
        case floatingOverlayAndStatusBar
        case statusBarOnly
    }

    enum RecentInsertionAutoReviewPresentationDecision: Equatable {
        case presentReviewPanel
        case deferToCallToAction
    }

    enum SelectionRewritePresentationDecision: Equatable {
        case presentRecentInsertionReviewPanel
        case presentFreshReviewPanel
    }

    struct ProcessingWorkflowSelection: Equatable {
        let postProcessingMode: PostProcessingMode
        let refinementProvider: RefinementProvider
    }

    enum ResultReviewSourceType: Equatable {
        case recentInsertion
        case selectedText
    }

    enum ResultReviewRegenerateOutcome: Equatable {
        case applyRegeneratedText
        case keepPreviousResult
        case failed
    }

    struct ResultReviewSelectionAnchor: Equatable {
        let targetIdentifier: String?
        let selectedText: String
        let selectedRange: NSRange
        let sourceApplicationBundleID: String?
    }

    struct RefinementReviewSession {
        let sessionID: UUID
        let sourceType: ResultReviewSourceType
        let rawTranscript: String
        let regenerateSourceText: String
        let sourceSnapshot: CapturedSourceSnapshot?
        var selectedPromptPresetID: String
        var selectedPromptTitle: String
        var pendingPromptPresetID: String?
        var pendingPromptTitle: String?
        var currentResultText: String
        let selectionAnchor: ResultReviewSelectionAnchor
        let recordingDurationMilliseconds: Int
        let workflow: ProcessingWorkflowSelection
        let workflowOverride: RecordingWorkflowOverride?
        let isAutoOpened: Bool

        init(
            sourceType: ResultReviewSourceType,
            rawTranscript: String,
            regenerateSourceText: String? = nil,
            selectedPromptPresetID: String,
            selectedPromptTitle: String,
            pendingPromptPresetID: String? = nil,
            pendingPromptTitle: String? = nil,
            currentResultText: String,
            selectionAnchor: ResultReviewSelectionAnchor,
            recordingDurationMilliseconds: Int,
            workflow: ProcessingWorkflowSelection,
            workflowOverride: RecordingWorkflowOverride?,
            isAutoOpened: Bool
        ) {
            self.sessionID = UUID()
            self.sourceType = sourceType
            self.rawTranscript = rawTranscript
            let normalizedExplicitSource = ExternalProcessorOutputSanitizer.sanitize(
                regenerateSourceText ?? ""
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedExplicitSource.isEmpty {
                self.regenerateSourceText = normalizedExplicitSource
            } else {
                let normalizedSelectedSource = ExternalProcessorOutputSanitizer.sanitize(
                    selectionAnchor.selectedText
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedRawTranscript = ExternalProcessorOutputSanitizer.sanitize(rawTranscript)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                switch sourceType {
                case .recentInsertion:
                    self.regenerateSourceText = !normalizedSelectedSource.isEmpty
                        ? normalizedSelectedSource
                        : normalizedRawTranscript
                case .selectedText:
                    self.regenerateSourceText = !normalizedRawTranscript.isEmpty
                        ? normalizedRawTranscript
                        : normalizedSelectedSource
                }
            }
            if sourceType == .selectedText,
               let normalizedSourceText = ExternalProcessorSourceSnapshotSupport.normalizedSourceText(
                selectionAnchor.selectedText
               ) {
                self.sourceSnapshot = CapturedSourceSnapshot(
                    text: normalizedSourceText,
                    previewText: ExternalProcessorSourceSnapshotSupport.previewText(
                        from: normalizedSourceText
                    ),
                    sourceApplicationBundleID: selectionAnchor.sourceApplicationBundleID,
                    targetIdentifier: selectionAnchor.targetIdentifier
                )
            } else {
                self.sourceSnapshot = nil
            }
            self.selectedPromptPresetID = selectedPromptPresetID
            self.selectedPromptTitle = selectedPromptTitle
            self.pendingPromptPresetID = pendingPromptPresetID
            self.pendingPromptTitle = pendingPromptTitle
            self.currentResultText = currentResultText
            self.selectionAnchor = selectionAnchor
            self.recordingDurationMilliseconds = recordingDurationMilliseconds
            self.workflow = workflow
            self.workflowOverride = workflowOverride
            self.isAutoOpened = isAutoOpened
        }
    }

    struct ExternalProcessorResultSession {
        var payload: ExternalProcessorResultPanelPayload
        let sourceText: String
        let workflowOverride: RecordingWorkflowOverride?
        let sourceApplicationBundleID: String?
        let recordingDurationMilliseconds: Int
    }

    struct ResultReviewPromptSelectionState: Equatable {
        let selectedPromptPresetID: String
        let selectedPromptTitle: String
        let pendingPromptPresetID: String?
        let pendingPromptTitle: String?
    }

    enum PostProcessingFailureAction: Equatable {
        case continueTranscriptDelivery
        case surfaceProcessorFailure
    }

    enum PostProcessingSuccessAction: Equatable {
        case deliverTranscriptNormally
        case presentExternalProcessorResultPanel
    }

    enum RealtimeStopResolution: Equatable {
        case realtimeFinalization
        case batchFallback
        case silentCancel
    }

    enum ReleaseAction: Equatable {
        case ignore
    }

    enum AppUpdateInstallError: LocalizedError {
        case downloadedBundleMissing

        var errorDescription: String? {
            switch self {
            case .downloadedBundleMissing:
                return "VoicePi downloaded the update, but the new app bundle was not ready to install."
            }
        }
    }

    enum ResultReviewInsertionError: LocalizedError {
        case sourceApplicationActivationFailed
        case selectionChanged

        var errorDescription: String? {
            switch self {
            case .sourceApplicationActivationFailed:
                return "VoicePi couldn't return focus to the previous app before pasting."
            case .selectionChanged:
                return "Selection changed. Re-select the text and try again."
            }
        }
    }

    struct DebugSettingsCaptureConfiguration: Equatable {
        enum ScrollPosition: Equatable {
            case top
            case bottom
        }

        let section: SettingsSection
        let interfaceTheme: InterfaceTheme?
        let scrollPosition: ScrollPosition
    }


}
