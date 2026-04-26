import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func refreshDictionarySection() {
        let presentation = SettingsPresentation.dictionarySectionPresentation(
            entries: model.dictionaryEntries,
            suggestions: model.dictionarySuggestions
        )
        dictionarySummaryLabel.stringValue = presentation.summaryText
        dictionaryPendingReviewLabel.stringValue = presentation.pendingReviewText

        rebuildDictionaryCollections()
        rebuildDictionaryTermRows()
        rebuildDictionarySuggestionRows()
        syncDictionaryContentPresentation()
    }

    func configureHistoryUsageMetricCards() {
        historyUsageMetricCardViews = [:]
        historyUsageMetricValueLabels = [:]
        historyUsageMetricLookup = [:]

        for metric in HistoryUsageMetric.allCases {
            _ = makeHistoryUsageMetricCard(for: metric)
        }
        rebuildHistoryUsageMetricRows()
        applyHistoryUsageMetricSelectionState()
    }

    func makeHistoryUsageMetricCard(for metric: HistoryUsageMetric) -> NSView {
        let card = ThemedSurfaceView(style: .row)
        card.identifier = NSUserInterfaceItemIdentifier("history.usage.metric.\(metric.rawValue)")
        card.translatesAutoresizingMaskIntoConstraints = false

        let accentColor = historyUsageMetricAccentColor(for: metric)

        let iconView = NSImageView()
        iconView.image = NSImage(
            systemSymbolName: metric.symbolName,
            accessibilityDescription: metric.title
        )?.withSymbolConfiguration(.init(pointSize: 17, weight: .semibold))
        iconView.contentTintColor = accentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 21
        iconContainer.layer?.borderWidth = 2
        iconContainer.layer?.borderColor = accentColor.withAlphaComponent(0.9).cgColor
        iconContainer.layer?.backgroundColor = accentColor.withAlphaComponent(0.06).cgColor
        iconContainer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 42),
            iconContainer.heightAnchor.constraint(equalToConstant: 42),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])

        let titleLabel = NSTextField(labelWithString: metric.title)
        titleLabel.font = .systemFont(ofSize: 13.5, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        let valueLabel = NSTextField(labelWithString: "0")
        valueLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        valueLabel.textColor = .labelColor
        valueLabel.maximumNumberOfLines = 1
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let subtitleLabel = NSTextField(labelWithString: metric.subtitle)
        subtitleLabel.font = .systemFont(ofSize: 12.5)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail

        let stack = NSStackView(views: [iconContainer, titleLabel, valueLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        pinCardContent(stack, into: card, horizontalPadding: 18, verticalPadding: 18)
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 132).isActive = true
        card.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        card.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let tapGesture = NSClickGestureRecognizer(
            target: self,
            action: #selector(selectHistoryUsageMetricFromCard(_:))
        )
        card.addGestureRecognizer(tapGesture)

        historyUsageMetricCardViews[metric] = card
        historyUsageMetricValueLabels[metric] = valueLabel
        historyUsageMetricLookup[ObjectIdentifier(card)] = metric
        return card
    }

    func rebuildHistoryUsageMetricRows() {
        for subview in historyUsageCardsStack.subviews {
            subview.removeFromSuperview()
        }

        let rowCards = HistoryUsageMetric.allCases.compactMap { historyUsageMetricCardViews[$0] }
        let row = NSStackView(views: rowCards)
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .top
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        row.setContentHuggingPriority(.required, for: .vertical)
        row.setContentCompressionResistancePriority(.required, for: .vertical)
        historyUsageCardsStack.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: historyUsageCardsStack.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: historyUsageCardsStack.trailingAnchor),
            row.topAnchor.constraint(equalTo: historyUsageCardsStack.topAnchor),
            row.bottomAnchor.constraint(equalTo: historyUsageCardsStack.bottomAnchor)
        ])
    }

    func configureHistoryUsageDetailCard() {
        historyUsageDetailCard.identifier = NSUserInterfaceItemIdentifier("history.usage.detail")
        historyUsageDetailTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        historyUsageDetailSubtitleLabel.font = .systemFont(ofSize: 12)
        historyUsageDetailSubtitleLabel.textColor = .secondaryLabelColor
        historyUsageDetailSubtitleLabel.maximumNumberOfLines = 0
        historyUsageDetailSubtitleLabel.lineBreakMode = .byWordWrapping
        historyUsageHeatmapTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        historyUsageTimeRangePopup.removeAllItems()
        historyUsageTimeRangePopup.addItems(withTitles: HistoryUsageTimeRange.allCases.map(\.title))
        historyUsageTimeRangePopup.target = self
        historyUsageTimeRangePopup.action = #selector(historyUsageTimeRangeChanged(_:))
        historyUsageTimeRangePopup.leadingSymbolName = "calendar"
        historyUsageTimeRangePopup.setContentHuggingPriority(.required, for: .horizontal)
        historyUsageTimeRangePopup.setContentCompressionResistancePriority(.required, for: .horizontal)
        syncHistoryUsageTimeRangePopupSelection()

        historyUsageLineChartView.translatesAutoresizingMaskIntoConstraints = false
        historyUsageLineChartView.heightAnchor.constraint(equalToConstant: 150).isActive = true

        historyUsageHeatmapView.translatesAutoresizingMaskIntoConstraints = false
        historyUsageHeatmapView.heightAnchor.constraint(equalToConstant: 170).isActive = true

        let stack = NSStackView(views: [
            historyUsageDetailTitleLabel,
            historyUsageDetailSubtitleLabel,
            historyUsageLineChartView,
            historyUsageHeatmapTitleLabel,
            historyUsageHeatmapView
        ])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading

        pinCardContent(stack, into: historyUsageDetailCard)
        historyUsageDetailCard.isHidden = true
    }

    func refreshHistoryUsageMetricCards(using stats: HistoryUsageStats) {
        let presentations = SettingsWindowSupport.historyUsageMetricCards(for: stats)
        for presentation in presentations {
            historyUsageMetricValueLabels[presentation.metric]?.stringValue = presentation.valueText
        }
    }

    func historyUsageMetricAccentColor(for metric: HistoryUsageMetric) -> NSColor {
        switch metric {
        case .sessions:
            return interfaceColor(
                light: NSColor.systemBlue.darker(),
                dark: NSColor.systemBlue.lighter()
            )
        case .characters:
            return interfaceColor(
                light: NSColor.systemGreen.darker(),
                dark: NSColor.systemGreen.lighter()
            )
        case .words:
            return interfaceColor(
                light: NSColor.systemPurple.darker(),
                dark: NSColor.systemPurple.lighter()
            )
        case .recordingDuration:
            return interfaceColor(
                light: NSColor.systemOrange.darker(),
                dark: NSColor.systemOrange.lighter()
            )
        }
    }

    func refreshHistoryUsageDetail(entries: [HistoryEntry]) {
        guard let selectedMetric = historyUsageSelectedMetric else {
            historyUsageDetailCard.isHidden = true
            return
        }

        let accentColor = historyUsageMetricAccentColor(for: selectedMetric)
        let visualization = SettingsWindowSupport.historyUsageVisualization(
            entries: entries,
            metric: selectedMetric,
            timeRange: historyUsageTimeRange
        )
        historyUsageDetailTitleLabel.stringValue = "\(selectedMetric.title) Trend"
        historyUsageDetailSubtitleLabel.stringValue =
            "Range: \(historyUsageTimeRange.title) • \(visualization.granularity.title) (\(selectedMetric.lineChartUnit))"
        historyUsageHeatmapTitleLabel.stringValue = "\(selectedMetric.title) Heatmap"
        historyUsageLineChartView.metricTitle = selectedMetric.title
        historyUsageLineChartView.accentColor = accentColor
        historyUsageLineChartView.points = visualization.timeline.map { point in
            .init(date: point.date, value: point.value)
        }
        historyUsageLineChartView.granularity = visualization.granularity
        historyUsageHeatmapView.metricTitle = selectedMetric.title
        historyUsageHeatmapView.accentColor = accentColor
        historyUsageHeatmapView.values = visualization.heatmap
        historyUsageDetailCard.isHidden = false
    }

    func applyHistoryUsageMetricSelectionState() {
        let selectedMetric = historyUsageSelectedMetric

        for (metric, card) in historyUsageMetricCardViews {
            let isSelected = selectedMetric == metric
            card.layer?.borderWidth = isSelected ? 1.8 : 1
            card.layer?.borderColor = (isSelected
                ? historyUsageMetricAccentColor(for: metric)
                : cardBorderColor).cgColor
        }
    }

    @objc
    func selectHistoryUsageMetricFromCard(_ sender: NSClickGestureRecognizer) {
        guard
            let view = sender.view,
            let selectedMetric = historyUsageMetricLookup[ObjectIdentifier(view)]
        else {
            return
        }

        historyUsageSelectedMetric = selectedMetric
        applyHistoryUsageMetricSelectionState()
        refreshHistoryUsageDetail(entries: model.historyEntries)
    }

    @objc
    func historyUsageTimeRangeChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard
            index >= 0,
            let selectedRange = HistoryUsageTimeRange(rawValue: index)
        else {
            return
        }
        historyUsageTimeRange = selectedRange
        refreshHistoryUsageDetail(entries: model.historyEntries)
    }

    func syncHistoryUsageTimeRangePopupSelection() {
        historyUsageTimeRangePopup.selectItem(at: historyUsageTimeRange.rawValue)
    }

    @objc
    func handleHistoryBackgroundClick(_ sender: NSClickGestureRecognizer) {
        guard historyUsageSelectedMetric != nil else { return }
        guard let container = historyDocumentContainerView else { return }

        let location = sender.location(in: container)
        if pointInAnyHistoryUsageMetricCard(location, container: container) {
            return
        }
        if pointInHistoryUsageDetailCard(location, container: container) {
            return
        }
        if pointInHistoryUsageTimeRangePopup(location, container: container) {
            return
        }

        historyUsageSelectedMetric = nil
        applyHistoryUsageMetricSelectionState()
        refreshHistoryUsageDetail(entries: model.historyEntries)
    }

}
