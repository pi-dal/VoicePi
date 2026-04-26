import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func buildExternalProcessorsView() {
        let contentStack = makePageStack()

        externalProcessorsSummaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        externalProcessorsSummaryLabel.textColor = .labelColor
        externalProcessorsSummaryLabel.alignment = .left
        externalProcessorsSummaryLabel.lineBreakMode = .byWordWrapping
        externalProcessorsSummaryLabel.maximumNumberOfLines = 0

        externalProcessorsDetailLabel.font = .systemFont(ofSize: 12.5)
        externalProcessorsDetailLabel.textColor = .secondaryLabelColor
        externalProcessorsDetailLabel.alignment = .left
        externalProcessorsDetailLabel.lineBreakMode = .byWordWrapping
        externalProcessorsDetailLabel.maximumNumberOfLines = 0

        externalProcessorsStatusLabel.font = .systemFont(ofSize: 12)
        externalProcessorsStatusLabel.textColor = .secondaryLabelColor
        externalProcessorsStatusLabel.alignment = .left
        externalProcessorsStatusLabel.lineBreakMode = .byWordWrapping
        externalProcessorsStatusLabel.maximumNumberOfLines = 0
        externalProcessorsStatusLabel.isHidden = true

        externalProcessorManagerButton.title = "+ Add Processor"
        externalProcessorManagerButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 164).isActive = true
        externalProcessorsRowsStack.orientation = .vertical
        externalProcessorsRowsStack.spacing = 8
        externalProcessorsRowsStack.alignment = .leading

        let listCard = makeExternalProcessorsListCard()
        listCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 248).isActive = true

        let selectedCard = makeExternalProcessorsSelectedCard()
        selectedCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 124).isActive = true

        let helpCard = makeExternalProcessorsHelpCard()
        let leftColumn = NSStackView(views: [listCard, selectedCard])
        leftColumn.orientation = .vertical
        leftColumn.alignment = .leading
        leftColumn.spacing = SettingsLayoutMetrics.pageSpacing
        listCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor).isActive = true
        selectedCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor).isActive = true

        let topRow = NSStackView(views: [leftColumn, helpCard])
        topRow.orientation = .horizontal
        topRow.alignment = .top
        topRow.spacing = SettingsLayoutMetrics.twoColumnSpacing
        topRow.distribution = .fill
        helpCard.widthAnchor.constraint(greaterThanOrEqualTo: topRow.widthAnchor, multiplier: 0.34).isActive = true
        helpCard.widthAnchor.constraint(lessThanOrEqualTo: topRow.widthAnchor, multiplier: 0.44).isActive = true

        leftColumn.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        leftColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        helpCard.setContentCompressionResistancePriority(.required, for: .horizontal)
        helpCard.setContentHuggingPriority(.required, for: .horizontal)

        addPageSection(topRow, to: contentStack)

        installScrollablePage(contentStack, in: externalProcessorsView, section: .externalProcessors)

        refreshExternalProcessorsSection()
    }

    func buildAboutView() {
        let contentStack = makePageStack()

        aboutVersionLabel.font = .systemFont(ofSize: 13)
        aboutVersionLabel.alignment = .left
        aboutBuildLabel.font = .systemFont(ofSize: 13)
        aboutBuildLabel.alignment = .left
        aboutAuthorLabel.font = .systemFont(ofSize: 13)
        aboutAuthorLabel.alignment = .left
        aboutRepositoryLabel.font = .systemFont(ofSize: 13)
        aboutRepositoryLabel.alignment = .left
        aboutRepositoryLabel.lineBreakMode = .byTruncatingTail
        aboutWebsiteLabel.font = .systemFont(ofSize: 13)
        aboutWebsiteLabel.alignment = .left
        aboutWebsiteLabel.lineBreakMode = .byTruncatingTail
        aboutGitHubLabel.font = .systemFont(ofSize: 13)
        aboutGitHubLabel.alignment = .left
        aboutGitHubLabel.lineBreakMode = .byTruncatingTail
        aboutXLabel.font = .systemFont(ofSize: 13)
        aboutXLabel.alignment = .left
        aboutXLabel.lineBreakMode = .byTruncatingTail
        aboutUpdateTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        aboutUpdateSummaryLabel.font = .systemFont(ofSize: 12.5)
        aboutUpdateSummaryLabel.textColor = .secondaryLabelColor
        aboutUpdateSummaryLabel.lineBreakMode = .byWordWrapping
        aboutUpdateSummaryLabel.maximumNumberOfLines = 0
        aboutUpdateStatusLabel.font = .systemFont(ofSize: 11.5, weight: .semibold)
        aboutUpdateStatusLabel.textColor = .secondaryLabelColor
        aboutUpdateSourceLabel.font = .systemFont(ofSize: 12)
        aboutUpdateSourceLabel.textColor = .secondaryLabelColor
        aboutUpdateStrategyLabel.font = .systemFont(ofSize: 12)
        aboutUpdateStrategyLabel.textColor = .secondaryLabelColor
        aboutUpdateStrategyLabel.lineBreakMode = .byWordWrapping
        aboutUpdateStrategyLabel.maximumNumberOfLines = 0
        aboutUpdateProgressLabel.font = .systemFont(ofSize: 11.5)
        aboutUpdateProgressLabel.textColor = .tertiaryLabelColor
        aboutUpdateProgressIndicator.isIndeterminate = false
        aboutUpdateProgressIndicator.minValue = 0
        aboutUpdateProgressIndicator.maxValue = 1
        aboutUpdateProgressIndicator.controlSize = .small
        aboutUpdatePrimaryButton.heightAnchor.constraint(
            equalToConstant: SettingsLayoutMetrics.actionButtonHeight
        ).isActive = true
        aboutUpdateSecondaryButton.heightAnchor.constraint(
            equalToConstant: SettingsLayoutMetrics.actionButtonHeight
        ).isActive = true
        let brandCard = makeAboutBrandCard()
        let updatesCard = makeSimpleSummaryCard(
            title: "Updates",
            subtitle: "Check GitHub Releases and apply the right update flow for this install.",
            bodyViews: [makeUpdateExperienceSection()]
        )
        let creditsCard = makeAboutCreditsCard()
        let rightColumn = makeVerticalStack([updatesCard, creditsCard], spacing: 12)
        let topRow = makeTwoColumnSection(
            left: brandCard,
            right: rightColumn,
            leftPriority: 0.44
        )
        brandCard.heightAnchor.constraint(equalTo: rightColumn.heightAnchor).isActive = true

        contentStack.addArrangedSubview(topRow)
        contentStack.addArrangedSubview(makeAboutFooter())

        installScrollablePage(contentStack, in: aboutView, section: .about)
    }

    func buildDictionaryView() {
        let contentStack = makePageStack()

        dictionarySummaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        dictionarySummaryLabel.textColor = .secondaryLabelColor
        dictionarySummaryLabel.alignment = .left
        dictionarySummaryLabel.lineBreakMode = .byWordWrapping
        dictionarySummaryLabel.maximumNumberOfLines = 0

        dictionaryPendingReviewLabel.font = .systemFont(ofSize: 12.5)
        dictionaryPendingReviewLabel.textColor = .secondaryLabelColor
        dictionaryPendingReviewLabel.alignment = .left
        dictionaryPendingReviewLabel.lineBreakMode = .byWordWrapping
        dictionaryPendingReviewLabel.maximumNumberOfLines = 0

        dictionarySearchField.placeholderString = "Search terms..."
        dictionarySearchField.target = self
        dictionarySearchField.action = #selector(dictionarySearchChanged(_:))
        dictionarySearchField.sendsSearchStringImmediately = true
        dictionarySearchField.sendsWholeSearchString = false

        dictionaryCollectionsStack.orientation = .vertical
        dictionaryCollectionsStack.spacing = 8
        dictionaryCollectionsStack.alignment = .leading

        dictionaryCollectionsFooterLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        dictionaryCollectionsFooterLabel.textColor = currentThemePalette.accent
        dictionaryCollectionsFooterLabel.alignment = .left
        dictionaryCollectionsFooterLabel.maximumNumberOfLines = 1

        dictionaryContentTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        dictionaryContentTitleLabel.textColor = .labelColor
        dictionaryContentTitleLabel.maximumNumberOfLines = 1

        dictionaryContentSubtitleLabel.font = .systemFont(ofSize: 12.5)
        dictionaryContentSubtitleLabel.textColor = .secondaryLabelColor
        dictionaryContentSubtitleLabel.lineBreakMode = .byWordWrapping
        dictionaryContentSubtitleLabel.maximumNumberOfLines = 2

        configureDictionaryTermHeaderRow()

        dictionaryTermRowsStack.orientation = .vertical
        dictionaryTermRowsStack.spacing = 10
        dictionaryTermRowsStack.alignment = .leading

        dictionarySuggestionRowsStack.orientation = .vertical
        dictionarySuggestionRowsStack.spacing = 10
        dictionarySuggestionRowsStack.alignment = .leading

        let termActionButton = makePrimaryActionButton(title: "Add Term", action: #selector(addDictionaryTermFromSettings))
        termActionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        termActionButton.setContentHuggingPriority(.required, for: .horizontal)
        let dictionaryActionsButton = makeOverflowActionButton(
            accessibilityLabel: "Dictionary actions",
            action: #selector(showDictionaryCollectionActions(_:))
        )

        let termsHeader = NSStackView(views: [dictionarySearchField, termActionButton, dictionaryActionsButton])
        termsHeader.orientation = .horizontal
        termsHeader.alignment = .centerY
        termsHeader.spacing = 8
        termsHeader.distribution = .fill
        dictionarySearchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dictionarySearchField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        dictionarySearchField.widthAnchor.constraint(greaterThanOrEqualToConstant: SettingsLayoutMetrics.dictionarySearchMinWidth).isActive = true

        let termsRowsScrollView = makeDictionaryRowsScrollView(contentStack: dictionaryTermRowsStack)
        dictionaryTermsRowsScrollView = termsRowsScrollView
        let suggestionRowsScrollView = makeDictionaryRowsScrollView(contentStack: dictionarySuggestionRowsStack)
        dictionarySuggestionRowsScrollView = suggestionRowsScrollView

        let librarySubviewControlRow = makeLibrarySubviewControl(selectedSection: .dictionary)
        let dictionarySidebarHeader = makeDictionarySidebarHeader(searchToolbar: termsHeader)
        let collectionsCard = makeDictionaryCollectionsCard()
        let contentCard = makeDictionaryContentCard(
            termsRowsScrollView: termsRowsScrollView,
            suggestionRowsScrollView: suggestionRowsScrollView
        )
        let leftColumn = makeDictionarySidebarColumn(
            headerView: dictionarySidebarHeader,
            collectionsCard: collectionsCard
        )
        let libraryContentRow = makeDictionaryContentSection(
            left: leftColumn,
            right: contentCard
        )

        addPageSection(librarySubviewControlRow, to: contentStack)
        addPageSection(libraryContentRow, to: contentStack)
        addPageSection(makeFlexiblePageSpacer(), to: contentStack)

        dictionaryView.drawsBackground = false
        dictionaryView.borderType = .noBorder
        dictionaryView.hasVerticalScroller = true
        dictionaryView.hasHorizontalScroller = false
        dictionaryView.autohidesScrollers = true

        let dictionaryDocumentView = FlippedLayoutView()
        dictionaryDocumentView.translatesAutoresizingMaskIntoConstraints = false
        dictionaryView.documentView = dictionaryDocumentView
        dictionaryDocumentView.addSubview(contentStack)

        let clipView = dictionaryView.contentView
        NSLayoutConstraint.activate([
            dictionaryDocumentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            dictionaryDocumentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            dictionaryDocumentView.topAnchor.constraint(equalTo: clipView.topAnchor),
            dictionaryDocumentView.bottomAnchor.constraint(greaterThanOrEqualTo: clipView.bottomAnchor),
            dictionaryDocumentView.widthAnchor.constraint(equalTo: clipView.widthAnchor),

            contentStack.leadingAnchor.constraint(equalTo: dictionaryDocumentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: dictionaryDocumentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: dictionaryDocumentView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: dictionaryDocumentView.bottomAnchor)
        ])
    }

    func buildHistoryView() {
        let contentStack = makePageStack()

        historyUsageCardsStack.translatesAutoresizingMaskIntoConstraints = false
        historyUsageCardsStack.setContentHuggingPriority(.required, for: .vertical)
        historyUsageCardsStack.setContentCompressionResistancePriority(.required, for: .vertical)
        let historyUsageMetricMinimumHeight: CGFloat = 154
        historyUsageCardsStack.heightAnchor.constraint(equalToConstant: historyUsageMetricMinimumHeight).isActive = true
        configureHistoryUsageMetricCards()
        historyUsageDetailCard.translatesAutoresizingMaskIntoConstraints = false
        configureHistoryUsageDetailCard()

        historyRowsStack.orientation = .vertical
        historyRowsStack.spacing = 8
        historyRowsStack.alignment = .leading

        historySessionCountLabel.font = .systemFont(ofSize: 14, weight: .medium)
        historySessionCountLabel.textColor = .secondaryLabelColor
        historySessionCountLabel.alignment = .right

        historySearchField.placeholderString = SettingsWindowSupport.historySearchPlaceholderText
        historySearchField.target = self
        historySearchField.action = #selector(historySearchChanged(_:))
        historySearchField.sendsSearchStringImmediately = true
        historySearchField.sendsWholeSearchString = false

        historyDateFilterPopup.removeAllItems()
        historyDateFilterPopup.addItems(withTitles: HistoryListDateFilter.allCases.map(\.title))
        historyDateFilterPopup.target = self
        historyDateFilterPopup.action = #selector(historyDateFilterChanged(_:))
        historyDateFilterPopup.leadingSymbolName = "calendar.badge.clock"
        historyDateFilterPopup.selectItem(at: historyDateFilter.rawValue)

        historyPaginationStack.orientation = .horizontal
        historyPaginationStack.spacing = 6
        historyPaginationStack.alignment = .centerY

        let librarySubviewControlRow = makeLibrarySubviewControl(selectedSection: .history)
        addPageSection(librarySubviewControlRow, to: contentStack)
        addPageSection(makeHistoryOverviewCard(), to: contentStack)
        addPageSection(makeHistorySessionHeaderView(), to: contentStack)
        addPageSection(makeHistoryToolbarView(), to: contentStack)
        addPageSection(makeHistoryEntriesCard(), to: contentStack)
        addPageSection(makeHistoryPaginationView(), to: contentStack)
        addPageSection(makeFlexiblePageSpacer(), to: contentStack)

        historyView.drawsBackground = false
        historyView.borderType = .noBorder
        historyView.hasVerticalScroller = true
        historyView.hasHorizontalScroller = false
        historyView.autohidesScrollers = true

        let historyDocumentView = FlippedLayoutView()
        historyDocumentView.identifier = NSUserInterfaceItemIdentifier("history.document")
        historyDocumentView.translatesAutoresizingMaskIntoConstraints = false
        historyView.documentView = historyDocumentView
        historyDocumentView.addSubview(contentStack)
        historyDocumentContainerView = historyDocumentView

        let backgroundTap = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleHistoryBackgroundClick(_:))
        )
        backgroundTap.delaysPrimaryMouseButtonEvents = false
        historyDocumentView.addGestureRecognizer(backgroundTap)

        let clipView = historyView.contentView
        NSLayoutConstraint.activate([
            historyDocumentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            historyDocumentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            historyDocumentView.topAnchor.constraint(equalTo: clipView.topAnchor),
            historyDocumentView.bottomAnchor.constraint(greaterThanOrEqualTo: clipView.bottomAnchor),
            historyDocumentView.widthAnchor.constraint(equalTo: clipView.widthAnchor),

            contentStack.leadingAnchor.constraint(equalTo: historyDocumentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: historyDocumentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: historyDocumentView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: historyDocumentView.bottomAnchor)
        ])
    }

}
