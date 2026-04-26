# Provider Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the top-level `ASR` settings section with a `Provider` section that contains `ASR` and `LLM` subtabs, while keeping the existing `Text` section unchanged.

**Architecture:** Add a new top-level `provider` navigation case, introduce provider subtab state and UI composition inside `SettingsWindowController`, then route existing ASR/LLM refresh and action wiring through that container without changing runtime backend logic.

**Tech Stack:** Swift 6, AppKit, Testing

### Task 1: Lock navigation copy and ordering in tests

**Files:**
- Modify: `Tests/VoicePiTests/SettingsWindowDictionaryTests.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowLayoutTests.swift`

**Step 1: Write the failing test**

Add tests for:

- `SettingsSection.provider.title == "Provider"`
- top navigation containing `Provider` and no longer containing `ASR`
- `Provider` remaining between `Text` and `Processors`

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowDictionaryTests`

Expected: FAIL because `SettingsSection.provider` does not exist yet and navigation still exposes `ASR`.

**Step 3: Write minimal implementation**

Update `SettingsSection`, navigation ordering, and navigation icons/titles to expose `Provider` in place of the old top-level `ASR`.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowDictionaryTests`

Expected: PASS.

### Task 2: Lock provider subtab routing in tests

**Files:**
- Modify: `Tests/VoicePiTests/SettingsWindowLayoutTests.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsChoiceControls.swift`

**Step 1: Write the failing test**

Add layout/controller tests for:

- `Provider` exposing `ASR` and `LLM` subtabs
- opening the LLM settings helper selecting `Provider` and the `LLM` subtab
- opening the ASR settings helper selecting `Provider` and the `ASR` subtab

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests`

Expected: FAIL because no provider subtab control exists and the helper methods still target separate top-level sections.

**Step 3: Write minimal implementation**

Introduce provider subtab state, add a provider subtab control, and route `openASRSection()` / `openLLMSection()` through `Provider`.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests`

Expected: PASS.

### Task 3: Move ASR and LLM content under Provider

**Files:**
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+Setup.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+DictionaryHistoryData.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+TextSection.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+SectionBuildersA.swift`

**Step 1: Write the failing test**

Expand controller/layout tests to lock:

- `Provider` hosting both ASR and LLM content containers
- only the selected provider subview being visible
- `selectSection(.provider)` using the provider container instead of standalone ASR/LLM pages

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests`

Expected: FAIL because the window still manages `asrView` and `llmView` as separate top-level pages.

**Step 3: Write minimal implementation**

Create a `providerView`, mount both ASR and LLM content inside it, and update section selection logic so top-level visibility is controlled through `providerView` plus provider-subtab state.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests`

Expected: PASS.

### Task 4: Reshape the LLM provider page to match the ASR-style layout

**Files:**
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+TextSection.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+Refresh.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowThinkingTests.swift`

**Step 1: Write the failing test**

Add tests for:

- LLM provider controls staying present and enabled/disabled correctly
- summary/status copy still reflecting current text-processing mode
- thinking selection behavior still round-tripping after the layout move

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowThinkingTests`

Expected: FAIL if the moved layout drops or miswires the existing LLM controls.

**Step 3: Write minimal implementation**

Refactor the current LLM page into a provider-oriented card layout that exposes:

- provider summary
- connection details
- live status

while preserving the existing field instances, actions, and refresh logic.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowThinkingTests`

Expected: PASS.

### Task 5: Repository verification

**Files:**
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsChoiceControls.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+Setup.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+TextSection.swift`
- Modify: `Sources/VoicePi/UI/Settings/SettingsWindowController+DictionaryHistoryData.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowDictionaryTests.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowLayoutTests.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowThinkingTests.swift`

**Step 1: Run targeted tests**

Run: `./Scripts/test.sh --filter SettingsWindowDictionaryTests`

Expected: PASS.

**Step 2: Run targeted layout tests**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests`

Expected: PASS.

**Step 3: Run targeted LLM tests**

Run: `./Scripts/test.sh --filter SettingsWindowThinkingTests`

Expected: PASS.

**Step 4: Run broader repository verification**

Run: `./Scripts/test.sh`

Expected: PASS.
