import AppKit
import Foundation
import Testing
@testable import VoicePi

@MainActor
struct SettingsWindowLayoutTests {
    @Test
    func settingsWindowShowsTitleAndCompactSubtitleInsideContentArea() {
        let controller = makeController()
        let labels = textLabels(in: controller.window?.contentView)
        let titleLabel = labels.first(where: { $0.stringValue == "VoicePi Settings" })
        let subtitleLabel = labels.first(where: {
            $0.stringValue == "Quick controls for permissions, dictation, dictionary, and processor settings."
        })

        #expect(titleLabel != nil)
        #expect(subtitleLabel != nil)
        #expect(subtitleLabel?.font?.pointSize == 11)
        #expect((subtitleLabel?.font?.pointSize ?? 0) < (titleLabel?.font?.pointSize ?? 0))
        #expect(controller.window?.title == "VoicePi Settings")
    }

    @Test
    func settingsWindowUsesCompactDefaultWidth() {
        let controller = makeController()

        #expect(controller.window?.frame.width == 820)
    }

    @Test
    func settingsNavigationButtonsUseIconAboveTextLayout() {
        let controller = makeController()
        let buttons = buttons(in: controller.window?.contentView)
        let navigationButtons = buttons.filter { button in
            guard let section = SettingsSection(rawValue: button.tag) else {
                return false
            }
            return button.title == section.title
        }

        #expect(navigationButtons.count == SettingsSection.allCases.count)
        for button in navigationButtons {
            #expect(button.imagePosition == .imageAbove)
        }
    }

    @Test
    func settingsNavigationButtonsUsePaddedIcons() {
        let controller = makeController()
        let buttons = buttons(in: controller.window?.contentView)
        let navigationButtons = buttons.filter { button in
            guard let section = SettingsSection(rawValue: button.tag) else {
                return false
            }
            return button.title == section.title
        }

        #expect(navigationButtons.count == SettingsSection.allCases.count)
        for button in navigationButtons {
            let iconHeight = button.image?.size.height ?? 0
            #expect(iconHeight >= 16)
        }
    }

    @Test
    func processorManagerEmptyStateOmitsActiveProcessorPicker() {
        let controller = makeController()
        controller.show(section: .externalProcessors)
        controller.perform(NSSelectorFromString("openExternalProcessorManager"))

        let sheetContentView = controller.window?.attachedSheet?.contentView
        let labels = textLabels(in: sheetContentView)
        let popups = popUpButtons(in: sheetContentView)

        #expect(labels.contains(where: { $0.stringValue == "Active Processor" }) == false)
        #expect(popups.contains(where: { $0.itemTitles.contains("No processors configured") }) == false)
    }

    @Test
    func processorManagerEmptyStateShowsSingleEmptyStateMessage() {
        let controller = makeController()
        controller.show(section: .externalProcessors)
        controller.perform(NSSelectorFromString("openExternalProcessorManager"))

        let labels = textLabels(in: controller.window?.attachedSheet?.contentView)
        let emptyStateMatches = labels.filter {
            $0.stringValue == SettingsWindowController.externalProcessorManagerEmptyStateText
        }

        #expect(emptyStateMatches.count == 1)
    }

    @Test
    func homeSectionIncludesProcessorShortcutControl() {
        let controller = makeController()
        controller.show(section: .home)
        let labels = textLabels(in: controller.window?.contentView).map(\.stringValue)
        let recorderFields = buttons(in: controller.window?.contentView).compactMap { $0 as? ShortcutRecorderField }

        #expect(labels.contains("Processor Shortcut"))
        #expect(recorderFields.count >= 3)
    }

    @Test
    func processorShortcutRecorderUpdatesModel() {
        let model = AppModel()
        let controller = makeController(model: model)
        let recorder = ShortcutRecorderField(frame: .zero)
        let modifierFlags = NSEvent.ModifierFlags.command.union(.shift)
        let shortcut = ActivationShortcut(
            keyCodes: [35],
            modifierFlagsRawValue: modifierFlags.rawValue
        )

        recorder.shortcut = shortcut
        controller.perform(NSSelectorFromString("processorShortcutRecorderChanged:"), with: recorder)

        #expect(model.processorShortcut == shortcut)
    }

    @Test
    func closingProcessorManagerPersistsLatestEdits() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.closingProcessorManagerPersistsLatestEdits.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        let controller = makeController(model: model)
        controller.show(section: .externalProcessors)
        controller.perform(NSSelectorFromString("openExternalProcessorManager"))
        controller.perform(NSSelectorFromString("addExternalProcessorEntry"))

        let nameField = textFields(in: controller.window?.attachedSheet?.contentView).first {
            $0.placeholderString == "Processor name"
        }

        guard let nameField else {
            Issue.record("Expected processor name field in manager sheet.")
            return
        }

        nameField.stringValue = "  Saved Processor  "
        controller.perform(NSSelectorFromString("closeExternalProcessorManagerSheet"))

        #expect(model.externalProcessorEntries.count == 1)
        #expect(model.externalProcessorEntries[0].name == "Saved Processor")
    }

    private func makeController() -> SettingsWindowController {
        makeController(model: AppModel())
    }

    private func makeController(model: AppModel) -> SettingsWindowController {
        SettingsWindowController(model: model, delegate: nil)
    }

    private func allViews(in root: NSView?) -> [NSView] {
        guard let root else { return [] }
        return [root] + root.subviews.flatMap(allViews)
    }

    private func textLabels(in root: NSView?) -> [NSTextField] {
        allViews(in: root).compactMap { $0 as? NSTextField }
    }

    private func textFields(in root: NSView?) -> [NSTextField] {
        allViews(in: root).compactMap { $0 as? NSTextField }
    }

    private func buttons(in root: NSView?) -> [NSButton] {
        allViews(in: root).compactMap { $0 as? NSButton }
    }

    private func popUpButtons(in root: NSView?) -> [NSPopUpButton] {
        allViews(in: root).compactMap { $0 as? NSPopUpButton }
    }
}
