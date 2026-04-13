import Foundation

struct PostInjectionReviewConfiguration: Equatable {
    var watchWindow: TimeInterval = 8
    var stabilizationInterval: TimeInterval = 0.35
}

struct PostInjectionReviewSession: Equatable {
    let id: UUID
    let sourceText: String
    let insertedText: String
    let selectedPromptPresetID: String
    let targetIdentifier: String?
    let sourceApplication: String?
    let startedAt: Date

    init(
        id: UUID = UUID(),
        sourceText: String,
        insertedText: String,
        selectedPromptPresetID: String,
        targetIdentifier: String?,
        sourceApplication: String?,
        startedAt: Date
    ) {
        self.id = id
        self.sourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.insertedText = insertedText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedPromptPresetID = selectedPromptPresetID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetIdentifier = targetIdentifier
        self.sourceApplication = sourceApplication
        self.startedAt = startedAt
    }
}

final class PostInjectionReviewCoordinator {
    private struct ActiveState {
        let session: PostInjectionReviewSession
        var pendingSelection: String?
        var pendingSince: Date?
        var didTrigger: Bool = false
    }

    private let configuration: PostInjectionReviewConfiguration
    private var activeState: ActiveState?

    init(configuration: PostInjectionReviewConfiguration = .init()) {
        self.configuration = configuration
    }

    var isTracking: Bool {
        activeState != nil
    }

    func startTracking(_ session: PostInjectionReviewSession) {
        guard !session.sourceText.isEmpty, !session.insertedText.isEmpty else {
            activeState = nil
            return
        }

        activeState = ActiveState(session: session)
    }

    func cancelTracking() {
        activeState = nil
    }

    func processSnapshot(
        _ snapshot: EditableTextTargetSnapshot?,
        now: Date
    ) -> PostInjectionReviewSession? {
        guard var state = activeState else { return nil }

        if now.timeIntervalSince(state.session.startedAt) > configuration.watchWindow {
            activeState = nil
            return nil
        }

        guard let snapshot else {
            activeState = state
            return nil
        }

        guard snapshot.inspection == .editable else {
            state.pendingSelection = nil
            state.pendingSince = nil
            activeState = state
            return nil
        }

        if let trackedTarget = state.session.targetIdentifier {
            guard let currentTarget = snapshot.targetIdentifier, currentTarget == trackedTarget else {
                activeState = nil
                return nil
            }
        }

        guard !state.didTrigger else {
            activeState = state
            return nil
        }

        let normalizedInsertedText = Self.normalizeForComparison(state.session.insertedText)
        guard !normalizedInsertedText.isEmpty else {
            activeState = nil
            return nil
        }

        let normalizedSelectedText = Self.normalizeForComparison(snapshot.selectedText ?? "")
        guard !normalizedSelectedText.isEmpty else {
            state.pendingSelection = nil
            state.pendingSince = nil
            activeState = state
            return nil
        }

        guard normalizedSelectedText == normalizedInsertedText else {
            state.pendingSelection = nil
            state.pendingSince = nil
            activeState = state
            return nil
        }

        if state.pendingSelection == normalizedSelectedText,
           let pendingSince = state.pendingSince
        {
            if now.timeIntervalSince(pendingSince) >= configuration.stabilizationInterval {
                state.didTrigger = true
                state.pendingSelection = nil
                state.pendingSince = nil
                activeState = state
                return state.session
            }

            activeState = state
            return nil
        }

        state.pendingSelection = normalizedSelectedText
        state.pendingSince = now
        activeState = state
        return nil
    }

    private static func normalizeForComparison(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
