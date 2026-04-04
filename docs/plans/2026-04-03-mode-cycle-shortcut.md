# Mode Cycle Shortcut Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a configurable global shortcut that cycles text-processing mode through Disabled, Refinement, and Translate, while keeping the existing record shortcut behavior intact.

**Architecture:** Persist a second shortcut on `AppModel`, expose a small `cyclePostProcessingMode()` behavior there, then wire a second monitor path in `AppController` that uses the same permission strategy rules as the existing activation shortcut. Update `SettingsWindowController` and `SettingsPresentation` so both shortcuts can be reviewed and edited from Settings, with copy that explains each shortcut independently.

**Tech Stack:** Swift, AppKit, Combine, Carbon hotkeys, CGEvent taps, Testing

### Task 1: Lock behavior with model tests

**Files:**
- Modify: `Tests/VoicePiTests/AppModelPersistenceTests.swift`
- Modify: `Sources/VoicePi/AppModel.swift`

**Step 1: Write the failing tests**

Add tests for:
- persisting a new `modeCycleShortcut`
- cycling `postProcessingMode` in the order `disabled -> refinement -> translation -> disabled`

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppModelPersistenceTests`
Expected: FAIL because `modeCycleShortcut` and cycle behavior do not exist yet.

**Step 3: Write minimal implementation**

Add:
- `AppModel.Keys.modeCycleShortcut`
- `@Published var modeCycleShortcut`
- init/persistence support
- `setModeCycleShortcut(_:)`
- `cyclePostProcessingMode()`

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppModelPersistenceTests`
Expected: PASS

### Task 2: Lock permission and monitor planning behavior

**Files:**
- Modify: `Tests/VoicePiTests/AppWorkflowSupportTests.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`

**Step 1: Write the failing tests**

Add tests for:
- launch/hotkey planning requiring Input Monitoring when either shortcut needs advanced monitoring
- hotkey monitor planning still preferring registered hotkeys when a shortcut is compatible

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppWorkflowSupportTests`
Expected: FAIL because the coordinator only reasons about the activation shortcut today.

**Step 3: Write minimal implementation**

Update the launch and monitor planning helpers so they consider both the activation shortcut and the new mode-cycle shortcut.

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppWorkflowSupportTests`
Expected: PASS

### Task 3: Add the second shortcut monitor path

**Files:**
- Modify: `Sources/VoicePi/ShortcutMonitor.swift`
- Modify: `Sources/VoicePi/RegisteredHotkeyMonitor.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`

**Step 1: Write the failing tests**

Add focused tests that prove monitor callbacks can be bound independently for the cycle shortcut without breaking existing delegate-driven recording behavior.

**Step 2: Run test to verify it fails**

Run: `swift test --filter ShortcutMonitorTests`
Expected: FAIL because monitors do not yet expose independent callback hooks for a second shortcut action.

**Step 3: Write minimal implementation**

Expose lightweight press/release callbacks on both monitor types, then instantiate and route a second set of monitors in `AppController` for mode cycling. On press, cycle the mode, refresh the menu/settings state, and show a transient status update.

**Step 4: Run test to verify it passes**

Run: `swift test --filter ShortcutMonitorTests`
Expected: PASS

### Task 4: Add settings UI and presentation support

**Files:**
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Tests/VoicePiTests/SettingsPresentationTests.swift`

**Step 1: Write the failing tests**

Add presentation tests for:
- current mode-cycle shortcut summary text
- correct hint copy for standard vs advanced cycle shortcuts

**Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsPresentationTests`
Expected: FAIL because Settings only exposes the activation shortcut.

**Step 3: Write minimal implementation**

Update the Home/General settings section to show:
- the existing activation shortcut field
- a second recorder field for the mode-cycle shortcut
- summary text that reflects the configured cycle shortcut

Route the new recorder field through the delegate back into `AppController`.

**Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsPresentationTests`
Expected: PASS

### Task 5: Verify end-to-end behavior

**Files:**
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Tests/VoicePiTests/StatusMenuPresentationTests.swift`

**Step 1: Run targeted test suite**

Run: `./Scripts/test.sh`
Expected: PASS

**Step 2: Run app verification if tests are green**

Run: `./Scripts/verify.sh`
Expected: PASS and `dist/debug/VoicePi.app` built successfully.

**Step 3: Manual sanity checks**

Confirm:
- activation shortcut still starts/stops recording
- cycle shortcut rotates Disabled, Refinement, Translate
- settings update both shortcuts live
- menu/status text refreshes after cycling
