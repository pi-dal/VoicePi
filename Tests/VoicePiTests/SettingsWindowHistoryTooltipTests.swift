import AppKit
import Testing
@testable import VoicePi

@MainActor
struct SettingsWindowHistoryTooltipTests {
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
