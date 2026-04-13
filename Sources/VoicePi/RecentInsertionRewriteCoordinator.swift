import Foundation

struct RecentInsertionRewriteConfiguration: Equatable {
    var watchWindow: TimeInterval = 8
    var selectionStabilizationDelay: TimeInterval = 0.35
}

struct RecentInsertionRewriteSession: Equatable {
    let id: UUID
    let rawTranscript: String
    let insertedText: String
    let appliedPromptPresetID: String
    let targetIdentifier: String?
    let sourceApplicationBundleID: String?
    let injectedAt: Date

    init(
        id: UUID = UUID(),
        rawTranscript: String,
        insertedText: String,
        appliedPromptPresetID: String?,
        targetIdentifier: String?,
        sourceApplicationBundleID: String?,
        injectedAt: Date
    ) {
        self.id = id
        self.rawTranscript = Self.normalized(rawTranscript)
        self.insertedText = Self.normalized(insertedText)
        let normalizedPromptID = appliedPromptPresetID?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.appliedPromptPresetID = normalizedPromptID.isEmpty
            ? PromptPreset.builtInDefaultID
            : normalizedPromptID
        self.targetIdentifier = targetIdentifier
        self.sourceApplicationBundleID = sourceApplicationBundleID
        self.injectedAt = injectedAt
    }

    private static func normalized(_ text: String) -> String {
        ExternalProcessorOutputSanitizer.sanitize(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class RecentInsertionRewriteCoordinator {
    private struct ActiveState {
        var session: RecentInsertionRewriteSession
        var pendingAutoOpenSince: Date?
        var didAutoOpen = false
    }

    private let configuration: RecentInsertionRewriteConfiguration
    private var activeState: ActiveState?

    init(
        configuration: RecentInsertionRewriteConfiguration = .init()
    ) {
        self.configuration = configuration
    }

    var isTracking: Bool {
        activeState != nil
    }

    func startTracking(_ session: RecentInsertionRewriteSession) {
        guard !session.rawTranscript.isEmpty, !session.insertedText.isEmpty else {
            activeState = nil
            return
        }
        guard let targetIdentifier = session.targetIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !targetIdentifier.isEmpty else {
            activeState = nil
            return
        }

        activeState = ActiveState(session: session)
    }

    func cancelTracking() {
        activeState = nil
    }

    func processSnapshotForAutoOpen(
        _ snapshot: EditableTextTargetSnapshot?,
        now: Date,
        reviewPanelVisible: Bool
    ) -> RecentInsertionRewriteSession? {
        guard var state = validatedState(snapshot: snapshot, now: now) else {
            return nil
        }

        guard matchesSelection(snapshot, insertedText: state.session.insertedText) else {
            state.pendingAutoOpenSince = nil
            activeState = state
            return nil
        }

        guard !reviewPanelVisible else {
            state.pendingAutoOpenSince = nil
            activeState = state
            return nil
        }

        guard !state.didAutoOpen else {
            state.pendingAutoOpenSince = nil
            activeState = state
            return nil
        }

        if let pendingAutoOpenSince = state.pendingAutoOpenSince {
            if now.timeIntervalSince(pendingAutoOpenSince) >= configuration.selectionStabilizationDelay {
                state.didAutoOpen = true
                state.pendingAutoOpenSince = nil
                activeState = state
                return state.session
            }
        } else {
            state.pendingAutoOpenSince = now
        }

        activeState = state
        return nil
    }

    func matchingSession(
        for snapshot: EditableTextTargetSnapshot?,
        now: Date
    ) -> RecentInsertionRewriteSession? {
        guard let state = validatedState(snapshot: snapshot, now: now) else {
            return nil
        }
        activeState = state
        guard matchesSelection(snapshot, insertedText: state.session.insertedText) else {
            return nil
        }
        return state.session
    }

    private func validatedState(
        snapshot: EditableTextTargetSnapshot?,
        now: Date
    ) -> ActiveState? {
        guard let state = activeState else {
            return nil
        }

        if now.timeIntervalSince(state.session.injectedAt) > configuration.watchWindow {
            activeState = nil
            return nil
        }

        if let trackedTargetIdentifier = state.session.targetIdentifier,
           let snapshot,
           snapshot.targetIdentifier != trackedTargetIdentifier {
            activeState = nil
            return nil
        }

        return state
    }

    private func matchesSelection(
        _ snapshot: EditableTextTargetSnapshot?,
        insertedText: String
    ) -> Bool {
        guard let snapshot, snapshot.inspection == .editable else {
            return false
        }
        guard let selectedTextRange = snapshot.selectedTextRange, selectedTextRange.length > 0 else {
            return false
        }

        let normalizedSelectedText = normalizedSnapshotSelection(snapshot.selectedText)
        guard !normalizedSelectedText.isEmpty else {
            return false
        }
        return normalizedSelectedText == normalizedSnapshotSelection(insertedText)
    }

    private func normalizedSnapshotSelection(_ text: String?) -> String {
        ExternalProcessorOutputSanitizer.sanitize(text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
