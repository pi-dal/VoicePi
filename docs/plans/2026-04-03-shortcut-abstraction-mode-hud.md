# Shortcut Abstraction And Mode HUD Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor global shortcut handling so recording and mode-switch shortcuts use the same capabilities and permission rules, then add a prominent floating HUD for mode changes.

**Architecture:** Replace the duplicated per-action monitor wiring in `AppController` with a shared shortcut-action abstraction that owns one registered-hotkey monitor and the event-tap fallbacks for a single action. Make monitor instances accept empty shortcuts cleanly and give registered hotkeys unique identifiers so two active shortcuts do not collide. Extend the floating panel to support a center-screen transient HUD for mode changes and trigger it from the mode-switch action.

**Tech Stack:** Swift, AppKit, Carbon hotkeys, CGEvent taps, Testing

### Task 1: Lock down the broken assumptions in tests

**Files:**
- Modify: `Tests/VoicePiTests/ShortcutMonitorTests.swift`
- Modify: `Tests/VoicePiTests/AppControllerInteractionTests.swift`
- Modify: `Tests/VoicePiTests/FloatingPanelControllerTests.swift`

**Step 1: Write the failing tests**

Add tests for:
- monitor objects preserving an empty shortcut instead of silently substituting the activation default
- registered hotkey monitors owning distinct hotkey identifiers
- a mode-switch HUD entry point that shows prominent mode text

**Step 2: Run test to verify it fails**

Run: `swift test --filter 'ShortcutMonitorTests|AppControllerInteractionTests|FloatingPanelControllerTests'`
Expected: FAIL because the monitor classes still normalize empty shortcuts to `.default`, registered hotkey monitors share a single identifier, and no mode HUD exists.

**Step 3: Write minimal implementation**

Implement only enough monitor/HUD API to satisfy the new tests.

**Step 4: Run test to verify it passes**

Run: `swift test --filter 'ShortcutMonitorTests|AppControllerInteractionTests|FloatingPanelControllerTests'`
Expected: PASS

### Task 2: Introduce a shared shortcut-action controller

**Files:**
- Create: `Sources/VoicePi/ShortcutActionController.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Sources/VoicePi/RegisteredHotkeyMonitor.swift`
- Modify: `Sources/VoicePi/ShortcutMonitor.swift`

**Step 1: Write the failing test**

Add or extend tests to prove one reusable controller can:
- apply a shortcut
- choose the right monitor strategy from a plan
- stop all backing monitors
- report the correct status/failure text

**Step 2: Run test to verify it fails**

Run: `swift test --filter 'ShortcutMonitorTests|AppControllerInteractionTests'`
Expected: FAIL because `AppController` still owns duplicated monitor-management code.

**Step 3: Write minimal implementation**

Move the three-monitor lifecycle into a reusable controller and make both recording and mode switching use it.

**Step 4: Run test to verify it passes**

Run: `swift test --filter 'ShortcutMonitorTests|AppControllerInteractionTests'`
Expected: PASS

### Task 3: Add the mode-switch HUD on top of the shared action

**Files:**
- Modify: `Sources/VoicePi/FloatingPanelController.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Tests/VoicePiTests/FloatingPanelControllerTests.swift`

**Step 1: Write the failing test**

Add tests that verify:
- mode HUD text matches the selected mode
- HUD presentation differs from the bottom recording overlay
- HUD auto-hides/reset behavior does not break recording overlay reuse

**Step 2: Run test to verify it fails**

Run: `swift test --filter FloatingPanelControllerTests`
Expected: FAIL because the floating panel only supports recording/refining overlays.

**Step 3: Write minimal implementation**

Add a mode-switch HUD variant that is visually prominent and centered, then call it from the mode-switch shortcut handler.

**Step 4: Run test to verify it passes**

Run: `swift test --filter FloatingPanelControllerTests`
Expected: PASS

### Task 4: Verify parity and ship confidence

**Files:**
- Modify: `Tests/VoicePiTests/SettingsPresentationTests.swift`
- Modify: `Tests/VoicePiTests/AppModelPersistenceTests.swift`

**Step 1: Run targeted verification**

Run: `swift test --filter 'ShortcutMonitorTests|AppControllerInteractionTests|FloatingPanelControllerTests|SettingsPresentationTests|AppModelPersistenceTests'`
Expected: PASS

**Step 2: Run repository verification**

Run: `./Scripts/test.sh`
Expected: PASS

**Step 3: Run build verification**

Run: `./Scripts/verify.sh`
Expected: PASS and `dist/debug/VoicePi.app` built successfully.
