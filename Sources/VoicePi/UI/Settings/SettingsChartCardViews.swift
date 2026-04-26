import AppKit
import Foundation

@MainActor
final class FlippedLayoutView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class HistoryUsageLineChartView: NSView, NSViewToolTipOwner {
    struct Point: Equatable {
        let date: Date
        let value: Double
    }

    var metricTitle: String = "Value" {
        didSet {
            needsDisplay = true
        }
    }

    var points: [Point] = [] {
        didSet {
            needsDisplay = true
        }
    }

    var granularity: HistoryUsageTimelineGranularity = .day {
        didSet {
            needsDisplay = true
        }
    }

    var accentColor: NSColor = .systemBlue {
        didSet {
            needsDisplay = true
        }
    }

    private var tooltipTags: [NSView.ToolTipTag] = []
    private var tooltipTextByTag: [NSView.ToolTipTag: String] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let background = isDark
            ? NSColor(calibratedWhite: 0.16, alpha: 0.9)
            : NSColor(calibratedWhite: 1.0, alpha: 0.66)
        background.setFill()
        dirtyRect.fill()

        let plotInset = NSEdgeInsets(top: 16, left: 10, bottom: 24, right: 10)
        let plotRect = NSRect(
            x: bounds.minX + plotInset.left,
            y: bounds.minY + plotInset.bottom,
            width: max(1, bounds.width - plotInset.left - plotInset.right),
            height: max(1, bounds.height - plotInset.top - plotInset.bottom)
        )

        let ruleColor = isDark
            ? NSColor.white.withAlphaComponent(0.08)
            : NSColor.black.withAlphaComponent(0.08)
        for index in 0...3 {
            let y = plotRect.minY + (CGFloat(index) / 3) * plotRect.height
            let path = NSBezierPath()
            path.move(to: NSPoint(x: plotRect.minX, y: y))
            path.line(to: NSPoint(x: plotRect.maxX, y: y))
            path.lineWidth = 1
            ruleColor.setStroke()
            path.stroke()
        }

        guard points.count >= 2 else {
            clearTooltips()
            drawEmptyMessage("No trend data yet", in: plotRect)
            return
        }

        let values = points.map(\.value)
        let maxValue = max(1, values.max() ?? 1)
        let minValue = min(0, values.min() ?? 0)
        let valueRange = max(1, maxValue - minValue)

        let linePath = NSBezierPath()
        let areaPath = NSBezierPath()
        areaPath.move(to: NSPoint(x: plotRect.minX, y: plotRect.minY))
        var pointLocations: [NSPoint] = []
        pointLocations.reserveCapacity(points.count)

        for (index, point) in points.enumerated() {
            let progress = CGFloat(index) / CGFloat(max(1, points.count - 1))
            let x = plotRect.minX + progress * plotRect.width
            let yProgress = CGFloat((point.value - minValue) / valueRange)
            let y = plotRect.minY + yProgress * plotRect.height
            let location = NSPoint(x: x, y: y)
            pointLocations.append(location)

            if index == 0 {
                linePath.move(to: location)
                areaPath.line(to: location)
            } else {
                linePath.line(to: location)
                areaPath.line(to: location)
            }
        }

        areaPath.line(to: NSPoint(x: plotRect.maxX, y: plotRect.minY))
        areaPath.close()

        let lineColor = accentColor
        lineColor.withAlphaComponent(0.16).setFill()
        areaPath.fill()

        linePath.lineWidth = 2
        lineColor.setStroke()
        linePath.stroke()

        clearTooltips()
        let dotRadius: CGFloat = 2.2
        for location in pointLocations {
            let dot = NSBezierPath(
                ovalIn: NSRect(
                    x: location.x - dotRadius,
                    y: location.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
            )
            lineColor.setFill()
            dot.fill()
        }

        for (index, region) in tooltipRegions(for: pointLocations, in: plotRect).enumerated() {
            registerTooltip(rect: region, text: pointTooltipText(for: points[index]))
        }

        let valueLabel = "\(Int(maxValue.rounded()))"
        drawAxisLabel(valueLabel, at: NSPoint(x: plotRect.minX + 2, y: plotRect.maxY - 12), color: .secondaryLabelColor)

        drawTimelineAxisLabels(in: plotRect)
    }

    private func drawAxisLabel(_ text: String, at point: NSPoint, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: color
        ]
        text.draw(at: point, withAttributes: attributes)
    }

    private func drawEmptyMessage(_ text: String, in rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        )
        text.draw(at: point, withAttributes: attributes)
    }

    func view(
        _ view: NSView,
        stringForToolTip tag: NSView.ToolTipTag,
        point: NSPoint,
        userData data: UnsafeMutableRawPointer?
    ) -> String {
        tooltipTextByTag[tag] ?? ""
    }

    private func clearTooltips() {
        for tag in tooltipTags {
            removeToolTip(tag)
        }
        tooltipTags.removeAll()
        tooltipTextByTag.removeAll()
    }

    func tooltipRegions(for locations: [NSPoint], in plotRect: NSRect) -> [NSRect] {
        guard !locations.isEmpty else { return [] }
        guard locations.count > 1 else { return [plotRect] }

        return locations.enumerated().map { index, _ in
            let minX = index == 0
                ? plotRect.minX
                : (locations[index - 1].x + locations[index].x) / 2
            let maxX = index == locations.count - 1
                ? plotRect.maxX
                : (locations[index].x + locations[index + 1].x) / 2

            return NSRect(
                x: minX,
                y: plotRect.minY,
                width: max(1, maxX - minX),
                height: plotRect.height
            )
        }
    }

    private func registerTooltip(rect: NSRect, text: String) {
        let tag = addToolTip(rect, owner: self, userData: nil)
        tooltipTags.append(tag)
        tooltipTextByTag[tag] = text
    }

    private func pointTooltipText(for point: Point) -> String {
        "\(pointDateLabel(for: point.date))\n\(metricTitle): \(pointValueLabel(point.value))"
    }

    private func pointDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch granularity {
        case .hour:
            formatter.dateFormat = "yyyy-MM-dd HH:00"
            return formatter.string(from: date)
        case .day:
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        case .week:
            formatter.dateFormat = "yyyy-MM-dd"
            return "Week of \(formatter.string(from: date))"
        case .month:
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: date)
        }
    }

    private func pointValueLabel(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.000_1 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.2f", value)
    }

    private func drawTimelineAxisLabels(in plotRect: NSRect) {
        guard points.count >= 2 else { return }

        let tickCount = min(6, max(2, points.count))
        let step = max(1, Int(ceil(Double(points.count - 1) / Double(tickCount - 1))))
        var indices = Array(stride(from: 0, to: points.count, by: step))
        if indices.last != points.count - 1 {
            indices.append(points.count - 1)
        }

        let formatter = DateFormatter()
        switch granularity {
        case .hour:
            formatter.dateFormat = "HH:mm"
        case .day:
            formatter.dateFormat = "M/d"
        case .week:
            formatter.dateFormat = "M/d"
        case .month:
            formatter.dateFormat = "yy/MM"
        }

        for index in indices {
            let progress = CGFloat(index) / CGFloat(max(1, points.count - 1))
            let x = plotRect.minX + progress * plotRect.width
            let label = formatter.string(from: points[index].date)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let size = label.size(withAttributes: attributes)
            let centeredX = min(
                max(plotRect.minX, x - size.width / 2),
                plotRect.maxX - size.width
            )
            label.draw(
                at: NSPoint(x: centeredX, y: bounds.minY + 6),
                withAttributes: attributes
            )
        }
    }
}

@MainActor
final class HistoryUsageHeatmapView: NSView, NSViewToolTipOwner {
    struct TooltipEntry: Equatable {
        let rect: NSRect
        let text: String
    }

    var metricTitle: String = "Value" {
        didSet {
            needsDisplay = true
        }
    }

    var values: [[Double]] = Array(repeating: Array(repeating: 0, count: 24), count: 7) {
        didSet {
            needsDisplay = true
        }
    }

    var accentColor: NSColor = .systemBlue {
        didSet {
            needsDisplay = true
        }
    }

    private let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private var tooltipTags: [NSView.ToolTipTag] = []
    private var tooltipTextByTag: [NSView.ToolTipTag: String] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let background = isDark
            ? NSColor(calibratedWhite: 0.16, alpha: 0.9)
            : NSColor(calibratedWhite: 1.0, alpha: 0.66)
        background.setFill()
        dirtyRect.fill()

        let labelWidth: CGFloat = 34
        let topLabelHeight: CGFloat = 16
        let bottomPadding: CGFloat = 8
        let rightPadding: CGFloat = 8
        let gridRect = NSRect(
            x: bounds.minX + labelWidth,
            y: bounds.minY + bottomPadding,
            width: max(1, bounds.width - labelWidth - rightPadding),
            height: max(1, bounds.height - topLabelHeight - bottomPadding - 2)
        )

        let rowCount = 7
        let columnCount = 24
        let rowHeight = gridRect.height / CGFloat(rowCount)
        let columnWidth = gridRect.width / CGFloat(columnCount)
        let maxValue = values.flatMap { $0 }.max() ?? 0
        clearTooltips()

        for row in 0..<rowCount {
            let weekdayLabel = weekdayLabels[row]
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let labelPoint = NSPoint(
                x: bounds.minX + 2,
                y: gridRect.maxY - CGFloat(row + 1) * rowHeight + (rowHeight - 10) / 2
            )
            weekdayLabel.draw(at: labelPoint, withAttributes: labelAttributes)

            for column in 0..<columnCount {
                let value = (row < values.count && column < values[row].count) ? values[row][column] : 0
                let intensity = maxValue > 0 ? value / maxValue : 0
                let cellRect = NSRect(
                    x: gridRect.minX + CGFloat(column) * columnWidth + 0.5,
                    y: gridRect.maxY - CGFloat(row + 1) * rowHeight + 0.5,
                    width: max(0.5, columnWidth - 1),
                    height: max(0.5, rowHeight - 1)
                )
                heatmapCellColor(intensity: intensity, darkMode: isDark).setFill()
                NSBezierPath(rect: cellRect).fill()
            }
        }

        for entry in tooltipEntries(in: gridRect) {
            registerTooltip(rect: entry.rect, text: entry.text)
        }

        let axisTicks: [(Int, String)] = [(0, "0"), (6, "6"), (12, "12"), (18, "18"), (23, "23")]
        for (hour, label) in axisTicks {
            let x = gridRect.minX + CGFloat(hour) * columnWidth
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            label.draw(at: NSPoint(x: x, y: bounds.maxY - topLabelHeight), withAttributes: labelAttributes)
        }
    }

    func view(
        _ view: NSView,
        stringForToolTip tag: NSView.ToolTipTag,
        point: NSPoint,
        userData data: UnsafeMutableRawPointer?
    ) -> String {
        tooltipTextByTag[tag] ?? ""
    }

    private func heatmapCellColor(intensity: Double, darkMode: Bool) -> NSColor {
        let clamped = max(0, min(1, intensity))
        if clamped == 0 {
            return darkMode
                ? NSColor.white.withAlphaComponent(0.04)
                : NSColor.black.withAlphaComponent(0.04)
        }

        let base = accentColor
        return base.withAlphaComponent(CGFloat(0.18 + clamped * 0.72))
    }

    private func clearTooltips() {
        for tag in tooltipTags {
            removeToolTip(tag)
        }
        tooltipTags.removeAll()
        tooltipTextByTag.removeAll()
    }

    func tooltipEntries(in gridRect: NSRect) -> [TooltipEntry] {
        let rowCount = 7
        let columnCount = 24
        let rowHeight = gridRect.height / CGFloat(rowCount)
        let columnWidth = gridRect.width / CGFloat(columnCount)
        var entries: [TooltipEntry] = []
        entries.reserveCapacity(rowCount * columnCount)

        for row in 0..<rowCount {
            for column in 0..<columnCount {
                let value = (row < values.count && column < values[row].count) ? values[row][column] : 0
                let cellRect = NSRect(
                    x: gridRect.minX + CGFloat(column) * columnWidth + 0.5,
                    y: gridRect.maxY - CGFloat(row + 1) * rowHeight + 0.5,
                    width: max(0.5, columnWidth - 1),
                    height: max(0.5, rowHeight - 1)
                )
                entries.append(.init(
                    rect: cellRect,
                    text: heatmapTooltipText(row: row, hour: column, value: value)
                ))
            }
        }

        return entries
    }

    private func registerTooltip(rect: NSRect, text: String) {
        let tag = addToolTip(rect, owner: self, userData: nil)
        tooltipTags.append(tag)
        tooltipTextByTag[tag] = text
    }

    private func heatmapTooltipText(row: Int, hour: Int, value: Double) -> String {
        let startHour = String(format: "%02d:00", hour)
        let endHour = String(format: "%02d:00", (hour + 1) % 24)
        return "\(weekdayLabels[row]) \(startHour)-\(endHour)\n\(metricTitle): \(valueLabel(value))"
    }

    private func valueLabel(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.000_1 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.2f", value)
    }
}

@MainActor
final class ThemedSurfaceView: NSView {
    enum Style {
        case card
        case header
        case pill
        case row
    }

    private let style: Style

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
        syncTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        syncTheme()
    }

    func syncTheme() {
        let chrome = SettingsWindowTheme.surfaceChrome(
            for: effectiveAppearance,
            style: {
                switch style {
                case .card:
                    return .card
                case .header:
                    return .header
                case .pill:
                    return .pill
                case .row:
                    return .row
                }
            }()
        )

        layer?.backgroundColor = chrome.background.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = chrome.border.cgColor
        layer?.shadowColor = chrome.shadowColor.cgColor
        layer?.shadowOpacity = chrome.shadowOpacity
        layer?.shadowRadius = chrome.shadowRadius
        layer?.shadowOffset = chrome.shadowOffset
        layer?.cornerRadius = chrome.cornerRadius
        layer?.masksToBounds = false
    }
}
