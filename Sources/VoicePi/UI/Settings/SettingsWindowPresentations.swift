import AppKit
import Foundation

struct ExternalProcessorsSectionPresentation: Equatable {
    let summaryText: String
    let detailText: String
}

struct ExternalProcessorHelpItemPresentation: Equatable {
    let title: String
    let detailText: String
}

struct TextPromptRulePresentation: Equatable {
    let detailText: String
    let symbolName: String
    let isActive: Bool
}

struct TextPromptRulesPresentation: Equatable {
    let strictModeDetailText: String
    let bindingCoverage: TextPromptRulePresentation
}

enum HistoryUsageMetric: Int, CaseIterable, Equatable {
    case sessions
    case characters
    case words
    case recordingDuration

    var title: String {
        switch self {
        case .sessions:
            return "Sessions"
        case .characters:
            return "Chars"
        case .words:
            return "Words"
        case .recordingDuration:
            return "Duration"
        }
    }

    var lineChartUnit: String {
        switch self {
        case .sessions:
            return "sessions/day"
        case .characters:
            return "chars/day"
        case .words:
            return "words/day"
        case .recordingDuration:
            return "sec/day"
        }
    }

    var subtitle: String {
        switch self {
        case .sessions:
            return "Sessions"
        case .characters:
            return "Characters"
        case .words:
            return "Words"
        case .recordingDuration:
            return "Recording time"
        }
    }

    var symbolName: String {
        switch self {
        case .sessions:
            return "waveform"
        case .characters:
            return "character.textbox"
        case .words:
            return "text.alignleft"
        case .recordingDuration:
            return "clock"
        }
    }

    func cardValueText(stats: HistoryUsageStats) -> String {
        switch self {
        case .sessions:
            return "\(stats.sessionCount)"
        case .characters:
            return "\(stats.totalCharacterCount)"
        case .words:
            return "\(stats.totalWordCount)"
        case .recordingDuration:
            return SettingsWindowSupport.historyRecordingDurationText(
                milliseconds: stats.totalRecordingDurationMilliseconds
            )
        }
    }

    func timelineValue(for entry: HistoryEntry) -> Double {
        switch self {
        case .sessions:
            return 1
        case .characters:
            return Double(entry.characterCount)
        case .words:
            return Double(entry.wordCount)
        case .recordingDuration:
            return Double(entry.recordingDurationMilliseconds) / 1_000
        }
    }
}

struct HistoryUsageMetricCardPresentation: Equatable {
    let metric: HistoryUsageMetric
    let title: String
    let valueText: String
    let subtitleText: String
}

enum HistoryUsageTimeRange: Int, CaseIterable, Equatable {
    case oneDay
    case oneWeek
    case twoWeeks
    case oneMonth
    case sixMonths
    case oneYear

    var title: String {
        switch self {
        case .oneDay:
            return "1 Day"
        case .oneWeek:
            return "1 Week"
        case .twoWeeks:
            return "2 Weeks"
        case .oneMonth:
            return "1 Month"
        case .sixMonths:
            return "6 Months"
        case .oneYear:
            return "1 Year"
        }
    }

    var trailingDays: Int {
        switch self {
        case .oneDay:
            return 1
        case .oneWeek:
            return 7
        case .twoWeeks:
            return 14
        case .oneMonth:
            return 30
        case .sixMonths:
            return 182
        case .oneYear:
            return 365
        }
    }

    var timelineGranularity: HistoryUsageTimelineGranularity {
        switch self {
        case .oneDay:
            return .hour
        case .oneWeek, .twoWeeks, .oneMonth:
            return .day
        case .sixMonths:
            return .week
        case .oneYear:
            return .month
        }
    }

    var timelineBucketCount: Int {
        switch self {
        case .oneDay:
            return 24
        case .oneWeek:
            return 7
        case .twoWeeks:
            return 14
        case .oneMonth:
            return 30
        case .sixMonths:
            return 26
        case .oneYear:
            return 12
        }
    }
}

enum HistoryUsageTimelineGranularity: Equatable {
    case hour
    case day
    case week
    case month

    var title: String {
        switch self {
        case .hour:
            return "Hourly"
        case .day:
            return "Daily"
        case .week:
            return "Weekly"
        case .month:
            return "Monthly"
        }
    }
}

struct HistoryUsageTimelinePoint: Equatable {
    let date: Date
    let value: Double
}

struct HistoryUsageVisualization: Equatable {
    let metric: HistoryUsageMetric
    let timeline: [HistoryUsageTimelinePoint]
    let heatmap: [[Double]]
    let granularity: HistoryUsageTimelineGranularity
}

enum HistoryListDateFilter: Int, CaseIterable, Equatable {
    case allDates
    case today
    case last7Days
    case last30Days

    var title: String {
        switch self {
        case .allDates:
            return "All Dates"
        case .today:
            return "Today"
        case .last7Days:
            return "Last 7 Days"
        case .last30Days:
            return "Last 30 Days"
        }
    }

    func includes(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        switch self {
        case .allDates:
            return true
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .last7Days:
            guard let start = calendar.date(
                byAdding: .day,
                value: -6,
                to: calendar.startOfDay(for: now)
            ) else {
                return true
            }
            return date >= start && date <= now
        case .last30Days:
            guard let start = calendar.date(
                byAdding: .day,
                value: -29,
                to: calendar.startOfDay(for: now)
            ) else {
                return true
            }
            return date >= start && date <= now
        }
    }
}

enum HistoryListSortOrder: Int, CaseIterable, Equatable {
    case newestFirst
    case oldestFirst
    case longestRecording
    case mostWords

    var title: String {
        switch self {
        case .newestFirst:
            return "Newest First"
        case .oldestFirst:
            return "Oldest First"
        case .longestRecording:
            return "Longest Recording"
        case .mostWords:
            return "Most Words"
        }
    }
}

struct HistoryListRowPresentation: Equatable {
    let timestampText: String
    let titleText: String
    let excerptText: String
    let fileTypeText: String
    let durationText: String
    let charactersText: String
    let wordsText: String
}

enum DictionaryCollectionSelection: Equatable, Hashable {
    case allTerms
    case tag(String)
    case suggestions
}

struct DictionaryCollectionPresentation: Equatable {
    let title: String
    let count: Int
    let selection: DictionaryCollectionSelection
}

