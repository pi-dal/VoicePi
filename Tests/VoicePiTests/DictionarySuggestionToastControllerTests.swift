import AppKit
import Foundation
import Testing
@testable import VoicePi

@MainActor
struct DictionarySuggestionToastControllerTests {
    @Test
    func toastLoadsSummaryAndThreeActions() {
        let controller = DictionarySuggestionToastController()
        let payload = makePayload(sessionID: UUID(), summary: "Saved to suggestions.")

        controller.show(payload: payload)

        #expect(controller.summaryText == "Saved to suggestions.")
        #expect(
            controller.actionTitles == [
                DictionarySuggestionToastController.approveTitle,
                DictionarySuggestionToastController.reviewTitle,
                DictionarySuggestionToastController.dismissTitle
            ]
        )

        controller.hide()
    }

    @Test
    func toastShowsOnlyOneSuggestionPerSession() {
        let controller = DictionarySuggestionToastController()
        let sessionID = UUID()
        let first = makePayload(sessionID: sessionID, summary: "First summary")
        let second = makePayload(sessionID: sessionID, summary: "Second summary")

        controller.show(payload: first)
        controller.show(payload: second)

        #expect(controller.summaryText == "First summary")
        #expect(controller.lastPresentedSessionID == sessionID)

        controller.hide()
    }

    @Test
    func dismissClosesToastWithoutTriggeringApproveOrReview() {
        let controller = DictionarySuggestionToastController()
        var approveCalls = 0
        var reviewCalls = 0
        var dismissCalls = 0
        controller.onApprove = { _ in approveCalls += 1 }
        controller.onReview = { _ in reviewCalls += 1 }
        controller.onDismiss = { _ in dismissCalls += 1 }

        controller.show(payload: makePayload(sessionID: UUID()))
        controller.performDismiss()

        #expect(controller.isToastVisible == false)
        #expect(approveCalls == 0)
        #expect(reviewCalls == 0)
        #expect(dismissCalls == 1)
    }

    @Test
    func approveInvokesApproveHandler() {
        let controller = DictionarySuggestionToastController()
        var approvedSuggestionID: UUID?
        let payload = makePayload(sessionID: UUID())
        controller.onApprove = { suggestion in
            approvedSuggestionID = suggestion.id
        }

        controller.show(payload: payload)
        controller.performApprove()

        #expect(approvedSuggestionID == payload.suggestion.id)
        #expect(controller.isToastVisible == false)
    }

    @Test
    func reviewInvokesReviewHandler() {
        let controller = DictionarySuggestionToastController()
        var reviewedSuggestionID: UUID?
        let payload = makePayload(sessionID: UUID())
        controller.onReview = { suggestion in
            reviewedSuggestionID = suggestion.id
        }

        controller.show(payload: payload)
        controller.performReview()

        #expect(reviewedSuggestionID == payload.suggestion.id)
        #expect(controller.isToastVisible == false)
    }

    private func makePayload(sessionID: UUID, summary: String? = nil) -> DictionarySuggestionToastPayload {
        DictionarySuggestionToastPayload(
            sessionID: sessionID,
            suggestion: DictionarySuggestion(
                id: UUID(),
                originalFragment: "postgre",
                correctedFragment: "PostgreSQL",
                proposedCanonical: "PostgreSQL",
                proposedAliases: ["postgre"],
                sourceApplication: "com.example.editor",
                capturedAt: Date(timeIntervalSince1970: 1_700_004_000)
            ),
            summaryText: summary
        )
    }
}
