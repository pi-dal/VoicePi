# Manual Prompt Workspace Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current prompt-profile selection flow with a manual prompt workspace that uses a built-in default fallback, supports shipped starter prompts plus editable user prompts, and preserves existing users through migration.

**Architecture:** Keep `LLMRefiner`'s prefix/middle/suffix prompt assembly, but replace the profile/inheritance prompt domain with a workspace model loaded from bundled starter assets and persisted user presets. Route refinement through a single active prompt selection, migrate legacy freeform prompts into an imported preset when needed, and rebuild the settings UI around explicit prompt picking and editing.

**Tech Stack:** Swift, AppKit, Foundation, `Testing`, `UserDefaults`

### Task 1: Add failing model tests for the manual prompt workspace

**Files:**
- Modify: `Tests/VoicePiTests/AppModelPersistenceTests.swift`
- Modify: `Tests/VoicePiTests/AppWorkflowSupportTests.swift`
- Modify: `Tests/VoicePiTests/LLMRefinerTests.swift`
- Create: `Tests/VoicePiTests/PromptWorkspaceTests.swift`

**Step 1: Write the failing tests**

Add focused tests for:

- bundled starter prompts load alongside the built-in default prompt
- default selection resolves to the built-in default prompt body
- selecting a user preset resolves that preset body
- empty legacy prompt migrates to default selection
- non-empty legacy prompt migrates to an imported user preset
- deleting the active user preset falls back to default

**Step 2: Run tests to verify they fail**

Run: `swift test --filter PromptWorkspaceTests`

Expected: FAIL because the prompt workspace model and resolver do not exist yet.

**Step 3: Write the minimal implementation**

Implement only the minimal model types and loader interfaces needed to satisfy the first failing tests.

**Step 4: Run tests to verify they pass**

Run: `swift test --filter PromptWorkspaceTests`

Expected: PASS for the new prompt workspace tests.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/AppModelPersistenceTests.swift Tests/VoicePiTests/AppWorkflowSupportTests.swift Tests/VoicePiTests/LLMRefinerTests.swift Tests/VoicePiTests/PromptWorkspaceTests.swift Sources/VoicePi
git commit -m "test: add prompt workspace coverage"
```

### Task 2: Implement the new prompt workspace domain and migration path

**Files:**
- Modify: `Sources/VoicePi/AppModel.swift`
- Modify: `Sources/VoicePi/PromptProfiles.swift` or replace with a new workspace-focused file
- Reuse: `Sources/VoicePi/PromptLibrary/profiles/*.json` as starter prompt bodies

**Step 1: Write the failing test**

Extend tests to prove:

- `AppModel` persists active prompt selection and user presets
- legacy `llmConfiguration.refinementPrompt` migration produces an imported preset once
- bundled starter prompts are available without being stored in defaults
- old `promptSettings` data can be imported once into a user preset when it resolves to non-empty prompt text

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter AppModelPersistenceTests`

Expected: FAIL because `AppModel` still persists the old prompt selection state.

**Step 3: Write minimal implementation**

Implement:

- prompt workspace types
- bundled starter prompt loading from existing profile bodies
- `AppModel` persistence for active selection and user presets
- migration from legacy refinement prompt
- one-time import of legacy `promptSettings` when it resolves to non-empty text
- clearing prompt-body persistence from the saved LLM configuration path after the workspace becomes the source of truth
- compatibility shims only where needed to keep the app compiling during the transition

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppModelPersistenceTests`

Expected: PASS for the migration and persistence tests.

**Step 5: Commit**

```bash
git add Sources/VoicePi/AppModel.swift Sources/VoicePi/PromptProfiles.swift Sources/VoicePi/PromptLibrary Tests/VoicePiTests/AppModelPersistenceTests.swift Tests/VoicePiTests/PromptWorkspaceTests.swift
git commit -m "feat: add prompt workspace model"
```

### Task 3: Switch refinement flow to the active prompt workspace

**Files:**
- Modify: `Sources/VoicePi/AppWorkflowSupport.swift`
- Modify: `Sources/VoicePi/LLMRefiner.swift`
- Modify: `Tests/VoicePiTests/AppWorkflowSupportTests.swift`
- Modify: `Tests/VoicePiTests/LLMRefinerTests.swift`

**Step 1: Write the failing test**

Add tests proving:

- refinement mode uses the built-in default prompt when no custom preset is selected
- refinement mode uses the active starter or user preset body when selected
- translation mode still ignores the refinement prompt body when it should

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppWorkflowSupportTests`

Expected: FAIL because refinement still uses the old resolved profile plumbing.

**Step 3: Write minimal implementation**

Replace the old profile-based resolution with a single active workspace resolver and keep translation behavior unchanged.

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppWorkflowSupportTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/VoicePi/AppWorkflowSupport.swift Sources/VoicePi/LLMRefiner.swift Tests/VoicePiTests/AppWorkflowSupportTests.swift Tests/VoicePiTests/LLMRefinerTests.swift
git commit -m "refactor: route refinement through prompt workspace"
```

### Task 4: Replace the settings UI with the manual prompt workspace

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowPromptTemplateTests.swift`
- Modify: `Tests/VoicePiTests/SettingsPresentationTests.swift`

**Step 1: Write the failing test**

Add UI-state tests covering:

- prompt picker shows `VoicePi Default`, starter prompts, and user prompts
- the main settings page stays compact and does not depend on inline editing controls
- `Edit` is disabled for the built-in default and starter presets
- `Duplicate` creates an editable user preset and opens the editor sheet
- deleting an active user preset falls back safely
- prompt tests stay CI-friendly and avoid real popup/window traversal where possible

**Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsWindowPromptTemplateTests`

Expected: FAIL because the UI still renders the old global/app profile controls.

**Step 3: Write minimal implementation**

Rebuild the prompt section in `StatusBarController` around:

- active prompt picker
- summary label
- edit, new, duplicate, delete, preview actions
- resolved summary text for the selected prompt
- explicit duplication before editing any shipped starter prompt
- a dedicated prompt editor sheet modeled on the existing preview sheet for prompt title/body editing

Keep the UI consistent with the existing settings window style.

**Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsWindowPromptTemplateTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/VoicePi/StatusBarController.swift Sources/VoicePi/SettingsPresentation.swift Tests/VoicePiTests/SettingsWindowPromptTemplateTests.swift Tests/VoicePiTests/SettingsPresentationTests.swift
git commit -m "feat: add manual prompt workspace UI"
```

### Task 5: Remove obsolete profile-registry behavior and clean up docs/tests

**Files:**
- Delete: `Tests/VoicePiTests/PromptProfileRegistryTests.swift`
- Create: `Tests/VoicePiTests/PromptWorkspaceTests.swift`
- Modify: `docs/plans/2026-04-03-prompt-profile-registry-design.md`
- Modify: `docs/plans/2026-04-03-prompt-profile-registry-implementation.md`
- Modify: `docs/plans/2026-04-04-manual-prompt-workspace-design.md`
- Modify: `docs/plans/2026-04-04-manual-prompt-workspace-implementation.md`

**Step 1: Write the failing test**

Adjust or replace old registry-specific tests so the suite asserts only the new supported behavior.

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh`

Expected: FAIL in obsolete prompt-profile tests or docs-related assertions until the cleanup is complete.

**Step 3: Write minimal implementation**

Delete or rewrite obsolete profile-registry-only behavior, update plan docs to reflect the new direction, and keep only the compatibility code still needed for migration.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh`

Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/PromptProfileRegistryTests.swift docs/plans/2026-04-03-prompt-profile-registry-design.md docs/plans/2026-04-03-prompt-profile-registry-implementation.md docs/plans/2026-04-04-manual-prompt-workspace-design.md docs/plans/2026-04-04-manual-prompt-workspace-implementation.md
git commit -m "docs: update prompt architecture direction"
```
