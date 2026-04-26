import AppKit
import Foundation
import UniformTypeIdentifiers

extension SettingsWindowController {
    @objc
    func historyDateFilterChanged(_ sender: NSPopUpButton) {
        guard
            sender.indexOfSelectedItem >= 0,
            let selectedFilter = HistoryListDateFilter(rawValue: sender.indexOfSelectedItem)
        else {
            return
        }

        historyDateFilter = selectedFilter
        historyCurrentPage = 0
        rebuildHistoryRows()
    }

    @objc
    func showHistorySortMenu(_ sender: NSButton) {
        let menu = NSMenu()

        for sortOrder in HistoryListSortOrder.allCases {
            let item = NSMenuItem(
                title: sortOrder.title,
                action: #selector(selectHistorySortOrder(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.state = historySortOrder == sortOrder ? .on : .off
            item.representedObject = sortOrder.rawValue
            menu.addItem(item)
        }

        showMenu(menu, anchoredTo: sender)
    }

    @objc
    func selectHistorySortOrder(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? Int,
            let selectedSortOrder = HistoryListSortOrder(rawValue: rawValue)
        else {
            return
        }

        historySortOrder = selectedSortOrder
        historyCurrentPage = 0
        rebuildHistoryRows()
    }

    @objc
    func exportHistoryEntries(_ sender: NSButton) {
        let entries = currentFilteredHistoryEntries()
        guard !entries.isEmpty else { return }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "VoicePi-History.txt"
        savePanel.allowedContentTypes = [.plainText]

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        let exportedText = entries
            .map { entry in
                let presentation = SettingsWindowSupport.historyListRowPresentation(for: entry)
                return [
                    presentation.timestampText,
                    entry.text
                ].joined(separator: "\n")
            }
            .joined(separator: "\n\n---\n\n")

        do {
            try exportedText.write(to: destinationURL, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
        }
    }

    @objc
    func selectHistoryPage(_ sender: NSButton) {
        historyCurrentPage = sender.tag
        rebuildHistoryRows()
    }

    @objc
    func goToPreviousHistoryPage() {
        guard historyCurrentPage > 0 else { return }
        historyCurrentPage -= 1
        rebuildHistoryRows()
    }

    @objc
    func goToNextHistoryPage() {
        let totalEntries = currentFilteredHistoryEntries().count
        let totalPages = max(1, Int(ceil(Double(max(1, totalEntries)) / 6.0)))
        guard historyCurrentPage < totalPages - 1 else { return }
        historyCurrentPage += 1
        rebuildHistoryRows()
    }

    @objc
    func addDictionaryTermFromSettings() {
        guard let term = presentDictionaryTermEditor(
            title: "Add Dictionary Term",
            confirmTitle: "Add"
        ) else {
            return
        }

        model.addDictionaryTerm(canonical: term.canonical, aliases: term.aliases, tag: term.tag)
        dictionarySelectedCollection = term.tag.map(DictionaryCollectionSelection.tag) ?? .allTerms
        reloadFromModel()
    }

    @objc
    func exportDictionaryTermsAsPlainText() {
        copyStringToPasteboard(model.exportDictionaryAsPlainText())
    }

    @objc
    func exportDictionaryTermsAsJSON() {
        copyStringToPasteboard(model.exportDictionaryAsJSON())
    }

    @objc
    func showDictionaryCollectionActions(_ sender: NSButton) {
        let menu = NSMenu()

        let importTextItem = NSMenuItem(
            title: "Import Text",
            action: #selector(importDictionaryTermsFromMenu(_:)),
            keyEquivalent: ""
        )
        importTextItem.target = self
        menu.addItem(importTextItem)

        menu.addItem(.separator())

        let exportTextItem = NSMenuItem(
            title: "Export Text",
            action: #selector(exportDictionaryTermsFromMenuAsPlainText(_:)),
            keyEquivalent: ""
        )
        exportTextItem.target = self
        menu.addItem(exportTextItem)

        let exportJSONItem = NSMenuItem(
            title: "Export JSON",
            action: #selector(exportDictionaryTermsFromMenuAsJSON(_:)),
            keyEquivalent: ""
        )
        exportJSONItem.target = self
        menu.addItem(exportJSONItem)

        showMenu(menu, anchoredTo: sender)
    }

    @objc
    func importDictionaryTermsFromMenu(_ sender: NSMenuItem) {
        guard let importedText = presentDictionaryImportEditor(
            title: "Import Dictionary Terms",
            confirmTitle: "Import",
            informativeText: "One entry per line. Optional aliases: Canonical | alias one, alias two."
        ) else {
            return
        }

        model.importDictionaryTerms(fromPlainText: importedText)
        dictionarySelectedCollection = .allTerms
        reloadFromModel()
    }

    @objc
    func exportDictionaryTermsFromMenuAsPlainText(_ sender: NSMenuItem) {
        exportDictionaryTermsAsPlainText()
    }

    @objc
    func exportDictionaryTermsFromMenuAsJSON(_ sender: NSMenuItem) {
        exportDictionaryTermsAsJSON()
    }

    @objc
    func showDictionaryTermActions(_ sender: NSButton) {
        guard
            let id = dictionaryTermID(from: sender),
            let entry = model.dictionaryEntries.first(where: { $0.id == id })
        else {
            return
        }

        let menu = NSMenu()
        let identifier = id.uuidString

        let toggleTitle = entry.isEnabled ? "Disable" : "Enable"
        let toggleItem = NSMenuItem(
            title: toggleTitle,
            action: #selector(toggleDictionaryTermFromMenu(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.representedObject = identifier
        menu.addItem(toggleItem)

        let editItem = NSMenuItem(
            title: "Edit",
            action: #selector(editDictionaryTermFromMenu(_:)),
            keyEquivalent: ""
        )
        editItem.target = self
        editItem.representedObject = identifier
        menu.addItem(editItem)

        menu.addItem(.separator())

        let deleteItem = NSMenuItem(
            title: "Delete",
            action: #selector(deleteDictionaryTermFromMenu(_:)),
            keyEquivalent: ""
        )
        deleteItem.target = self
        deleteItem.representedObject = identifier
        menu.addItem(deleteItem)

        showMenu(menu, anchoredTo: sender)
    }

    @objc
    func toggleDictionaryTermFromMenu(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        toggleDictionaryTermEnabled(buttonProxy(withIdentifier: identifier))
    }

    @objc
    func editDictionaryTermFromMenu(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        editDictionaryTermFromSettings(buttonProxy(withIdentifier: identifier))
    }

    @objc
    func deleteDictionaryTermFromMenu(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        deleteDictionaryTermFromSettings(buttonProxy(withIdentifier: identifier))
    }

    @objc
    func showDictionarySuggestionActions(_ sender: NSButton) {
        guard let id = dictionaryTermID(from: sender) else { return }
        let identifier = id.uuidString
        let menu = NSMenu()

        let approveItem = NSMenuItem(
            title: "Approve",
            action: #selector(approveDictionarySuggestionFromMenu(_:)),
            keyEquivalent: ""
        )
        approveItem.target = self
        approveItem.representedObject = identifier
        menu.addItem(approveItem)

        let reviewItem = NSMenuItem(
            title: "Review",
            action: #selector(reviewDictionarySuggestionFromMenu(_:)),
            keyEquivalent: ""
        )
        reviewItem.target = self
        reviewItem.representedObject = identifier
        menu.addItem(reviewItem)

        menu.addItem(.separator())

        let dismissItem = NSMenuItem(
            title: "Dismiss",
            action: #selector(dismissDictionarySuggestionFromMenu(_:)),
            keyEquivalent: ""
        )
        dismissItem.target = self
        dismissItem.representedObject = identifier
        menu.addItem(dismissItem)

        showMenu(menu, anchoredTo: sender)
    }

    @objc
    func approveDictionarySuggestionFromMenu(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        approveDictionarySuggestionFromSettings(buttonProxy(withIdentifier: identifier))
    }

    @objc
    func reviewDictionarySuggestionFromMenu(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        reviewDictionarySuggestionFromSettings(buttonProxy(withIdentifier: identifier))
    }

    @objc
    func dismissDictionarySuggestionFromMenu(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        dismissDictionarySuggestionFromSettings(buttonProxy(withIdentifier: identifier))
    }

    @objc
    func showHistoryEntryActions(_ sender: NSButton) {
        guard let id = historyEntryID(from: sender) else { return }
        let identifier = id.uuidString
        let menu = NSMenu()

        let copyItem = NSMenuItem(
            title: "Copy",
            action: #selector(copyHistoryEntryFromMenu(_:)),
            keyEquivalent: ""
        )
        copyItem.target = self
        copyItem.representedObject = identifier
        menu.addItem(copyItem)

        menu.addItem(.separator())

        let deleteItem = NSMenuItem(
            title: "Delete",
            action: #selector(deleteHistoryEntryFromMenu(_:)),
            keyEquivalent: ""
        )
        deleteItem.target = self
        deleteItem.representedObject = identifier
        menu.addItem(deleteItem)

        showMenu(menu, anchoredTo: sender)
    }

    @objc
    func copyHistoryEntryFromMenu(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        copyHistoryEntry(buttonProxy(withIdentifier: identifier))
    }

    @objc
    func deleteHistoryEntryFromMenu(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        deleteHistoryEntry(buttonProxy(withIdentifier: identifier))
    }

    @objc
    func toggleDictionaryTermEnabled(_ sender: NSButton) {
        guard
            let id = dictionaryTermID(from: sender),
            let entry = model.dictionaryEntries.first(where: { $0.id == id })
        else {
            return
        }

        model.setDictionaryTermEnabled(id: id, isEnabled: !entry.isEnabled)
        reloadFromModel()
    }

    @objc
    func editDictionaryTermFromSettings(_ sender: NSButton) {
        guard
            let id = dictionaryTermID(from: sender),
            let entry = model.dictionaryEntries.first(where: { $0.id == id })
        else {
            return
        }

        guard let term = presentDictionaryTermEditor(
            title: "Edit Dictionary Term",
            confirmTitle: "Save",
            canonical: entry.canonical,
            aliases: entry.aliases,
            tag: entry.tag
        ) else {
            return
        }

        model.editDictionaryTerm(id: id, canonical: term.canonical, aliases: term.aliases, tag: term.tag)
        dictionarySelectedCollection = term.tag.map(DictionaryCollectionSelection.tag) ?? .allTerms
        reloadFromModel()
    }

    @objc
    func deleteDictionaryTermFromSettings(_ sender: NSButton) {
        guard
            let id = dictionaryTermID(from: sender),
            let entry = model.dictionaryEntries.first(where: { $0.id == id })
        else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete dictionary term?"
        alert.informativeText = "“\(entry.canonical)” will be removed from the dictionary."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        model.deleteDictionaryTerm(id: id)
        reloadFromModel()
    }

    @objc
    func approveDictionarySuggestionFromSettings(_ sender: NSButton) {
        guard let id = dictionaryTermID(from: sender) else { return }
        model.approveDictionarySuggestion(id: id)
        reloadFromModel()
    }

    @objc
    func reviewDictionarySuggestionFromSettings(_ sender: NSButton) {
        guard
            let id = dictionaryTermID(from: sender),
            let suggestion = model.dictionarySuggestions.first(where: { $0.id == id })
        else {
            return
        }

        guard let term = presentDictionaryTermEditor(
            title: "Review Suggestion",
            confirmTitle: "Save Term",
            canonical: suggestion.proposedCanonical,
            aliases: suggestion.proposedAliases,
            tag: nil
        ) else {
            return
        }

        model.addDictionaryTerm(canonical: term.canonical, aliases: term.aliases, tag: term.tag)
        model.dismissDictionarySuggestion(id: id)
        dictionarySelectedCollection = term.tag.map(DictionaryCollectionSelection.tag) ?? .allTerms
        reloadFromModel()
    }

    @objc
    func dismissDictionarySuggestionFromSettings(_ sender: NSButton) {
        guard let id = dictionaryTermID(from: sender) else { return }
        model.dismissDictionarySuggestion(id: id)
        reloadFromModel()
    }

}
