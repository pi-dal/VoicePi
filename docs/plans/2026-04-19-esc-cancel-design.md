# Esc Cancellation Design

**Status:** Superseded by `docs/plans/2026-04-19-configurable-cancel-shortcut-design.md`

This earlier design assumed a dedicated `Esc` path plus a hard-coded fallback shortcut. VoicePi now ships a single configurable **Cancel Shortcut** setting, defaults it to `Control + .`, and treats bare `Esc` as an advanced opt-in shortcut with explicit permission guidance.

## Goal

Let users cancel the current VoicePi capture or processing run quickly, using `Esc` when permissions allow it and a reliable `Command + .` fallback when they do not.

## Scope

This change covers the active capture pipeline only:

- recording startup
- active recording
- post-stop processing such as remote transcription, refinement, and external processor execution

This change does not alter existing `Esc` handling in result/review panels, and it does not add a new settings control.

## Product Decision

VoicePi should support temporary global cancel actions only while a capture session is active.

The behavior should be:

1. during recording startup, `Command + .` and `Esc` cancel the in-flight session immediately
2. during active recording, the same cancel shortcuts abort immediately and skip stop-time transcription
3. during post-stop processing, the same cancel shortcuts cancel the processing task, clear transient state, and hide the overlay
4. when VoicePi is idle, the temporary cancel shortcuts are not monitored

## Permission Model

Global `Esc` cancellation is implemented only when both Accessibility and Input Monitoring are granted.
Global `Command + .` cancellation is implemented through the registered-hotkey path and does not depend on Input Monitoring.

Rationale:

- a bare `Esc` key requires event tap monitoring rather than Carbon hotkey registration
- without Accessibility, VoicePi cannot suppress the frontmost app's own `Esc` handling
- without Input Monitoring, VoicePi cannot reliably observe the bare global `Esc` key at all
- dual delivery is too risky for cancellation because it can dismiss unrelated UI in the frontmost app

This design therefore prefers predictable behavior over partial availability.

## Architecture

Add a dedicated temporary shortcut monitor owned by `AppController` for `Esc`.
Add a second dedicated temporary shortcut monitor for `Command + .`.

The monitor should:

- be configured with an `ActivationShortcut` for key code `53` and no modifiers
- only run while a cancellable recording workflow is active
- use the same monitor planning machinery already used by the other shortcuts
- use `.listenAndSuppress` when both Accessibility and Input Monitoring are granted
- stay disabled otherwise

The command-period monitor should:

- use the standard registered-hotkey path
- stay active during the same cancellable workflow window
- route into the same cancellation handler as `Esc`

`AppController` should own the lifecycle and centralize the cancellation target so all paths produce the same cleanup semantics.

## State Wiring

Enable the `Esc` monitor when any of the following is true:

- `isStartingRecording`
- `speechRecorder.isRecording`
- `isProcessingRelease`

Disable it when the session ends through success, failure, or cancellation.

The action target should branch like this:

1. if startup is still in progress, cancel startup and hide UI
2. else if recording is active, reuse the existing immediate-cancel path
3. else if post-stop processing is active, reuse `cancelProcessingAndHideOverlay()`
4. else ignore

## Testing

Add tests before implementation for:

- the monitor plan for bare `Esc`
- the decision to enable the monitor only when Accessibility is granted
- the action routing for startup, recording, processing, and idle states

Keep the tests focused on `AppController` decision logic so the behavior is locked without requiring UI event injection.

## Implementation Notes

The shipped implementation adds:

- a dedicated temporary `ShortcutActionController` for bare `Esc`
- a dedicated temporary `ShortcutActionController` for `Command + .`

Both monitors are enabled only while a cancellable recording workflow is active and both route into the same shared startup, recording, and processing cancellation paths in `AppController`.
