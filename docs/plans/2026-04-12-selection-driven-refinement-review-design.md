# Selection-Driven Refinement Review Design

**Date:** 2026-04-12  
**Status:** Implemented on `feat-refinement-prompt-cycle-rerun`  
**Supersedes:** `docs/plans/2026-04-12-refinement-prompt-cycle-and-rerun-design.md`

## Goal

Keep recording as the fastest default path, while making post-insertion rewrite and prompt rerun easy through text selection.

## Product Decision

The review panel is no longer a recording-completion panel.  
Recording now remains direct:

1. Record.
2. Resolve transcript + post-processing as usual.
3. Insert directly into the active target.
4. Optionally reopen rewrite/review from selection.

## Entry Points

### 1. Auto-open for recent VoicePi insertion

After successful direct injection, VoicePi tracks a short-lived recent-insertion session.

Auto-open is eligible only when all conditions are met:

1. Same editable target identity.
2. Current contiguous selection exactly matches normalized inserted text.
3. Selection stays stable for a short delay.
4. Session is still inside watch window.
5. Auto-open has not already been consumed for that session.
6. Review panel is not already visible.

Defaults:

- Watch window: `8s`
- Stabilization delay: `350ms`

### 2. Manual invoke via existing activation shortcut

When idle, activation shortcut is context-sensitive:

1. Recording -> keep stop behavior.
2. Processing -> keep cancel behavior.
3. Idle + confirmed non-empty selection in editable target -> start selection rewrite.
4. Otherwise -> start normal recording.

If the selection matches an active recent-insertion session, manual invoke reuses that session context.

## Rewrite Source Model

Two source types are supported:

1. **Recent insertion source**
   - keeps: `rawTranscript`, `insertedText`, `appliedPromptPresetID`, `targetIdentifier`, `sourceApplicationBundleID`, `injectedAt`
   - rerun source is `rawTranscript`
2. **Ad hoc selected text source**
   - source is current `selectedText`
   - rerun source is selected text itself

## Review Panel Semantics

Shared panel fields:

- `Original`
- `Prompt`
- `Result`
- `Regenerate`
- `Replace Selection`
- `Copy`
- `Dismiss`

Initial state by source:

- **Recent insertion**
  - Original = preserved `rawTranscript`
  - Result = already inserted text
  - Prompt = prompt used at insertion time
- **Ad hoc selection**
  - Original = selected text
  - Panel immediately runs rewrite before showing success state
  - Panel does not open as fake success when rewrite cannot actually run

## Replace Selection Safety

On review start, capture a selection anchor:

- `targetIdentifier`
- `selectedText`
- `selectedRange`
- `sourceApplicationBundleID`

On `Replace Selection`:

1. Reactivate source app (if needed).
2. Validate current selection against anchor.
3. If needed and supported, restore saved selected range via AX.
4. Re-validate selected text/range.
5. Inject replacement text.

If validation/restoration fails, keep panel open and show:

`Selection changed. Re-select the text and try again.`

No cursor-only blind paste fallback is allowed for this flow.

## Accessibility/Inspection Contract

`EditableTextTargetInspector` must expose:

- full text (`kAXValueAttribute`)
- selected text (`kAXSelectedTextAttribute`)
- selected range (`kAXSelectedTextRangeAttribute`)
- whether selection range is settable/restorable

Targets that lack reliable selection support:

1. still support normal recording/injection
2. do not support selection-driven auto-open
3. do not trigger manual rewrite without confirmed non-empty selection

## Monitoring Model

Keep dictionary-learning observation logic and recent-insertion rewrite eligibility as sibling tracks:

- dictionary track: learns post-injection edits
- rewrite track: watches stable exact selection of recent inserted text

`AppController` drives both in the same polling loop.

## Guardrails

Per recent-insertion session:

1. auto-open at most once
2. no auto-open while panel is visible
3. dismiss does not re-enable auto-open for same session
4. expiry removes session
5. target change removes session

Manual invoke remains available after auto-open is consumed.

## Resolved Decisions

1. Watch window is `8s` (not `10s`).
2. Version 1 restore strategy uses AX selected-range restoration (`kAXSelectedTextRangeAttribute`).
3. Manual rewrite remains selection-first and does not introduce a new dedicated shortcut.
