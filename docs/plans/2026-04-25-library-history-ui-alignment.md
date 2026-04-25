# Library History UI Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align the Library > History settings experience with the new list-first design while preserving existing history data and actions.

**Architecture:** Keep `HistoryStore` and `AppModel` unchanged. Move presentation-specific formatting into `SettingsWindowSupport`, then rebuild the AppKit history section in `StatusBarController` around a toolbar and richer history cards.

**Tech Stack:** Swift 6, AppKit, Testing

### Task 1: History presentation coverage

**Files:**
- Modify: `Tests/VoicePiTests/SettingsWindowHistoryTests.swift`
- Modify: `Sources/VoicePi/SettingsWindowSupport.swift`

**Step 1: Write the failing test**

Add tests for:
- toolbar session count copy
- empty search placeholder copy
- row title/subtitle/metadata formatting
- empty-state messaging when no entries are available

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowHistoryTests`
Expected: FAIL because the new helpers do not exist yet.

**Step 3: Write minimal implementation**

Add focused helper types/functions in `SettingsWindowSupport.swift` to format the history list toolbar and row presentation without changing history storage.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowHistoryTests`
Expected: PASS

### Task 2: History settings layout update

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/SettingsWindowSupport.swift`

**Step 1: Write the failing test**

Expand tests to lock the new list-first layout behavior through presentation helpers and any layout-facing copy used by the view.

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowHistoryTests`
Expected: FAIL with copy/layout expectations not yet satisfied.

**Step 3: Write minimal implementation**

Replace the old summary/detail/list composition with:
- header row showing session count
- toolbar row with search, date filter, filter button, export button
- card-based history rows with timestamp, title, excerpt, metrics, and overflow actions
- empty state for filtered/no history cases

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowHistoryTests`
Expected: PASS

### Task 3: Verification

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/SettingsWindowSupport.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowHistoryTests.swift`

**Step 1: Run targeted tests**

Run: `./Scripts/test.sh --filter SettingsWindowHistoryTests`
Expected: PASS

**Step 2: Run broader verification**

Run: `./Scripts/verify.sh`
Expected: PASS if the settings window still builds and packages correctly.
