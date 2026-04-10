import Foundation

struct PostInjectionLearningConfiguration: Equatable {
    var watchWindow: TimeInterval = 15
    var stabilizationInterval: TimeInterval = 1.2
}

struct PostInjectionLearningSession: Equatable {
    let id: UUID
    let insertedText: String
    let targetIdentifier: String?
    let sourceApplication: String?
    let startedAt: Date

    init(
        id: UUID = UUID(),
        insertedText: String,
        targetIdentifier: String?,
        sourceApplication: String?,
        startedAt: Date
    ) {
        self.id = id
        self.insertedText = insertedText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetIdentifier = targetIdentifier
        self.sourceApplication = sourceApplication
        self.startedAt = startedAt
    }
}

final class PostInjectionLearningCoordinator {
    private struct ActiveState {
        let session: PostInjectionLearningSession
        var referenceText: String
        var pendingSuggestion: DictionarySuggestion?
        var pendingSince: Date?
    }

    private let configuration: PostInjectionLearningConfiguration
    private let extractor: DictionarySuggestionExtracting
    private var activeState: ActiveState?

    init(
        configuration: PostInjectionLearningConfiguration = .init(),
        extractor: DictionarySuggestionExtracting = DictionarySuggestionExtractor()
    ) {
        self.configuration = configuration
        self.extractor = extractor
    }

    var isTracking: Bool {
        activeState != nil
    }

    func startTracking(_ session: PostInjectionLearningSession) {
        guard !session.insertedText.isEmpty else {
            activeState = nil
            return
        }

        activeState = ActiveState(
            session: session,
            referenceText: session.insertedText
        )
    }

    func cancelTracking() {
        activeState = nil
    }

    func processSnapshot(
        _ snapshot: EditableTextTargetSnapshot?,
        now: Date
    ) -> DictionarySuggestion? {
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
            activeState = state
            return nil
        }

        if let trackedTarget = state.session.targetIdentifier {
            guard let currentTarget = snapshot.targetIdentifier, currentTarget == trackedTarget else {
                activeState = state
                return nil
            }
        }

        guard let value = snapshot.textValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            activeState = state
            return nil
        }

        guard let suggestion = extractor.extractSuggestion(
            injectedText: state.referenceText,
            editedText: value,
            sourceApplication: state.session.sourceApplication,
            capturedAt: now
        ) else {
            state.pendingSuggestion = nil
            state.pendingSince = nil
            activeState = state
            return nil
        }

        if let pending = state.pendingSuggestion,
           Self.isEquivalentSuggestion(pending, suggestion),
           let pendingSince = state.pendingSince
        {
            if now.timeIntervalSince(pendingSince) >= configuration.stabilizationInterval {
                state.referenceText = value
                state.pendingSuggestion = nil
                state.pendingSince = nil
                activeState = state
                return suggestion
            }

            activeState = state
            return nil
        }

        state.pendingSuggestion = suggestion
        state.pendingSince = now
        activeState = state
        return nil
    }

    private static func isEquivalentSuggestion(
        _ lhs: DictionarySuggestion,
        _ rhs: DictionarySuggestion
    ) -> Bool {
        lhs.originalFragment == rhs.originalFragment &&
        lhs.correctedFragment == rhs.correctedFragment &&
        lhs.proposedCanonical == rhs.proposedCanonical &&
        lhs.proposedAliases == rhs.proposedAliases &&
        lhs.sourceApplication == rhs.sourceApplication
    }
}
