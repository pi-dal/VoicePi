import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func presentExternalProcessorManagerSheet() {
        captureExternalProcessorManagerEdits()

        if externalProcessorManagerSheetWindow == nil {
            externalProcessorManagerState = ExternalProcessorManagerState(
                entries: model.externalProcessorEntries,
                selectedEntryID: model.selectedExternalProcessorEntryID ?? model.externalProcessorEntries.first?.id
            )
            if externalProcessorManagerState.selectedEntryID == nil {
                externalProcessorManagerState.selectedEntryID = externalProcessorManagerState.entries.first?.id
                model.setSelectedExternalProcessorEntryID(externalProcessorManagerState.selectedEntryID)
            }

            let sheetSize = NSSize(width: 860, height: 620)
            let sheet = PreviewSheetWindow(
                contentRect: NSRect(origin: .zero, size: sheetSize),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            sheet.title = Self.externalProcessorManagerSheetTitle
            sheet.setContentSize(sheetSize)
            sheet.minSize = sheetSize
            sheet.appearance = window?.effectiveAppearance ?? window?.appearance
            sheet.onCloseRequest = { [weak self] in
                self?.closeExternalProcessorManagerSheet()
            }

            externalProcessorManagerSheetWindow = sheet
            reloadExternalProcessorManagerSheet()
            if RuntimeEnvironment.isRunningTests {
                sheet.orderOut(nil)
            } else {
                window?.beginSheet(sheet)
                sheet.makeKeyAndOrderFront(nil)
            }
        } else {
            reloadExternalProcessorManagerSheet()
            if RuntimeEnvironment.isRunningTests {
                externalProcessorManagerSheetWindow?.orderOut(nil)
            } else {
                externalProcessorManagerSheetWindow?.makeKeyAndOrderFront(nil)
            }
        }
    }

    func reloadExternalProcessorManagerSheet() {
        guard let sheet = externalProcessorManagerSheetWindow else { return }
        sheet.contentView = makeExternalProcessorManagerSheetContent(sheet: sheet)

        if let selectedPopup = externalProcessorManagerSelectedEntryPopup,
           selectedPopup.numberOfItems > 0 {
            sheet.initialFirstResponder = selectedPopup
            sheet.makeFirstResponder(selectedPopup)
        }
    }

    @objc
    func closeExternalProcessorManagerSheet() {
        captureExternalProcessorManagerEdits()
        persistExternalProcessorManagerState()

        externalProcessorManagerState = ExternalProcessorManagerState(
            entries: model.externalProcessorEntries,
            selectedEntryID: model.selectedExternalProcessorEntryID
        )

        externalProcessorManagerSelectedEntryPopup = nil
        externalProcessorManagerFeedbackLabel = nil
        externalProcessorManagerEntriesContainer = nil
        externalProcessorManagerNameFields = [:]
        externalProcessorManagerKindPopups = [:]
        externalProcessorManagerExecutablePathFields = [:]
        externalProcessorManagerEnabledSwitches = [:]
        externalProcessorManagerArgumentFields = [:]

        if let sheet = externalProcessorManagerSheetWindow, window?.attachedSheet == sheet {
            window?.endSheet(sheet)
        }
        externalProcessorManagerSheetWindow?.orderOut(nil)
        externalProcessorManagerSheetWindow = nil
    }

    func reloadExternalProcessorManagerSheetContent() {
        reloadExternalProcessorManagerSheet()
        refreshLLMSection()
    }

    func captureExternalProcessorManagerEdits() {
        guard externalProcessorManagerSheetWindow != nil else { return }

        externalProcessorManagerSheetWindow?.makeFirstResponder(nil)

        var updatedEntries: [ExternalProcessorEntry] = []
        updatedEntries.reserveCapacity(externalProcessorManagerState.entries.count)

        for entry in externalProcessorManagerState.entries {
            var updatedEntry = entry

            if let field = externalProcessorManagerNameFields[entry.id] {
                updatedEntry.name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let popup = externalProcessorManagerKindPopups[entry.id] {
                let index = max(0, popup.indexOfSelectedItem)
                updatedEntry.kind = ExternalProcessorKind.allCases[min(index, ExternalProcessorKind.allCases.count - 1)]
            }

            if let field = externalProcessorManagerExecutablePathFields[entry.id] {
                updatedEntry.executablePath = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let toggle = externalProcessorManagerEnabledSwitches[entry.id] {
                updatedEntry.isEnabled = toggle.state == .on
            }

            if let argumentFields = externalProcessorManagerArgumentFields[entry.id] {
                updatedEntry.additionalArguments = entry.additionalArguments.map { argument in
                    ExternalProcessorArgument(
                        id: argument.id,
                        value: argumentFields[argument.id]?.stringValue ?? argument.value
                    )
                }
            }

            updatedEntries.append(updatedEntry)
        }

        externalProcessorManagerState.entries = updatedEntries
        externalProcessorManagerState.selectedEntryID = selectedEntryIDFromPopup(externalProcessorManagerSelectedEntryPopup)
            ?? externalProcessorManagerState.selectedEntryID
    }

    func persistExternalProcessorManagerState() {
        model.setExternalProcessorEntries(externalProcessorManagerState.entries)
        model.setSelectedExternalProcessorEntryID(externalProcessorManagerState.selectedEntryID)
        externalProcessorManagerFeedbackLabel?.stringValue = externalProcessorManagerFeedbackText()
        refreshHomeSection()
        refreshLLMSection()
    }

    func makeExternalProcessorManagerSheetContent(sheet: PreviewSheetWindow) -> NSView {
        let sheetSize = NSSize(width: 860, height: 620)
        externalProcessorManagerNameFields = [:]
        externalProcessorManagerKindPopups = [:]
        externalProcessorManagerExecutablePathFields = [:]
        externalProcessorManagerEnabledSwitches = [:]
        externalProcessorManagerArgumentFields = [:]

        let addProcessorButton = StyledSettingsButton(
            title: Self.externalProcessorManagerAddProcessorButtonTitle,
            role: .secondary,
            target: self,
            action: #selector(addExternalProcessorEntry)
        )
        addProcessorButton.translatesAutoresizingMaskIntoConstraints = false
        addProcessorButton.widthAnchor.constraint(equalToConstant: 34).isActive = true

        let doneButton = makePrimaryActionButton(title: "Done", action: #selector(closeExternalProcessorManagerSheet))
        let footerButton = makeSecondaryActionButton(title: "Close", action: #selector(closeExternalProcessorManagerSheet))
        footerButton.translatesAutoresizingMaskIntoConstraints = false
        footerButton.keyEquivalent = "\u{1b}"

        let footerRow = NSStackView(views: [NSView(), footerButton])
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY
        footerRow.spacing = 8
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        if externalProcessorManagerState.entries.isEmpty {
            externalProcessorManagerSelectedEntryPopup = nil
            externalProcessorManagerFeedbackLabel = nil
            externalProcessorManagerEntriesContainer = nil

            let emptyStateCard = makeExternalProcessorManagerEmptyStateCard(addButton: addProcessorButton, doneButton: doneButton)
            contentStack.addArrangedSubview(emptyStateCard)
            emptyStateCard.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        } else {
            let selectedPopup = ThemedPopUpButton()
            selectedPopup.target = self
            selectedPopup.action = #selector(externalProcessorManagerSelectedEntryChanged(_:))
            selectedPopup.translatesAutoresizingMaskIntoConstraints = false
            selectedPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
            selectedPopup.removeAllItems()

            for entry in externalProcessorManagerState.entries {
                selectedPopup.addItem(withTitle: externalProcessorManagerDisplayTitle(for: entry))
                selectedPopup.lastItem?.representedObject = entry.id.uuidString
            }

            if let selectedID = externalProcessorManagerState.selectedEntryID {
                let index = selectedPopup.indexOfItem(withRepresentedObject: selectedID.uuidString)
                if index >= 0 {
                    selectedPopup.selectItem(at: index)
                } else {
                    selectedPopup.selectItem(at: 0)
                    externalProcessorManagerState.selectedEntryID = selectedEntryIDFromPopup(selectedPopup)
                }
            } else {
                selectedPopup.selectItem(at: 0)
                externalProcessorManagerState.selectedEntryID = selectedEntryIDFromPopup(selectedPopup)
            }

            let introLabel = makeBodyLabel(
                "Manage external CLI processor profiles here, then choose which one VoicePi should use during review-panel refinement."
            )
            let feedbackLabel = NSTextField(labelWithString: externalProcessorManagerFeedbackText())
            feedbackLabel.font = .systemFont(ofSize: 12)
            feedbackLabel.textColor = .secondaryLabelColor
            feedbackLabel.lineBreakMode = .byWordWrapping
            feedbackLabel.maximumNumberOfLines = 0
            feedbackLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true

            let selectionRow = makePreferenceRow(title: "Active Processor", control: selectedPopup)
            let actionRow = makeButtonGroup([addProcessorButton, doneButton])
            let controlsRow = NSStackView(views: [selectionRow, actionRow])
            controlsRow.orientation = .horizontal
            controlsRow.alignment = .centerY
            controlsRow.spacing = 16
            controlsRow.distribution = .fill
            selectionRow.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            selectionRow.setContentHuggingPriority(.defaultLow, for: .horizontal)
            actionRow.setContentCompressionResistancePriority(.required, for: .horizontal)
            actionRow.setContentHuggingPriority(.required, for: .horizontal)

            let controlsStack = NSStackView(views: [introLabel, controlsRow, feedbackLabel])
            controlsStack.orientation = .vertical
            controlsStack.alignment = .leading
            controlsStack.spacing = 10
            introLabel.widthAnchor.constraint(equalTo: controlsStack.widthAnchor).isActive = true
            controlsRow.widthAnchor.constraint(equalTo: controlsStack.widthAnchor).isActive = true
            feedbackLabel.widthAnchor.constraint(equalTo: controlsStack.widthAnchor).isActive = true

            let controlsCard = makeCardView()
            pinCardContent(controlsStack, into: controlsCard)

            let entriesStack = NSStackView()
            entriesStack.orientation = .vertical
            entriesStack.spacing = 12
            entriesStack.alignment = .leading
            entriesStack.translatesAutoresizingMaskIntoConstraints = false
            externalProcessorManagerEntriesContainer = entriesStack

            for entry in externalProcessorManagerState.entries {
                let entryCard = makeExternalProcessorEntryCard(for: entry)
                entriesStack.addArrangedSubview(entryCard)
                entryCard.widthAnchor.constraint(equalTo: entriesStack.widthAnchor).isActive = true
            }

            let documentView = FlippedLayoutView()
            documentView.translatesAutoresizingMaskIntoConstraints = false
            documentView.addSubview(entriesStack)

            let scrollView = NSScrollView(frame: .zero)
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.drawsBackground = false
            scrollView.borderType = .noBorder
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            scrollView.documentView = documentView

            NSLayoutConstraint.activate([
                entriesStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
                entriesStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
                entriesStack.topAnchor.constraint(equalTo: documentView.topAnchor),
                entriesStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
                entriesStack.widthAnchor.constraint(equalTo: documentView.widthAnchor),
                documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
            ])

            contentStack.addArrangedSubview(controlsCard)
            contentStack.addArrangedSubview(scrollView)
            controlsCard.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
            scrollView.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
            scrollView.heightAnchor.constraint(equalToConstant: 392).isActive = true
            externalProcessorManagerSelectedEntryPopup = selectedPopup
            externalProcessorManagerFeedbackLabel = feedbackLabel
        }

        contentStack.addArrangedSubview(footerRow)
        footerRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        let contentView = NSView()
        contentView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: sheetSize.width),
            contentView.heightAnchor.constraint(equalToConstant: sheetSize.height),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SettingsLayoutMetrics.promptEditorOuterInset),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SettingsLayoutMetrics.promptEditorOuterInset),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SettingsLayoutMetrics.promptEditorOuterInset),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SettingsLayoutMetrics.promptEditorOuterInset)
        ])
        return contentView
    }

    func makeExternalProcessorManagerEmptyStateCard(addButton: NSButton, doneButton: NSButton) -> NSView {
        let card = makeCardView()
        let stack = NSStackView(views: [
            makeSectionTitle("No processors yet"),
            makeBodyLabel(Self.externalProcessorManagerEmptyStateText),
            makeBodyLabel("Add one now, then choose it as the active processor when you want VoicePi to hand transcript refinement to an external CLI."),
            makeButtonGroup([addButton, doneButton])
        ])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        if let actionsRow = stack.arrangedSubviews.last {
            actionsRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        pinCardContent(stack, into: card)
        return card
    }

    func makeExternalProcessorEntryCard(for entry: ExternalProcessorEntry) -> NSView {
        let card = makeCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 252).isActive = true

        let titleLabel = NSTextField(labelWithString: externalProcessorManagerDisplayTitle(for: entry))
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor

        let titleSubtitleLabel = makeSubtleCaption(entry.kind.title)
        titleSubtitleLabel.maximumNumberOfLines = 1

        let titleStack = NSStackView(views: [titleLabel, titleSubtitleLabel])
        titleStack.orientation = .vertical
        titleStack.spacing = 3
        titleStack.alignment = .leading

        let testButton = makeSecondaryActionButton(title: "Test", action: #selector(testExternalProcessorEntry(_:)))
        testButton.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)

        let removeButton = makeSecondaryActionButton(title: "Remove", action: #selector(removeExternalProcessorEntry(_:)))
        removeButton.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)

        let headerRow = NSStackView(views: [titleStack, NSView(), testButton, removeButton])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8

        let nameField = NSTextField(string: entry.name)
        nameField.placeholderString = "Processor name"
        nameField.target = self
        nameField.action = #selector(externalProcessorNameChanged(_:))
        nameField.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)
        externalProcessorManagerNameFields[entry.id] = nameField

        let kindPopup = ThemedPopUpButton()
        kindPopup.addItems(withTitles: ExternalProcessorKind.allCases.map(\.title))
        kindPopup.target = self
        kindPopup.action = #selector(externalProcessorKindChanged(_:))
        kindPopup.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)
        if let index = ExternalProcessorKind.allCases.firstIndex(of: entry.kind) {
            kindPopup.selectItem(at: index)
        }
        externalProcessorManagerKindPopups[entry.id] = kindPopup

        let executablePathField = NSTextField(string: entry.executablePath)
        executablePathField.placeholderString = "alma"
        executablePathField.target = self
        executablePathField.action = #selector(externalProcessorExecutablePathChanged(_:))
        executablePathField.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)
        externalProcessorManagerExecutablePathFields[entry.id] = executablePathField

        let enabledSwitch = NSSwitch()
        enabledSwitch.state = entry.isEnabled ? .on : .off
        enabledSwitch.target = self
        enabledSwitch.action = #selector(externalProcessorEnabledChanged(_:))
        enabledSwitch.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)
        externalProcessorManagerEnabledSwitches[entry.id] = enabledSwitch

        let nameRow = makePreferenceRow(title: "Name", control: nameField)
        let kindRow = makePreferenceRow(title: "Kind", control: kindPopup)
        let pathRow = makePreferenceRow(title: "Executable", control: executablePathField)
        let enabledRow = makePreferenceRow(title: "Enabled", control: enabledSwitch)

        let commandPreviewTitle = makeSubtleCaption("Command Preview")
        commandPreviewTitle.maximumNumberOfLines = 1

        let commandPreviewLabel = makeProcessorCommandLabel(
            SettingsWindowSupport.externalProcessorCommandPreview(for: entry),
            maximumNumberOfLines: 1
        )
        commandPreviewLabel.toolTip = SettingsWindowSupport.externalProcessorCommandPreview(for: entry)

        let commandPreviewSurface = ThemedSurfaceView(style: .row)
        pinCardContent(
            commandPreviewLabel,
            into: commandPreviewSurface,
            horizontalPadding: 12,
            verticalPadding: 10
        )

        let commandPreviewStack = NSStackView(views: [commandPreviewTitle, commandPreviewSurface])
        commandPreviewStack.orientation = .vertical
        commandPreviewStack.alignment = .leading
        commandPreviewStack.spacing = 6

        let argumentsTitle = NSTextField(labelWithString: "Arguments")
        argumentsTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        argumentsTitle.textColor = .labelColor

        let addArgumentButton = StyledSettingsButton(
            title: Self.externalProcessorManagerAddArgumentButtonTitle,
            role: .secondary,
            target: self,
            action: #selector(addExternalProcessorArgument(_:))
        )
        addArgumentButton.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)
        addArgumentButton.widthAnchor.constraint(equalToConstant: 34).isActive = true

        let argumentsHeaderRow = NSStackView(views: [argumentsTitle, NSView(), addArgumentButton])
        argumentsHeaderRow.orientation = .horizontal
        argumentsHeaderRow.alignment = .centerY
        argumentsHeaderRow.spacing = 8

        let argumentStack = NSStackView()
        argumentStack.orientation = .vertical
        argumentStack.alignment = .leading
        argumentStack.spacing = 8
        argumentStack.translatesAutoresizingMaskIntoConstraints = false

        var argumentFields: [UUID: NSTextField] = [:]
        if entry.additionalArguments.isEmpty {
            let placeholder = makeBodyLabel("No additional arguments yet. Use + to add a row.")
            placeholder.textColor = .secondaryLabelColor
            argumentStack.addArrangedSubview(placeholder)
            placeholder.widthAnchor.constraint(equalTo: argumentStack.widthAnchor).isActive = true
        } else {
            for argument in entry.additionalArguments {
                let row = makeExternalProcessorArgumentRow(entryID: entry.id, argument: argument, argumentFields: &argumentFields)
                argumentStack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: argumentStack.widthAnchor).isActive = true
            }
        }
        externalProcessorManagerArgumentFields[entry.id] = argumentFields

        let entryStack = NSStackView(views: [
            headerRow,
            nameRow,
            kindRow,
            pathRow,
            enabledRow,
            commandPreviewStack,
            argumentsHeaderRow,
            argumentStack
        ])
        entryStack.orientation = .vertical
        entryStack.spacing = 10
        entryStack.alignment = .leading
        [headerRow, nameRow, kindRow, pathRow, enabledRow, commandPreviewStack, argumentsHeaderRow, argumentStack].forEach { row in
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: entryStack.widthAnchor).isActive = true
        }
        commandPreviewSurface.widthAnchor.constraint(equalTo: commandPreviewStack.widthAnchor).isActive = true
        pinCardContent(entryStack, into: card)
        return card
    }

    func makeExternalProcessorArgumentRow(
        entryID: UUID,
        argument: ExternalProcessorArgument,
        argumentFields: inout [UUID: NSTextField]
    ) -> NSView {
        let argumentField = NSTextField(string: argument.value)
        argumentField.placeholderString = "Argument"
        argumentField.target = self
        argumentField.action = #selector(externalProcessorArgumentChanged(_:))
        argumentField.identifier = NSUserInterfaceItemIdentifier("\(entryID.uuidString)|\(argument.id.uuidString)")
        argumentFields[argument.id] = argumentField

        let removeButton = makeSecondaryActionButton(title: "−", action: #selector(removeExternalProcessorArgument(_:)))
        removeButton.identifier = NSUserInterfaceItemIdentifier("\(entryID.uuidString)|\(argument.id.uuidString)")
        removeButton.widthAnchor.constraint(equalToConstant: 34).isActive = true

        let row = NSStackView(views: [argumentField, removeButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        argumentField.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        return row
    }

    func externalProcessorManagerDisplayTitle(for entry: ExternalProcessorEntry) -> String {
        ExternalProcessorManagerPresentation.displayTitle(for: entry)
    }

    func selectedEntryIDFromPopup(_ popup: NSPopUpButton?) -> UUID? {
        guard let rawValue = popup?.selectedItem?.representedObject as? String else { return nil }
        return UUID(uuidString: rawValue)
    }

    func externalProcessorManagerFeedbackText() -> String {
        ExternalProcessorManagerPresentation.feedbackText(for: externalProcessorManagerState)
    }

    @objc
    func externalProcessorManagerSelectedEntryChanged(_ sender: NSPopUpButton) {
        captureExternalProcessorManagerEdits()
        externalProcessorManagerState.selectedEntryID = selectedEntryIDFromPopup(sender)
        persistExternalProcessorManagerState()
    }

    @objc
    func addExternalProcessorEntry() {
        captureExternalProcessorManagerEdits()
        externalProcessorManagerState = ExternalProcessorManagerActions.addEntry(to: externalProcessorManagerState)
        persistExternalProcessorManagerState()
        reloadExternalProcessorManagerSheetContent()
    }

    @objc
    func addExternalProcessorArgument(_ sender: NSButton) {
        captureExternalProcessorManagerEdits()
        guard let entryID = sender.identifier.flatMap({ UUID(uuidString: $0.rawValue) }) else { return }
        externalProcessorManagerState = ExternalProcessorManagerActions.addArgument(to: entryID, state: externalProcessorManagerState)
        persistExternalProcessorManagerState()
        reloadExternalProcessorManagerSheetContent()
    }

    @objc
    func removeExternalProcessorEntry(_ sender: NSButton) {
        captureExternalProcessorManagerEdits()
        guard let entryID = sender.identifier.flatMap({ UUID(uuidString: $0.rawValue) }) else { return }
        externalProcessorManagerState = ExternalProcessorManagerActions.removeEntry(entryID, from: externalProcessorManagerState)
        persistExternalProcessorManagerState()
        reloadExternalProcessorManagerSheetContent()
    }

    @objc
    func removeExternalProcessorArgument(_ sender: NSButton) {
        captureExternalProcessorManagerEdits()
        guard
            let rawValue = sender.identifier?.rawValue,
            let (entryID, argumentID) = externalProcessorArgumentIDs(from: rawValue)
        else {
            return
        }

        guard let entryIndex = externalProcessorManagerState.entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        externalProcessorManagerState.entries[entryIndex].additionalArguments.removeAll { $0.id == argumentID }
        persistExternalProcessorManagerState()
        reloadExternalProcessorManagerSheetContent()
    }

    @objc
    func externalProcessorNameChanged(_ sender: NSTextField) {
        captureExternalProcessorManagerEdits()
        persistExternalProcessorManagerState()
    }

    @objc
    func externalProcessorExecutablePathChanged(_ sender: NSTextField) {
        captureExternalProcessorManagerEdits()
        persistExternalProcessorManagerState()
    }

    @objc
    func externalProcessorKindChanged(_ sender: NSPopUpButton) {
        captureExternalProcessorManagerEdits()
        persistExternalProcessorManagerState()
    }

    @objc
    func externalProcessorEnabledChanged(_ sender: NSSwitch) {
        captureExternalProcessorManagerEdits()
        persistExternalProcessorManagerState()
    }

    @objc
    func externalProcessorArgumentChanged(_ sender: NSTextField) {
        captureExternalProcessorManagerEdits()
        persistExternalProcessorManagerState()
    }

    @objc
    func testExternalProcessorEntry(_ sender: NSButton) {
        captureExternalProcessorManagerEdits()

        guard
            let rawValue = sender.identifier?.rawValue,
            let entryID = UUID(uuidString: rawValue),
            let entry = externalProcessorManagerState.entries.first(where: { $0.id == entryID })
        else {
            return
        }

        runExternalProcessorTest(for: entry) { [weak self] message in
            self?.externalProcessorManagerFeedbackLabel?.stringValue = message
            self?.externalProcessorsStatusLabel.stringValue = message
        }
    }

    func externalProcessorArgumentIDs(from rawValue: String) -> (UUID, UUID)? {
        let parts = rawValue.split(separator: "|", omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        guard let entryID = UUID(uuidString: String(parts[0])),
              let argumentID = UUID(uuidString: String(parts[1])) else {
            return nil
        }
        return (entryID, argumentID)
    }

}
