# Menubar Prompt Binding Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add menubar-first app and website prompt binding actions that share one binding write path with settings.

**Architecture:** Introduce a pure Swift helper for prompt binding capture normalization and target resolution, then wire `StatusBarController` to expose capture actions in the `Refinement Prompt` submenu and immediately present a lightweight picker popup after capture. Keep settings and menubar aligned by routing both flows through the same merge and save logic.

**Tech Stack:** Swift, AppKit, Foundation, `Testing`

### Task 1: Lock the shared binding rules with failing tests

**Files:**
- Create: `Tests/VoicePiTests/PromptBindingActionTests.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowPromptTemplateTests.swift`

**Step 1: Write the failing tests**

Add tests proving:

- binding to a user prompt appends a normalized app bundle ID
- binding to a user prompt appends a normalized website host
- binding to a starter prompt creates a user copy and saves the binding there
- binding to the built-in default creates a new user prompt and saves the binding there
- duplicate bindings are not appended twice

**Step 2: Run test to verify it fails**

Run: `swift test --filter PromptBindingActionTests`
Expected: FAIL because the shared helper does not exist yet.

**Step 3: Write minimal implementation**

Create the binding helper and route existing settings merge behavior through it.

**Step 4: Run test to verify it passes**

Run: `swift test --filter PromptBindingActionTests`
Expected: PASS.

### Task 2: Expose menubar capture actions and immediate picker popup

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Tests/VoicePiTests/StatusBarLanguageMenuTests.swift`

**Step 1: Write the failing test**

Add tests proving:

- the refinement prompt menu advertises menubar capture actions
- a prompt editor sheet disables menubar capture actions
- picker button labels are stable and expected

**Step 2: Run test to verify it fails**

Run: `swift test --filter StatusBarLanguageMenuTests`
Expected: FAIL because the menu metadata does not include the new actions.

**Step 3: Write minimal implementation**

Replace the pending submenu flow with an immediate picker popup that lets the user bind to the active prompt, another prompt, or a new prompt, all backed by the shared helper.

**Step 4: Run test to verify it passes**

Run: `swift test --filter StatusBarLanguageMenuTests`
Expected: PASS.

### Task 3: Integrate settings and menubar refresh paths

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowPromptTemplateTests.swift`

**Step 1: Write the failing test**

Add tests proving:

- settings capture field merging still uses the shared normalization path
- menubar binding success can report `added` vs `already present`
- non-user prompt sources still follow duplicate-or-create rules

**Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsWindowPromptTemplateTests`
Expected: FAIL until the shared path is wired through.

**Step 3: Write minimal implementation**

Use the helper from both UI flows and refresh prompt summaries/menu state after binding changes.

**Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsWindowPromptTemplateTests`
Expected: PASS.

### Task 4: Run focused and repo-wide verification

**Files:**
- No source changes required unless verification finds regressions

**Step 1: Run focused tests**

Run:

- `swift test --filter PromptBindingActionTests`
- `swift test --filter StatusBarLanguageMenuTests`
- `swift test --filter SettingsWindowPromptTemplateTests`

Expected: PASS.

**Step 2: Run repository tests**

Run: `./Scripts/test.sh`
Expected: PASS.
