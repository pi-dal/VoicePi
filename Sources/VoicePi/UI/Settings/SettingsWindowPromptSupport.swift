import AppKit
import Foundation

extension SettingsWindowController {
    enum PromptBindingEntryAction {
        case createFromDefault
        case createFromStarter
        case editUser
    }

    struct PromptAppBindingConflictAlertContent: Equatable {
        let messageText: String
        let informativeText: String
    }

    struct PromptEditorBodyPalette: Equatable {
        let text: NSColor
        let background: NSColor
        let insertionPoint: NSColor
    }

    struct PromptEditorBodyContainerChrome: Equatable {
        let background: NSColor
        let border: NSColor
        let cornerRadius: CGFloat
    }

    static func livePreviewLLMConfiguration(
        from configuration: LLMConfiguration,
        mode: PostProcessingMode,
        refinementProvider: RefinementProvider,
        resolvedPromptText: String?
    ) -> LLMConfiguration {
        var resolved = configuration
        if mode == .refinement && refinementProvider == .llm {
            resolved.refinementPrompt = resolvedPromptText?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else {
            resolved.refinementPrompt = ""
        }
        return resolved
    }

    static func makeReadOnlyPromptPreviewScrollView(
        text: String,
        borderType: NSBorderType = .noBorder
    ) -> NSScrollView {
        let textView = NSTextView(frame: .zero)
        textView.isRichText = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.string = text

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = borderType
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        return scrollView
    }

    static func thinkingTitles() -> [String] {
        [thinkingUnsetTitle, "On", "Off"]
    }

    static func thinkingSelectionIndex(
        for enableThinking: Bool?
    ) -> Int {
        guard let enableThinking else {
            return 0
        }

        return enableThinking ? 1 : 2
    }

    static func enableThinkingForSelectionIndex(_ index: Int) -> Bool? {
        switch index {
        case 1:
            return true
        case 2:
            return false
        default:
            return nil
        }
    }

    static func promptEditorSheetTitle(for preset: PromptPreset) -> String {
        isNewPromptDraft(preset) ? "New Prompt" : "Edit Prompt"
    }

    static func promptEditorPrimaryActionTitle(for preset: PromptPreset) -> String {
        isNewPromptDraft(preset) ? "Create Prompt" : "Save Prompt"
    }

    static func strictModeSummaryText(enabled: Bool) -> String {
        if enabled {
            return "Strict Mode on • Matching app bindings override Active Prompt"
        }
        return "Strict Mode off • Always uses Active Prompt"
    }

    static func promptAppBindingConflictAlertContent(
        for conflicts: [PromptAppBindingConflict],
        destinationPromptTitle: String
    ) -> PromptAppBindingConflictAlertContent {
        if
            let conflict = conflicts.first,
            conflicts.count == 1,
            let owner = conflict.owners.first,
            conflict.owners.count == 1
        {
            return .init(
                messageText: "\(conflict.appBundleID) is already bound to “\(owner.title)”.",
                informativeText: "Do you want to unbind it there and bind it to “\(destinationPromptTitle)” instead?"
            )
        }

        let details = conflicts.map { conflict in
            let owners = conflict.owners.map(\.title).joined(separator: ", ")
            return "\(conflict.appBundleID) → \(owners)"
        }.joined(separator: "\n")

        return .init(
            messageText: "Some apps are already bound to other prompts.",
            informativeText: """
            Do you want to unbind these app bindings and bind them to “\(destinationPromptTitle)” instead?

            \(details)
            """
        )
    }

    static func bindingEntryAction(for source: PromptPresetSource) -> PromptBindingEntryAction {
        switch source {
        case .builtInDefault:
            return .createFromDefault
        case .starter:
            return .createFromStarter
        case .user:
            return .editUser
        }
    }

    static func activeSelectionAfterSavingPromptEditor(
        previousSelection: PromptActiveSelection,
        savedPreset: PromptPreset
    ) -> PromptActiveSelection {
        let hasAutomaticBindings = !savedPreset.appBundleIDs.isEmpty || !savedPreset.websiteHosts.isEmpty

        guard hasAutomaticBindings else {
            return .preset(savedPreset.id)
        }

        if previousSelection == .preset(savedPreset.id) {
            return .preset(savedPreset.id)
        }

        return previousSelection
    }

    @discardableResult
    static func persistPromptEditorSaveResult(
        model: AppModel,
        promptWorkspaceDraft: inout PromptWorkspaceSettings,
        savedPreset: PromptPreset,
        confirmedConflictReassignment: Bool
    ) -> Bool {
        let conflicts = promptWorkspaceDraft.appBindingConflicts(for: savedPreset)
        if !conflicts.isEmpty && !confirmedConflictReassignment {
            return false
        }

        var nextWorkspace = promptWorkspaceDraft
        if !conflicts.isEmpty {
            nextWorkspace.reassignConflictingAppBindings(for: savedPreset)
        }

        let nextSelection = activeSelectionAfterSavingPromptEditor(
            previousSelection: nextWorkspace.activeSelection,
            savedPreset: savedPreset
        )
        nextWorkspace.saveUserPreset(savedPreset)
        nextWorkspace.activeSelection = nextSelection

        promptWorkspaceDraft = nextWorkspace
        model.promptWorkspace = nextWorkspace
        return true
    }

    static func makeNewUserPromptDraft(template: PromptPreset? = nil) -> PromptPreset {
        let id = "user.\(UUID().uuidString.lowercased())"
        guard let template else {
            return PromptPreset(
                id: id,
                title: "New Prompt",
                body: "",
                source: .user
            )
        }

        return PromptPreset(
            id: id,
            title: "\(template.resolvedTitle) Copy",
            body: template.body,
            source: .user,
            appBundleIDs: template.appBundleIDs,
            websiteHosts: template.websiteHosts
        )
    }

    static func makeNewUserPromptDraft(
        prefillingCapturedValue capturedRawValue: String,
        kind: PromptBindingKind
    ) -> PromptPreset {
        let normalized = PromptBindingActions.normalizedCapturedValue(capturedRawValue, kind: kind)
        return PromptPreset(
            id: "user.\(UUID().uuidString.lowercased())",
            title: "New Prompt",
            body: "",
            source: .user,
            appBundleIDs: kind == .appBundleID ? [normalized].compactMap { $0 } : [],
            websiteHosts: kind == .websiteHost ? [normalized].compactMap { $0 } : []
        )
    }

    static func promptEditorBodyPalette(for appearance: NSAppearance?) -> PromptEditorBodyPalette {
        let resolvedAppearance = appearance ?? NSApp.effectiveAppearance
        let isDarkTheme = resolvedAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let background = isDarkTheme
            ? NSColor(calibratedWhite: 0.205, alpha: 1)
            : NSColor(
                calibratedRed: 0xFC / 255.0,
                green: 0xFB / 255.0,
                blue: 0xF8 / 255.0,
                alpha: 1
            )

        return PromptEditorBodyPalette(
            text: .labelColor,
            background: background,
            insertionPoint: .labelColor
        )
    }

    static func promptEditorBodyContainerChrome(for appearance: NSAppearance?) -> PromptEditorBodyContainerChrome {
        let resolvedAppearance = appearance ?? NSApp.effectiveAppearance
        let isDarkTheme = resolvedAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        return PromptEditorBodyContainerChrome(
            background: isDarkTheme
                ? NSColor(calibratedWhite: 0.24, alpha: 1)
                : NSColor(
                    calibratedRed: 0xF6 / 255.0,
                    green: 0xF3 / 255.0,
                    blue: 0xEC / 255.0,
                    alpha: 1
                ),
            border: isDarkTheme
                ? NSColor(calibratedWhite: 1, alpha: 0.08)
                : NSColor(calibratedWhite: 0, alpha: 0.08),
            cornerRadius: 12
        )
    }

    private static func isNewPromptDraft(_ preset: PromptPreset) -> Bool {
        preset.source == .user
            && preset.title == "New Prompt"
            && preset.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
