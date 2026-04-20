# Esc Cancellation Implementation Plan

**Status:** Superseded by `docs/plans/2026-04-19-configurable-cancel-shortcut-implementation.md`

This earlier plan targeted a dedicated `Esc` monitor without a settings-backed cancel shortcut. VoicePi now persists a configurable **Cancel Shortcut**, defaults it to `Control + .`, and uses special `Esc` guidance only when the user opts into bare `Esc`.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a temporary global `Esc` cancel action for active VoicePi capture sessions so users can abort startup, recording, or post-stop processing without adding a new shortcut setting.

**Architecture:** Reuse the existing shortcut monitor stack with a dedicated bare-`Esc` monitor that is only enabled during cancellable workflow states. Keep all cleanup in `AppController` by routing `Esc` into the current startup, recording, or processing cancellation paths instead of creating a second cleanup implementation.

**Tech Stack:** Swift, AppKit event monitoring, existing `ShortcutActionController` and `ShortcutMonitor` abstractions, Testing framework.

### Task 1: Lock Esc Monitor Policy in Tests

**Files:**
- Modify: `Tests/VoicePiTests/AppControllerInteractionTests.swift`

**Step 1: Write the failing tests**

Add focused tests for:

- a bare `Esc` shortcut monitor plan uses `.eventTap(.listenAndSuppress)` when both Input Monitoring and Accessibility are granted
- the plan stays disabled when Accessibility is missing
- `Esc` cancellation action resolves to startup cancel, recording cancel, processing cancel, or ignore based on current state

**Step 2: Run the focused test target and verify it fails**

Run: `swift test --filter AppControllerInteractionTests`

Expected: FAIL because `AppController` does not yet expose dedicated `Esc` cancellation planning and action routing.

### Task 2: Implement AppController Esc Decision Helpers

**Files:**
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Test: `Tests/VoicePiTests/AppControllerInteractionTests.swift`

**Step 1: Add the minimal decision surface**

Introduce:

- a static bare-`Esc` shortcut constant
- a monitor-plan helper for the temporary cancel monitor
- a small action enum/helper for resolving what `Esc` should cancel

Keep the behavior policy-driven and testable.

**Step 2: Make the focused tests pass**

Run: `swift test --filter AppControllerInteractionTests`

Expected: PASS.

### Task 3: Wire the Temporary Esc Monitor Into the App Lifecycle

**Files:**
- Modify: `Sources/VoicePi/AppCoordinator.swift`

**Step 1: Add the dedicated monitor**

Create a `ShortcutActionController` instance for `Esc` and hook its `onPress` callback into the new cancellation routing helper.

**Step 2: Toggle monitoring only for active sessions**

Add a small lifecycle helper that enables or disables the `Esc` monitor whenever startup, recording, or processing state changes.

Use the existing monitor planning path so the monitor is suppressed only when permissions allow it.

**Step 3: Route into existing cleanup**

Startup:
- cancel realtime connect if needed
- call `speechRecorder.cancelImmediately()`
- clear workflow state

Recording:
- call `speechRecorder.cancelImmediately()`
- clear status/overlay state

Processing:
- call `cancelProcessingAndHideOverlay()`

Do not add duplicate cleanup logic if an existing path already owns it.

**Step 4: Run the focused test target again**

Run: `swift test --filter AppControllerInteractionTests`

Expected: PASS.

### Task 4: Run Regression Verification

**Files:**
- Verify all files above

**Step 1: Run shortcut and workflow regression slices**

Run: `swift test --filter ShortcutMonitorTests && swift test --filter AppControllerInteractionTests`

Expected: PASS.

**Step 2: Run the repository test script if the focused slices are clean**

Run: `./Scripts/test.sh`

Expected: PASS.

**Step 3: Review final diff**

Run: `git diff --stat`

Expected: only the planned app controller, tests, and docs files changed.
