import Foundation

struct FloatingPanelTranscriptPresentationState: Equatable {
    enum Phase: Equatable {
        case recording
        case refining
        case modeSwitch
    }

    struct Update: Equatable {
        let displayedText: String
        let requiresLayoutRecalculation: Bool
    }

    private(set) var phase: Phase?
    private(set) var displayedText: String = ""

    mutating func prepareUpdate(for phase: Phase, transcript: String) -> Update {
        apply(
            phase: phase,
            displayedText: Self.displayedTranscript(for: phase, transcript: transcript)
        )
    }

    mutating func prepareDisplayedText(_ displayedText: String, for phase: Phase) -> Update {
        apply(phase: phase, displayedText: displayedText)
    }

    mutating func reset() {
        phase = nil
        displayedText = ""
    }

    static func displayedTranscript(for phase: Phase, transcript: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        switch phase {
        case .recording:
            return trimmed.isEmpty ? "正在聆听…" : transcript
        case .refining:
            return trimmed.isEmpty ? "Refining..." : transcript
        case .modeSwitch:
            return transcript
        }
    }

    static func isRefiningPlaceholder(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "Refining..." || trimmed.hasPrefix("Refining with ")
    }

    private mutating func apply(phase: Phase, displayedText: String) -> Update {
        let requiresLayoutRecalculation = self.phase != phase || self.displayedText != displayedText
        self.phase = phase
        self.displayedText = displayedText
        return Update(
            displayedText: displayedText,
            requiresLayoutRecalculation: requiresLayoutRecalculation
        )
    }
}
