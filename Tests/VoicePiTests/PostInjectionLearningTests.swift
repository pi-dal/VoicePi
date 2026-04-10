import Foundation
import Testing
@testable import VoicePi

struct PostInjectionLearningTests {
    @Test
    func startsTrackingOnlyAfterExplicitSessionStart() {
        let coordinator = PostInjectionLearningCoordinator()
        let baseTime = Date(timeIntervalSince1970: 1_700_003_000)

        let beforeStart = coordinator.processSnapshot(
            snapshot(target: "target-1", text: "Use PostgreSQL"),
            now: baseTime
        )
        #expect(beforeStart == nil)

        coordinator.startTracking(
            .init(
                insertedText: "Use postgre",
                targetIdentifier: "target-1",
                sourceApplication: "com.example.editor",
                startedAt: baseTime
            )
        )

        #expect(coordinator.isTracking)
    }

    @Test
    func ignoresEditsAfterWatchWindowExpires() {
        let coordinator = PostInjectionLearningCoordinator(
            configuration: .init(watchWindow: 15, stabilizationInterval: 1.2)
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_003_010)

        coordinator.startTracking(
            .init(
                insertedText: "Use postgre",
                targetIdentifier: "target-2",
                sourceApplication: "com.example.editor",
                startedAt: baseTime
            )
        )

        let suggestion = coordinator.processSnapshot(
            snapshot(target: "target-2", text: "Use PostgreSQL"),
            now: baseTime.addingTimeInterval(15.5)
        )

        #expect(suggestion == nil)
        #expect(coordinator.isTracking == false)
    }

    @Test
    func capturesMultipleStableSuggestionsWithinOneSession() throws {
        let coordinator = PostInjectionLearningCoordinator()
        let baseTime = Date(timeIntervalSince1970: 1_700_003_020)

        coordinator.startTracking(
            .init(
                insertedText: "Use postgre with cloud flare in production",
                targetIdentifier: "target-3",
                sourceApplication: "com.example.editor",
                startedAt: baseTime
            )
        )

        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-3", text: "Use PostgreSQL with cloud flare in production"),
                now: baseTime.addingTimeInterval(0.2)
            ) == nil
        )

        let firstSuggestion = try #require(
            coordinator.processSnapshot(
                snapshot(target: "target-3", text: "Use PostgreSQL with cloud flare in production"),
                now: baseTime.addingTimeInterval(1.5)
            )
        )

        #expect(firstSuggestion.proposedCanonical == "PostgreSQL")
        #expect(coordinator.isTracking == true)
        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-3", text: "Use PostgreSQL with Cloudflare in production"),
                now: baseTime.addingTimeInterval(1.8)
            ) == nil
        )

        let secondSuggestion = try #require(
            coordinator.processSnapshot(
                snapshot(target: "target-3", text: "Use PostgreSQL with Cloudflare in production"),
                now: baseTime.addingTimeInterval(3.1)
            )
        )
        #expect(secondSuggestion.proposedCanonical == "Cloudflare")
        #expect(secondSuggestion.proposedAliases == ["cloud flare"])
    }

    @Test
    func waitsForStableTextBeforeEmittingSuggestion() {
        let coordinator = PostInjectionLearningCoordinator(
            configuration: .init(watchWindow: 15, stabilizationInterval: 1.2)
        )
        let baseTime = Date(timeIntervalSince1970: 1_700_003_030)

        coordinator.startTracking(
            .init(
                insertedText: "postgre",
                targetIdentifier: "target-4",
                sourceApplication: "com.example.editor",
                startedAt: baseTime
            )
        )

        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-4", text: "PostgreSQL"),
                now: baseTime.addingTimeInterval(0.3)
            ) == nil
        )
        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-4", text: "PostgreSQL"),
                now: baseTime.addingTimeInterval(1.0)
            ) == nil
        )
        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-4", text: "PostgreSQL"),
                now: baseTime.addingTimeInterval(1.6)
            ) != nil
        )
    }

    @Test
    func ignoresTargetChangesAndUnreadableSnapshots() {
        let coordinator = PostInjectionLearningCoordinator()
        let baseTime = Date(timeIntervalSince1970: 1_700_003_040)

        coordinator.startTracking(
            .init(
                insertedText: "Use postgre",
                targetIdentifier: "target-5",
                sourceApplication: "com.example.editor",
                startedAt: baseTime
            )
        )

        #expect(
            coordinator.processSnapshot(
                snapshot(target: "target-other", text: "Use PostgreSQL"),
                now: baseTime.addingTimeInterval(0.4)
            ) == nil
        )
        #expect(
            coordinator.processSnapshot(
                .init(inspection: .editable, targetIdentifier: "target-5", textValue: nil),
                now: baseTime.addingTimeInterval(0.8)
            ) == nil
        )
        #expect(
            coordinator.processSnapshot(
                .init(inspection: .unavailable, targetIdentifier: "target-5", textValue: "Use PostgreSQL"),
                now: baseTime.addingTimeInterval(1.2)
            ) == nil
        )
    }

    private func snapshot(target: String, text: String) -> EditableTextTargetSnapshot {
        .init(
            inspection: .editable,
            targetIdentifier: target,
            textValue: text
        )
    }
}
