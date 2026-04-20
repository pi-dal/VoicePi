# Configurable Cancel Shortcut Design

**Status:** Approved

## Goal

Make capture cancellation configurable through Settings, default it to `Control + .`, and treat bare `Esc` as an advanced opt-in shortcut with explicit permission guidance.

## Problem

The temporary cancel action is currently too tied to bare `Esc`.

That creates two product issues:

1. bare `Esc` is a poor default because it depends on the event-tap path rather than the standard registered-hotkey path
2. when the required permissions are missing, `Esc` cancellation can look broken instead of intentionally unavailable

The user expectation is simpler:

- cancellation should work by default
- bare `Esc` should still be possible for users who want it
- Settings should explain the tradeoff before the user relies on it

## Product Decision

VoicePi should expose a dedicated `Cancel Shortcut` setting alongside the existing recording, mode-switch, prompt-cycle, and processor shortcuts.

The default value should be:

- `Control + .`

Behavior policy:

1. the configured cancel shortcut is only active while VoicePi is starting a recording, actively recording, or post-processing a captured result
2. the configured cancel shortcut is not monitored while VoicePi is idle
3. standard one-key-plus-modifier shortcuts should use the registered-hotkey path
4. advanced shortcuts, including bare `Esc`, should use the event-tap path and surface their permission requirements clearly

## Permission Model

Default `Control + .` should work as a standard registered hotkey and should not require Input Monitoring.

If the user changes the cancel shortcut to bare `Esc`:

- VoicePi should treat it as an advanced shortcut
- Settings should immediately explain that `Esc` requires Input Monitoring for listening
- Settings should also explain that Accessibility is required if VoicePi needs to suppress the key before it reaches the frontmost app

This keeps the default path reliable while still supporting `Esc` for users who explicitly choose it.

## Settings UX

Add a new recorder row:

- `Cancel Shortcut`

Copy rules:

- unset is not allowed; if the user clears the field, restore the current configured value
- standard shortcut copy should say cancellation works without Input Monitoring
- advanced shortcut copy should say Input Monitoring is required and Accessibility enables suppression
- bare `Esc` should use the strongest copy, explicitly calling out that it is an advanced global key and may need both permissions

The row should live with the other shortcut settings on the Home / General page so users discover it naturally.

## Architecture

### AppModel

Persist a fifth shortcut:

- `cancelShortcut`

Default it to `Control + .` and persist it exactly like the other shortcuts.

### Runtime Monitor

Replace the current hard-coded cancel monitor setup with one monitor driven by `model.cancelShortcut`.

The planner should:

- choose registered hotkey for standard shortcuts
- choose event tap for advanced shortcuts
- reuse the current active-session-only lifecycle

The action routing stays the same:

- cancel startup
- cancel active recording
- cancel post-stop processing

## Testing

Add tests for:

- `AppModel` default and persistence of `cancelShortcut`
- monitor planning for standard cancel shortcuts versus bare `Esc`
- settings hint copy for default standard cancel shortcuts and for `Esc`
- README and design docs matching the shipped behavior
