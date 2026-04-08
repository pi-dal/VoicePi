# Dictionary Learning Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a structured user dictionary to VoicePi, surface low-friction dictionary management in Settings, and learn candidate terms from post-injection user edits with a one-time review toast and suggestion queue.

**Architecture:** Keep the dictionary out of `UserDefaults` and store it as versioned JSON under `~/Library/Application Support/VoicePi/Dictionary.json`, with a separate suggestion queue file beside it. Build the feature in layers: pure dictionary models and stores first, then pure diff/suggestion extraction, then a short-lived post-injection learning coordinator, then Settings UI, then LLM prompt integration and runtime approval/review wiring.

**Tech Stack:** Swift, AppKit, Foundation, ApplicationServices, Testing

### Task 1: Add structured dictionary models and storage

**Files:**
- Create: `Sources/VoicePi/DictionaryModels.swift`
- Create: `Sources/VoicePi/DictionaryStore.swift`
- Create: `Tests/VoicePiTests/DictionaryStoreTests.swift`

**Step 1: Write the failing test**

Add tests for:

- creating an empty dictionary document when no file exists
- persisting a versioned document with entries
- preserving `canonical`, `aliases`, `isEnabled`, and timestamps across save/load
- using an app-support-style file URL supplied by the test instead of `UserDefaults`

**Step 2: Run test to verify it fails**

Run: `swift test --filter DictionaryStoreTests`
Expected: FAIL because the dictionary store and models do not exist.

**Step 3: Write minimal implementation**

Create:

- a versioned dictionary document type
- a dictionary entry model with `canonical`, `aliases`, `isEnabled`, `createdAt`, `updatedAt`
- a store that reads and writes JSON atomically to a caller-supplied file URL
- a small path helper that resolves the future production location under Application Support

**Step 4: Run test to verify it passes**

Run: `swift test --filter DictionaryStoreTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/DictionaryStoreTests.swift Sources/VoicePi/DictionaryModels.swift Sources/VoicePi/DictionaryStore.swift
git commit -m "feat: add dictionary storage foundation"
```

### Task 2: Add suggestion queue models and storage

**Files:**
- Modify: `Sources/VoicePi/DictionaryModels.swift`
- Modify: `Sources/VoicePi/DictionaryStore.swift`
- Modify: `Tests/VoicePiTests/DictionaryStoreTests.swift`

**Step 1: Write the failing test**

Extend tests for:

- loading an empty suggestion queue when no suggestions file exists
- saving and loading pending suggestions independently from the main dictionary
- removing a suggestion after approval or dismissal
- merging an approved suggestion into an existing dictionary entry by alias

**Step 2: Run test to verify it fails**

Run: `swift test --filter DictionaryStoreTests`
Expected: FAIL because suggestion persistence and merge behavior do not exist.

**Step 3: Write minimal implementation**

Add:

- a versioned suggestion document type
- a suggestion model that captures original fragment, corrected fragment, proposed canonical term, proposed aliases, source app, and capture time
- store helpers to load/save/remove suggestions
- an approval path that writes directly into the formal dictionary and updates aliases without duplication

**Step 4: Run test to verify it passes**

Run: `swift test --filter DictionaryStoreTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/DictionaryStoreTests.swift Sources/VoicePi/DictionaryModels.swift Sources/VoicePi/DictionaryStore.swift
git commit -m "feat: add dictionary suggestion queue storage"
```

### Task 3: Add pure suggestion extraction rules

**Files:**
- Create: `Sources/VoicePi/DictionarySuggestionExtractor.swift`
- Create: `Tests/VoicePiTests/DictionarySuggestionExtractorTests.swift`

**Step 1: Write the failing test**

Add tests for:

- `postgre` -> `PostgreSQL` producing one suggestion
- `cloud flare` -> `Cloudflare` producing one suggestion
- punctuation-only changes producing no suggestion
- full sentence rewrites producing no suggestion
- multiple disjoint replacements producing no suggestion
- replacements outside the allowed length range producing no suggestion

**Step 2: Run test to verify it fails**

Run: `swift test --filter DictionarySuggestionExtractorTests`
Expected: FAIL because the extractor does not exist.

**Step 3: Write minimal implementation**

Implement a pure extractor that:

- compares injected text with stabilized edited text
- finds one contiguous replacement window only
- rejects whitespace-only, punctuation-only, casing-only, or large rewrites
- emits a normalized suggestion with one canonical term and one or more aliases

**Step 4: Run test to verify it passes**

Run: `swift test --filter DictionarySuggestionExtractorTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/DictionarySuggestionExtractorTests.swift Sources/VoicePi/DictionarySuggestionExtractor.swift
git commit -m "feat: add dictionary suggestion extraction rules"
```

### Task 4: Add post-injection learning session tracking

**Files:**
- Create: `Sources/VoicePi/PostInjectionLearning.swift`
- Create: `Tests/VoicePiTests/PostInjectionLearningTests.swift`
- Modify: `Sources/VoicePi/EditableTextTargetInspector.swift`
- Modify: `Sources/VoicePi/TextInjector.swift`

**Step 1: Write the failing test**

Add tests for a pure coordinator/state machine that:

- starts tracking only after a successful injection
- ignores edits after the watch window expires
- emits at most one toast-worthy suggestion per recording
- waits for 1.2 seconds of stable text before reporting a suggestion
- ignores target changes and empty/unreadable snapshots

**Step 2: Run test to verify it fails**

Run: `swift test --filter PostInjectionLearningTests`
Expected: FAIL because the learning coordinator and richer target snapshot types do not exist.

**Step 3: Write minimal implementation**

Implement:

- a short-lived learning coordinator with a 15 second watch window and 1.2 second stabilization timer
- a richer editable target snapshot API that can identify the focused element and read its text value when available
- a small injection session payload returned by `TextInjector` or assembled around injection so the coordinator knows what was inserted and where

Keep the AppKit/AX polling thin and keep the timing and state rules pure and testable.

**Step 4: Run test to verify it passes**

Run: `swift test --filter PostInjectionLearningTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/PostInjectionLearningTests.swift Sources/VoicePi/PostInjectionLearning.swift Sources/VoicePi/EditableTextTargetInspector.swift Sources/VoicePi/TextInjector.swift
git commit -m "feat: add post-injection dictionary learning tracking"
```

### Task 5: Add suggestion toast UI and actions

**Files:**
- Create: `Sources/VoicePi/DictionarySuggestionToastController.swift`
- Create: `Tests/VoicePiTests/DictionarySuggestionToastControllerTests.swift`
- Modify: `Sources/VoicePi/InputFallbackPanelController.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`

**Step 1: Write the failing test**

Add tests that:

- load the toast with summary text and three actions: `Approve`, `Review`, `Dismiss`
- verify the toast exposes only one suggestion per session
- verify `Dismiss` closes the toast without deleting the queued suggestion
- verify `Approve` calls into a supplied handler
- verify `Review` calls into a supplied handler

**Step 2: Run test to verify it fails**

Run: `swift test --filter DictionarySuggestionToastControllerTests`
Expected: FAIL because the toast controller does not exist.

**Step 3: Write minimal implementation**

Implement a small non-activating panel or reuse the existing panel style language to show:

- one-line success copy
- a concise “saved to suggestions” explanation
- three actions: approve, review, dismiss

Wire `AppCoordinator` to present the toast after the learning coordinator emits a stabilized suggestion.

**Step 4: Run test to verify it passes**

Run: `swift test --filter DictionarySuggestionToastControllerTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/DictionarySuggestionToastControllerTests.swift Sources/VoicePi/DictionarySuggestionToastController.swift Sources/VoicePi/InputFallbackPanelController.swift Sources/VoicePi/AppCoordinator.swift
git commit -m "feat: add dictionary suggestion toast"
```

### Task 6: Add dictionary state to `AppModel`

**Files:**
- Modify: `Sources/VoicePi/AppModel.swift`
- Create: `Tests/VoicePiTests/AppModelDictionaryTests.swift`

**Step 1: Write the failing test**

Add tests for:

- loading dictionary entries and suggestions from injected stores
- approving a suggestion writes directly to the formal dictionary and removes the suggestion
- dismissing a suggestion removes it from the queue only
- exposing counts needed by the settings summary and toast state

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppModelDictionaryTests`
Expected: FAIL because `AppModel` has no dictionary state or store integration.

**Step 3: Write minimal implementation**

Update `AppModel` to:

- hold dictionary entries and pending suggestions in published state
- use injected stores instead of `UserDefaults`
- expose actions for add/edit/delete/toggle term
- expose actions for approve/review/dismiss suggestion
- refresh dictionary state on launch and after runtime learning actions

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppModelDictionaryTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/AppModelDictionaryTests.swift Sources/VoicePi/AppModel.swift
git commit -m "feat: add dictionary state to app model"
```

### Task 7: Build the Settings dictionary section

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Create: `Tests/VoicePiTests/SettingsWindowDictionaryTests.swift`

**Step 1: Write the failing test**

Add tests for:

- a new `Dictionary` section appearing in the settings navigation
- summary text that includes term count and suggestion count
- a dictionary list row presentation with canonical term, alias summary, and enabled state
- a suggestions area that can surface pending review count

**Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsWindowDictionaryTests`
Expected: FAIL because the dictionary section and presentation helpers do not exist.

**Step 3: Write minimal implementation**

Update settings UI to include:

- a dedicated `Dictionary` section
- search, add, import, export controls
- a term list with enable/edit/delete affordances
- a suggestions list with `Approve`, `Review`, and `Dismiss`
- direct routing from runtime `Review` action into this section

Keep first-pass editing simple: sheet-based editor for canonical term and comma-separated aliases.

**Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsWindowDictionaryTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/SettingsWindowDictionaryTests.swift Sources/VoicePi/StatusBarController.swift Sources/VoicePi/SettingsPresentation.swift
git commit -m "feat: add dictionary settings section"
```

### Task 8: Inject dictionary context into LLM refinement

**Files:**
- Modify: `Sources/VoicePi/LLMRefiner.swift`
- Modify: `Sources/VoicePi/AppWorkflowSupport.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Create: `Tests/VoicePiTests/LLMRefinerDictionaryTests.swift`
- Modify: `Tests/VoicePiTests/AppWorkflowSupportTests.swift`

**Step 1: Write the failing test**

Add tests for:

- building a refinement system or user prompt that includes enabled dictionary terms
- omitting disabled entries
- including aliases only when they help the LLM learn alternate spellings
- leaving translation-only flows unchanged unless refinement is active

**Step 2: Run test to verify it fails**

Run:

- `swift test --filter LLMRefinerDictionaryTests`
- `swift test --filter AppWorkflowSupportTests`

Expected: FAIL because refinement does not yet receive dictionary context.

**Step 3: Write minimal implementation**

Update refinement wiring so:

- `AppModel` supplies enabled dictionary entries
- `AppWorkflowSupport` passes them into the refiner
- `LLMRefiner` appends a small dictionary section to the conservative prompt or user content without disturbing the current prompt preset architecture

Keep this first pass refinement-only. Do not expand scope into remote ASR hotwords yet.

**Step 4: Run test to verify it passes**

Run:

- `swift test --filter LLMRefinerDictionaryTests`
- `swift test --filter AppWorkflowSupportTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/LLMRefinerDictionaryTests.swift Tests/VoicePiTests/AppWorkflowSupportTests.swift Sources/VoicePi/LLMRefiner.swift Sources/VoicePi/AppWorkflowSupport.swift Sources/VoicePi/AppCoordinator.swift
git commit -m "feat: use dictionary in llm refinement"
```

### Task 9: Verify import/export and end-to-end learning flow

**Files:**
- Modify: `Tests/VoicePiTests/AppModelDictionaryTests.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowDictionaryTests.swift`
- Verify all changed source files

**Step 1: Write the failing test**

Add coverage for:

- importing plain text terms into structured dictionary entries
- exporting the current dictionary to plain text and JSON
- approving a runtime suggestion immediately updates formal dictionary state
- dismissing a toast leaves the suggestion queued for later review

**Step 2: Run test to verify it fails**

Run:

- `swift test --filter AppModelDictionaryTests`
- `swift test --filter SettingsWindowDictionaryTests`

Expected: FAIL because import/export or runtime queue refresh is incomplete.

**Step 3: Write minimal implementation**

Finish:

- plain text importer that turns one term per line into canonical-only entries
- JSON export of the full structured document
- plain text export of canonical terms
- runtime refresh paths so toast actions and settings views stay in sync

**Step 4: Run test to verify it passes**

Run:

- `swift test --filter AppModelDictionaryTests`
- `swift test --filter SettingsWindowDictionaryTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/VoicePiTests/AppModelDictionaryTests.swift Tests/VoicePiTests/SettingsWindowDictionaryTests.swift
git commit -m "feat: finish dictionary import export and review flow"
```

### Task 10: Run full verification

**Files:**
- Verify all changed source and test files

**Step 1: Run focused verification**

Run:

- `swift test --filter DictionaryStoreTests`
- `swift test --filter DictionarySuggestionExtractorTests`
- `swift test --filter PostInjectionLearningTests`
- `swift test --filter DictionarySuggestionToastControllerTests`
- `swift test --filter AppModelDictionaryTests`
- `swift test --filter SettingsWindowDictionaryTests`
- `swift test --filter LLMRefinerDictionaryTests`
- `swift test --filter AppWorkflowSupportTests`

Expected: PASS.

**Step 2: Run repository verification**

Run: `./Scripts/test.sh`
Expected: PASS.

**Step 3: Sanity-check the manual flow**

Verify manually:

- add a canonical term plus aliases in Settings
- refine speech containing that term and confirm the LLM keeps the preferred spelling
- inject text into a normal editable target
- edit the injected term in place
- wait for the 1.2 second stabilization period
- confirm the toast appears once with `Approve`, `Review`, and `Dismiss`
- confirm `Approve` writes directly into the formal dictionary
- confirm `Review` opens `Dictionary > Suggestions`
- confirm `Dismiss` keeps the suggestion queued
