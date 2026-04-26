import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func makeAboutActionRowButton(title: String, symbolName: String, action: Selector) -> NSButton {
        let button = AboutActionRowButton(
            title: title,
            symbolName: symbolName,
            target: self,
            action: action
        )
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 66).isActive = true
        return button
    }

    func makeActionCard(title: String, description: String, actions: [NSButton], verticalActions: Bool = false) -> NSView {
        let card = makeCardView()
        let actionRow = makeButtonGroup(actions)
        actionRow.orientation = verticalActions ? .vertical : .horizontal
        actionRow.spacing = verticalActions ? 8 : 10
        actionRow.alignment = verticalActions ? .leading : .centerY

        let stack = NSStackView(views: [
            makeSectionTitle(title),
            makeBodyLabel(description),
            actionRow
        ])
        stack.orientation = .vertical
        stack.spacing = SettingsLayoutMetrics.pageSpacing - 2
        stack.alignment = .leading

        pinCardContent(stack, into: card)
        return card
    }

    func makeHistorySessionHeaderView() -> NSView {
        let row = NSStackView(views: [NSView(), historySessionCountLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    func makeHistoryOverviewCard() -> NSView {
        let card = makeCardView()
        historyUsageTimeRangePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 104).isActive = true

        let headerRow = NSStackView(views: [
            makeSectionTitle("Overview"),
            NSView(),
            historyUsageTimeRangePopup
        ])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 10

        let stack = NSStackView(views: [
            headerRow,
            historyUsageCardsStack,
            historyUsageDetailCard
        ])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading

        historyUsageCardsStack.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        historyUsageDetailCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        pinCardContent(stack, into: card)
        return card
    }

    func makeHistoryToolbarView() -> NSView {
        let filterButton = makeSecondaryActionButton(
            title: "Filter",
            action: #selector(showHistorySortMenu(_:))
        )
        filterButton.image = NSImage(
            systemSymbolName: "line.3.horizontal.decrease.circle",
            accessibilityDescription: "Filter"
        )
        filterButton.imagePosition = .imageLeading
        filterButton.setContentHuggingPriority(.required, for: .horizontal)

        let exportButton = makeSecondaryActionButton(
            title: "Export",
            action: #selector(exportHistoryEntries(_:))
        )
        exportButton.image = NSImage(
            systemSymbolName: "square.and.arrow.down",
            accessibilityDescription: "Export"
        )
        exportButton.imagePosition = .imageLeading
        exportButton.setContentHuggingPriority(.required, for: .horizontal)

        historySearchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
        historyDateFilterPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 126).isActive = true

        let row = NSStackView(views: [
            historySearchField,
            historyDateFilterPopup,
            filterButton,
            exportButton
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.distribution = .fillProportionally
        return row
    }

    func makeHistoryEntriesCard() -> NSView {
        let card = makeCardView()
        let stack = NSStackView(views: [historyRowsStack])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        historyRowsStack.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        pinCardContent(stack, into: card)
        return card
    }

    func makeHistoryPaginationView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        historyPaginationStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(historyPaginationStack)
        NSLayoutConstraint.activate([
            historyPaginationStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            historyPaginationStack.topAnchor.constraint(equalTo: container.topAnchor),
            historyPaginationStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            historyPaginationStack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            historyPaginationStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        return container
    }

    func configureDictionaryTermHeaderRow() {
        for arrangedSubview in dictionaryTermHeaderRow.arrangedSubviews {
            dictionaryTermHeaderRow.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        let termLabel = makeDictionaryHeaderLabel("Term")
        termLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        let bindingsLabel = makeDictionaryHeaderLabel("Bindings")
        bindingsLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        let tagLabel = makeDictionaryHeaderLabel("Tag")
        tagLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
        let stateLabel = makeDictionaryHeaderLabel("State")
        stateLabel.alignment = .right
        stateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.actionButtonHeight).isActive = true

        [termLabel, bindingsLabel, tagLabel, NSView(), stateLabel, spacer].forEach {
            dictionaryTermHeaderRow.addArrangedSubview($0)
        }
        dictionaryTermHeaderRow.orientation = .horizontal
        dictionaryTermHeaderRow.spacing = 10
        dictionaryTermHeaderRow.alignment = .centerY
    }

    func makeDictionaryHeaderLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    func makeDictionarySidebarHeader(searchToolbar: NSView) -> NSView {
        let statusStack = NSStackView(views: [dictionarySummaryLabel, dictionaryPendingReviewLabel])
        statusStack.orientation = .vertical
        statusStack.spacing = 4
        statusStack.alignment = .leading
        statusStack.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [searchToolbar, statusStack])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        searchToolbar.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        statusStack.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    func makeDictionarySidebarColumn(headerView: NSView, collectionsCard: NSView) -> NSView {
        let stack = makeVerticalStack([headerView, collectionsCard], spacing: 12)
        headerView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        collectionsCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.dictionarySidebarWidth).isActive = true
        return stack
    }

    func makeDictionaryCollectionsCard() -> NSView {
        let card = makeCardView()
        let stack = NSStackView(views: [
            makeSectionHeader(title: "Collections", subtitle: "Browse all terms, tag buckets, or pending suggestions."),
            dictionaryCollectionsStack,
            NSView(),
            dictionaryCollectionsFooterLabel
        ])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        dictionaryCollectionsStack.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        dictionaryCollectionsFooterLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        pinCardContent(stack, into: card)
        return card
    }

    func makeDictionaryContentCard(
        termsRowsScrollView: NSScrollView,
        suggestionRowsScrollView: NSScrollView
    ) -> NSView {
        let card = makeCardView()
        let stack = NSStackView(views: [
            dictionaryContentTitleLabel,
            dictionaryContentSubtitleLabel,
            dictionaryTermHeaderRow,
            termsRowsScrollView,
            suggestionRowsScrollView
        ])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        dictionaryContentTitleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        dictionaryContentSubtitleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        dictionaryTermHeaderRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        termsRowsScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        suggestionRowsScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        pinCardContent(stack, into: card)
        return card
    }

    func rebuildDictionaryCollections() {
        let collections = SettingsWindowSupport.dictionaryCollections(
            entries: model.dictionaryEntries,
            suggestions: model.dictionarySuggestions
        )
        let availableSelections = Set(collections.map(\.selection))
        if !availableSelections.contains(dictionarySelectedCollection) {
            dictionarySelectedCollection = .allTerms
        }

        dictionaryCollectionRowViews = [:]
        dictionaryCollectionLookup = [:]

        let views = collections.map(makeDictionaryCollectionRow(collection:))
        replaceArrangedSubviews(in: dictionaryCollectionsStack, with: views)
        applyDictionaryCollectionSelectionState()
    }

    func makeDictionaryCollectionRow(collection: DictionaryCollectionPresentation) -> NSView {
        let row = ThemedSurfaceView(style: .row)
        row.identifier = NSUserInterfaceItemIdentifier("dictionary.collection.\(collection.title)")

        let titleLabel = NSTextField(labelWithString: collection.title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.toolTip = collection.title

        let countLabel = NSTextField(labelWithString: "\(collection.count)")
        countLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .center

        let countBadge = ThemedSurfaceView(style: .pill)
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        countBadge.setContentHuggingPriority(.required, for: .horizontal)
        pinCardContent(countLabel, into: countBadge, horizontalPadding: 10, verticalPadding: 5)

        let content = NSStackView(views: [titleLabel, NSView(), countBadge])
        content.orientation = .horizontal
        content.spacing = 10
        content.alignment = .centerY
        content.distribution = .fill

        pinCardContent(content, into: row, horizontalPadding: 12, verticalPadding: 10)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        let tapGesture = NSClickGestureRecognizer(
            target: self,
            action: #selector(selectDictionaryCollectionFromCard(_:))
        )
        row.addGestureRecognizer(tapGesture)

        dictionaryCollectionRowViews[collection.selection] = row
        dictionaryCollectionLookup[ObjectIdentifier(row)] = collection.selection
        return row
    }

    func applyDictionaryCollectionSelectionState() {
        for (selection, row) in dictionaryCollectionRowViews {
            let isSelected = selection == dictionarySelectedCollection
            row.layer?.borderWidth = isSelected ? 1.5 : 1
            row.layer?.borderColor = (isSelected ? currentThemePalette.accent : cardBorderColor).cgColor
            row.layer?.backgroundColor = isSelected
                ? currentThemePalette.accent.withAlphaComponent(0.12).cgColor
                : SettingsWindowTheme.surfaceChrome(for: currentThemeAppearance, style: .row).background.cgColor
        }
    }

    @objc
    func selectDictionaryCollectionFromCard(_ sender: NSClickGestureRecognizer) {
        guard
            let view = sender.view,
            let selection = dictionaryCollectionLookup[ObjectIdentifier(view)]
        else {
            return
        }

        dictionarySelectedCollection = selection
        refreshDictionarySection()
    }

    func makeDictionaryTagBadge(text: String, isActive: Bool) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11.5, weight: .medium)
        label.textColor = isActive ? currentThemePalette.accent : .secondaryLabelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail

        let badge = ThemedSurfaceView(style: .pill)
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.wantsLayer = true
        badge.layer?.backgroundColor = isActive
            ? currentThemePalette.accent.withAlphaComponent(0.12).cgColor
            : SettingsWindowTheme.surfaceChrome(for: currentThemeAppearance, style: .pill).background.cgColor
        pinCardContent(label, into: badge, horizontalPadding: 10, verticalPadding: 6)
        return badge
    }

    func rebuildHistoryRows() {
        historyEntryByIdentifier = [:]

        let filteredEntries = currentFilteredHistoryEntries()
        historySessionCountLabel.stringValue = SettingsWindowSupport.historySessionCountText(
            filteredCount: filteredEntries.count,
            totalCount: model.historyEntries.count
        )

        let pageSize = 6
        let totalPages = max(1, Int(ceil(Double(max(1, filteredEntries.count)) / Double(pageSize))))
        historyCurrentPage = max(0, min(historyCurrentPage, totalPages - 1))

        let startIndex = historyCurrentPage * pageSize
        let pageEntries = Array(filteredEntries.dropFirst(startIndex).prefix(pageSize))

        if pageEntries.isEmpty {
            let message = SettingsWindowSupport.historyEmptyStateText(
                totalEntryCount: model.historyEntries.count,
                filteredEntryCount: filteredEntries.count,
                query: historySearchField.stringValue
            )
            replaceArrangedSubviews(
                in: historyRowsStack,
                with: [makeBodyLabel(message)]
            )
        } else {
            replaceArrangedSubviews(
                in: historyRowsStack,
                with: pageEntries.map { makeHistoryRow(entry: $0) }
            )
        }

        rebuildHistoryPagination(totalPages: totalPages)
    }

    func makeHistoryRow(entry: HistoryEntry) -> NSView {
        let presentation = SettingsWindowSupport.historyListRowPresentation(for: entry)

        let iconView = NSImageView()
        iconView.image = NSImage(
            systemSymbolName: "doc.text",
            accessibilityDescription: "History entry"
        )?.withSymbolConfiguration(.init(pointSize: 21, weight: .regular))
        iconView.contentTintColor = .labelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let iconContainer = ThemedSurfaceView(style: .pill)
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 56),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])

        let timestampLabel = makeSubtleCaption(presentation.timestampText)
        timestampLabel.maximumNumberOfLines = 1
        timestampLabel.lineBreakMode = .byTruncatingTail

        let titleLabel = NSTextField(labelWithString: presentation.titleText)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        let excerptLabel = NSTextField(wrappingLabelWithString: presentation.excerptText)
        excerptLabel.font = .systemFont(ofSize: 12.5)
        excerptLabel.textColor = .secondaryLabelColor
        excerptLabel.maximumNumberOfLines = 2
        excerptLabel.lineBreakMode = .byTruncatingTail
        excerptLabel.isHidden = presentation.excerptText.isEmpty

        let actionsButton = makeOverflowActionButton(
            accessibilityLabel: "History actions",
            action: #selector(showHistoryEntryActions(_:))
        )
        actionsButton.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)
        actionsButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        historyEntryByIdentifier[entry.id.uuidString] = entry

        let badgeLabel = makeHistoryFileTypeBadge(presentation.fileTypeText)

        let titleRow = NSStackView(views: [titleLabel, NSView(), badgeLabel, actionsButton])
        titleRow.orientation = .horizontal
        titleRow.spacing = 10
        titleRow.alignment = .centerY

        let metadataRow = NSStackView(views: [
            makeHistoryMetadataItem(symbolName: "clock", text: presentation.durationText),
            makeHistoryMetadataItem(symbolName: "text.alignleft", text: presentation.charactersText),
            makeHistoryMetadataItem(symbolName: "text.word.spacing", text: presentation.wordsText)
        ])
        metadataRow.orientation = .horizontal
        metadataRow.spacing = 14
        metadataRow.alignment = .centerY

        let textStack = NSStackView(views: [timestampLabel, titleRow, excerptLabel, metadataRow])
        textStack.orientation = .vertical
        textStack.spacing = 6
        textStack.alignment = .leading
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let rowContent = NSStackView(views: [iconContainer, textStack])
        rowContent.orientation = .horizontal
        rowContent.spacing = 12
        rowContent.alignment = .top

        let row = makeCompactListRow(content: rowContent)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true
        return row
    }

    func makeHistoryFileTypeBadge(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = currentThemePalette.accent

        let badge = ThemedSurfaceView(style: .pill)
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.wantsLayer = true
        badge.layer?.backgroundColor = currentThemePalette.accent.withAlphaComponent(0.12).cgColor
        badge.layer?.borderColor = currentThemePalette.accent.withAlphaComponent(0.10).cgColor
        pinCardContent(label, into: badge, horizontalPadding: 10, verticalPadding: 6)
        return badge
    }

    func makeHistoryMetadataItem(symbolName: String, text: String) -> NSView {
        let iconView = NSImageView()
        iconView.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: text
        )?.withSymbolConfiguration(.init(pointSize: 11, weight: .regular))
        iconView.contentTintColor = .secondaryLabelColor

        let label = makeSubtleCaption(text)
        label.maximumNumberOfLines = 1

        let row = NSStackView(views: [iconView, label])
        row.orientation = .horizontal
        row.spacing = 5
        row.alignment = .centerY
        return row
    }

    func currentFilteredHistoryEntries() -> [HistoryEntry] {
        SettingsWindowSupport.filteredHistoryEntries(
            model.historyEntries,
            query: historySearchField.stringValue,
            dateFilter: historyDateFilter,
            sortOrder: historySortOrder
        )
    }

    func rebuildHistoryPagination(totalPages: Int) {
        guard totalPages > 1 else {
            historyPaginationStack.isHidden = true
            for arrangedSubview in historyPaginationStack.arrangedSubviews {
                historyPaginationStack.removeArrangedSubview(arrangedSubview)
                arrangedSubview.removeFromSuperview()
            }
            return
        }

        historyPaginationStack.isHidden = false

        var views: [NSView] = []
        views.append(makeHistoryPaginationArrowButton(
            symbolName: "chevron.left",
            action: #selector(goToPreviousHistoryPage)
        ))

        for page in historyVisiblePageIndices(totalPages: totalPages, currentPage: historyCurrentPage) {
            if page < 0 {
                views.append(makeHistoryPaginationEllipsis())
            } else {
                views.append(
                    makeHistoryPaginationPageButton(
                        page: page,
                        isCurrent: page == historyCurrentPage
                    )
                )
            }
        }

        views.append(makeHistoryPaginationArrowButton(
            symbolName: "chevron.right",
            action: #selector(goToNextHistoryPage)
        ))

        for arrangedSubview in historyPaginationStack.arrangedSubviews {
            historyPaginationStack.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }
        for view in views {
            historyPaginationStack.addArrangedSubview(view)
        }

        if let previousButton = historyPaginationStack.arrangedSubviews.first as? NSButton {
            previousButton.isEnabled = historyCurrentPage > 0
        }
        if let nextButton = historyPaginationStack.arrangedSubviews.last as? NSButton {
            nextButton.isEnabled = historyCurrentPage < totalPages - 1
        }
    }

    func historyVisiblePageIndices(totalPages: Int, currentPage: Int) -> [Int] {
        guard totalPages > 0 else { return [] }
        if totalPages <= 7 {
            return Array(0..<totalPages)
        }

        let middleStart = max(1, currentPage - 1)
        let middleEnd = min(totalPages - 2, currentPage + 1)

        var result: [Int] = [0]
        if middleStart > 1 {
            result.append(-1)
        }
        result.append(contentsOf: middleStart...middleEnd)
        if middleEnd < totalPages - 2 {
            result.append(-1)
        }
        result.append(totalPages - 1)
        return result
    }

    func makeHistoryPaginationPageButton(page: Int, isCurrent: Bool) -> NSButton {
        let button = StyledSettingsButton(
            title: "\(page + 1)",
            role: isCurrent ? .primary : .secondary,
            target: self,
            action: #selector(selectHistoryPage(_:))
        )
        button.tag = page
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        return button
    }

    func makeHistoryPaginationArrowButton(symbolName: String, action: Selector) -> NSButton {
        let button = makeSecondaryActionButton(title: "", action: action)
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: symbolName
        )
        button.imagePosition = .imageOnly
        button.widthAnchor.constraint(equalToConstant: 32).isActive = true
        return button
    }

    func makeHistoryPaginationEllipsis() -> NSView {
        let label = makeSubtleCaption("...")
        label.alignment = .center
        return label
    }

    func makeDictionaryRowsScrollView(contentStack: NSStackView) -> NSScrollView {
        let scrollView = NSScrollView(frame: .zero)
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let heightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 170)
        heightConstraint.isActive = true
        if contentStack === dictionaryTermRowsStack {
            dictionaryTermsRowsHeightConstraint = heightConstraint
        } else if contentStack === dictionarySuggestionRowsStack {
            dictionarySuggestionRowsHeightConstraint = heightConstraint
        }

        let documentView = FlippedLayoutView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)

        let clipView = scrollView.contentView
        NSLayoutConstraint.activate([
            documentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: clipView.topAnchor),
            documentView.widthAnchor.constraint(equalTo: clipView.widthAnchor),

            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])

        return scrollView
    }

    func updateDictionaryTermsRowsHeight(forVisibleRowCount rowCount: Int) {
        guard let constraint = dictionaryTermsRowsHeightConstraint else { return }
        constraint.constant = SettingsWindowSupport.dictionaryTermsRowsHeight(
            forVisibleRowCount: rowCount,
            rowSpacing: dictionaryTermRowsStack.spacing
        )
    }

    func updateDictionarySuggestionRowsHeight(forVisibleRowCount rowCount: Int) {
        guard let constraint = dictionarySuggestionRowsHeightConstraint else { return }
        let visibleRows = max(1, min(3, rowCount))
        let rowHeight: CGFloat = 56
        let targetHeight = (CGFloat(visibleRows) * rowHeight)
            + (CGFloat(max(0, visibleRows - 1)) * dictionarySuggestionRowsStack.spacing)
        constraint.constant = min(188, max(56, targetHeight))
    }

    func makeDictionaryTermsCard(
        headerSupplementaryView: NSView,
        rowsScrollView: NSScrollView
    ) -> NSView {
        let card = makeCardView()
        let stack = NSStackView(views: [
            makeSectionTitle("Terms"),
            headerSupplementaryView,
            rowsScrollView
        ])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        headerSupplementaryView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        rowsScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        pinCardContent(stack, into: card)
        return card
    }

    func makeDictionaryCollectionCard(
        title: String,
        headerSupplementaryView: NSView? = nil,
        listContainerView: NSView
    ) -> NSView {
        let card = makeCardView()
        var views: [NSView] = [makeSectionTitle(title)]
        if let headerSupplementaryView {
            views.append(headerSupplementaryView)
        }
        views.append(listContainerView)

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        listContainerView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        pinCardContent(stack, into: card)
        return card
    }

}
