# Settings Window Visual Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refresh the VoicePi settings window to match the new poster direction while preserving the current 600pt window height and existing scrollable section structure.

**Architecture:** Keep the existing `SettingsWindowController` layout and section content intact, then centralize the new design language in reusable theme tokens and chrome helpers used by page backgrounds, cards, navigation tabs, and action buttons. This limits behavioral risk while making the visual system coherent across light and dark appearances.

**Tech Stack:** Swift, AppKit, Testing framework

### Task 1: Lock the redesign constraints in tests

**Files:**
- Modify: `Tests/VoicePiTests/SettingsWindowLayoutTests.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowPromptEditorAppearanceTests.swift`

**Step 1: Write the failing tests**

- Add tests for the new settings chrome tokens:
  - light and dark page background colors
  - light and dark card background + border colors
  - updated navigation metrics that preserve window height
- Add tests for prompt editor chrome only if the shared token changes should affect it.

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests`

Expected: FAIL because the new token helpers and expected values do not exist yet.

**Step 3: Write minimal implementation**

- Introduce reusable settings theme/token helpers in the settings window code.
- Route the existing window and control chrome through those helpers.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests`

Expected: PASS

### Task 2: Refresh the shared settings chrome

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/SettingsWindowSupport.swift`

**Step 1: Write the failing test**

- Add assertions for the updated visual metrics and token-backed values that describe:
  - warmer light surface
  - darker graphite dark mode surface
  - greener selected navigation treatment
  - larger card and tab radii

**Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsWindow`

Expected: FAIL with mismatched token expectations.

**Step 3: Write minimal implementation**

- Update the header chrome and navigation row to look closer to the approved poster direction.
- Refresh `StyledSettingsButton` for primary, secondary, and navigation roles.
- Refresh `ThemedSurfaceView` card, row, and pill styling.
- Keep all existing layout constraints that enforce the current window height.

**Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsWindow`

Expected: PASS

### Task 3: Verify section behavior still fits within the existing window

**Files:**
- Modify: `Tests/VoicePiTests/SettingsWindowLayoutTests.swift`
- Modify: `Sources/VoicePi/StatusBarController.swift`

**Step 1: Write the failing test**

- Add a regression test that still expects every section to live inside a scroll view.
- Add a regression test that the settings window default and minimum heights remain unchanged.

**Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsWindowLayoutTests`

Expected: FAIL if any size or scroll structure was accidentally changed.

**Step 3: Write minimal implementation**

- Fix any regressions from the visual refresh without increasing the window height.

**Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsWindowLayoutTests`

Expected: PASS

### Task 4: Final verification

**Files:**
- No code changes required unless verification finds regressions

**Step 1: Run targeted tests**

Run: `swift test --filter SettingsWindow`

Expected: PASS

**Step 2: Run repo verification if targeted tests pass**

Run: `./Scripts/test.sh`

Expected: PASS

**Step 3: Manually verify app UI**

Run: `make run`

Expected: Settings window opens with refreshed light/dark styling, same height, and scrollable content where needed.
