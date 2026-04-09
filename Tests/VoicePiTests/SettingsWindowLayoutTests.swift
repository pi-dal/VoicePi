import AppKit
import Foundation
import Testing
@testable import VoicePi

@MainActor
struct SettingsWindowLayoutTests {
    @Test
    func settingsWindowDoesNotDuplicateTitleInsideContentArea() {
        let controller = makeController()
        let labels = textLabels(in: controller.window?.contentView)

        #expect(labels.contains(where: { $0.stringValue == "VoicePi Settings" }) == false)
        #expect(
            labels.contains(where: {
                $0.stringValue == "Quick controls for permissions, dictation, dictionary, and processor settings."
            }) == false
        )
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

    private func makeController() -> SettingsWindowController {
        SettingsWindowController(model: AppModel(), delegate: nil)
    }

    private func allViews(in root: NSView?) -> [NSView] {
        guard let root else { return [] }
        return [root] + root.subviews.flatMap(allViews)
    }

    private func textLabels(in root: NSView?) -> [NSTextField] {
        allViews(in: root).compactMap { $0 as? NSTextField }
    }

    private func buttons(in root: NSView?) -> [NSButton] {
        allViews(in: root).compactMap { $0 as? NSButton }
    }

    private func popUpButtons(in root: NSView?) -> [NSPopUpButton] {
        allViews(in: root).compactMap { $0 as? NSPopUpButton }
    }
}
