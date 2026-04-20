# Configurable Cancel Shortcut Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a configurable `Cancel Shortcut` setting, default it to `Control + .`, and keep bare `Esc` available as an advanced opt-in shortcut with explicit permission guidance.

**Architecture:** Persist a fifth shortcut in `AppModel`, expose it in the settings UI using the same recorder-field pattern as the other shortcuts, and drive the active-session cancel monitor from that single configured shortcut. Standard cancel shortcuts should use registered hotkeys by default, while advanced choices such as bare `Esc` should reuse the event-tap permission logic.

**Tech Stack:** Swift, AppKit, Combine, Carbon hotkeys, CGEvent taps, Testing framework.

### Task 1: Lock model defaults and persistence in tests

**Files:**
- Modify: `Tests/VoicePiTests/AppModelPersistenceTests.swift`
- Modify: `Sources/VoicePi/AppModel.swift`

**Step 1: Write the failing test**

Add tests for:

- a fresh model defaulting `cancelShortcut` to `Control + .`
- `cancelShortcut` persisting across model reloads

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppModelPersistenceTests`

Expected: FAIL because `cancelShortcut` does not exist yet.

### Task 2: Lock runtime planning behavior in tests

**Files:**
- Modify: `Tests/VoicePiTests/AppControllerInteractionTests.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`

**Step 1: Write the failing tests**

Add tests for:

- standard configured cancel shortcuts preferring the registered-hotkey plan
- bare `Esc` requiring the advanced event-tap permission path

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppControllerInteractionTests`

Expected: FAIL because cancel monitoring is still hard-coded instead of using `model.cancelShortcut`.

### Task 3: Lock settings copy and recorder presentation in tests

**Files:**
- Modify: `Tests/VoicePiTests/SettingsPresentationTests.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Modify: `Sources/VoicePi/SettingsWindowSupport.swift`

**Step 1: Write the failing tests**

Add tests for:

- the Home presentation showing a `Cancel Shortcut` summary
- default `Control + .` copy describing the standard no-Input-Monitoring path
- bare `Esc` copy explicitly warning about advanced permission requirements

**Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsPresentationTests`

Expected: FAIL because the settings presentation does not include cancel shortcut copy yet.

### Task 4: Implement model, settings, and runtime wiring

**Files:**
- Modify: `Sources/VoicePi/AppModel.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Modify: `Sources/VoicePi/SettingsWindowSupport.swift`

**Step 1: Add `cancelShortcut` to `AppModel`**

Implement:

- persistence key
- default `Control + .`
- published property
- setter
- persistence helper

**Step 2: Add the new settings row**

Use the same `ShortcutRecorderField` pattern as the other shortcut settings and route updates through the existing delegate chain.

**Step 3: Replace the hard-coded cancel shortcut logic**

Make `AppController`:

- use `model.cancelShortcut`
- choose registered hotkey or event tap based on that shortcut
- keep the active-session-only monitor lifecycle

**Step 4: Re-run the focused test targets**

Run: `swift test --filter AppModelPersistenceTests && swift test --filter AppControllerInteractionTests && swift test --filter SettingsPresentationTests`

Expected: PASS.

### Task 5: Update user-facing docs and verify

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/2026-04-19-configurable-cancel-shortcut-design.md`

**Step 1: Update docs**

Document:

- default cancel shortcut = `Control + .`
- bare `Esc` is optional and advanced
- permission expectations for `Esc`

**Step 2: Run verification**

Run: `swift test --filter ReadmeDocumentationTests && swift test --filter ShortcutMonitorTests && ./Scripts/test.sh`

Expected: PASS.
