# Provider Settings Design

**Date:** 2026-04-26

## Goal

Add a dedicated `Provider` top-level settings section that replaces the current standalone `ASR` navigation item, then expose `ASR` and `LLM` as sibling subtabs inside that section while leaving the existing `Text` section unchanged.

## Problem

The current settings information architecture splits speech-recognition and large-model configuration across separate top-level sections:

- `ASR` is visible as a dedicated top-level page.
- `Text` contains post-processing rules and prompt controls.
- LLM connection details exist in code, but they are not surfaced in a way that makes the active provider/model obvious.

This makes it hard to answer a basic operational question: when refinement uses an LLM, which configured model and endpoint are actually in play? The configuration exists, but the settings UI does not present it as a first-class provider surface.

## UX Direction

The settings window should distinguish between:

1. text-processing behavior, which stays in `Text`
2. backend/provider connectivity, which moves into a new `Provider` section

The top navigation should replace `ASR` with `Provider`. Inside `Provider`, the page should present two subtabs using the same visual language as `Library > History / Dictionary`:

- `ASR`
- `LLM`

This keeps `Text` focused on refinement, translation, prompts, and preview behavior, while `Provider` becomes the single place to inspect and edit backend credentials, endpoints, and model choices.

## Information Architecture

Top-level navigation should become:

- `Home`
- `Permissions`
- `Library`
- `Text`
- `Provider`
- `Processors`
- `About`

`Provider` takes over the old `ASR` slot in navigation order. `Text` keeps its current title and continues to represent processing rules rather than credentials.

Within `Provider`, subtabs should switch between two independent content panes:

- `ASR`: the existing ASR backend page content
- `LLM`: a new provider-oriented LLM page

Existing direct-entry helpers that currently open `.asr` or `.llm` should route through the `Provider` section and select the matching subtab.

## Provider > ASR

The `ASR` subtab should reuse the current ASR page behavior and copy as much as possible:

- backend mode choice cards
- remote provider selection
- remote connection fields
- local-mode explanatory hint
- connection test/save actions
- live connection status

This is intentionally a structural move, not an ASR redesign. The goal is to preserve existing behavior while relocating it under the new provider hierarchy.

## Provider > LLM

The `LLM` subtab should make backend configuration explicit and visually parallel to the current ASR section. The page should use a similar two-column card composition:

- left column: a compact provider summary or mode/context card
- right column: `Connection Details`
- right column below: `Live Status`

The LLM page should surface these controls directly:

- `API Base URL`
- `API Key`
- `Model`
- `Thinking`
- `Test Connection`
- `Save`

The page should also include concise summary copy explaining that this configuration is used when current `Text` settings require an LLM for refinement or translation. It should not absorb prompt editing, prompt bindings, or live preview; those stay in `Text`.

## Interaction Model

Entering `Provider` should show one selected subtab at a time. The implementation can default to `ASR` first for minimal change and lower risk, though remembering the last selected subtab is a reasonable future enhancement.

Subtab switching should only affect page visibility inside `Provider`; it should not trigger unrelated model changes.

When code paths request a settings jump to the LLM configuration area, the app should:

1. switch top-level navigation to `Provider`
2. activate the `LLM` subtab

The same rule applies to ASR-specific entry points, which should land on `Provider > ASR`.

## Architecture

This change should stay inside the settings window layer:

- extend `SettingsSection` to introduce `provider`
- add provider-specific subview state for `ASR` vs `LLM`
- reuse or generalize the existing subtab control pattern used by `Library`
- move top-level view visibility management from separate `.asr` / `.llm` pages to a shared `providerView`
- preserve existing `refreshASRSection()`, `refreshLLMSection()`, save/test handlers, and model persistence

The runtime speech, refinement, translation, and persistence paths should remain unchanged.

## Constraints

- Do not change the `Text` section’s current feature set or layout.
- Do not change the semantics of saved ASR or LLM configuration.
- Keep `ASR` and `LLM` refresh/save/test wiring intact.
- Avoid broader settings-window refactors unrelated to the new navigation hierarchy.

## Verification

Implementation should cover:

- top navigation copy/order reflecting `Provider` instead of `ASR`
- navigation helpers opening `Provider > ASR` and `Provider > LLM`
- provider subtab selection state and view visibility
- LLM provider controls remaining wired to existing save/test logic
- settings window layout tests continuing to recognize the updated navigation labels

Repository verification should end with targeted settings tests and `./Scripts/test.sh`.
