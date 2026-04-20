import AppKit

enum SettingsWindowChrome {
    static let title = "VoicePi Settings"
    static let subtitle = "Quick controls for permissions, dictation, dictionary, and processor settings."
    static let defaultSize = NSSize(width: 820, height: 600)
    static let minimumSize = NSSize(width: 720, height: 600)
}

struct ExternalProcessorsSectionPresentation: Equatable {
    let summaryText: String
    let detailText: String
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

enum SettingsWindowSupport {
    static func cancelShortcutHintText(for shortcut: ActivationShortcut) -> String {
        let format: String

        if shortcut.keyCodes == [53], shortcut.modifierFlags.isEmpty {
            format = PermissionsCopy.escapeCancelShortcutHint
        } else if shortcut.isRegisteredHotkeyCompatible {
            format = PermissionsCopy.standardCancelShortcutHint
        } else {
            format = PermissionsCopy.advancedCancelShortcutHint
        }

        return formattedShortcutHint(format: format, shortcutDisplay: shortcut.displayString)
    }

    static func dictionaryTermsRowsHeight(
        forVisibleRowCount rowCount: Int,
        rowHeight: CGFloat = 56,
        rowSpacing: CGFloat = 10,
        maxVisibleRows: Int = 4,
        minimumHeight: CGFloat = 56,
        maximumHeight: CGFloat = 260
    ) -> CGFloat {
        let visibleRows = max(1, min(maxVisibleRows, rowCount))
        let targetHeight = (CGFloat(visibleRows) * rowHeight)
            + (CGFloat(max(0, visibleRows - 1)) * rowSpacing)
        return min(maximumHeight, max(minimumHeight, targetHeight))
    }

    static func processorShortcutHintText(for shortcut: ActivationShortcut) -> String {
        if shortcut.isEmpty {
            return "Set a processor shortcut to start a dedicated processor capture."
        }

        if shortcut.isRegisteredHotkeyCompatible {
            return "Current shortcut: \(sentenceTerminatedShortcutDisplay(shortcut.displayString)) Starts a dedicated processor capture. Standard shortcuts work without Input Monitoring."
        }

        return "Current shortcut: \(sentenceTerminatedShortcutDisplay(shortcut.displayString)) Starts a dedicated processor capture. Advanced shortcuts require Input Monitoring. Accessibility lets VoicePi suppress it first."
    }

    static func promptCycleShortcutHintText(for shortcut: ActivationShortcut) -> String {
        if shortcut.isEmpty {
            return "Set a prompt-cycle shortcut to rotate the Active Prompt before recording."
        }

        if shortcut.isRegisteredHotkeyCompatible {
            return "Current shortcut: \(sentenceTerminatedShortcutDisplay(shortcut.displayString)) Cycles the Active Prompt. Standard shortcuts work without Input Monitoring."
        }

        return "Current shortcut: \(sentenceTerminatedShortcutDisplay(shortcut.displayString)) Cycles the Active Prompt. Advanced shortcuts require Input Monitoring. Accessibility lets VoicePi suppress it first."
    }

    static func formattedShortcutHint(format: String, shortcutDisplay: String) -> String {
        let hint = String(format: format, shortcutDisplay)
        let duplicatedSentenceBoundary = "\(shortcutDisplay)."

        guard shortcutDisplayHasTerminalPunctuation(shortcutDisplay),
              let duplicatedRange = hint.range(of: duplicatedSentenceBoundary) else {
            return hint
        }

        var normalizedHint = hint
        normalizedHint.replaceSubrange(duplicatedRange, with: shortcutDisplay)
        return normalizedHint
    }

    static func sentenceTerminatedShortcutDisplay(_ shortcutDisplay: String) -> String {
        guard !shortcutDisplayHasTerminalPunctuation(shortcutDisplay) else {
            return shortcutDisplay
        }

        return shortcutDisplay + "."
    }

    static func shortcutDisplayHasTerminalPunctuation(_ shortcutDisplay: String) -> Bool {
        guard let lastCharacter = shortcutDisplay.last else {
            return false
        }

        return ".!?".contains(lastCharacter)
    }

    static func historySummaryText(forEntryCount count: Int) -> String {
        guard count > 0 else {
            return "No history yet. Final transcript outputs will appear here after successful delivery."
        }

        let noun = count == 1 ? "entry" : "entries"
        return "Saved outputs: \(count) \(noun)"
    }

    static func historyUsageStatsText(for stats: HistoryUsageStats) -> String {
        guard stats.sessionCount > 0 else {
            return "Usage stats: No sessions yet."
        }

        let noun = stats.sessionCount == 1 ? "session" : "sessions"
        let recordingDurationText = historyRecordingDurationText(
            milliseconds: stats.totalRecordingDurationMilliseconds
        )
        return "Usage stats: \(stats.sessionCount) \(noun) • \(stats.totalCharacterCount) chars • \(stats.totalWordCount) words • \(recordingDurationText) recording"
    }

    static func historyRecordingDurationText(milliseconds: Int) -> String {
        let totalSeconds = max(0, milliseconds / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }

    static func historyUsageMetricCards(for stats: HistoryUsageStats) -> [HistoryUsageMetricCardPresentation] {
        HistoryUsageMetric.allCases.map { metric in
            HistoryUsageMetricCardPresentation(
                metric: metric,
                title: metric.title,
                valueText: metric.cardValueText(stats: stats)
            )
        }
    }

    static func historyUsageVisualization(
        entries: [HistoryEntry],
        metric: HistoryUsageMetric,
        now: Date = Date(),
        timeRange: HistoryUsageTimeRange,
        calendar: Calendar = .current
    ) -> HistoryUsageVisualization {
        historyUsageVisualization(
            entries: entries,
            metric: metric,
            now: now,
            granularity: timeRange.timelineGranularity,
            bucketCount: timeRange.timelineBucketCount,
            calendar: calendar
        )
    }

    static func historyUsageVisualization(
        entries: [HistoryEntry],
        metric: HistoryUsageMetric,
        now: Date = Date(),
        trailingDays: Int = 7,
        calendar: Calendar = .current
    ) -> HistoryUsageVisualization {
        let granularity = automaticHistoryTimelineGranularity(forTrailingDays: trailingDays)
        let bucketCount = automaticHistoryBucketCount(
            granularity: granularity,
            trailingDays: trailingDays
        )
        return historyUsageVisualization(
            entries: entries,
            metric: metric,
            now: now,
            granularity: granularity,
            bucketCount: bucketCount,
            calendar: calendar
        )
    }

    private static func historyUsageVisualization(
        entries: [HistoryEntry],
        metric: HistoryUsageMetric,
        now: Date,
        granularity: HistoryUsageTimelineGranularity,
        bucketCount: Int,
        calendar: Calendar
    ) -> HistoryUsageVisualization {
        let normalizedBucketCount = max(2, bucketCount)
        let latestBucket = historyTimelineBucketStart(
            for: now,
            granularity: granularity,
            calendar: calendar
        )
        let oldestBucket = historyAddingTimelineBuckets(
            from: latestBucket,
            granularity: granularity,
            offset: -(normalizedBucketCount - 1),
            calendar: calendar
        )

        var timelineValues: [Date: Double] = [:]
        var heatmap = Array(
            repeating: Array(repeating: 0.0, count: 24),
            count: 7
        )

        for entry in entries {
            let bucket = historyTimelineBucketStart(
                for: entry.createdAt,
                granularity: granularity,
                calendar: calendar
            )
            guard bucket >= oldestBucket, bucket <= latestBucket else { continue }
            timelineValues[bucket, default: 0] += metric.timelineValue(for: entry)

            let weekday = calendar.component(.weekday, from: entry.createdAt)
            let hour = calendar.component(.hour, from: entry.createdAt)
            guard (0..<24).contains(hour) else { continue }
            let row = historyHeatmapWeekdayRow(for: weekday)
            heatmap[row][hour] += metric.timelineValue(for: entry)
        }

        var timeline: [HistoryUsageTimelinePoint] = []
        timeline.reserveCapacity(normalizedBucketCount)
        for index in 0..<normalizedBucketCount {
            let bucket = historyAddingTimelineBuckets(
                from: oldestBucket,
                granularity: granularity,
                offset: index,
                calendar: calendar
            )
            timeline.append(
                HistoryUsageTimelinePoint(
                    date: bucket,
                    value: timelineValues[bucket, default: 0]
                )
            )
        }

        return HistoryUsageVisualization(
            metric: metric,
            timeline: timeline,
            heatmap: heatmap,
            granularity: granularity
        )
    }

    private static func historyHeatmapWeekdayRow(for weekday: Int) -> Int {
        let sundayBased = weekday - 1
        let mondayBased = (sundayBased + 6) % 7
        return max(0, min(6, mondayBased))
    }

    private static func automaticHistoryTimelineGranularity(
        forTrailingDays trailingDays: Int
    ) -> HistoryUsageTimelineGranularity {
        if trailingDays <= 1 {
            return .hour
        }
        if trailingDays <= 45 {
            return .day
        }
        if trailingDays <= 220 {
            return .week
        }
        return .month
    }

    private static func automaticHistoryBucketCount(
        granularity: HistoryUsageTimelineGranularity,
        trailingDays: Int
    ) -> Int {
        switch granularity {
        case .hour:
            return max(24, trailingDays * 24)
        case .day:
            return max(2, trailingDays)
        case .week:
            return max(2, Int(ceil(Double(trailingDays) / 7.0)))
        case .month:
            return max(2, Int(ceil(Double(trailingDays) / 30.0)))
        }
    }

    private static func historyTimelineBucketStart(
        for date: Date,
        granularity: HistoryUsageTimelineGranularity,
        calendar: Calendar
    ) -> Date {
        switch granularity {
        case .hour:
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            return calendar.date(from: components) ?? date
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }
    }

    private static func historyAddingTimelineBuckets(
        from date: Date,
        granularity: HistoryUsageTimelineGranularity,
        offset: Int,
        calendar: Calendar
    ) -> Date {
        switch granularity {
        case .hour:
            return calendar.date(byAdding: .hour, value: offset, to: date) ?? date
        case .day:
            return calendar.date(byAdding: .day, value: offset, to: date) ?? date
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: offset, to: date) ?? date
        case .month:
            return calendar.date(byAdding: .month, value: offset, to: date) ?? date
        }
    }

    static func externalProcessorsSectionPresentation(
        entries: [ExternalProcessorEntry],
        selectedEntry: ExternalProcessorEntry?
    ) -> ExternalProcessorsSectionPresentation {
        if entries.isEmpty {
            return ExternalProcessorsSectionPresentation(
                summaryText: "No processors configured yet.",
                detailText: "Open the Processors tab to add your first backend, set its executable, and add any command-line arguments."
            )
        }

        if let selectedEntry {
            let stateText = selectedEntry.isEnabled ? "Enabled" : "Disabled"
            return ExternalProcessorsSectionPresentation(
                summaryText: "Active processor: \(selectedEntry.name) • \(selectedEntry.kind.title) • \(stateText)",
                detailText: "Manage the processors used by refinement. Each entry can be tested before VoicePi uses it."
            )
        }

        return ExternalProcessorsSectionPresentation(
            summaryText: "Choose a processor to make it active.",
            detailText: "Manage the processors used by refinement. Each entry can be tested before VoicePi uses it."
        )
    }
}
