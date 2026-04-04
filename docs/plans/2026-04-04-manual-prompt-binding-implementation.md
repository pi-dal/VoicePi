# Manual Prompt Binding Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add manual prompt bindings for apps and websites so users can attach prompts to specific destinations while keeping a manual fallback prompt and an explicit routing toggle.

**Architecture:** Extend the prompt workspace domain with user-editable app bundle ID and website host bindings plus a routing mode flag. Resolve prompts against a captured destination context before refinement, with website matches taking precedence over app matches and the active prompt selection remaining the manual fallback when routing is disabled or no binding matches. Capture frontmost app context directly and browser website context through a small browser URL resolver abstraction so tests stay deterministic.

**Tech Stack:** Swift, AppKit, Foundation, AppleScript/browser URL abstraction, `Testing`, `UserDefaults`

### Task 1: Lock the binding model and resolver behavior with failing tests

**Files:**
- Modify: `Tests/VoicePiTests/PromptWorkspaceTests.swift`
- Modify: `Tests/VoicePiTests/AppModelPersistenceTests.swift`
- Modify: `Tests/VoicePiTests/SettingsPresentationTests.swift`

**Step 1: Write the failing tests**

Add or complete tests proving:

- user prompts can persist app bundle ID bindings
- user prompts can persist website host bindings
- destination-aware resolution uses a bound website prompt when routing is enabled
- destination-aware resolution uses a bound app prompt when routing is enabled
- the active prompt remains the resolved prompt when routing is disabled
- the active prompt remains the fallback when no binding matches

**Step 2: Run test to verify it fails**

Run: `swift test --filter PromptWorkspaceTests`

Expected: FAIL because the prompt model and resolver do not yet support bindings or destination-aware resolution.

**Step 3: Write minimal implementation**

Implement only the domain types and resolver changes required for the first failing tests.

**Step 4: Run test to verify it passes**

Run: `swift test --filter PromptWorkspaceTests`

Expected: PASS.

### Task 2: Persist bindings and routing mode through `AppModel`

**Files:**
- Modify: `Sources/VoicePi/AppModel.swift`
- Modify: `Sources/VoicePi/PromptProfiles.swift`
- Modify: `Tests/VoicePiTests/AppModelPersistenceTests.swift`

**Step 1: Write the failing test**

Extend persistence tests so a reloaded model preserves:

- routing mode
- bound app bundle IDs
- bound website hosts
- active prompt fallback selection

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppModelPersistenceTests`

Expected: FAIL because the stored workspace shape does not yet include binding metadata.

**Step 3: Write minimal implementation**

Persist the new prompt workspace fields through the existing `UserDefaults` blob without changing unrelated settings behavior.

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppModelPersistenceTests`

Expected: PASS.

### Task 3: Add destination-context capture for runtime prompt routing

**Files:**
- Create: `Sources/VoicePi/DestinationContext.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Tests/VoicePiTests/AppControllerInteractionTests.swift`
- Create: `Tests/VoicePiTests/DestinationContextTests.swift`

**Step 1: Write the failing tests**

Add tests proving:

- frontmost app bundle ID becomes a destination context
- supported browser URLs normalize into website hosts
- unsupported browser or script failure falls back safely
- the coordinator resolves refinement prompts from the captured destination context instead of the old `.voicePi` global path

**Step 2: Run test to verify it fails**

Run: `swift test --filter DestinationContextTests`

Expected: FAIL because destination capture does not exist yet.

**Step 3: Write minimal implementation**

Add a small destination-context provider abstraction, use it to capture the current destination when recording begins, and pass that context into prompt resolution before refinement.

**Step 4: Run test to verify it passes**

Run: `swift test --filter DestinationContextTests`

Expected: PASS.

### Task 4: Extend the prompt editor sheet for manual app/site binding

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowPromptTemplateTests.swift`
- Modify: `Tests/VoicePiTests/SettingsPresentationTests.swift`

**Step 1: Write the failing test**

Add UI-state tests covering:

- routing toggle state persists in the draft workspace
- user prompts can expose/edit app bundle IDs and website hosts
- starter prompts still require duplication before editing bindings
- prompt summary reflects whether routing is manual-only or binding-aware

**Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsWindowPromptTemplateTests`

Expected: FAIL because the current editor sheet has only title/body controls.

**Step 3: Write minimal implementation**

Add compact routing controls on the main page and app/site binding fields in the editor sheet, plus optional capture actions for frontmost app/current website when available.

**Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsWindowPromptTemplateTests`

Expected: PASS.

### Task 5: Update docs and run full verification

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/2026-04-04-manual-prompt-workspace-design.md`
- Modify: `docs/plans/2026-04-04-manual-prompt-workspace-implementation.md`
- Modify: `Tests/VoicePiTests/ReadmeDocumentationTests.swift`

**Step 1: Write the failing doc test**

Extend docs assertions to mention:

- app bindings
- website bindings
- routing toggle/manual fallback behavior

**Step 2: Run test to verify it fails**

Run: `swift test --filter ReadmeDocumentationTests`

Expected: FAIL until the docs are updated.

**Step 3: Write minimal implementation**

Update README and plan docs to describe the new binding workflow and its current browser-support limits.

**Step 4: Run test to verify it passes**

Run: `swift test --filter ReadmeDocumentationTests`

Expected: PASS.

**Step 5: Run full verification**

Run:

- `./Scripts/test.sh`
- `./Scripts/verify.sh`

Expected: PASS with the debug app bundle generated successfully.
