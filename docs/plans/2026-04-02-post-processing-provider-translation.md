# Post-Processing Provider And Translation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current binary LLM-refinement toggle with a provider-aware post-processing flow that supports refinement, translation, translation provider selection, and target-language output.

**Architecture:** Introduce a new persisted post-processing model in `AppModel` with three concerns: mode, translation provider, and target language. Keep the existing LLM configuration for the remote provider, route workflow decisions through `AppWorkflowSupport`, and teach `LLMRefiner` to optionally emit translated output when refinement mode is active so translation can be folded directly into the prompt.

**Tech Stack:** SwiftPM, AppKit, Foundation networking, Testing, optional macOS Translation framework gating.

### Task 1: Add model and workflow regression tests

**Files:**
- Modify: `Tests/VoicePiTests/AppModelPersistenceTests.swift`
- Modify: `Tests/VoicePiTests/SettingsPresentationTests.swift`
- Modify: `Tests/VoicePiTests/AppWorkflowSupportTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:
- post-processing mode, translation provider, and target language persist across reloads
- readiness reflects LLM configuration independently from whether refinement mode is selected
- home/settings presentation reflects the new post-processing model
- refinement mode disables separate translation flow and passes the target language into the LLM path
- translation mode defaults to Apple Translate behavior, while an LLM translation provider is used only when explicitly selected

**Step 2: Run test to verify it fails**

Run: `swift test --filter 'AppModelPersistenceTests|SettingsPresentationTests|AppWorkflowSupportTests'`
Expected: FAIL because the new mode/provider/target-language model and workflow routing do not exist yet.

**Step 3: Write minimal implementation**

Add new enums and pure decision helpers that satisfy the tests without redesigning unrelated state.

**Step 4: Run test to verify it passes**

Run: `swift test --filter 'AppModelPersistenceTests|SettingsPresentationTests|AppWorkflowSupportTests'`
Expected: PASS.

### Task 2: Extend the LLM processing surface

**Files:**
- Modify: `Sources/VoicePi/LLMRefiner.swift`
- Modify: `Tests/VoicePiTests/LLMRefinerTests.swift`

**Step 1: Write the failing test**

Add tests that prove the LLM request prompt stays conservative for refinement and adds an explicit target-language instruction when translation should be folded into the LLM prompt.

**Step 2: Run test to verify it fails**

Run: `swift test --filter LLMRefinerTests`
Expected: FAIL because the refiner currently only has a refinement-only prompt path.

**Step 3: Write minimal implementation**

Introduce a small LLM post-processing mode or target-language argument so the refiner can build either the original conservative prompt or a conservative-plus-translate prompt.

**Step 4: Run test to verify it passes**

Run: `swift test --filter LLMRefinerTests`
Expected: PASS.

### Task 3: Wire the new state through AppModel and workflow support

**Files:**
- Modify: `Sources/VoicePi/AppModel.swift`
- Modify: `Sources/VoicePi/AppWorkflowSupport.swift`

**Step 1: Write the failing test**

Use the workflow and persistence tests from Task 1 to prove the new state and routing behavior.

**Step 2: Run test to verify it fails**

Run: `swift test --filter 'AppModelPersistenceTests|AppWorkflowSupportTests'`
Expected: FAIL until the new state is persisted and the workflow uses it.

**Step 3: Write minimal implementation**

Persist the new enums in `UserDefaults`, add helper APIs for the settings/controller layer, and replace `refineIfNeeded` with a provider-aware post-processing function that chooses between disabled, refinement, Apple Translate, and LLM translation paths.

**Step 4: Run test to verify it passes**

Run: `swift test --filter 'AppModelPersistenceTests|AppWorkflowSupportTests'`
Expected: PASS.

### Task 4: Update settings and menu UI

**Files:**
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`

**Step 1: Write the failing test**

Use `SettingsPresentationTests` as the regression gate for the new summaries and add the smallest possible controller changes needed to compile.

**Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsPresentationTests`
Expected: FAIL because the UI summary still assumes a simple LLM enabled/disabled toggle.

**Step 3: Write minimal implementation**

Replace the checkbox-first LLM UI with a mode selector, translation-provider selector, and target-language selector. Disable translation-provider selection while refinement mode is active, keep Apple Translate as the default translation provider, and continue to expose LLM configuration fields for the LLM-backed paths.

**Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsPresentationTests`
Expected: PASS and `swift build` succeeds.

### Task 5: Add the Apple Translate integration seam and verify end-to-end behavior

**Files:**
- Create: `Sources/VoicePi/AppleTranslateService.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Package.swift`

**Step 1: Write the failing test**

Keep this task scoped to compile-time integration and provider routing. Unit tests should continue to use protocol-backed stubs from earlier tasks.

**Step 2: Run build to verify it fails**

Run: `swift build`
Expected: FAIL until the Apple Translate service is linked and injected.

**Step 3: Write minimal implementation**

Add a protocol-backed Apple Translate service abstraction. If a native Translation-framework bridge is feasible in the current AppKit structure, wire it here; otherwise keep the seam explicit and return a clear unsupported error instead of silently doing the wrong thing.

**Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS.

### Task 6: Final verification

**Files:**
- Modify: `docs/plans/2026-04-02-post-processing-provider-translation.md`

**Step 1: Run focused verification**

Run: `swift test --filter 'AppModelPersistenceTests|SettingsPresentationTests|AppWorkflowSupportTests|LLMRefinerTests'`
Expected: PASS.

**Step 2: Run broader verification**

Run: `swift test`
Expected: PASS.

**Step 3: Run build verification**

Run: `swift build`
Expected: PASS.
