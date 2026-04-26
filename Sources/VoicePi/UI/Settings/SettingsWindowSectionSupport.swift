import AppKit
import Foundation

enum SettingsWindowSupport {
    static let historySearchPlaceholderText = "Search history..."

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

    static func dictionaryCollections(
        entries: [DictionaryEntry],
        suggestions: [DictionarySuggestion]
    ) -> [DictionaryCollectionPresentation] {
        var collections: [DictionaryCollectionPresentation] = [
            .init(
                title: "All Terms",
                count: entries.count,
                selection: .allTerms
            )
        ]

        let groupedTags = Dictionary(grouping: entries) { entry in
            DictionaryNormalization.optionalTrimmed(entry.tag)
        }

        let tagCollections = groupedTags
            .compactMap { tag, taggedEntries -> DictionaryCollectionPresentation? in
                guard let tag else { return nil }
                return .init(
                    title: tag,
                    count: taggedEntries.count,
                    selection: .tag(tag)
                )
            }
            .sorted { lhs, rhs in
                if lhs.title != rhs.title {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.count > rhs.count
            }

        collections.append(contentsOf: tagCollections)
        collections.append(
            .init(
                title: "Suggestions",
                count: suggestions.count,
                selection: .suggestions
            )
        )
        return collections
    }

    static func filteredDictionaryEntries(
        _ entries: [DictionaryEntry],
        query: String,
        selection: DictionaryCollectionSelection
    ) -> [DictionaryEntry] {
        let normalizedQuery = DictionaryNormalization.normalized(query)
        let trimmedSelectionTag: String? = {
            if case let .tag(tag) = selection {
                return DictionaryNormalization.optionalTrimmed(tag)
            }
            return nil
        }()

        return entries.filter { entry in
            switch selection {
            case .allTerms:
                break
            case .tag:
                guard DictionaryNormalization.optionalTrimmed(entry.tag) == trimmedSelectionTag else {
                    return false
                }
            case .suggestions:
                return false
            }

            guard !normalizedQuery.isEmpty else {
                return true
            }

            if DictionaryNormalization.normalized(entry.canonical).contains(normalizedQuery) {
                return true
            }

            if let tag = entry.tag,
               DictionaryNormalization.normalized(tag).contains(normalizedQuery) {
                return true
            }

            return entry.aliases.contains { alias in
                DictionaryNormalization.normalized(alias).contains(normalizedQuery)
            }
        }
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

    static func historySessionCountText(filteredCount: Int, totalCount: Int) -> String {
        let total = max(0, totalCount)
        let filtered = max(0, min(filteredCount, total))

        if filtered == total {
            let noun = total == 1 ? "session" : "sessions"
            return "\(total) \(noun)"
        }

        return "\(filtered) of \(total) sessions"
    }

    static func historyEmptyStateText(
        totalEntryCount: Int,
        filteredEntryCount: Int,
        query: String
    ) -> String {
        if totalEntryCount == 0 {
            return historySummaryText(forEntryCount: 0)
        }

        if filteredEntryCount > 0 {
            return ""
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            return "No history matches \"\(trimmedQuery)\"."
        }

        return "No history matches the current filters."
    }

    static func historyListRowPresentation(for entry: HistoryEntry) -> HistoryListRowPresentation {
        let summary = historyListHeadlineAndExcerpt(for: entry.text)
        return HistoryListRowPresentation(
            timestampText: DateFormatter.localizedString(
                from: entry.createdAt,
                dateStyle: .short,
                timeStyle: .short
            ),
            titleText: summary.title,
            excerptText: summary.excerpt,
            fileTypeText: "txt",
            durationText: historyRecordingDurationText(
                milliseconds: entry.recordingDurationMilliseconds
            ),
            charactersText: "\(entry.characterCount) chars",
            wordsText: "\(entry.wordCount) words"
        )
    }

    static func filteredHistoryEntries(
        _ entries: [HistoryEntry],
        query: String,
        dateFilter: HistoryListDateFilter,
        sortOrder: HistoryListSortOrder,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [HistoryEntry] {
        let normalizedQuery = DictionaryNormalization.normalized(query)

        let filtered = entries.filter { entry in
            guard dateFilter.includes(entry.createdAt, now: now, calendar: calendar) else {
                return false
            }

            guard !normalizedQuery.isEmpty else {
                return true
            }

            return DictionaryNormalization.normalized(entry.text).contains(normalizedQuery)
        }

        switch sortOrder {
        case .newestFirst:
            return filtered.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        case .oldestFirst:
            return filtered.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        case .longestRecording:
            return filtered.sorted { lhs, rhs in
                if lhs.recordingDurationMilliseconds != rhs.recordingDurationMilliseconds {
                    return lhs.recordingDurationMilliseconds > rhs.recordingDurationMilliseconds
                }
                return lhs.createdAt > rhs.createdAt
            }
        case .mostWords:
            return filtered.sorted { lhs, rhs in
                if lhs.wordCount != rhs.wordCount {
                    return lhs.wordCount > rhs.wordCount
                }
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    static func historyUsageMetricCards(for stats: HistoryUsageStats) -> [HistoryUsageMetricCardPresentation] {
        HistoryUsageMetric.allCases.map { metric in
            HistoryUsageMetricCardPresentation(
                metric: metric,
                title: metric.title,
                valueText: metric.cardValueText(stats: stats),
                subtitleText: metric.subtitle
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

    private static func historyListHeadlineAndExcerpt(
        for text: String
    ) -> (title: String, excerpt: String) {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let firstLine = lines.first {
            let remainder = lines.dropFirst().joined(separator: " ")
            if !remainder.isEmpty {
                return (
                    title: historyCollapsedText(firstLine),
                    excerpt: historyCollapsedText(remainder)
                )
            }
        }

        let collapsed = historyCollapsedText(text)
        return (title: collapsed, excerpt: "")
    }

    private static func historyCollapsedText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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
