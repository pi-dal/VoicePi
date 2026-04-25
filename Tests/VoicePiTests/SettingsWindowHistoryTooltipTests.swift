import AppKit
import Testing
@testable import VoicePi

@MainActor
struct SettingsWindowHistoryTooltipTests {
    @Test
    func historyUsageLineChartsUseMetricSpecificAccentColors() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.historyUsageLineChartsUseMetricSpecificAccentColors.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        model.historyEntries = historyEntriesForChartColorTests()

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.show(section: .history)
        let contentView = try #require(controller.window?.contentView)
        let lineChart = try #require(findSubview(in: contentView, matching: { $0 as? HistoryUsageLineChartView }))

        let expectations: [(HistoryUsageMetric, (NSColor) -> Bool)] = [
            (.sessions, { $0.isBlueFamily }),
            (.characters, { $0.isGreenFamily }),
            (.words, { $0.isPurpleFamily }),
            (.recordingDuration, { $0.isOrangeFamily })
        ]

        for (metric, matcher) in expectations {
            try selectHistoryMetric(metric, in: contentView)
            #expect(matcher(lineChart.accentColor))
        }
    }

    @Test
    func historyUsageHeatmapsUseMetricSpecificAccentColors() throws {
        let defaults = UserDefaults(
            suiteName: "VoicePiTests.historyUsageHeatmapsUseMetricSpecificAccentColors.\(UUID().uuidString)"
        )!
        let model = AppModel(defaults: defaults)
        model.historyEntries = historyEntriesForChartColorTests()

        let controller = SettingsWindowController(model: model, delegate: nil)
        controller.show(section: .history)
        let contentView = try #require(controller.window?.contentView)
        let heatmap = try #require(findSubview(in: contentView, matching: { $0 as? HistoryUsageHeatmapView }))

        let expectations: [(HistoryUsageMetric, (NSColor) -> Bool)] = [
            (.sessions, { $0.isBlueFamily }),
            (.characters, { $0.isGreenFamily }),
            (.words, { $0.isPurpleFamily }),
            (.recordingDuration, { $0.isOrangeFamily })
        ]

        for (metric, matcher) in expectations {
            try selectHistoryMetric(metric, in: contentView)
            #expect(matcher(heatmap.accentColor))
        }
    }

    @Test
    func lineChartTooltipRegionsCoverPointColumns() {
        let view = HistoryUsageLineChartView(frame: NSRect(x: 0, y: 0, width: 320, height: 150))
        let plotRect = NSRect(x: 10, y: 24, width: 300, height: 100)
        let locations = [
            NSPoint(x: 10, y: 60),
            NSPoint(x: 160, y: 100),
            NSPoint(x: 310, y: 40)
        ]

        let regions = view.tooltipRegions(for: locations, in: plotRect)

        #expect(regions.count == 3)
        #expect(regions[0].width > 10)
        #expect(regions[1].width > 10)
        #expect(regions[2].width > 10)
        #expect(regions[0].minX <= plotRect.minX)
        #expect(regions[2].maxX >= plotRect.maxX)
    }

    @Test
    func heatmapTooltipEntriesIncludeZeroValueCells() {
        let view = HistoryUsageHeatmapView(frame: NSRect(x: 0, y: 0, width: 320, height: 170))
        view.metricTitle = "Words"
        view.values = Array(repeating: Array(repeating: 0, count: 24), count: 7)

        let gridRect = NSRect(x: 34, y: 8, width: 240, height: 140)
        let entries = view.tooltipEntries(in: gridRect)

        #expect(entries.count == 7 * 24)
        #expect(entries.first?.text == "Mon 00:00-01:00\nWords: 0")
    }
}

@MainActor
private func selectHistoryMetric(_ metric: HistoryUsageMetric, in contentView: NSView) throws {
    contentView.layoutSubtreeIfNeeded()
    let card = try #require(findSubview(in: contentView, matching: { view -> ThemedSurfaceView? in
        guard let card = view as? ThemedSurfaceView else { return nil }
        return card.identifier?.rawValue == "history.usage.metric.\(metric.rawValue)" ? card : nil
    }))
    let tapGesture = try #require(
        card.gestureRecognizers
            .compactMap { $0 as? NSClickGestureRecognizer }
            .first
    )
    _ = (tapGesture.target as? NSObject)?.perform(tapGesture.action, with: tapGesture)
    contentView.layoutSubtreeIfNeeded()
}

private func historyEntriesForChartColorTests() -> [HistoryEntry] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let baseDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 25, hour: 12))!

    return [
        HistoryEntry(
            text: "One two",
            createdAt: calendar.date(byAdding: .day, value: -2, to: baseDate)!,
            characterCount: 40,
            wordCount: 2,
            recordingDurationMilliseconds: 20_000
        ),
        HistoryEntry(
            text: "One two three four five six seven eight nine ten",
            createdAt: calendar.date(byAdding: .day, value: -1, to: baseDate)!,
            characterCount: 180,
            wordCount: 10,
            recordingDurationMilliseconds: 95_000
        ),
        HistoryEntry(
            text: "One two three four five",
            createdAt: baseDate,
            characterCount: 90,
            wordCount: 5,
            recordingDurationMilliseconds: 45_000
        )
    ]
}

private func findSubview<T>(in root: NSView, matching transform: (NSView) -> T?) -> T? {
    if let match = transform(root) {
        return match
    }

    for subview in root.subviews {
        if let match = findSubview(in: subview, matching: transform) {
            return match
        }
    }

    return nil
}

private extension NSColor {
    var isBlueFamily: Bool {
        guard let color = usingColorSpace(.deviceRGB) else { return false }
        return color.blueComponent > color.greenComponent + 0.05
            && color.blueComponent > color.redComponent + 0.05
    }

    var isGreenFamily: Bool {
        guard let color = usingColorSpace(.deviceRGB) else { return false }
        return color.greenComponent > color.blueComponent + 0.03
            && color.greenComponent > color.redComponent + 0.05
    }

    var isPurpleFamily: Bool {
        guard let color = usingColorSpace(.deviceRGB) else { return false }
        return color.redComponent > color.greenComponent + 0.04
            && color.blueComponent > color.greenComponent + 0.04
    }

    var isOrangeFamily: Bool {
        guard let color = usingColorSpace(.deviceRGB) else { return false }
        return color.redComponent > color.blueComponent + 0.06
            && color.greenComponent > color.blueComponent + 0.02
    }
}
