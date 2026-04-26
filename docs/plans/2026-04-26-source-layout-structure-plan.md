# VoicePi Source Layout Structure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align the app with a maintainable layered source layout, repair any path-sensitive tooling that still assumes the old flat file tree, and codify the new structure rules in repository instructions.

**Architecture:** Keep `Sources/VoicePi` as a single executable target so package and bundle behavior stay stable, but organize Swift sources by responsibility under `App`, `Core`, `Adapters`, `UI`, and `Support`. Keep bundle resources at the `Sources/VoicePi/` root to avoid accidental packaging regressions.

**Tech Stack:** SwiftPM, Swift 6.3 wrappers in `Scripts/`, POSIX shell regression tests, repository documentation in `AGENTS.md`

### Task 1: Repair benchmark script source paths

**Files:**
- Modify: `Scripts/benchmark.sh`
- Test: `Tests/benchmark_script_test.sh`

**Step 1:** Replace the old flat `Sources/VoicePi/*.swift` benchmark inputs with the new nested `Core/...` and `UI/...` paths.

**Step 2:** Preserve the existing compile flags and script contract so `benchmark_main.swift` still receives the same helper types and output semantics.

**Step 3:** Update the shell regression fixture to create the new nested source directories and touch the moved files at their new paths.

### Task 2: Repair path-sensitive translation import test

**Files:**
- Modify: `Tests/apple_translation_swiftui_import_test.sh`

**Step 1:** Point `SOURCE_FILE` at `Sources/VoicePi/Adapters/ASR/AppleTranslateService.swift`.

**Step 2:** Keep the typecheck behavior unchanged so the test still guards the SwiftUI `translationTask` import contract.

### Task 3: Codify the layered source layout

**Files:**
- Modify: `AGENTS.md`

**Step 1:** Rewrite the project structure section so it explains the `App`, `Core`, `Adapters`, `UI`, and `Support` folders under `Sources/VoicePi/`.

**Step 2:** Add explicit placement rules for new code:
- `Core` for domain models, prompt composition, policies, workflow logic, and pure helpers.
- `Adapters` for system, persistence, network, update, and external service integrations.
- `UI` for AppKit/SwiftUI presentation controllers and view support.
- `App` for app composition, lifecycle coordination, and cross-layer orchestration.
- Root `Sources/VoicePi/` only for bundle resources such as `Info.plist`, `AppIcon.appiconset`, and `PromptLibrary`.

**Step 3:** Add a source-size rule: no Swift file may exceed 800 lines, and files should generally be split before they reach that ceiling.

### Task 4: Verify the refactor contract

**Files:**
- Verify: `Sources/VoicePi/**/*.swift`
- Verify: `Scripts/benchmark.sh`
- Verify: `Tests/benchmark_script_test.sh`
- Verify: `Tests/apple_translation_swiftui_import_test.sh`

**Step 1:** Run a line-count check to confirm every Swift file is `<= 800` lines.

**Step 2:** Run `./Scripts/swiftw test --filter SettingsWindowLayoutTests` as a focused regression check around the recent settings split.

**Step 3:** Run `./Scripts/test.sh` for the full suite.

**Step 4:** Run `git diff --check` to catch whitespace or patch hygiene issues.
