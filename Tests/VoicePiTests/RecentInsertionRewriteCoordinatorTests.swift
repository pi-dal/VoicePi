import Foundation
import Testing
@testable import VoicePi

struct RecentInsertionRewriteCoordinatorTests {
    @Test
    func autoOpenRequiresStableExactSelectionMatch() {
        let coordinator = RecentInsertionRewriteCoordinator(
            configuration: .init(
                watchWindow: 8,
                selectionStabilizationDelay: 0.35
            )
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_200_000)
        let session = RecentInsertionRewriteSession(
            rawTranscript: "Original transcript",
            insertedText: "Refined output",
            appliedPromptPresetID: PromptPreset.builtInDefaultID,
            targetIdentifier: "target-1",
            sourceApplicationBundleID: "com.apple.TextEdit",
            injectedAt: baseTime
        )
        coordinator.startTracking(session)

        let snapshot = matchingSelectionSnapshot(target: "target-1", selectedText: "Refined output")
        #expect(
            coordinator.processSnapshotForAutoOpen(
                snapshot,
                now: baseTime.addingTimeInterval(0.1),
                reviewPanelVisible: false
            ) == nil
        )
        #expect(
            coordinator.processSnapshotForAutoOpen(
                snapshot,
                now: baseTime.addingTimeInterval(0.6),
                reviewPanelVisible: false
            ) == session
        )
    }

    @Test
    func autoOpenIsOneShotButManualMatchingStillWorks() throws {
        let coordinator = RecentInsertionRewriteCoordinator(
            configuration: .init(
                watchWindow: 8,
                selectionStabilizationDelay: 0.35
            )
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_200_010)
        let session = RecentInsertionRewriteSession(
            rawTranscript: "Original transcript",
            insertedText: "Refined output",
            appliedPromptPresetID: PromptPreset.builtInDefaultID,
            targetIdentifier: "target-2",
            sourceApplicationBundleID: "com.apple.TextEdit",
            injectedAt: baseTime
        )
        coordinator.startTracking(session)
        let snapshot = matchingSelectionSnapshot(target: "target-2", selectedText: "Refined output")

        _ = coordinator.processSnapshotForAutoOpen(
            snapshot,
            now: baseTime.addingTimeInterval(0.1),
            reviewPanelVisible: false
        )
        let autoOpened = try #require(
            coordinator.processSnapshotForAutoOpen(
                snapshot,
                now: baseTime.addingTimeInterval(0.6),
                reviewPanelVisible: false
            )
        )
        #expect(autoOpened == session)
        #expect(
            coordinator.processSnapshotForAutoOpen(
                snapshot,
                now: baseTime.addingTimeInterval(0.9),
                reviewPanelVisible: false
            ) == nil
        )
        #expect(coordinator.matchingSession(for: snapshot, now: baseTime.addingTimeInterval(1.0)) == session)
    }

    @Test
    func autoOpenMatchesSelectionTextWhenSelectedRangeIsUnavailable() {
        let coordinator = RecentInsertionRewriteCoordinator(
            configuration: .init(
                watchWindow: 8,
                selectionStabilizationDelay: 0.35
            )
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_200_015)
        let session = RecentInsertionRewriteSession(
            rawTranscript: "Original transcript",
            insertedText: "Refined output",
            appliedPromptPresetID: PromptPreset.builtInDefaultID,
            targetIdentifier: "target-2b",
            sourceApplicationBundleID: "com.apple.TextEdit",
            injectedAt: baseTime
        )
        coordinator.startTracking(session)
        let snapshot = EditableTextTargetSnapshot(
            inspection: .editable,
            targetIdentifier: "target-2b",
            textValue: "Refined output",
            selectedText: "Refined output",
            selectedTextRange: nil,
            canSetSelectedTextRange: true
        )

        #expect(
            coordinator.processSnapshotForAutoOpen(
                snapshot,
                now: baseTime.addingTimeInterval(0.1),
                reviewPanelVisible: false
            ) == nil
        )
        #expect(
            coordinator.processSnapshotForAutoOpen(
                snapshot,
                now: baseTime.addingTimeInterval(0.6),
                reviewPanelVisible: false
            ) == session
        )
        #expect(
            coordinator.matchingSession(
                for: snapshot,
                now: baseTime.addingTimeInterval(1.0)
            ) == session
        )
    }

    @Test
    func trackingExpiresAfterWatchWindow() {
        let coordinator = RecentInsertionRewriteCoordinator(
            configuration: .init(
                watchWindow: 8,
                selectionStabilizationDelay: 0.35
            )
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_200_020)
        let session = RecentInsertionRewriteSession(
            rawTranscript: "Original transcript",
            insertedText: "Refined output",
            appliedPromptPresetID: PromptPreset.builtInDefaultID,
            targetIdentifier: "target-3",
            sourceApplicationBundleID: "com.apple.TextEdit",
            injectedAt: baseTime
        )
        coordinator.startTracking(session)
        let snapshot = matchingSelectionSnapshot(target: "target-3", selectedText: "Refined output")

        #expect(
            coordinator.processSnapshotForAutoOpen(
                snapshot,
                now: baseTime.addingTimeInterval(8.2),
                reviewPanelVisible: false
            ) == nil
        )
        #expect(coordinator.isTracking == false)
        #expect(coordinator.matchingSession(for: snapshot, now: baseTime.addingTimeInterval(8.3)) == nil)
    }

    @Test
    func trackingSurvivesTemporaryFocusedTargetChanges() {
        let coordinator = RecentInsertionRewriteCoordinator(
            configuration: .init(
                watchWindow: 8,
                selectionStabilizationDelay: 0.35
            )
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_200_030)
        let session = RecentInsertionRewriteSession(
            rawTranscript: "Original transcript",
            insertedText: "Refined output",
            appliedPromptPresetID: PromptPreset.builtInDefaultID,
            targetIdentifier: "target-4",
            sourceApplicationBundleID: "com.apple.TextEdit",
            injectedAt: baseTime
        )
        coordinator.startTracking(session)

        #expect(
            coordinator.processSnapshotForAutoOpen(
                matchingSelectionSnapshot(target: "other-target", selectedText: "Refined output"),
                now: baseTime.addingTimeInterval(0.2),
                reviewPanelVisible: false
            ) == nil
        )
        #expect(coordinator.isTracking)
        #expect(
            coordinator.processSnapshotForAutoOpen(
                matchingSelectionSnapshot(target: "target-4", selectedText: "Refined output"),
                now: baseTime.addingTimeInterval(0.3),
                reviewPanelVisible: false
            ) == nil
        )
        #expect(
            coordinator.processSnapshotForAutoOpen(
                matchingSelectionSnapshot(target: "target-4", selectedText: "Refined output"),
                now: baseTime.addingTimeInterval(0.8),
                reviewPanelVisible: false
            ) == session
        )
    }

    @Test
    func trackingRequiresTargetIdentifier() {
        let coordinator = RecentInsertionRewriteCoordinator(
            configuration: .init(
                watchWindow: 8,
                selectionStabilizationDelay: 0.35
            )
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_200_040)
        let session = RecentInsertionRewriteSession(
            rawTranscript: "Original transcript",
            insertedText: "Refined output",
            appliedPromptPresetID: PromptPreset.builtInDefaultID,
            targetIdentifier: nil,
            sourceApplicationBundleID: "com.apple.TextEdit",
            injectedAt: baseTime
        )
        coordinator.startTracking(session)

        #expect(coordinator.isTracking == false)
        #expect(
            coordinator.matchingSession(
                for: matchingSelectionSnapshot(target: "target-5", selectedText: "Refined output"),
                now: baseTime.addingTimeInterval(0.2)
            ) == nil
        )
    }

    private func matchingSelectionSnapshot(
        target: String,
        selectedText: String
    ) -> EditableTextTargetSnapshot {
        .init(
            inspection: .editable,
            targetIdentifier: target,
            textValue: selectedText,
            selectedText: selectedText,
            selectedTextRange: NSRange(location: 0, length: selectedText.utf16.count),
            canSetSelectedTextRange: true
        )
    }
}
