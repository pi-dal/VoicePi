# Input Fallback Service Panel Design

**Date:** 2026-04-07

## Goal

Preserve recognized speech when VoicePi cannot inject into a frontmost input field, and give the user an immediate fallback path that lets them copy the final text without losing the recording result.

## Problem

Today the recording flow always ends by calling `TextInjector.inject(text:)`. That path assumes the frontmost target can accept a pasted `Cmd+V` event. When the user triggers recording without a focused editable input, the speech result is still recognized and refined correctly, but the app has no guardrail before paste injection. The text is effectively wasted because VoicePi does not detect the missing input target or preserve the result in a user-actionable UI.

## UX Direction

VoicePi should treat transcript delivery as a two-step decision:

1. Produce the final text through ASR and optional post-processing.
2. Decide how to deliver that text based on the frontmost focus target.

The preferred path remains unchanged: if the current focus is an editable text control, VoicePi pastes the text directly.

When VoicePi does not detect an editable input target, it should not attempt a blind paste. Instead, it should open a dedicated fallback service panel that:

- appears automatically after recording completes
- uses the same visual language as the existing recording floating panel
- supports both light mode and dark mode
- shows a compact summary by default
- lets the user expand to inspect the full text
- offers a single `Copy` action
- copies the full final text, then closes immediately

This preserves the result and keeps the interaction predictable.

## Delivery States

The delivery stage should resolve to one of three states:

- `emptyResult`: the final transcript is empty after trimming. VoicePi closes the recording UI and does nothing else.
- `injectableTarget`: the frontmost accessibility focus is an editable text target. VoicePi continues with the existing paste injection flow.
- `fallbackPanel`: no editable target is detected, or VoicePi cannot confidently read the focus state. VoicePi skips paste injection and presents the fallback service panel instead.

Treating accessibility inspection failures as `fallbackPanel` is intentional. In this flow, preserving text is better than gambling on a paste that may land in the wrong place.

## Architecture

The change should keep responsibilities narrow:

- `AppController` remains the orchestration point for recording, post-processing, and final delivery.
- A new focus-target inspection component should determine whether the frontmost accessibility focus is editable.
- `TextInjector` should continue to own only clipboard preservation, input source switching, and `Cmd+V` simulation after a target is already known to be injectable.
- A new fallback service panel controller should own display state, expand/collapse behavior, copy handling, and theme updates.

This separation avoids mixing accessibility detection into the paste engine and keeps the fallback UI independent from the recording overlay.

## App Flow

`AppController.endRecordingAndInject()` should change from a single direct injection path into a guarded delivery flow:

1. Stop recording and resolve the final transcript.
2. Trim and drop empty results.
3. Run optional refinement or translation.
4. Ask the new target inspector whether the current focus is editable.
5. If editable, call `TextInjector.inject(text:)` and keep the current success status behavior.
6. If not editable, hide the recording floating panel, preserve the final text in memory, and present the fallback service panel.

The fallback path should not be treated as an error. It is a deliberate alternate delivery mode, so the app should avoid showing failure copy such as an injection error unless the clipboard copy action later fails.

## Fallback Service Panel

The fallback service panel should be a dedicated `NSPanel`, not a reused recording panel mode. The recording panel is non-interactive today (`ignoresMouseEvents = true`), while the fallback panel needs direct user interaction.

The panel should follow these interaction rules:

- It appears near the same bottom-center location as the recording panel.
- It becomes the only visible delivery surface after recording completes.
- It opens in a collapsed summary state.
- It exposes an expand/collapse affordance only when the transcript is long enough to need it.
- It copies the full final text, not the summary text.
- It closes immediately after a successful copy.

Suggested copy:

- Title: `未检测到输入框`
- Description: `这次语音结果没有自动输入，你可以先复制再粘贴。`
- Button: `Copy`
- Toggle: `展开全文` / `收起全文`

## Visual Design And Theme

The fallback panel should align with the current recording floating panel rather than introducing a second design system. It should reuse the same appearance-driven palette approach so the panel responds correctly to both supported modes:

- `Light mode`
- `Dark mode`

Theme behavior should cover the panel background, border, title, description, transcript text, expand/collapse affordance, and `Copy` button. The panel should also react to runtime appearance changes, matching the behavior users already see in the recording overlay.

## State Management

The app should keep at most one pending fallback transcript at a time. When a new recording completes while a fallback panel is already visible, the new result should replace the previous pending text and refresh the panel content instead of stacking multiple panels.

The pending fallback payload should include:

- full final text
- collapsed summary text
- whether expansion is available
- current expansion state

This keeps UI-specific state out of the recording pipeline while making the panel easy to test.

## Constraints

- The fallback path must not interfere with the existing direct-paste flow when a valid editable target exists.
- Accessibility inspection should be conservative. If the app cannot prove the target is editable, it should prefer the fallback panel.
- The panel should not persist across launches or recordings; it only represents the most recent undelivered result.
- The new UI should reuse existing appearance conventions from the recording floating panel so light and dark presentation stay visually consistent.

## Verification

The implementation should be covered at three levels:

- pure decision tests for delivery routing (`emptyResult`, direct inject, fallback panel)
- panel presentation tests for collapsed summary state, expansion availability, and copy-close behavior
- theme-oriented tests that lock the light and dark appearance mapping used by the fallback panel

Focused verification should also cover:

- editable target detected -> injection path used
- non-editable or unreadable target -> fallback panel used
- `Copy` copies the full text and closes the panel
- long transcripts can expand to show the full content
- only one pending fallback panel exists at a time

Repository verification should end with the relevant focused Swift test runs and `./Scripts/test.sh`.
