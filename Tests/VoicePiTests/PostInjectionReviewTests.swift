import Foundation
import Testing
@testable import VoicePi

struct PostInjectionReviewTests {
    @Test
    func emitsReviewTriggerAfterStableExactSelectionMatch() throws {
        let coordinator = PostInjectionReviewCoordinator(
            configuration: .init(watchWindow: 8, stabilizationInterval: 0.35)
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_104_000)
        let session = PostInjectionReviewSession(
            sourceText: "Original transcript",
            insertedText: "Hello VoicePi",
            selectedPromptPresetID: PromptPreset.builtInDefaultID,
            targetIdentifier: "target-1",
            sourceApplication: "com.example.editor",
            startedAt: baseTime
        )
        coordinator.startTracking(session)

        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-1", text: "Hello VoicePi", selectedText: "Hello VoicePi"),
                now: baseTime.addingTimeInterval(0.05)
            ) == nil
        )
        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-1", text: "Hello VoicePi", selectedText: "Hello VoicePi"),
                now: baseTime.addingTimeInterval(0.20)
            ) == nil
        )

        let triggered = try #require(
            coordinator.processSnapshot(
                snapshot(target: "target-1", text: "Hello VoicePi", selectedText: "Hello VoicePi"),
                now: baseTime.addingTimeInterval(0.50)
            )
        )
        #expect(triggered.id == session.id)
        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-1", text: "Hello VoicePi", selectedText: "Hello VoicePi"),
                now: baseTime.addingTimeInterval(0.80)
            ) == nil
        )
    }

    @Test
    func ignoresSelectionThatDoesNotExactlyMatchInsertedText() {
        let coordinator = PostInjectionReviewCoordinator(
            configuration: .init(watchWindow: 8, stabilizationInterval: 0.2)
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_104_100)
        coordinator.startTracking(
            .init(
                sourceText: "Original transcript",
                insertedText: "Hello VoicePi",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                targetIdentifier: "target-2",
                sourceApplication: "com.example.editor",
                startedAt: baseTime
            )
        )

        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-2", text: "Hello VoicePi", selectedText: "Hello"),
                now: baseTime.addingTimeInterval(0.10)
            ) == nil
        )
        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-2", text: "Hello VoicePi", selectedText: "Hello"),
                now: baseTime.addingTimeInterval(0.45)
            ) == nil
        )
    }

    @Test
    func cancelsTrackingWhenFocusedTargetChanges() {
        let coordinator = PostInjectionReviewCoordinator()
        let baseTime = Date(timeIntervalSince1970: 1_700_104_200)
        coordinator.startTracking(
            .init(
                sourceText: "Original transcript",
                insertedText: "Hello VoicePi",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                targetIdentifier: "target-3",
                sourceApplication: "com.example.editor",
                startedAt: baseTime
            )
        )

        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-other", text: "Hello VoicePi", selectedText: "Hello VoicePi"),
                now: baseTime.addingTimeInterval(0.15)
            ) == nil
        )
        #expect(coordinator.isTracking == false)
    }

    @Test
    func stopsTrackingAfterWatchWindowExpires() {
        let coordinator = PostInjectionReviewCoordinator(
            configuration: .init(watchWindow: 8, stabilizationInterval: 0.35)
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_104_300)
        coordinator.startTracking(
            .init(
                sourceText: "Original transcript",
                insertedText: "Hello VoicePi",
                selectedPromptPresetID: PromptPreset.builtInDefaultID,
                targetIdentifier: "target-4",
                sourceApplication: "com.example.editor",
                startedAt: baseTime
            )
        )

        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-4", text: "Hello VoicePi", selectedText: "Hello VoicePi"),
                now: baseTime.addingTimeInterval(8.3)
            ) == nil
        )
        #expect(coordinator.isTracking == false)
    }

    private func snapshot(
        target: String,
        text: String,
        selectedText: String?
    ) -> EditableTextTargetSnapshot {
        .init(
            inspection: .editable,
            targetIdentifier: target,
            textValue: text,
            selectedText: selectedText
        )
    }
}
