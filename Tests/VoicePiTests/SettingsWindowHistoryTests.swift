import AppKit
import Foundation
import Testing
@testable import VoicePi

@MainActor
struct SettingsWindowHistoryTests {
    @Test
    func settingsRoutingIncludesHistorySubview() {
        #expect(SettingsSection.allCases.contains(.history))
        #expect(SettingsSection.navigationCases.contains(.history) == false)
    }

    @Test
    func historySummaryUsesEmptyStateCopyWhenNothingIsSaved() {
        #expect(
            SettingsWindowSupport.historySummaryText(forEntryCount: 0)
                == "No history yet. Final transcript outputs will appear here after successful delivery."
        )
    }

    @Test
    func historySummaryPluralizesSavedOutputs() {
        #expect(SettingsWindowSupport.historySummaryText(forEntryCount: 1) == "Saved outputs: 1 entry")
        #expect(SettingsWindowSupport.historySummaryText(forEntryCount: 4) == "Saved outputs: 4 entries")
    }

    @Test
    func historyUsageStatsUsesEmptyStateCopyWhenNothingIsSaved() {
        #expect(
            SettingsWindowSupport.historyUsageStatsText(for: .empty)
                == "Usage stats: No sessions yet."
        )
    }

    @Test
    func historyUsageStatsFormatsCountsAndRecordingDuration() {
        let stats = HistoryUsageStats(
            sessionCount: 3,
            totalRecordingDurationMilliseconds: 125_000,
            totalCharacterCount: 120,
            totalWordCount: 45
        )

        #expect(
            SettingsWindowSupport.historyUsageStatsText(for: stats)
                == "Usage stats: 3 sessions • 120 chars • 45 words • 2m 5s recording"
        )
    }

    @Test
    func historyUsageMetricCardsExposeAllCoreStats() {
        let cards = SettingsWindowSupport.historyUsageMetricCards(for: HistoryUsageStats(
            sessionCount: 6,
            totalRecordingDurationMilliseconds: 65_000,
            totalCharacterCount: 320,
            totalWordCount: 89
        ))

        #expect(cards.count == 4)
        #expect(cards.first(where: { $0.metric == .sessions })?.valueText == "6")
        #expect(cards.first(where: { $0.metric == .characters })?.valueText == "320")
        #expect(cards.first(where: { $0.metric == .words })?.valueText == "89")
        #expect(cards.first(where: { $0.metric == .recordingDuration })?.valueText == "1m 5s")
    }

    @Test
    func historyUsageTimeRangesUseExpectedDayCounts() {
        #expect(HistoryUsageTimeRange.oneDay.trailingDays == 1)
        #expect(HistoryUsageTimeRange.oneWeek.trailingDays == 7)
        #expect(HistoryUsageTimeRange.twoWeeks.trailingDays == 14)
        #expect(HistoryUsageTimeRange.oneMonth.trailingDays == 30)
        #expect(HistoryUsageTimeRange.sixMonths.trailingDays == 182)
        #expect(HistoryUsageTimeRange.oneYear.trailingDays == 365)
        #expect(HistoryUsageTimeRange.oneDay.timelineBucketCount == 24)
        #expect(HistoryUsageTimeRange.sixMonths.timelineBucketCount == 26)
        #expect(HistoryUsageTimeRange.oneYear.timelineBucketCount == 12)
    }

    @Test
    func historyUsageVisualizationBuildsTimelineAndHeatmapByTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 15,
            hour: 10
        )))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        let oldDay = try #require(calendar.date(byAdding: .day, value: -10, to: now))

        let entryA = HistoryEntry(
            text: "A",
            createdAt: try #require(calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: now
            )),
            characterCount: 10,
            wordCount: 2
        )
        let entryB = HistoryEntry(
            text: "B",
            createdAt: try #require(calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: yesterday
            )),
            characterCount: 6,
            wordCount: 1
        )
        let entryC = HistoryEntry(
            text: "C",
            createdAt: try #require(calendar.date(
                bySettingHour: 15,
                minute: 0,
                second: 0,
                of: yesterday
            )),
            characterCount: 4,
            wordCount: 1
        )
        let entryOutOfRange = HistoryEntry(
            text: "Old",
            createdAt: try #require(calendar.date(
                bySettingHour: 22,
                minute: 0,
                second: 0,
                of: oldDay
            )),
            characterCount: 99,
            wordCount: 10
        )

        let visualization = SettingsWindowSupport.historyUsageVisualization(
            entries: [entryA, entryB, entryC, entryOutOfRange],
            metric: .characters,
            now: now,
            trailingDays: 3,
            calendar: calendar
        )

        #expect(visualization.timeline.count == 3)
        #expect(visualization.timeline.map(\.value) == [0, 10, 10])

        let weekdayRowNow = ((calendar.component(.weekday, from: now) - 1 + 6) % 7)
        let weekdayRowYesterday = ((calendar.component(.weekday, from: yesterday) - 1 + 6) % 7)
        let weekdayRowOld = ((calendar.component(.weekday, from: oldDay) - 1 + 6) % 7)

        #expect(visualization.heatmap[weekdayRowNow][9] == 10)
        #expect(visualization.heatmap[weekdayRowYesterday][9] == 6)
        #expect(visualization.heatmap[weekdayRowYesterday][15] == 4)
        #expect(visualization.heatmap[weekdayRowOld][22] == 0)
    }

    @Test
    func historyUsageVisualizationSupportsHourlyOneDayRange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 15,
            hour: 10
        )))
        let todayNine = try #require(calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: now
        ))
        let yesterdayNine = try #require(calendar.date(byAdding: .day, value: -1, to: todayNine))

        let inRange = HistoryEntry(
            text: "A",
            createdAt: todayNine,
            characterCount: 5,
            wordCount: 1
        )
        let outOfRange = HistoryEntry(
            text: "B",
            createdAt: yesterdayNine,
            characterCount: 8,
            wordCount: 2
        )

        let visualization = SettingsWindowSupport.historyUsageVisualization(
            entries: [inRange, outOfRange],
            metric: .characters,
            now: now,
            timeRange: .oneDay,
            calendar: calendar
        )

        #expect(visualization.granularity == .hour)
        #expect(visualization.timeline.count == 24)
        #expect(visualization.timeline.last?.value == 0)
        #expect(visualization.timeline[22].value == 5)
    }

    @Test
    func historyUsageVisualizationSupportsMonthlyOneYearRange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 15,
            hour: 10
        )))
        let december = try #require(calendar.date(from: DateComponents(
            year: 2025,
            month: 12,
            day: 8,
            hour: 10
        )))

        let entry = HistoryEntry(
            text: "A",
            createdAt: december,
            characterCount: 9,
            wordCount: 1
        )

        let visualization = SettingsWindowSupport.historyUsageVisualization(
            entries: [entry],
            metric: .characters,
            now: now,
            timeRange: .oneYear,
            calendar: calendar
        )

        #expect(visualization.granularity == .month)
        #expect(visualization.timeline.count == 12)
        #expect(visualization.timeline.contains(where: { $0.value == 9 }))
    }
}
