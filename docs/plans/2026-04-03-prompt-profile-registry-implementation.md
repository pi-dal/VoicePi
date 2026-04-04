# Prompt Profile Registry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the freeform refinement prompt field with a bundled prompt-profile system that supports a blank global default, per-app override inheritance, explicit no-op overrides, and legacy freeform migration.

**Architecture:** Add a bundled prompt library and app policy loader, persist prompt selection state separately from LLM credentials, resolve the effective prompt middle section at runtime, and replace the settings UI with profile/option controls. Keep core prefix/suffix prompt logic in code and preserve current behavior when no profile content resolves.

**Tech Stack:** SwiftPM, AppKit, Foundation, bundled package resources, Testing.

### Task 1: Add failing tests for prompt-domain loading and resolution

**Files:**
- Create: `Tests/VoicePiTests/PromptProfileRegistryTests.swift`

### Task 2: Add failing tests for model persistence and legacy migration

**Files:**
- Modify: `Tests/VoicePiTests/AppModelPersistenceTests.swift`

### Task 3: Add failing tests for prompt integration behavior

**Files:**
- Modify: `Tests/VoicePiTests/LLMRefinerTests.swift`
- Modify: `Tests/VoicePiTests/AppWorkflowSupportTests.swift`

### Task 4: Implement bundled prompt library and persistence model

**Files:**
- Create: `Sources/VoicePi/PromptProfiles.swift`
- Create: `Sources/VoicePi/PromptLibrary/registry.toml`
- Create: `Sources/VoicePi/PromptLibrary/profiles/*.toml`
- Create: `Sources/VoicePi/PromptLibrary/fragments/*.toml`
- Create: `Sources/VoicePi/PromptLibrary/apps/voicepi.toml`
- Modify: `Package.swift`
- Modify: `Sources/VoicePi/AppModel.swift`

### Task 5: Integrate resolved prompt sections into refinement flow

**Files:**
- Modify: `Sources/VoicePi/LLMRefiner.swift`
- Modify: `Sources/VoicePi/AppWorkflowSupport.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`

### Task 6: Replace the settings UI with profile and option controls

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Modify: `Tests/VoicePiTests/SettingsPresentationTests.swift`

### Task 7: Final verification

**Files:**
- Modify: `docs/plans/2026-04-03-prompt-profile-registry-implementation.md`
