import Foundation

struct PostInjectionLearningConfiguration: Equatable {
    var watchWindow: TimeInterval = 15
    var stabilizationInterval: TimeInterval = 1.2
}

struct PostInjectionLearningRunRegistry: Equatable {
    private(set) var activeRunID: UUID?

    mutating func start(_ runID: UUID) {
        activeRunID = runID
    }

    mutating func clear() {
        activeRunID = nil
    }

    mutating func finish(_ runID: UUID) -> Bool {
        guard activeRunID == runID else { return false }
        activeRunID = nil
        return true
    }
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

actor PostInjectionLearningCoordinator {
    private struct SuggestionKey: Hashable {
        let originalFragment: String
        let correctedFragment: String
        let proposedCanonical: String
        let proposedAliases: [String]
        let sourceApplication: String?

        init(_ suggestion: DictionarySuggestion) {
            self.originalFragment = suggestion.originalFragment
            self.correctedFragment = suggestion.correctedFragment
            self.proposedCanonical = suggestion.proposedCanonical
            self.proposedAliases = suggestion.proposedAliases
            self.sourceApplication = suggestion.sourceApplication
        }
    }

    private struct ActiveState {
        let session: PostInjectionLearningSession
        var referenceText: String
        var observedTexts: [String]
        var pendingSuggestion: DictionarySuggestion?
        var pendingSince: Date?
        var emittedSuggestionKeys: Set<SuggestionKey>
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
            referenceText: session.insertedText,
            observedTexts: [],
            emittedSuggestionKeys: []
        )
    }

    func cancelTracking(sessionID: UUID? = nil) {
        guard let sessionID else {
            activeState = nil
            return
        }

        guard activeState?.session.id == sessionID else { return }
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

        guard let rawValue = snapshot.textValue else {
            activeState = state
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            activeState = nil
            return nil
        }

        recordObservedText(value, in: &state)

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
                state.emittedSuggestionKeys.insert(SuggestionKey(suggestion))
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

    func finishTracking(
        _ snapshot: EditableTextTargetSnapshot?,
        now: Date
    ) -> [DictionarySuggestion] {
        guard var state = activeState else { return [] }
        activeState = nil

        guard now.timeIntervalSince(state.session.startedAt) <= configuration.watchWindow else {
            return []
        }

        if let trackedTarget = state.session.targetIdentifier,
           let currentTarget = snapshot?.targetIdentifier,
           currentTarget != trackedTarget {
            return []
        }

        if let snapshot,
           snapshot.inspection == .editable,
           let finalText = snapshot.textValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !finalText.isEmpty
        {
            recordObservedText(finalText, in: &state)
        }

        var suggestions: [DictionarySuggestion] = []
        var previousText = state.session.insertedText

        for observedText in state.observedTexts {
            guard observedText != previousText else { continue }

            if let suggestion = extractor.extractSuggestion(
                injectedText: previousText,
                editedText: observedText,
                sourceApplication: state.session.sourceApplication,
                capturedAt: now
            ) {
                let key = SuggestionKey(suggestion)
                if !state.emittedSuggestionKeys.contains(key) {
                    suggestions.append(suggestion)
                    state.emittedSuggestionKeys.insert(key)
                }
            }

            previousText = observedText
        }

        return suggestions
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

    private func recordObservedText(
        _ value: String,
        in state: inout ActiveState
    ) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return }
        guard state.observedTexts.last != trimmedValue else { return }
        state.observedTexts.append(trimmedValue)
    }
}
