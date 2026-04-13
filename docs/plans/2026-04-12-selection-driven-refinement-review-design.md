# Selection-Driven Refinement Review Design

**Date:** 2026-04-12
**Status:** Partially implemented
**Supersedes:** `docs/plans/2026-04-12-refinement-prompt-cycle-and-rerun-design.md`

## Goal

Keep VoicePi fast by default after recording, while still making prompt-based refinement iteration easy when the user wants it later.

## Current Branch Status

This document describes the broader target design, but the current branch implements a narrower, merge-ready slice.

Implemented on this branch:

1. a dedicated prompt-cycle shortcut that rotates the global Active Prompt before recording
2. recent-insertion tracking for exact-match selection of the latest VoicePi text in the same editable target
3. a one-shot review tooltip that lets the user reopen the review panel from the original transcript after direct insertion
4. prompt selection inside the review panel, plus regenerate state handling and retry fallback between external processors and LLM

Deferred from the original design:

1. intercepting the main activation shortcut to rewrite arbitrary selected text while idle
2. capturing and restoring AX selection ranges before replacement
3. validating or reselecting a moved selection anchor before replace

Treat the remaining sections below as the full product direction, not as a claim that every slice is already shipped in this branch.

The product should support two complementary workflows:

1. pre-recording prompt switching via the dedicated prompt-cycle shortcut
2. post-insertion rewrite/review driven by selected text, not by an automatic panel at the end of recording

## Product Decision

The previous design opened the review panel immediately after a refinement capture finished. That is no longer the desired interaction.

The new default flow is:

1. user records
2. VoicePi resolves transcript and optional refinement as usual
3. VoicePi directly inserts the result into the active field
4. VoicePi briefly remembers enough context to let the user reopen that result for prompt-based rerun

The review panel becomes a selected-text tool, not a recording-completion tool.

## User Problems

The revised design addresses three separate pains:

1. the user still wants to change refinement prompts quickly before recording
2. after direct insertion, the user may immediately realize the wording should be rerun with another prompt
3. sometimes the user wants to rewrite arbitrary selected text without dictating again

These need different entry points, but they should converge on one review surface.

## Core UX Model

### 1. Recording Stays Direct

Recording should continue to behave like the fast path:

1. hold or press the activation shortcut
2. speak
3. VoicePi inserts the final text directly

VoicePi should not interrupt this path by automatically opening the review panel after recording.

### 2. Prompt Cycle Stays Available

The dedicated prompt-cycle shortcut remains valuable.

It should continue to:

1. rotate the manual active prompt selection
2. avoid changing `Strict Mode` bindings
3. work even when the current processing mode is not `Refinement`

This still solves the "I know which prompt I want before I speak" case.

### 3. Review Becomes Selection-Driven

There are now two ways to enter the review flow:

1. auto-open after the user selects recently inserted VoicePi text within a short watch window
2. manual open by pressing the existing activation shortcut while non-empty text is selected

Both paths open the same review panel and end with replacement of the selected text.

## Entry Points

### A. Auto Review For Recent VoicePi Insertions

After VoicePi inserts text, it should keep a short-lived session describing that insertion.

If all of the following are true, VoicePi should automatically open the review panel:

1. the active editable target is still the same target VoicePi inserted into
2. the user selects text whose normalized content exactly matches the recently inserted VoicePi text
3. that selection remains stable for a short delay
4. the selection happens before the watch window expires
5. the panel has not already auto-opened for that insertion session

Recommended defaults:

- watch window: `8s`
- selection stabilization delay: `350ms`

The watch window should be short enough to feel intentional, not like persistent background surveillance.

### B. Manual Rewrite Via The Existing Activation Shortcut

The activation shortcut becomes context-sensitive when VoicePi is idle.

Press behavior should become:

1. if VoicePi is currently recording, keep the existing stop/cancel behavior
2. if VoicePi is currently processing, keep the existing cancel/ignore behavior
3. if VoicePi is idle and the current editable target has non-empty selected text, open selected-text rewrite
4. otherwise, start normal recording

This avoids adding a fourth shortcut and makes rewrite discoverable in the same place users already think of as "invoke VoicePi".

If the selected text also matches an active recent-insertion session, the manual shortcut should reuse that richer session context instead of falling back to ad hoc selected-text mode.

## Rewrite Source Model

Not every review session has the same source of truth.

### Source Type 1: Recent VoicePi Insertion

When the user selects text that VoicePi just inserted, VoicePi should preserve:

- `rawTranscript`
- `insertedText`
- `appliedPromptPresetID`
- `targetIdentifier`
- `sourceApplicationBundleID`
- `injectedAt`

For reruns in this case, the panel should refine from `rawTranscript`, not from `insertedText`.

This preserves the original value of the earlier prompt-rerun design: trying multiple prompt styles against the same recognized wording.

### Source Type 2: Ad Hoc Selected Text

When the user manually invokes rewrite on arbitrary selected text, VoicePi does not have a prior transcript session.

In that case, the source of truth is simply:

- `selectedText`

Reruns should refine from that selected text.

This is a rewrite tool, not a historical transcript recovery tool.

## Selection Matching Rules

### Auto-Open Matching

Version 1 should be strict.

Auto-open should require:

1. same editable target identity
2. exact normalized text match against the full inserted VoicePi text
3. a contiguous non-empty selection

Version 1 should not attempt:

- partial overlap matching
- fuzzy substring matching
- sentence-level guessing inside a larger paragraph

Those heuristics would make the feature unpredictable.

### Manual Shortcut Matching

Manual rewrite should work on any non-empty selected text in an editable target.

It should not require:

- recent VoicePi insertion
- watch-window eligibility
- strict content match

## Review Panel Behavior

The review panel remains the single surface for prompt rerun and confirmation.

### Shared Panel Requirements

The panel should show:

- current prompt title
- prompt picker
- original/source text
- current rewritten result
- `Regenerate`
- `Replace Selection`
- `Copy`
- `Dismiss`

The panel vocabulary should stop treating the source text as "Prompt". The source text is the rewrite input. The prompt picker controls the prompt preset separately.

Recommended section titles:

- `Original`
- `Prompt`
- `Result`

### Auto-Open Session Initial State

For recent VoicePi insertions:

- `Original` shows the preserved `rawTranscript`
- `Result` starts as the already inserted text
- prompt picker starts on the prompt used during the original recording

This lets the user immediately compare "what I said" vs "what got inserted" and then rerun from the original transcript.

### Manual Rewrite Initial State

For ad hoc selected text:

- `Original` shows the selected text
- prompt picker starts on the prompt VoicePi currently resolves for that target context
- the panel should begin rewriting immediately after opening

Manual shortcut invocation is expected to perform work, not just stage it. Opening a panel that still requires another explicit button press would make the shortcut feel slow and indirect.

## Replace Behavior

The confirm action must replace the captured selection, not append at the cursor.

To do this safely, VoicePi should capture a selection anchor when the review session begins:

- `targetIdentifier`
- selected text
- selected range
- source application bundle ID

On `Replace Selection`, VoicePi should:

1. reactivate the source application if needed
2. restore or validate the saved selection
3. paste the current result over that selection

If the selection can no longer be restored or validated, VoicePi should keep the panel open and show an actionable error such as:

`Selection changed. Re-select the text and try again.`

Blindly pasting at the current caret is not acceptable for this flow.

## Accessibility And Selection Inspection

The current `EditableTextTargetInspector` only reads the focused target and its full text value. That is insufficient for this design.

VoicePi should extend inspection to capture:

- full text value
- selected text
- selected text range
- whether the selected range can be restored

Recommended AX attributes:

- `kAXValueAttribute`
- `kAXSelectedTextAttribute`
- `kAXSelectedTextRangeAttribute`

If a target exposes value but not selection information, VoicePi should:

1. allow normal recording/injection behavior
2. disable selection-based auto review for that target
3. avoid presenting manual rewrite unless a non-empty selection can be confirmed

## Monitoring Model

VoicePi already has a post-injection watch loop for dictionary-learning suggestions. The new design should reuse the same general observation window idea, but not overload the dictionary suggestion logic itself.

Recommended structure:

1. keep dictionary suggestion extraction focused on text edits after insertion
2. add a sibling coordinator for recent-insertion rewrite eligibility
3. let `AppController` drive both from the same polling task when possible

This keeps responsibilities separate:

- dictionary learning watches for edits to inserted text
- rewrite review watches for stable selection of the inserted text

## State Model

Introduce a review-session model that can represent both source types.

Recommended shape:

```swift
enum RewriteSource {
    case recentInsertion(
        rawTranscript: String,
        insertedText: String,
        appliedPromptPresetID: String?
    )
    case selectedText(String)
}
```

Each live review session should also track:

- `selectionAnchor`
- `currentResultText`
- `selectedPromptPresetID`
- `appliedPromptPresetID`
- `isRegenerating`
- `isAutoOpened`

The prompt selection bug found earlier still matters here: the panel must not relabel stale output with a newly chosen prompt before regenerate completes.

## Guardrails Against Repeated Popups

Version 1 should be conservative.

For each recent insertion session:

1. auto-open at most once
2. do not auto-open while the review panel is already visible
3. after dismiss, do not auto-open again for the same insertion session
4. if the watch window expires, discard the session
5. if the focused target changes, discard the session

Manual shortcut invocation remains available even after auto-open has been consumed.

## Error Handling

### Unsupported Selection Targets

If the target is editable enough for normal paste injection but does not expose a stable selection, VoicePi should not guess. Manual rewrite should fail fast with a short error.

### LLM Or Processor Unavailable

If refinement cannot actually run, VoicePi should not open a fake-success review session populated only with unchanged text. The panel should open only when there is a real rewrite operation to show or run.

### Source App Lost

If VoicePi cannot reactivate the original app or restore the saved selection, it should keep the result in the panel and allow copy, rather than risking insertion into the wrong place.

## Non-Goals

Version 1 should not include:

- automatic review panel immediately after recording
- a new dedicated rewrite shortcut
- partial-selection auto matching
- side-by-side diffing
- multi-version history
- freeform prompt editing in the panel
- arbitrary background monitoring of non-VoicePi text selections

## Implementation Slices

### Slice 1. Selection Inspection

- extend `EditableTextTargetSnapshot`
- add selected-text and selected-range AX reads
- add tests around editable targets with and without selection support

### Slice 2. Recent Insertion Tracking

- preserve raw transcript and applied prompt metadata after direct insertion
- add a sibling coordinator for recent-insertion review eligibility
- keep the watch window short and one-shot

### Slice 3. Context-Sensitive Activation Shortcut

- intercept idle activation-shortcut press when non-empty selected text is present
- route into selected-text rewrite instead of recording
- keep recording and processing semantics unchanged in all other states

### Slice 4. Review Panel Semantics

- rename panel sections away from the current `Prompt`/`Answer` mismatch
- support both recent-insertion and ad hoc selected-text sessions
- support immediate rewrite on manual invocation

### Slice 5. Safe Replacement

- capture and restore selection anchors
- replace the original selection on confirm
- fail safely when the anchor is no longer valid

## Test Plan

Add unit coverage for:

1. activation-shortcut decision priority when VoicePi is idle vs recording vs processing
2. recent-insertion watch window expiry
3. selection stabilization timing
4. one-shot auto-open behavior
5. exact-match auto-open eligibility
6. manual rewrite on arbitrary selected text
7. rerun source text selection for recent insertion vs ad hoc selection
8. replacement refusal when saved selection can no longer be validated
9. panel prompt state staying consistent while regenerate is pending

## Open Questions

These do not block the first implementation, but should be decided during planning:

1. whether the recent-insertion watch window should be `8s` or `10s`
2. whether manual rewrite should support non-editable but copyable targets in a later version
3. whether restoring selection should be implemented through AX range setting, synthetic events, or both

## Recommendation

Implement the selected-text rewrite flow without removing the prompt-cycle shortcut. They solve different moments:

- prompt cycle helps before speaking
- selected-text review helps after insertion

That combination gives VoicePi a fast default path, a lightweight rescue path, and an explicit rewrite tool without adding shortcut sprawl.
