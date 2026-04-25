import AppKit

enum SettingsWindowChrome {
    static let title = "VoicePi Settings"
    static let subtitle = "Quick controls for permissions, dictation, dictionary, and processor settings."
    static let defaultSize = NSSize(width: 820, height: 600)
    static let minimumSize = NSSize(width: 720, height: 600)
}

enum SettingsWindowSurfaceStyle {
    case card
    case header
    case pill
    case row
}

enum SettingsWindowButtonRole {
    case primary
    case secondary
    case navigation
}

struct SettingsWindowThemePalette: Equatable {
    let pageBackground: NSColor
    let accent: NSColor
    let accentGlow: NSColor
    let titleText: NSColor
    let subtitleText: NSColor
}

struct SettingsWindowSurfaceChrome: Equatable {
    let background: NSColor
    let border: NSColor
    let shadowColor: NSColor
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let cornerRadius: CGFloat
}

struct SettingsWindowButtonChrome: Equatable {
    let fill: NSColor
    let border: NSColor
    let text: NSColor
    let shadowColor: NSColor
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let cornerRadius: CGFloat
}

enum SettingsWindowTheme {
    static func isDark(_ appearance: NSAppearance?) -> Bool {
        appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func palette(for appearance: NSAppearance?) -> SettingsWindowThemePalette {
        if isDark(appearance) {
            return .init(
                pageBackground: NSColor(
                    calibratedRed: 0x16 / 255.0,
                    green: 0x1A / 255.0,
                    blue: 0x1C / 255.0,
                    alpha: 1
                ),
                accent: NSColor(
                    calibratedRed: 0x76 / 255.0,
                    green: 0xE7 / 255.0,
                    blue: 0x89 / 255.0,
                    alpha: 1
                ),
                accentGlow: NSColor(
                    calibratedRed: 0x4A / 255.0,
                    green: 0xF2 / 255.0,
                    blue: 0x72 / 255.0,
                    alpha: 1
                ),
                titleText: NSColor(
                    calibratedRed: 0xEE / 255.0,
                    green: 0xF4 / 255.0,
                    blue: 0xEF / 255.0,
                    alpha: 1
                ),
                subtitleText: NSColor(
                    calibratedRed: 0xB7 / 255.0,
                    green: 0xC0 / 255.0,
                    blue: 0xB9 / 255.0,
                    alpha: 1
                )
            )
        }

        return .init(
            pageBackground: NSColor(
                calibratedRed: 0xF6 / 255.0,
                green: 0xF0 / 255.0,
                blue: 0xE8 / 255.0,
                alpha: 1
            ),
            accent: NSColor(
                calibratedRed: 0x3E / 255.0,
                green: 0x64 / 255.0,
                blue: 0x4A / 255.0,
                alpha: 1
            ),
            accentGlow: NSColor(
                calibratedRed: 0x4A / 255.0,
                green: 0xF2 / 255.0,
                blue: 0x72 / 255.0,
                alpha: 1
            ),
            titleText: NSColor(
                calibratedRed: 0x1D / 255.0,
                green: 0x2C / 255.0,
                blue: 0x24 / 255.0,
                alpha: 1
            ),
            subtitleText: NSColor(
                calibratedRed: 0x63 / 255.0,
                green: 0x68 / 255.0,
                blue: 0x60 / 255.0,
                alpha: 1
            )
        )
    }

    static func surfaceChrome(
        for appearance: NSAppearance?,
        style: SettingsWindowSurfaceStyle
    ) -> SettingsWindowSurfaceChrome {
        if isDark(appearance) {
            switch style {
            case .card:
                return .init(
                    background: NSColor(
                        calibratedRed: 0x1B / 255.0,
                        green: 0x1F / 255.0,
                        blue: 0x21 / 255.0,
                        alpha: 0.90
                    ),
                    border: NSColor(calibratedWhite: 1, alpha: 0.040),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0.05,
                    shadowRadius: 8,
                    shadowOffset: CGSize(width: 0, height: -2),
                    cornerRadius: 14
                )
            case .header:
                return .init(
                    background: NSColor(
                        calibratedRed: 0x18 / 255.0,
                        green: 0x1C / 255.0,
                        blue: 0x1E / 255.0,
                        alpha: 0.98
                    ),
                    border: NSColor(calibratedWhite: 1, alpha: 0.045),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0,
                    shadowRadius: 0,
                    shadowOffset: .zero,
                    cornerRadius: 0
                )
            case .pill:
                return .init(
                    background: NSColor(
                        calibratedRed: 0x30 / 255.0,
                        green: 0x35 / 255.0,
                        blue: 0x37 / 255.0,
                        alpha: 0.86
                    ),
                    border: NSColor(calibratedWhite: 1, alpha: 0.032),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0,
                    shadowRadius: 0,
                    shadowOffset: .zero,
                    cornerRadius: 11
                )
            case .row:
                return .init(
                    background: NSColor(
                        calibratedRed: 0x22 / 255.0,
                        green: 0x27 / 255.0,
                        blue: 0x29 / 255.0,
                        alpha: 0.86
                    ),
                    border: NSColor(calibratedWhite: 1, alpha: 0.035),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0,
                    shadowRadius: 0,
                    shadowOffset: .zero,
                    cornerRadius: 12
                )
            }
        }

        switch style {
        case .card:
            return .init(
                background: NSColor(
                    calibratedRed: 0xFC / 255.0,
                    green: 0xF8 / 255.0,
                    blue: 0xF1 / 255.0,
                    alpha: 0.94
                ),
                border: NSColor(calibratedWhite: 0, alpha: 0.035),
                shadowColor: NSColor.black,
                shadowOpacity: 0.045,
                shadowRadius: 10,
                shadowOffset: CGSize(width: 0, height: -2),
                cornerRadius: 14
            )
        case .header:
            return .init(
                background: NSColor(
                    calibratedRed: 0xF7 / 255.0,
                    green: 0xF2 / 255.0,
                    blue: 0xEA / 255.0,
                    alpha: 0.985
                ),
                border: NSColor(calibratedWhite: 0, alpha: 0.045),
                shadowColor: NSColor.black,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowOffset: .zero,
                cornerRadius: 0
            )
        case .pill:
            return .init(
                background: NSColor(
                    calibratedRed: 0xF2 / 255.0,
                    green: 0xEC / 255.0,
                    blue: 0xE4 / 255.0,
                    alpha: 0.95
                ),
                border: NSColor(calibratedWhite: 0, alpha: 0.03),
                shadowColor: NSColor.black,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowOffset: .zero,
                cornerRadius: 11
            )
        case .row:
            return .init(
                background: NSColor(
                    calibratedRed: 0xFB / 255.0,
                    green: 0xF7 / 255.0,
                    blue: 0xF0 / 255.0,
                    alpha: 0.90
                ),
                border: NSColor(calibratedWhite: 0, alpha: 0.03),
                shadowColor: NSColor.black,
                shadowOpacity: 0.015,
                shadowRadius: 3,
                shadowOffset: CGSize(width: 0, height: -1),
                cornerRadius: 12
            )
        }
    }

    static func buttonChrome(
        for appearance: NSAppearance?,
        role: SettingsWindowButtonRole,
        isSelected: Bool,
        isHovered: Bool,
        isHighlighted: Bool
    ) -> SettingsWindowButtonChrome {
        let palette = palette(for: appearance)
        let darkMode = isDark(appearance)

        switch role {
        case .primary:
            if darkMode {
                return .init(
                    fill: NSColor(
                        calibratedRed: 0x2F / 255.0,
                        green: 0x69 / 255.0,
                        blue: 0x39 / 255.0,
                        alpha: isHighlighted ? 1.0 : 0.96
                    ),
                    border: NSColor(
                        calibratedRed: 0x74 / 255.0,
                        green: 0xD7 / 255.0,
                        blue: 0x83 / 255.0,
                        alpha: 0.18
                    ),
                    text: NSColor(
                        calibratedRed: 0xF4 / 255.0,
                        green: 0xF8 / 255.0,
                        blue: 0xF4 / 255.0,
                        alpha: 1
                    ),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0.12,
                    shadowRadius: 8,
                    shadowOffset: CGSize(width: 0, height: -2),
                    cornerRadius: 12
                )
            }

            return .init(
                fill: palette.accent.withAlphaComponent(isHighlighted ? 0.94 : 0.90),
                border: palette.accent.withAlphaComponent(0.10),
                text: NSColor(
                    calibratedRed: 0xFB / 255.0,
                    green: 0xF8 / 255.0,
                    blue: 0xF1 / 255.0,
                    alpha: 1
                ),
                shadowColor: NSColor.black,
                shadowOpacity: 0.10,
                shadowRadius: 8,
                shadowOffset: CGSize(width: 0, height: -2),
                cornerRadius: 12
            )
        case .secondary:
            if darkMode {
                return .init(
                    fill: NSColor.white.withAlphaComponent(isHighlighted ? 0.070 : 0.045),
                    border: NSColor(calibratedWhite: 1, alpha: 0.055),
                    text: NSColor(
                        calibratedRed: 0xE6 / 255.0,
                        green: 0xEC / 255.0,
                        blue: 0xE7 / 255.0,
                        alpha: 1
                    ),
                    shadowColor: NSColor.black,
                    shadowOpacity: 0,
                    shadowRadius: 0,
                    shadowOffset: .zero,
                    cornerRadius: 12
                )
            }

            return .init(
                fill: NSColor.white.withAlphaComponent(isHighlighted ? 0.56 : 0.40),
                border: NSColor(calibratedWhite: 0, alpha: 0.045),
                text: NSColor(
                    calibratedRed: 0x2A / 255.0,
                    green: 0x35 / 255.0,
                    blue: 0x2E / 255.0,
                    alpha: 1
                ),
                shadowColor: NSColor.black,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowOffset: .zero,
                cornerRadius: 12
            )
        case .navigation:
            let showsHoverChrome = isHovered || isHighlighted

            if darkMode {
                return .init(
                    fill: isSelected
                        ? NSColor.white.withAlphaComponent(0.020)
                        : (showsHoverChrome
                            ? NSColor.white.withAlphaComponent(0.018)
                            : .clear),
                    border: .clear,
                    text: isSelected
                        ? palette.accent
                        : NSColor(
                            calibratedRed: 0xB7 / 255.0,
                            green: 0xC0 / 255.0,
                            blue: 0xB9 / 255.0,
                            alpha: 1
                        ),
                    shadowColor: palette.accentGlow,
                    shadowOpacity: 0,
                    shadowRadius: 0,
                    shadowOffset: .zero,
                    cornerRadius: 0
                )
            }

            return .init(
                fill: isSelected
                    ? NSColor.black.withAlphaComponent(0.015)
                    : (showsHoverChrome
                        ? NSColor.black.withAlphaComponent(0.02)
                        : .clear),
                border: .clear,
                text: isSelected
                    ? palette.accent
                    : NSColor(
                        calibratedRed: 0x62 / 255.0,
                        green: 0x66 / 255.0,
                        blue: 0x61 / 255.0,
                        alpha: 1
                    ),
                shadowColor: NSColor.black,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowOffset: .zero,
                cornerRadius: 0
            )
        }
    }

    static func homeShortcutIconColor(for appearance: NSAppearance?) -> NSColor {
        let palette = palette(for: appearance)
        return isDark(appearance) ? palette.subtitleText : palette.accent
    }

    static func homeShortcutTitleColor(for appearance: NSAppearance?) -> NSColor {
        if isDark(appearance) {
            return NSColor(
                calibratedRed: 0xF1 / 255.0,
                green: 0xF5 / 255.0,
                blue: 0xF2 / 255.0,
                alpha: 1
            )
        }

        return NSColor(
            calibratedRed: 0x25 / 255.0,
            green: 0x2D / 255.0,
            blue: 0x28 / 255.0,
            alpha: 1
        )
    }

    static func homeReadinessTitleColor(for appearance: NSAppearance?, isError: Bool) -> NSColor {
        if isError {
            return isDark(appearance)
                ? NSColor(
                    calibratedRed: 0xFF / 255.0,
                    green: 0xC4 / 255.0,
                    blue: 0x6B / 255.0,
                    alpha: 1
                )
                : NSColor(
                    calibratedRed: 0xC9 / 255.0,
                    green: 0x6A / 255.0,
                    blue: 0x10 / 255.0,
                    alpha: 1
                )
        }

        return isDark(appearance)
            ? homeShortcutTitleColor(for: appearance)
            : palette(for: appearance).titleText
    }

    static func featureEyebrowTextColor(for appearance: NSAppearance?) -> NSColor {
        let palette = palette(for: appearance)
        return isDark(appearance) ? palette.subtitleText : palette.accent
    }

    static func processorEnabledTextColor(for appearance: NSAppearance?) -> NSColor {
        let palette = palette(for: appearance)
        return isDark(appearance) ? palette.titleText : palette.accent
    }
}

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
                summaryText: "No processor selected yet.",
                detailText: "Add a processor to configure an external command and arguments."
            )
        }

        if let selectedEntry {
            return ExternalProcessorsSectionPresentation(
                summaryText: ExternalProcessorManagerPresentation.displayTitle(for: selectedEntry),
                detailText: externalProcessorCommandPreview(for: selectedEntry)
            )
        }

        return ExternalProcessorsSectionPresentation(
            summaryText: "No processor selected yet.",
            detailText: "Enable a processor to make it available for refinement."
        )
    }

    static func externalProcessorCommandPreview(for entry: ExternalProcessorEntry) -> String {
        let parts = [entry.executablePath] + entry.additionalArguments.map(\.value)
        let trimmedParts = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if trimmedParts.isEmpty {
            return "No command configured yet."
        }

        return trimmedParts.joined(separator: " ")
    }

    static func externalProcessorArgumentsPreview(for entry: ExternalProcessorEntry) -> String {
        let arguments = entry.additionalArguments
            .map(\.value)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if arguments.isEmpty {
            return "None"
        }

        return arguments.joined(separator: " ")
    }

    static let externalProcessorHelpItems: [ExternalProcessorHelpItemPresentation] = [
        ExternalProcessorHelpItemPresentation(
            title: "Reorder",
            detailText: "Arrange processors in the order you want them to appear."
        ),
        ExternalProcessorHelpItemPresentation(
            title: "Toggle",
            detailText: "Disable a processor without removing it."
        ),
        ExternalProcessorHelpItemPresentation(
            title: "Arguments",
            detailText: "Use {input} to pass the recognized text to your command."
        ),
        ExternalProcessorHelpItemPresentation(
            title: "Output",
            detailText: "The last line of command output is used as the result."
        )
    ]

    static let externalProcessorHelpExamples: [String] = [
        "/usr/local/bin/summarize {input} --short",
        "/usr/bin/python3 script.py --text \"{input}\""
    ]

    static func textPromptRulesPresentation(
        workspace: PromptWorkspaceSettings,
        selectedPreset: PromptPreset?,
        resolvedPromptBody _: String
    ) -> TextPromptRulesPresentation {
        let strictModeEnabled = workspace.strictModeEnabled
        let strictModeDetailText = strictModeEnabled
            ? "Matching app bindings override the active prompt."
            : "VoicePi always uses the active prompt."

        let bindingCoverage: TextPromptRulePresentation
        if let selectedPreset,
           let coverageSummary = bindingCoverageSummary(
               appCount: selectedPreset.appBundleIDs.count,
               siteCount: selectedPreset.websiteHosts.count
           ) {
            let detailText = strictModeEnabled
                ? "This prompt matches \(coverageSummary)."
                : "Saved coverage: \(coverageSummary). Turn on Strict Mode to apply it automatically."
            bindingCoverage = TextPromptRulePresentation(
                detailText: detailText,
                symbolName: strictModeEnabled ? "checkmark.square.fill" : "square",
                isActive: strictModeEnabled
            )
        } else if
            strictModeEnabled,
            workspace.activeSelection == .builtInDefault,
            let coverageSummary = bindingCoverageSummary(
                appCount: Set(workspace.userPresets.flatMap(\.appBundleIDs)).count,
                siteCount: Set(workspace.userPresets.flatMap(\.websiteHosts)).count
            ) {
            bindingCoverage = TextPromptRulePresentation(
                detailText: "Automatic matching can override the default for \(coverageSummary).",
                symbolName: "checkmark.square.fill",
                isActive: true
            )
        } else {
            bindingCoverage = TextPromptRulePresentation(
                detailText: selectedPreset == nil || selectedPreset == .builtInDefault
                    ? "No app or website bindings configured."
                    : "This prompt has no app or website bindings.",
                symbolName: "square",
                isActive: false
            )
        }

        return TextPromptRulesPresentation(
            strictModeDetailText: strictModeDetailText,
            bindingCoverage: bindingCoverage
        )
    }

    private static func bindingCoverageSummary(appCount: Int, siteCount: Int) -> String? {
        var parts: [String] = []

        if appCount > 0 {
            let noun = appCount == 1 ? "app" : "apps"
            parts.append("\(appCount) \(noun)")
        }

        if siteCount > 0 {
            let noun = siteCount == 1 ? "site" : "sites"
            parts.append("\(siteCount) \(noun)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}
