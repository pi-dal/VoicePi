# External Processor Refinement Design

**Date:** 2026-04-09

**Goal:** Add a first-class external post-processing architecture to VoicePi so recorded dictation can be sent through tools such as `alma run` without relying on UI focus, hotkeys, or paste injection into another desktop window.

## Context

VoicePi already supports three major stages:

1. capture speech
2. optionally post-process the transcript
3. inject the final text into the active target

The current post-processing path treats "refinement" as an OpenAI-compatible LLM HTTP request and treats "translation" as either Apple Translate or that same LLM path. This works, but it couples refinement to a specific API shape and misses a more universal integration point.

Local verification on 2026-04-09 confirmed that Alma exposes a CLI with a pipe-friendly one-shot entrypoint:

- `alma run [options] [prompt]`
- accepts transcript content on `stdin`
- prints the completion to `stdout`
- supports `--raw` and `--no-stream`
- supports optional model override via `-m`

That contract is a better fit for VoicePi than a desktop-window automation path because it is:

- less brittle than hotkey-plus-focus orchestration
- independent of Alma window state
- closer to a generic future "CLI post-processor" abstraction

The same shape is likely useful for other backends later, including other CLI-based agents or text processors.

## Decision

VoicePi should introduce a generic external processing layer instead of a one-off Alma-only integration.

This design explicitly does **not** introduce a plugin system. It also does **not** route through Alma Prompt Apps or Alma desktop UI automation.

The first version should add a new refinement provider family and ship Alma CLI as the first concrete provider.

At the architecture level, VoicePi should distinguish between:

- `LLM`
- `External Processor`

Inside `External Processor`, the first shipped backend is:

- `Alma CLI`

When the user selects `External Processor` and the configured processor is `Alma CLI`, VoicePi should:

1. finish speech capture as usual
2. resolve the active prompt preset as usual
3. build a refinement prompt for Alma
4. invoke `alma run --raw --no-stream <prompt>`
5. send the captured transcript to `stdin`
6. read the refined result from `stdout`
7. present the centered result review panel
8. insert the reviewed result into the original destination only if the user confirms

## Non-Goals

This spec does not include:

- a general plugin system
- arbitrary shell command execution
- Alma desktop app hotkey launching
- Alma Prompt App window automation
- support for `alma run` as a translation provider
- support for Alma thread/session management
- support for interactive or streaming Alma CLI sessions

Those can be layered later if this first integration proves stable.

## User Experience

### Primary User Story

As a VoicePi user, I want to choose an external processor for refinement so my dictated text can be cleaned up by tools such as Alma before I decide whether to insert the result back into the app I was using.

### Settings Experience

The settings surface should eventually support a dedicated management area for external processors.

For the first version, VoicePi can keep the primary selection inside the existing "Text Processing" section, but the design must leave room for a later dedicated settings tab such as:

- `Processors`
- `Automation`
- `Integrations`

That later management view should not be modeled as a single flat form. It should behave more like a processor manager.

Add a new control:

- `Refinement Provider`

Values:

- `LLM`
- `External Processor`

When `External Processor` is selected, a secondary selector chooses the concrete backend.

Initial backend values:

- `Alma CLI`

The processor configuration should also leave room for backend-specific options such as:

- executable path override
- additional arguments
- health/test action

Behavior:

- When mode is `Disabled`, the provider has no effect.
- When mode is `Refinement`, the selected refinement provider is active.
- When mode is `Translation`, the existing translation provider behavior remains unchanged.

The current prompt preset system remains the source of user-editable refinement instructions.

### Processor Manager Interaction

The long-term settings direction should use a dedicated sheet-based manager for external processors.

Recommended interaction:

- user opens the processor manager
- user sees a sheet, not a full page replacement
- the sheet can scroll naturally when there are many configured processors or many backend-specific options
- the sheet contains a `+` action for adding another processor configuration

Each time the user taps or clicks `+`, VoicePi should create a new processor entry row/card/app-style item inside the sheet.

Each processor entry represents one user-configured backend instance, for example:

- Alma CLI default
- Alma CLI with custom model args
- future Codex CLI profile

Each entry should support at minimum:

- processor type/backend
- display name
- executable path override
- additional arguments
- test action
- enable/disable
- delete

This gives the user a mental model closer to "I manage my processor apps here" rather than "I fill one global advanced form."

### Sheet Behavior

The processor manager sheet should feel lightweight and natural to navigate.

Recommended characteristics:

- presented as a sheet anchored to the settings window
- vertically scrollable
- comfortable for incremental editing
- supports multiple processor entries without crowding the main settings page
- preserves the active selection state when reopened

The first implementation can still keep the actual runtime selection simple, but the information architecture should be prepared for multiple stored processor entries.

### Backend-Specific Arguments

Users should be able to add backend-specific arguments for a selected external processor.

For the first version, this should be supported for Alma CLI as:

- `Additional Arguments`

Examples:

- `-m openai:gpt-5`
- `--temperature 0.2`

This should be treated as backend-specific configuration, not as a full custom shell command.

To keep execution safe and predictable:

- VoicePi should invoke processes with argv arrays, not through a shell
- user-supplied arguments should be appended as parsed argv items, not string-interpolated into a shell command
- obviously incompatible flags should be rejected in validation for the selected backend

For Alma CLI, examples of incompatible flags include:

- `--help`
- `-l`
- `--list-models`
- `-v`
- flags that intentionally turn the command into a non-completion mode

The exact allowlist/denylist can evolve, but the first version should explicitly protect the one-shot refinement contract.

### Result Presentation

External-processor refinement should not directly overwrite the user's target field by default.

Instead, VoicePi should show a centered result review panel after the external processor returns.

Recommended panel behavior:

- centered on screen
- roughly one-third of screen width and height
- large editable or selectable result text area
- actions:
  - `Insert`
  - `Copy`
  - `Retry`
  - `Dismiss`

`Insert` means "send this reviewed result back to the original target input field."

This review step is especially important for external processors because they may rewrite content more aggressively than raw dictation.

### Home Summary

The home/settings summary should reflect both the provider family and the concrete backend when applicable. Example summary strings:

- `Text processing: Refinement via LLM • Target English • Prompt Meeting Notes • LLM configured`
- `Text processing: Refinement via External Processor • Backend Alma CLI • Target English • Prompt Meeting Notes • Available`
- `Text processing: Refinement via External Processor • Backend Alma CLI • Target English • Prompt VoicePi Default • Unavailable`

## Prompting Contract

VoicePi should continue to use its existing prompt-selection system.

### Prompt Source

The prompt passed to Alma should come from the resolved VoicePi prompt preset. This keeps prompt selection, strict mode, and app/site bindings unchanged.

### Default Prompt Fallback

Unlike the current OpenAI-compatible refinement path, external processors cannot rely on VoicePi's internal HTTP prompt builder alone. If the resolved prompt preset contributes no editable middle section, VoicePi should supply a built-in fallback prompt for external refinement.

That fallback should instruct Alma to:

- preserve meaning
- remove filler words and self-corrections
- fix obvious speech recognition errors
- produce natural final text
- avoid meta commentary
- output only the final refined content

### Target Language Handling

Current VoicePi behavior allows refinement mode to fold translation into refinement when the selected target language differs from the recognition language.

That behavior should remain intact for external refinement. If the target language differs from the source language, VoicePi should append a concise output-language instruction to the external prompt instead of silently dropping the target-language setting.

## Runtime Architecture

### New Abstractions

Add a small command-backed refinement seam rather than wiring `Process` calls directly into `AppCoordinator`.

Recommended concepts:

- `RefinementProvider`
- `ExternalProcessorKind`
- `CLITranscriptRefining`
- `ExternalProcessorRefiner`
- `AlmaCLIRefiner`
- `ResultReviewPresentation`

Responsibilities:

- `AppModel` stores which provider family and backend are selected
- `AppWorkflowSupport` chooses the correct refinement path
- `ExternalProcessorRefiner` defines the common command-backed path
- `AlmaCLIRefiner` owns Alma-specific command construction
- `AppCoordinator` remains responsible for the overall recording lifecycle and UI status updates
- result presentation stays inside VoicePi, not inside the processor UI

### Alma CLI Command Shape

The first concrete backend should execute Alma with this baseline behavior:

```bash
alma run --raw --no-stream "<resolved prompt>"
```

Transcript text is written to `stdin`.

The command result is taken from `stdout`, trimmed, and used as the refined text. If the output is empty after trimming, VoicePi should fall back to the original transcript.

### Model Override

The first version should **not** add an Alma-specific model override field. VoicePi should use Alma's current default model. This keeps the first integration focused and avoids duplicating Alma's own provider/model configuration UI.

If users need model override or other Alma flags, they can provide them through backend-specific additional arguments instead of a dedicated Alma-only field in Phase 1.

### Command Composition

For Alma CLI, the effective command should be composed as:

```bash
alma run --raw --no-stream [user additional args...] "<resolved prompt>"
```

The implementation should define a stable merge order:

1. executable name or configured executable path
2. required subcommand and VoicePi-owned flags
3. validated user additional args
4. resolved prompt

VoicePi-owned flags should retain priority for the base contract. If user-provided args conflict with required behavior, validation should fail rather than silently producing ambiguous execution.

## Processor Test And Validation

VoicePi should expose a backend-specific `Test` action so users can verify that their selected processor and additional arguments actually work.

### Test Goal

The test should answer:

- is the executable available?
- do the supplied arguments produce a valid one-shot completion?
- does the backend return a usable result without hanging?

### Test Behavior

For Alma CLI, the test should run a lightweight completion using the exact configured executable and validated additional arguments.

Suggested shape:

- prompt argument: a fixed short instruction such as `Reply with OK only.`
- stdin payload: a tiny sample transcript such as `test`
- timeout: short and bounded

Success criteria:

- process launches
- exits with status 0
- returns non-empty stdout

Failure criteria:

- executable missing
- invalid or conflicting args
- timeout
- non-zero exit
- empty stdout

### Test Output

The settings UI should show a concise result, for example:

- `Processor test passed.`
- `Processor test failed: alma command not found.`
- `Processor test failed: --help is incompatible with one-shot refinement.`
- `Processor test failed: command timed out.`

The goal is not to prove model quality. The goal is to prove that the configured backend invocation contract is valid.

## Error Handling

### Missing CLI

If the selected processor executable is not found in `PATH`, VoicePi should:

- show a clear transient error
- keep the original transcript
- avoid crashing or hanging

Suggested user-facing wording:

- `External processor failed: alma command not found.`

### Command Failure

If the process exits non-zero or stderr indicates failure, VoicePi should:

- report a transient error
- preserve the original transcript
- keep the rest of the recording flow intact

### Timeout

The first version should include a bounded timeout for the CLI run. A stuck CLI process must not block VoicePi indefinitely.

On timeout:

- terminate the child process
- show a transient error
- fall back to the original transcript

### Empty Output

If the external processor returns empty output:

- do not inject an empty string
- use the original transcript instead

## Status Presentation

The current overlay already shows a refining phase. That should remain.

When external refinement is active, status text should identify the backend. Example:

- `Refining with Alma CLI`
- `Refining with Meeting Notes via Alma CLI`

The goal is to make the runtime path understandable without adding new windows or overlays.

After refinement succeeds, the overlay should give way to the centered result review panel rather than immediately injecting text.

## Persistence

The selected refinement provider family and external backend should be stored in `AppModel` alongside existing post-processing settings.

This should persist across reloads, just like:

- `postProcessingMode`
- `translationProvider`
- `targetLanguage`
- `promptWorkspace`

No separate Alma credential storage is needed for the first backend because Alma CLI reads its own local app state.

Additional backend arguments should also persist with the selected processor configuration.

When the processor-manager sheet is introduced, VoicePi should persist a list of configured processor entries rather than only one global backend record.

## Testing Scope

The implementation should be covered by tests before production changes land.

Minimum expected test coverage:

### App model and persistence

- selected refinement provider family persists across reloads
- selected external backend persists across reloads
- selected additional backend arguments persist across reloads
- multiple configured processor entries persist in stable order
- existing users without the new key default to `LLM`

### Workflow routing

- refinement mode uses the LLM path when provider is `LLM`
- refinement mode uses the external-processor path when provider is `External Processor`
- the external-processor path dispatches to Alma when backend is `Alma CLI`
- translation mode remains unaffected

### Alma command execution

- builds the expected command arguments
- merges validated user additional args in the correct position
- writes transcript text to `stdin`
- returns trimmed `stdout`
- falls back on empty output
- surfaces missing-command and non-zero-exit failures
- rejects incompatible backend args
- applies timeout behavior

### Result review presentation

- successful external refinement opens the centered review panel
- `Insert` sends the reviewed text back to the original target
- `Copy` leaves the original target untouched
- `Dismiss` abandons the result without injection

### Settings presentation

- home/settings summary reflects the selected refinement provider
- feedback messaging explains when Alma CLI is selected but unavailable

## File Impact

This is not an implementation plan, but the likely code touch points are:

- `Sources/VoicePi/AppModel.swift`
- `Sources/VoicePi/AppWorkflowSupport.swift`
- `Sources/VoicePi/AppCoordinator.swift`
- `Sources/VoicePi/StatusBarController.swift`
- new Alma CLI executor/refiner source file
- targeted tests under `Tests/VoicePiTests/`

## Settings Evolution

### Phase 1 settings

Keep setup lightweight in the existing "Text Processing" section:

- `Refinement Provider`
- `External Backend` when needed
- `Additional Arguments`
- `Test`

### Phase 2 settings

Add a dedicated settings tab for managing external processors. That tab can later include:

- installed or available processor backends
- backend-specific health checks
- optional backend-specific settings
- future non-Alma processors
- a scrollable sheet-based manager opened from the tab
- `+` to add a new processor entry
- multiple saved processor profiles

## Rollout Plan

### Phase 1

Add the generic external-processor refinement path with `Alma CLI` as the first backend.

### Phase 2

If stable, add more concrete backends such as Codex CLI or other one-shot transcript processors.

### Phase 3

Only if needed, add:

- Alma model override
- custom CLI timeout
- additional backend-specific options

## Open Questions

These are explicitly deferred, not blockers for Phase 1:

1. Which second backend should follow Alma first?
2. Should the app surface an "Install Alma CLI" helper if `alma` is missing?
3. Should external processors eventually be allowed for translation, not only refinement?
4. Should backend-specific arguments be entered as a single string, chips, or one-arg-per-line fields?
5. Should the result review panel become optional per backend in the future?
6. Should processor entries be selectable globally, per prompt preset, or both?

## Recommendation

Implement this as a focused external-processor refinement architecture, not as a plugin system and not as a general shell-command executor.

That gives VoicePi a concrete user-facing win now, keeps the architecture coherent with the existing prompt system, leaves room for a future dedicated settings tab, and preserves a clean path toward multiple CLI-backed processors later.
