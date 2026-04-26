import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    func presentPromptEditorSheet(for preset: PromptPreset) {
        guard preset.source == .user else { return }

        promptEditorDraft = preset

        let sheetSize = NSSize(width: 760, height: 664)
        let sheet = PreviewSheetWindow(
            contentRect: NSRect(origin: .zero, size: sheetSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        sheet.title = Self.promptEditorSheetTitle(for: preset)
        sheet.setContentSize(sheetSize)
        sheet.minSize = sheetSize
        sheet.appearance = window?.effectiveAppearance ?? window?.appearance
        sheet.onCloseRequest = { [weak self] in
            self?.cancelPromptEditorSheet()
        }

        let nameLabel = NSTextField(labelWithString: "Prompt Name")
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor = .secondaryLabelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameField = NSTextField(string: preset.resolvedTitle)
        nameField.placeholderString = "Short name, for example Meeting Notes"
        nameField.font = .systemFont(ofSize: 14, weight: .medium)
        nameField.controlSize = .large
        nameField.translatesAutoresizingMaskIntoConstraints = false

        let bindingsTitleLabel = NSTextField(labelWithString: "Automatic Bindings")
        bindingsTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bindingsTitleLabel.textColor = .labelColor
        bindingsTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bindingsSubtitleLabel = NSTextField(
            wrappingLabelWithString: "Use captures to target this prompt to the frontmost app or current site. Matching bindings override the selected Active Prompt automatically."
        )
        bindingsSubtitleLabel.font = .systemFont(ofSize: 12)
        bindingsSubtitleLabel.textColor = .secondaryLabelColor
        bindingsSubtitleLabel.maximumNumberOfLines = 0
        bindingsSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let captureFrontmostAppButton = makeSecondaryActionButton(
            title: Self.captureFrontmostAppButtonTitle,
            action: #selector(captureFrontmostAppBinding)
        )
        captureFrontmostAppButton.translatesAutoresizingMaskIntoConstraints = false

        let captureCurrentWebsiteButton = makeSecondaryActionButton(
            title: Self.captureCurrentWebsiteButtonTitle,
            action: #selector(captureCurrentWebsiteBinding)
        )
        captureCurrentWebsiteButton.translatesAutoresizingMaskIntoConstraints = false

        let bindingActionButtons = NSStackView(views: [captureFrontmostAppButton, captureCurrentWebsiteButton])
        bindingActionButtons.orientation = .vertical
        bindingActionButtons.alignment = .leading
        bindingActionButtons.distribution = .fill
        bindingActionButtons.spacing = 8
        bindingActionButtons.translatesAutoresizingMaskIntoConstraints = false

        let bindingStatusLabel = NSTextField(labelWithString: "")
        bindingStatusLabel.font = .systemFont(ofSize: 12)
        bindingStatusLabel.textColor = .secondaryLabelColor
        bindingStatusLabel.lineBreakMode = .byWordWrapping
        bindingStatusLabel.maximumNumberOfLines = 0
        bindingStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        let appBindingsLabel = NSTextField(labelWithString: "App Bundle IDs")
        appBindingsLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        appBindingsLabel.textColor = .secondaryLabelColor
        appBindingsLabel.translatesAutoresizingMaskIntoConstraints = false

        let appBindingsField = NSTextField(string: preset.appBundleIDs.joined(separator: ", "))
        appBindingsField.placeholderString = "com.tinyspeck.slackmacgap, com.figma.Desktop"
        appBindingsField.translatesAutoresizingMaskIntoConstraints = false

        let websiteBindingsLabel = NSTextField(labelWithString: "Website Hosts")
        websiteBindingsLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        websiteBindingsLabel.textColor = .secondaryLabelColor
        websiteBindingsLabel.translatesAutoresizingMaskIntoConstraints = false

        let websiteBindingsField = NSTextField(string: preset.websiteHosts.joined(separator: ", "))
        websiteBindingsField.placeholderString = "mail.google.com, trello.com, *.notion.so"
        websiteBindingsField.translatesAutoresizingMaskIntoConstraints = false

        let bindingsHintLabel = NSTextField(
            wrappingLabelWithString: "You can type comma-separated bundle IDs or hosts manually if capture is not enough."
        )
        bindingsHintLabel.font = .systemFont(ofSize: 12)
        bindingsHintLabel.textColor = .secondaryLabelColor
        bindingsHintLabel.maximumNumberOfLines = 0
        bindingsHintLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = NSTextField(labelWithString: "Instructions")
        bodyLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bodyLabel.textColor = .labelColor
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyHintLabel = NSTextField(
            wrappingLabelWithString: Self.promptEditorBodyHintText
        )
        bodyHintLabel.font = .systemFont(ofSize: 12)
        bodyHintLabel.textColor = .secondaryLabelColor
        bodyHintLabel.maximumNumberOfLines = 0
        bodyHintLabel.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView(frame: .zero)
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.font = Self.promptEditorBodyFont
        textView.textContainerInset = Self.promptEditorBodyTextInset
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.autoresizingMask = .width
        let bodyPalette = Self.promptEditorBodyPalette(for: sheet.appearance)
        textView.textColor = bodyPalette.text
        textView.backgroundColor = bodyPalette.background
        textView.insertionPointColor = bodyPalette.insertionPoint
        textView.typingAttributes = [
            .font: textView.font ?? Self.promptEditorBodyFont,
            .foregroundColor: bodyPalette.text
        ]
        textView.string = preset.body

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        let bodyContainerChrome = Self.promptEditorBodyContainerChrome(for: sheet.appearance)
        let bodyContainer = NSView()
        bodyContainer.translatesAutoresizingMaskIntoConstraints = false
        bodyContainer.wantsLayer = true
        bodyContainer.layer?.cornerRadius = bodyContainerChrome.cornerRadius
        bodyContainer.layer?.borderWidth = 1
        bodyContainer.layer?.borderColor = bodyContainerChrome.border.cgColor
        bodyContainer.layer?.backgroundColor = bodyContainerChrome.background.cgColor
        bodyContainer.addSubview(scrollView)

        let cancelButton = makeSecondaryActionButton(
            title: "Cancel",
            action: #selector(cancelPromptEditorSheet)
        )
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.keyEquivalent = "\u{1b}"

        let saveButton = makePrimaryActionButton(
            title: Self.promptEditorPrimaryActionTitle(for: preset),
            action: #selector(savePromptEditorSheet)
        )
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.keyEquivalent = "\r"
        saveButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 118).isActive = true
        cancelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 94).isActive = true

        let buttonRow = NSStackView(views: [NSView(), cancelButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let nameStack = NSStackView(views: [nameLabel, nameField])
        nameStack.orientation = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = SettingsLayoutMetrics.promptEditorFieldSpacing
        nameField.widthAnchor.constraint(equalTo: nameStack.widthAnchor).isActive = true

        let bindingsStack = NSStackView(views: [
            bindingsTitleLabel,
            bindingsSubtitleLabel,
            bindingActionButtons,
            bindingStatusLabel,
            appBindingsLabel,
            appBindingsField,
            websiteBindingsLabel,
            websiteBindingsField,
            bindingsHintLabel
        ])
        bindingsStack.orientation = .vertical
        bindingsStack.alignment = .leading
        bindingsStack.spacing = SettingsLayoutMetrics.promptEditorFieldSpacing
        bindingsStack.setCustomSpacing(SettingsLayoutMetrics.promptEditorSectionSpacing, after: bindingsSubtitleLabel)
        bindingsStack.setCustomSpacing(SettingsLayoutMetrics.promptEditorSectionSpacing, after: bindingStatusLabel)
        bindingsStack.setCustomSpacing(SettingsLayoutMetrics.promptEditorSectionSpacing, after: appBindingsField)
        bindingsStack.setCustomSpacing(SettingsLayoutMetrics.promptEditorSectionSpacing, after: websiteBindingsField)
        bindingActionButtons.widthAnchor.constraint(equalTo: bindingsStack.widthAnchor).isActive = true
        bindingStatusLabel.widthAnchor.constraint(equalTo: bindingsStack.widthAnchor).isActive = true
        appBindingsField.widthAnchor.constraint(equalTo: bindingsStack.widthAnchor).isActive = true
        websiteBindingsField.widthAnchor.constraint(equalTo: bindingsStack.widthAnchor).isActive = true
        bindingsHintLabel.widthAnchor.constraint(equalTo: bindingsStack.widthAnchor).isActive = true

        let bindingsCard = makeCardView()
        pinCardContent(bindingsStack, into: bindingsCard)
        bindingsCard.translatesAutoresizingMaskIntoConstraints = false
        bindingsCard.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.promptEditorSidebarWidth).isActive = true

        let bodyStack = NSStackView(views: [bodyLabel, bodyHintLabel, bodyContainer])
        bodyStack.orientation = .vertical
        bodyStack.alignment = .leading
        bodyStack.spacing = SettingsLayoutMetrics.promptEditorFieldSpacing
        bodyContainer.widthAnchor.constraint(equalTo: bodyStack.widthAnchor).isActive = true
        bodyHintLabel.widthAnchor.constraint(equalTo: bodyStack.widthAnchor).isActive = true

        let bodyCard = makeCardView()
        pinCardContent(bodyStack, into: bodyCard)
        bodyCard.translatesAutoresizingMaskIntoConstraints = false

        let contentSplit = NSStackView(views: [bindingsCard, bodyCard])
        contentSplit.orientation = .horizontal
        contentSplit.alignment = .top
        contentSplit.distribution = .fill
        contentSplit.spacing = SettingsLayoutMetrics.promptEditorSectionSpacing
        contentSplit.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView(views: [nameStack, contentSplit])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = SettingsLayoutMetrics.promptEditorSectionSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        nameStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        contentSplit.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        bodyCard.widthAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true

        let contentView = NSView()
        contentView.addSubview(contentStack)
        contentView.addSubview(buttonRow)
        sheet.contentView = contentView

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: sheetSize.width),
            contentView.heightAnchor.constraint(equalToConstant: sheetSize.height),

            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SettingsLayoutMetrics.promptEditorOuterInset),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SettingsLayoutMetrics.promptEditorOuterInset),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SettingsLayoutMetrics.promptEditorOuterInset),
            contentStack.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -SettingsLayoutMetrics.promptEditorSectionSpacing),

            bodyContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsLayoutMetrics.promptEditorBodyMinHeight),

            scrollView.leadingAnchor.constraint(equalTo: bodyContainer.leadingAnchor, constant: 1),
            scrollView.trailingAnchor.constraint(equalTo: bodyContainer.trailingAnchor, constant: -1),
            scrollView.topAnchor.constraint(equalTo: bodyContainer.topAnchor, constant: 1),
            scrollView.bottomAnchor.constraint(equalTo: bodyContainer.bottomAnchor, constant: -1),

            buttonRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SettingsLayoutMetrics.promptEditorOuterInset),
            buttonRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SettingsLayoutMetrics.promptEditorOuterInset),
            buttonRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SettingsLayoutMetrics.promptEditorOuterInset)
        ])

        promptEditorNameField = nameField
        promptEditorAppBindingsField = appBindingsField
        promptEditorWebsiteHostsField = websiteBindingsField
        promptEditorBindingStatusLabel = bindingStatusLabel
        promptEditorBodyTextView = textView
        promptEditorSheetWindow = sheet

        if let attachedSheet = window?.attachedSheet {
            window?.endSheet(attachedSheet)
        }
        if RuntimeEnvironment.isRunningTests {
            sheet.orderOut(nil)
            sheet.initialFirstResponder = textView
            sheet.makeFirstResponder(textView)
            return
        }
        window?.beginSheet(sheet)
        sheet.initialFirstResponder = textView
        sheet.makeFirstResponder(textView)
    }

    @objc
    func savePromptEditorSheet() {
        guard var draft = promptEditorDraft else {
            closePromptEditorSheet()
            return
        }

        let title = promptEditorNameField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = promptEditorBodyTextView?.string ?? draft.body
        let appBundleIDs = promptBindingValues(from: promptEditorAppBindingsField?.stringValue ?? "")
        let websiteHosts = promptBindingValues(from: promptEditorWebsiteHostsField?.stringValue ?? "")
        draft = PromptPreset(
            id: draft.id,
            title: title.isEmpty ? "Untitled Prompt" : title,
            body: body,
            source: draft.source,
            appBundleIDs: appBundleIDs,
            websiteHosts: websiteHosts
        )

        let conflicts = promptWorkspaceDraft.appBindingConflicts(for: draft)
        if !conflicts.isEmpty {
            guard confirmPromptEditorAppBindingReassignment(
                conflicts: conflicts,
                destinationPromptTitle: draft.resolvedTitle
            ) else {
                return
            }
        }

        guard Self.persistPromptEditorSaveResult(
            model: model,
            promptWorkspaceDraft: &promptWorkspaceDraft,
            savedPreset: draft,
            confirmedConflictReassignment: !conflicts.isEmpty
        ) else {
            return
        }

        reloadPromptPopupItems()
        selectPromptWorkspaceItem(in: activePromptPopup, for: promptWorkspaceDraft.activeSelection)
        updatePromptEditorState()
        closePromptEditorSheet()
    }

    func confirmPromptEditorAppBindingReassignment(
        conflicts: [PromptAppBindingConflict],
        destinationPromptTitle: String
    ) -> Bool {
        let copy = Self.promptAppBindingConflictAlertContent(
            for: conflicts,
            destinationPromptTitle: destinationPromptTitle
        )
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = copy.messageText
        alert.informativeText = copy.informativeText
        alert.addButton(withTitle: "Reassign and Save")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc
    func cancelPromptEditorSheet() {
        closePromptEditorSheet()
    }

    @objc
    func captureFrontmostAppBinding() {
        let destination = promptDestinationInspector.currentDestinationContext()
        applyCapturedPromptBinding(
            kind: .appBundleID,
            capturedRawValue: destination.appBundleID,
            field: promptEditorAppBindingsField,
            unavailableMessage: "Couldn't capture a frontmost app bundle ID. Bring the target app to the front and try again."
        )
    }

    @objc
    func captureCurrentWebsiteBinding() {
        let destination = promptDestinationInspector.currentDestinationContext()
        applyCapturedPromptBinding(
            kind: .websiteHost,
            capturedRawValue: destination.websiteHost,
            field: promptEditorWebsiteHostsField,
            unavailableMessage: "Couldn't capture a website host from the frontmost browser tab. Make sure Safari or a supported Chromium browser is frontmost."
        )
    }

    func closePromptEditorSheet() {
        promptEditorDraft = nil
        promptEditorNameField = nil
        promptEditorAppBindingsField = nil
        promptEditorWebsiteHostsField = nil
        promptEditorBindingStatusLabel = nil
        promptEditorBodyTextView = nil
        if let sheet = promptEditorSheetWindow, window?.attachedSheet == sheet {
            window?.endSheet(sheet)
        }
        promptEditorSheetWindow?.orderOut(nil)
        promptEditorSheetWindow = nil
    }

}
