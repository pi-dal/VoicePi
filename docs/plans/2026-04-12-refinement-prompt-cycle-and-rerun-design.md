# Refinement Prompt Cycle And Rerun Design

**Date:** 2026-04-12

## Goal

Add a first-class prompt switching workflow for refinement so VoicePi users can:

1. quickly cycle refinement prompts before recording without opening settings
2. rerun refinement against the same captured transcript after recording with a different prompt

The first version should make both entry points work together through one coherent prompt-session model instead of adding two unrelated features.

## Problem

VoicePi already has a capable prompt system:

- `Active Prompt` selection
- starter and user prompt presets
- app and website bindings
- `Strict Mode` runtime routing

VoicePi also already has:

- a mode-cycle shortcut
- a processor shortcut
- a centered review panel for external-processor refinement

What is missing is a fast operational workflow for prompt iteration.

Today, if the user wants a different refinement style, they must manually change the prompt selection in settings or the menu before recording. If the result is wrong after recording, there is no explicit product flow for "use the same source transcript again, but refine it with another prompt."

This creates two separate user pains:

1. recording-time friction when the user already knows they want a different prompt
2. post-result friction when the user wants to salvage a good transcript by trying another prompt instead of dictating again

## Product Decision

VoicePi should support both of these workflows in the first version:

1. a dedicated prompt-cycle shortcut for pre-recording switching
2. prompt selection plus regenerate inside the review panel for post-recording reruns

These are not separate systems. They should share one refinement prompt state model.

## Core Principle

Every rerun must start from the original recognized transcript, never from the previous refined output.

For one capture session, VoicePi should conceptually track:

- `rawTranscript`
- `selectedPromptPreset`
- `currentResultText`

When the user changes the prompt and reruns, VoicePi should:

1. keep `rawTranscript`
2. resolve the newly selected prompt
3. rerun refinement from `rawTranscript`
4. replace only `currentResultText`

This prevents stacked rewrites, keeps prompt behavior predictable, and matches the user expectation that they are trying multiple prompt styles against the same original wording.

## UX Direction

### Shortcut Entry Point

Add a new global shortcut:

- `Prompt Cycle Shortcut`

This shortcut only changes the refinement prompt selection. It does not change:

- post-processing mode
- refinement provider
- target language
- ASR backend

It should work independently from the existing:

- recording shortcut
- mode-cycle shortcut
- processor shortcut

### Review Entry Point

Upgrade the result review panel into a lightweight prompt-rerun surface:

- show the current prompt title
- let the user choose another prompt preset
- let the user regenerate the result against the same original transcript
- keep a single current result view

The first version should not become a diff tool, prompt editor, or multi-version comparison workspace.

## Prompt Cycle Rules

### Cycle Scope

The prompt-cycle shortcut should rotate through the same prompt choices the user can manually select today:

1. `VoicePi Default`
2. starter prompts
3. user prompts

The first version should not introduce favorites or pinned prompt subsets.

### Cycle Order

The order must be stable and predictable.

Recommended order:

1. built-in default
2. starter prompts in the same order exposed by the current UI/library
3. user prompts in the same order exposed by the current UI

The order should not be based on:

- recent use
- dynamic matching
- runtime success/failure

Users need to build muscle memory for cycling.

### Shortcut Interaction Style

The prompt-cycle shortcut should be press-to-advance, not hold-to-repeat.

Reasoning:

- prompt lists are longer than the three mode-cycle states
- repeated advance is harder to control with long text labels
- overshooting a prompt is more expensive than overshooting a mode

One key press should advance exactly one prompt.

### Overlay Feedback

After each cycle action, VoicePi should show a short-lived visual confirmation.

For the first implementation, reuse existing presentation surfaces:

- floating mode-switch HUD (to keep interaction consistent with existing shortcut feedback)
- transient status text (for explicit copy like `Prompt default: ...`)

Do not add a brand-new overlay system in this slice.

Recommended shape:

- `Prompt: Meeting Notes`

If the user is currently in a context where `Strict Mode` would still route refinement to a bound prompt, the feedback should make it clear that the default selection changed, not necessarily the effective bound prompt for the current app.

Recommended shape:

- `Prompt default: Meeting Notes`

The first version does not need a separate panel for browsing prompt choices from the shortcut alone.

### Interaction With Post-Processing Mode

Prompt cycling should still work when VoicePi is not currently in `Refinement` mode.

This lets the user prepare the next refinement prompt in advance without first switching modes.

## Strict Mode And Binding Rules

The new feature must preserve the existing prompt-routing model.

### Recording-Time Resolution

When the user cycles prompts before recording, VoicePi should only update the global manual `Active Prompt` selection.

It should not:

- clear app bindings
- disable `Strict Mode`
- force runtime override of bound prompts

So runtime behavior remains:

1. if `Strict Mode` is enabled and the destination matches a binding, use the bound prompt
2. otherwise use the active manual prompt selection

This keeps prompt cycling consistent with the existing meaning of `Strict Mode`.

### Review-Time Resolution

The review panel is different.

Once the user explicitly opens a result and intentionally chooses another prompt for that result, VoicePi should honor that explicit selection for the current review session, even if `Strict Mode` would normally route the active app to a bound prompt.

That review-time prompt choice should behave as a session-scoped override, not as a global change to binding behavior.

In other words:

- pre-recording cycle updates the global manual prompt selection
- review-panel rerun uses an explicit session override

This separation keeps the runtime model coherent while still letting the user intentionally experiment with other prompts after the transcript already exists.

## Review Panel Changes

### Current Problem In The Existing Panel

The current review panel payload uses `sourceText` as the displayed `Prompt` content.

That is misleading for this feature. The source transcript is not the refinement prompt.

The panel vocabulary and data model must be corrected before adding prompt rerun controls.

### First-Version Panel Goals

The review panel should support these tasks:

1. inspect the current result
2. see which prompt produced it
3. switch to another prompt preset
4. regenerate from the original transcript
5. insert or copy the currently displayed result

### First-Version Non-Goals

The review panel should not support:

- prompt body editing
- side-by-side result comparison
- version history
- result diff views
- freeform prompt text input

### Recommended Interaction

The panel should expose:

- current prompt title
- prompt picker control
- `Regenerate` button
- current result text
- existing insert, copy, and dismiss actions

The first version should not auto-regenerate on prompt selection change.

Instead:

1. user chooses a different prompt
2. user presses `Regenerate`
3. VoicePi reruns refinement with the session's original transcript

This avoids accidental repeated LLM or processor runs while the user is just browsing choices.

### Loading Behavior

While regenerate is running:

- keep the existing result visible
- disable repeated regenerate actions
- show loading state in the button or status text

If regenerate succeeds:

- replace the displayed result
- update the displayed prompt title

If regenerate fails:

- keep the previous displayed result
- show a transient error
- keep the panel open

### Original Transcript Exposure

The original transcript must remain in session state for reruns.

The first version does not need to dedicate major panel space to showing it all the time.

If needed, VoicePi may later add:

- `Copy Original`
- `View Original`

But those are not required for the first version.

## Provider Support

The rerun path should support the same refinement providers the initial refinement path already supports:

- `LLM`
- `External Processor`

The product should not force the review rerun experience to be processor-only.

If the user reached a reviewable refinement result, they should be able to rerun that same source transcript with another prompt through the active refinement provider path for the review session.

Implementation note for coherence:

- entering review should be available for refinement results from both `LLM` and `External Processor`
- review reruns should reuse the workflow snapshot captured when the review session was created (instead of silently drifting if settings change while the panel is open)

## Architecture

### Review Session Model

Introduce an explicit review-session state instead of scattering rerun data across loosely related pending fields.

Suggested shape:

```swift
struct RefinementReviewSession {
    let rawTranscript: String
    var selectedPromptPresetID: String
    var selectedPromptTitle: String
    var currentResultText: String
    let targetSnapshot: EditableTextTargetSnapshot?
    let sourceApplication: NSRunningApplication?
    let recordingDurationMilliseconds: Int
    let workflow: AppController.ProcessingWorkflowSelection
    let workflowOverride: AppController.RecordingWorkflowOverride?
}
```

The exact type names can change, but the model should explicitly separate:

- the immutable source transcript
- the selected prompt for the session
- the currently displayed result

### Prompt Resolution Override

The refinement path should accept an optional prompt override for reruns.

The cleanest boundary is to extend the coordinator-driven refinement path so both of these use the same pipeline:

1. initial post-recording refinement
2. review-panel regenerate

That means `AppController.refineIfNeeded(_:)` should gain an override path for prompt selection or fully resolved prompt data, instead of forcing every call to re-read only the current global model selection.

When an explicit review-session prompt is chosen, resolution should bypass strict-mode destination binding and use the chosen preset directly for that rerun.

### AppModel Responsibilities

`AppModel` should own the prompt-cycle list and prompt selection mutation.

Suggested responsibilities:

- produce the ordered cycleable prompt list
- return the next prompt selection from the current manual selection
- update the persisted active manual prompt selection

This keeps prompt ordering logic out of the UI and coordinator layers.

### AppCoordinator Responsibilities

`AppController` (coordinator role) should own:

- recording-time prompt cycle shortcut handling
- review-session lifecycle
- rerun dispatch
- error handling
- overlay and status updates

The coordinator should stay responsible for deciding whether a rerun uses:

- global manual prompt resolution
- explicit review-session override

### Result Review Panel Responsibilities

`ResultReviewPanelController` should remain a UI surface, not a refinement engine.

It should emit user intents such as:

- prompt selection changed
- regenerate requested
- insert requested
- copy requested
- dismiss requested

The controller should not directly resolve prompts or call providers.

## Data Flow

### Recording-Time Flow

1. user cycles prompt with the new shortcut
2. VoicePi updates the manual active prompt selection
3. VoicePi shows short overlay feedback
4. user records normally
5. VoicePi resolves the effective prompt for the capture context
6. VoicePi runs refinement normally

### Review-Time Flow

1. VoicePi creates a review session after a reviewable refinement result is produced (`LLM` or `External Processor`)
2. session stores the original transcript and the prompt that produced the current result
3. user changes prompt selection in the review panel
4. user presses `Regenerate`
5. VoicePi reruns refinement from the original transcript using the session override
6. VoicePi replaces only the current result in the same panel
7. insert action inserts the currently displayed result

## Error Handling

### Shortcut Path

If no prompt list can be produced, VoicePi should do nothing and avoid corrupting prompt state.

If prompt library loading fails, VoicePi should fall back to the built-in default prompt list shape as safely as possible.

### Review Rerun Path

If the session has no original transcript:

- disable regenerate
- keep the panel usable for copy/insert if a result already exists

If rerun fails:

- keep the previous result
- keep the current panel open
- show an error message

If rerun returns empty text:

- treat it as a failed rerun for panel refresh purposes
- keep the previous result visible
- surface a user-facing error or warning

The first version should not replace a usable displayed result with an empty response.

## Settings And Presentation Updates

The settings and home presentation surfaces should be updated where needed so users can understand that prompt selection is now operationally switchable outside the settings form.

At minimum:

- add a prompt-cycle shortcut setting with help text similar to other shortcut settings
- ensure transient status and floating panel copy distinguish prompt switching from mode switching
- ensure review panel labels refer to prompt titles, not source transcript text

## Testing Strategy

Use TDD.

Coverage should include:

1. prompt-cycle ordering across built-in, starter, and user prompts
2. cycle wraparound behavior from last item back to first
3. prompt-cycle mutation updates the active manual selection only
4. `Strict Mode` runtime resolution still honors bindings after prompt-cycle changes
5. review-session regenerate uses the original transcript, not the current refined result
6. review-session regenerate updates the displayed result on success
7. regenerate failure preserves the previous result
8. empty regenerate output preserves the previous result
9. review panel presentation state exposes prompt title separately from source transcript
10. both `LLM` and `External Processor` refinement paths support rerun through the same session model

## Non-Goals

This spec does not include:

- prompt favorites or pinned cycle subsets
- multiple direct prompt shortcuts
- automatic regenerate on prompt selection change
- side-by-side comparison of multiple refined outputs
- prompt body editing from the review panel
- translation prompt cycling
- per-app custom prompt-cycle lists
- a general prompt history browser

## Rollout Recommendation

Implement this in two internal slices under one user-facing feature:

1. prompt-cycle shortcut and prompt-ordering support
2. review-session rerun support and panel updates

Both slices should ship together because the product value depends on the user being able to switch prompts both before and after recording.

## Summary

VoicePi should treat refinement prompt iteration as a first-class workflow.

The right first version is not shortcut-only and not review-only. It is a shared model with two entry points:

- pre-recording prompt cycling for speed
- post-recording rerun for recovery and experimentation

The implementation should preserve the existing `Strict Mode` rules for normal recording-time routing while allowing the review panel to apply an explicit session-scoped prompt override for the current captured transcript.
