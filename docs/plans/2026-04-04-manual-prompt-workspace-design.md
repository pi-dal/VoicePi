# Manual Prompt Workspace Design

**Status:** Approved for implementation

**Goal:** Replace the current constrained prompt-profile UX with a more open prompt workspace that keeps VoicePi's default correction and translation behavior intact while letting users manually switch between freeform prompts and grow into future app- and site-specific routing.

## Product Direction

VoicePi should keep one built-in default prompt that covers the minimum behavior the product always wants:

- basic speech-recognition error correction
- conservative transcript cleanup
- existing translation suffix behavior when translation is active

Everything beyond that should be user-controlled. Users should be able to pick from a small set of shipped starter prompts, duplicate them, edit them freely, and create their own prompts from scratch.

The first shipped workflow should be manual prompt switching. VoicePi should not rely on automatic destination-app matching in this phase. The user explicitly selects the prompt they want to use, which improves output accuracy and keeps the system understandable.

## Core Runtime Rule

The prompt resolver should become:

1. If the user has manually selected a prompt preset, use that preset body as the customizable middle section.
2. Otherwise, use the built-in VoicePi default prompt.
3. Continue assembling the final system prompt from:
   - hardcoded prefix from `LLMRefiner`
   - resolved middle section
   - existing language/output suffix from `LLMRefiner`

For the first implementation, the built-in default resolves to a no-op editable middle section. That intentionally preserves the current behavior: VoicePi's minimum correction and translation logic still comes from code, and the default prompt does not add extra user-editable instructions until we choose to strengthen it later.

## Prompt Domain

The current prompt model is centered on bundled profiles and VoicePi-specific inheritance:

- `PromptSelectionMode`
- `PromptSelection`
- `PromptSettings`
- `PromptResolver`
- `PromptAppPolicy`

That model is too restrictive for the new product direction. The new domain should instead model a prompt workspace:

- `PromptPreset`
  - `id`
  - `title`
  - `body`
  - `source`
  - optional future assignment metadata
- `PromptPresetSource`
  - `builtInDefault`
  - `starter`
  - `user`
- `ActivePromptSelection`
  - `.default`
  - `.preset(id)`
- `PromptWorkspace`
  - starter presets
  - user presets
  - active selection

The built-in default prompt should remain non-editable. Starter prompts should be bundled assets. User prompts should be persisted in settings and remain fully editable.

## Manual Binding Routing

Manual prompt switching remains important, but VoicePi now also needs a practical way to route prompts by destination without reintroducing the old profile matrix.

The simplest runtime rule is:

1. If the user pins a concrete prompt from the **Active Prompt** picker, use that prompt globally.
2. If the picker remains on `VoicePi Default`, treat that as automatic mode.
3. In automatic mode, check user-defined bindings in this order:
   - exact app bundle ID matches
   - exact or wildcard website host matches from supported browsers
4. If nothing matches, fall back to the built-in default prompt.

To support that cleanly, each user-editable `PromptPreset` can carry:

- app bundle ids
- website host patterns

Starter prompts remain read-only. If the user wants to bind one, they should duplicate it into a user prompt first and attach bindings there.

## Migration

Migration must preserve behavior for existing users.

### Existing users with no custom refinement prompt

- create the new prompt workspace state
- set active selection to `.default`
- do not create an imported user preset

### Existing users with a non-empty legacy custom refinement prompt

- create a user preset, such as `Imported Prompt`
- copy the legacy prompt body into that preset
- set active selection to the imported preset
- persist the new workspace so the import happens once
- stop relying on `LLMConfiguration.refinementPrompt` after migration; keep it only as a compatibility import source until the user saves newer settings

### Existing bundled prompt profiles

The current bundled prompt library should stop driving the main UX. Existing bundled profiles should instead be surfaced as starter presets. For v1, VoicePi should flatten the current profile bodies directly into starter prompts:

- `Meeting Notes`
- `JSON Output`
- `Support Reply`

Option fragments and per-app profile inheritance should not participate in the new UI.

This keeps shipping flexibility while removing the current restrictive UI.

## UI Changes

The prompt section in settings should become a manual prompt workspace instead of a global/app override matrix. The main settings page should stay compact, and prompt editing should happen in a dedicated sheet.

### Required controls

- active prompt picker
  - `VoicePi Default`
  - bundled starter prompts
  - user-created prompts
- prompt summary label showing the selected prompt source/title
- `Edit`
- `New`
- `Duplicate`
- `Delete` for user presets only
- `Preview`

The main settings page should not embed a large text editor. It should expose only the active selection, summary, and actions.

### Prompt Editor Sheet

Prompt editing should reuse the existing preview-sheet interaction pattern:

- open as a modal sheet attached to the settings window
- use a titled window with close/save controls
- contain:
  - prompt title field
  - large prompt body editor
- `Save` commits prompt title/body changes
- `Cancel` closes without applying sheet-local edits

Sheet entry points:

- `Edit` opens the selected user prompt
- `New` creates a new user prompt and opens it immediately
- `Duplicate` creates a user copy of the current prompt and opens that copy

`VoicePi Default` remains non-editable, so `Edit` should be disabled for it. Starter prompts should also stay non-editable in place; users edit them through `Duplicate`.

### UX rules

- selecting `Default` uses the built-in prompt and disables editing
- starter prompts are read-only
- editing a starter requires an explicit duplicate action rather than auto-converting on first edit
- user presets are fully editable
- prompt edits should be staged inside the sheet and applied on `Save`, not live as the user types

This design intentionally favors an explicit editing model over the current hidden `legacy-custom` escape hatch.

## Persistence

The workspace should be stored in `UserDefaults` through `AppModel` alongside other settings, but separate from LLM credentials.

Suggested persisted shape:

```json
{
  "version": 1,
  "activeSelection": {
    "mode": "preset",
    "presetID": "user-imported"
  },
  "userPresets": [
    {
      "id": "user-imported",
      "title": "Imported Prompt",
      "body": "..."
    }
  ]
}
```

Bundled starter presets should not be duplicated into persisted state. They should be loaded from bundled resources and merged with user presets in memory.

## Implementation Boundaries

### Keep

- `LLMRefiner` prompt assembly pattern: prefix + middle + suffix
- translation suffix behavior
- existing networking and post-processing flow

### Replace or simplify

- `PromptSelectionMode`
- `PromptTemplateFormState`
- VoicePi-specific app override controls in `StatusBarController`
- registry-driven prompt option popup rendering as the primary UX
- `.voicePi`-only prompt resolution
- prompt-body persistence inside `LLMConfiguration`

### Transitional compatibility

The current prompt library files may stay in the repository temporarily if they are repurposed into starter presets or still used by tests during migration. The product behavior should no longer depend on per-app profile inheritance in this first phase.

## Testing Strategy

Use TDD.

Coverage should include:

- migration from empty legacy prompt to default selection
- migration from non-empty legacy prompt to imported user preset
- default runtime resolution
- runtime resolution for a selected starter preset
- runtime resolution for a selected user preset
- settings UI behavior for default vs starter vs user presets
- editing constraints:
  - built-in default not editable
  - starter prompt duplication behavior
  - deleting a user preset falls back safely

## Deferred Work

Do not implement these in the first slice:

- automatic destination-app matching
- browser-domain matching
- prompt priority resolution across app and site rules
- generic schema-driven option fragments
- cross-app inheritance UI

Those features can be added after the manual workspace is stable.
