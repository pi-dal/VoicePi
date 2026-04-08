# Prompt Editor Immediate Save Design

**Status:** Proposed

**Goal:** Make the prompt editor sheet's top-level `Save Prompt` action persist prompt changes immediately, without requiring the user to also click the settings page's bottom `Save` button afterward.

## Problem

The current save model splits prompt editing across two layers:

- `Save Prompt` in the prompt editor sheet writes only to `SettingsWindowController.promptWorkspaceDraft`
- the settings page's bottom `Save` writes `promptWorkspaceDraft` into `AppModel.promptWorkspace`, which is the persisted source of truth

That means a user can:

1. open the prompt editor
2. edit a prompt
3. click `Save Prompt`
4. close settings without clicking the page-level `Save`

and still lose the prompt changes.

This is surprising because the editor sheet uses explicit commit language (`Save Prompt`), while other nearby settings actions such as ASR `Save` already persist immediately. The current interaction reads like a real save, but behaves like a local draft apply.

## Current Behavior

Today the settings window maintains a local prompt workspace draft:

- prompt selection changes update `promptWorkspaceDraft`
- strict mode changes update `promptWorkspaceDraft`
- prompt editor sheet saves update `promptWorkspaceDraft`
- only the page-level `saveConfiguration()` call copies `promptWorkspaceDraft` into `model.promptWorkspace`

Persistence already exists in the model layer. `AppModel.promptWorkspace` is `@Published` and writes to `UserDefaults` in `didSet`. The mismatch is therefore not in persistence infrastructure, but in when the controller chooses to write to the model.

## Options Considered

### Option A: Keep Current Behavior and Rename the Button

Examples:

- rename `Save Prompt` to `Apply`
- add helper copy explaining that bottom `Save` is still required

Pros:

- smallest code change
- preserves the current draft architecture exactly

Cons:

- keeps an unusual two-step commit model
- adds cognitive overhead to a simple prompt-editing task
- remains inconsistent with other `Save` buttons in the settings UI

### Option B: Make `Save Prompt` Persist Immediately

When the sheet save succeeds, write the updated prompt workspace directly to `AppModel.promptWorkspace`.

Pros:

- matches user expectation
- aligns prompt editing with ASR save semantics
- reduces risk of accidental data loss when closing settings

Cons:

- introduces mixed save semantics inside the LLM section, because prompt edits persist immediately while API base URL / key / model still use page-level save

## Decision

Choose **Option B**.

`Save Prompt` should be a real save. The current behavior is harder to understand than the implementation simplification it provides. Prompt editing is a sufficiently self-contained workflow that it should commit immediately once the sheet save has validated and the user confirms any binding reassignment.

## Product Rules

### Prompt Editor Save

When the user clicks `Save Prompt` or `Create Prompt` in the prompt editor sheet:

1. Validate and normalize the prompt draft exactly as today.
2. Resolve any app-binding conflicts exactly as today.
3. If the user cancels conflict reassignment, keep the sheet open and persist nothing.
4. If save succeeds, persist the updated prompt workspace immediately.
5. Close the sheet only after the immediate save completes.

The saved result must survive closing the settings window without any additional action.

### Scope of Immediate Save

Immediate save applies only to prompt-workspace state:

- user prompt title/body
- app bundle ID bindings
- website host bindings
- active prompt selection changes caused by saving the prompt

Immediate save does not implicitly commit unrelated LLM settings from the page:

- API base URL
- API key
- model
- post-processing mode
- translation provider
- target language
- strict mode toggle changes that were not part of the prompt save

Those settings keep their current page-level save behavior unless changed by a separate design.

## UX Expectations

After `Save Prompt` succeeds:

- reopening the same prompt editor should show the saved content
- closing and reopening settings should show the saved prompt
- the prompt picker and prompt summary should refresh immediately
- menu bar prompt state should reflect the saved prompt workspace without waiting for the page-level save

No extra confirmation is needed for the normal success path beyond the existing app-binding conflict confirmation.

## Controller Design

The cleanest change is in `SettingsWindowController.savePromptEditorSheet()`.

Current behavior:

- mutate `promptWorkspaceDraft`
- update controls
- close sheet

Proposed behavior:

1. Build the saved `PromptPreset` as today.
2. Apply conflict reassignment to a next prompt workspace value.
3. Compute the next active selection as today.
4. Write that workspace both:
   - to `promptWorkspaceDraft`, so the open settings UI stays internally consistent
   - to `model.promptWorkspace`, so persistence happens immediately
5. Refresh prompt UI state from the now-saved workspace.

This keeps the draft and persisted state aligned after a prompt save, while still allowing unrelated LLM form fields to remain unsaved.

## Data Flow Constraint

The prompt editor save path must not accidentally discard unsaved prompt-workspace changes that already exist in the settings page.

Examples:

- if the user changed `Strict Mode` in the page but has not clicked bottom `Save`, then saving a prompt should preserve that in-memory `promptWorkspaceDraft`
- if the user changed the active prompt popup before opening the editor, the prompt save should preserve that draft context unless the save logic intentionally changes active selection

In practice, the sheet save should persist the current `promptWorkspaceDraft` plus the prompt-specific mutation, not rebuild from `model.promptWorkspace`.

## Non-Goals

This spec does not change:

- page-level `Save` behavior for LLM credentials and post-processing settings
- whether prompt selection changes outside the editor should also persist immediately
- prompt conflict rules
- starter-prompt duplication behavior
- prompt runtime resolution logic

## Testing Strategy

Add coverage for the controller/model interaction boundary:

- saving a prompt from the editor persists it to `AppModel.promptWorkspace` immediately
- closing settings after editor save does not lose the prompt
- unsaved LLM credential fields are not committed by editor save
- unsaved `promptWorkspaceDraft` state unrelated to the edited prompt is preserved when editor save persists
- prompt save still keeps built-in default selected when saving a newly bound automatic prompt
- cancelling app-binding conflict reassignment leaves both `promptWorkspaceDraft` and `model.promptWorkspace` unchanged

Also run the existing prompt workspace persistence tests to confirm no regression in reload behavior.

## Implementation Notes

- `AppModel` already persists `promptWorkspace` via `didSet`, so no new storage layer is needed.
- The main risk is stale draft overwrite, not persistence.
- If future UX work wants consistent immediate-save semantics across the whole LLM page, that should be a separate design, because it changes a broader set of settings and expectations.
