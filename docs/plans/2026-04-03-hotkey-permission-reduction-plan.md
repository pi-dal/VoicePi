# Hotkey Permission Reduction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce `Input Monitoring` prompts by using registered global hotkeys for standard shortcuts and reserving the event-tap path for advanced shortcuts only.

**Architecture:** Keep the existing `ShortcutMonitor` event-tap implementation for advanced shortcuts such as modifier-only, `fn`-based, and multi-key chords. Add a second monitor backed by Carbon registered hotkeys for standard one-key-plus-modifier shortcuts, and have `AppController` select the appropriate monitor path based on the chosen shortcut.

**Tech Stack:** Swift, AppKit, Carbon Event Hot Keys, existing `Testing` framework.

### Task 1: Define Shortcut Capability Rules

**Files:**
- Modify: `Sources/VoicePi/AppModel.swift`
- Test: `Tests/VoicePiTests/ShortcutMonitorTests.swift`

**Step 1: Write the failing test**

Add tests that classify:
- `Command + Shift + V` as standard registered-hotkey compatible.
- `Option + Fn` as advanced and requiring the event-tap path.
- Multi-key chords as advanced.

**Step 2: Run test to verify it fails**

Run: `swift test --filter ShortcutMonitorTests`

**Step 3: Write minimal implementation**

Add small computed properties on `ActivationShortcut` that answer:
- whether the shortcut is standard registered-hotkey compatible
- whether it requires advanced monitoring

**Step 4: Run test to verify it passes**

Run: `swift test --filter ShortcutMonitorTests`

### Task 2: Add Registered Hotkey Monitor

**Files:**
- Create: `Sources/VoicePi/RegisteredHotkeyMonitor.swift`
- Test: `Tests/VoicePiTests/ShortcutMonitorTests.swift`

**Step 1: Write the failing test**

Add a test proving the new monitor exposes press/release callbacks and can recover from registration failure through injected registration closures.

**Step 2: Run test to verify it fails**

Run: `swift test --filter ShortcutMonitorTests`

**Step 3: Write minimal implementation**

Implement a monitor that:
- registers `EventHotKey`
- dispatches press/release to the same delegate shape used by `ShortcutMonitor`
- supports injected register/unregister closures for tests

**Step 4: Run test to verify it passes**

Run: `swift test --filter ShortcutMonitorTests`

### Task 3: Route Monitoring by Shortcut Type

**Files:**
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Test: `Tests/VoicePiTests/AppControllerInteractionTests.swift`

**Step 1: Write the failing test**

Add tests for:
- standard shortcuts working without `Input Monitoring`
- advanced shortcuts still requiring `Input Monitoring`
- accessibility messaging changing when suppression is not needed for standard shortcuts

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppControllerInteractionTests`

**Step 3: Write minimal implementation**

Update `AppController` to:
- own the new registered-hotkey monitor
- choose the active monitoring path from the shortcut capability
- refresh monitors when the shortcut changes
- use status text that only mentions `Input Monitoring` when the active shortcut actually needs it

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppControllerInteractionTests`

### Task 4: Verify End-to-End Regression Surface

**Files:**
- Modify as needed: `Sources/VoicePi/StatusBarController.swift`
- Test: existing suites only unless a gap is discovered

**Step 1: Run focused suites**

Run:
- `swift test --filter ShortcutMonitorTests`
- `swift test --filter AppControllerInteractionTests`

**Step 2: Fix any regressions minimally**

Only adjust copy or wiring needed for the new monitor split.

**Step 3: Run full verification**

Run: `./Scripts/test.sh`

**Step 4: Commit**

```bash
git add Sources/VoicePi/AppModel.swift Sources/VoicePi/AppCoordinator.swift Sources/VoicePi/RegisteredHotkeyMonitor.swift Tests/VoicePiTests/ShortcutMonitorTests.swift Tests/VoicePiTests/AppControllerInteractionTests.swift docs/plans/2026-04-03-hotkey-permission-reduction-plan.md
git commit -m "feat: reduce hotkey permission requirements"
```
