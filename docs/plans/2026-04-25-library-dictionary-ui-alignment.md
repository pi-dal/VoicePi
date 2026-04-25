# Library Dictionary UI Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align the Library > Dictionary settings UI with the new list-first design while adding per-entry tags that can be created or rebound during term editing.

**Architecture:** Keep dictionary persistence in `DictionaryStore` and mutation flows in `AppModel`, but extend `DictionaryEntry` with an optional `tag`. Move dictionary filtering and sidebar/table presentation into `SettingsWindowSupport` and `SettingsPresentation`, then rebuild the AppKit dictionary section in `StatusBarController` around a toolbar, dynamic tag sidebar, and structured term table. Keep suggestions available inside the Dictionary view as a selectable collection instead of a separate primary card.

**Tech Stack:** Swift 6, AppKit, Testing

### Task 1: Model and persistence coverage

**Files:**
- Modify: `Tests/VoicePiTests/DictionaryStoreTests.swift`
- Modify: `Tests/VoicePiTests/AppModelDictionaryTests.swift`
- Modify: `Sources/VoicePi/DictionaryModels.swift`
- Modify: `Sources/VoicePi/AppModel.swift`

**Step 1: Write the failing test**

Add tests for:
- dictionary entry tag round-tripping through `DictionaryStore`
- `AppModel.editDictionaryTerm` updating a term tag
- `AppModel.addDictionaryTerm` preserving a supplied tag

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter AppModelDictionaryTests`
Expected: FAIL because `DictionaryEntry` and edit/add flows do not yet support tags.

**Step 3: Write minimal implementation**

Add an optional normalized `tag` field to `DictionaryEntry`, thread it through `AppModel`, and preserve backward compatibility for existing dictionary JSON documents.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter AppModelDictionaryTests`
Expected: PASS

### Task 2: Presentation and filtering coverage

**Files:**
- Modify: `Tests/VoicePiTests/SettingsWindowDictionaryTests.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Modify: `Sources/VoicePi/SettingsWindowSupport.swift`

**Step 1: Write the failing test**

Add tests for:
- sidebar category generation from dictionary tags plus the suggestions collection
- combined filtering by search query and selected category
- row presentation exposing canonical text, bindings summary, and tag label

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowDictionaryTests`
Expected: FAIL because the new presentation helpers do not exist yet.

**Step 3: Write minimal implementation**

Introduce focused helper types/functions for dictionary categories, term row presentation, and filtered collections without changing storage responsibilities.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowDictionaryTests`
Expected: PASS

### Task 3: Dictionary view rebuild

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/SettingsWindowSupport.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`

**Step 1: Write the failing test**

Expand dictionary tests around the new copy and any view-facing presentation used by the AppKit layout.

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowDictionaryTests`
Expected: FAIL with missing table/sidebar-oriented presentation and copy expectations.

**Step 3: Write minimal implementation**

Replace the stacked summary/terms/suggestions cards with:
- toolbar row containing search, add-term action, and collection actions
- left sidebar showing all terms, dynamic tags, and suggestions
- right content card showing either the term table or suggestion list depending on the selected collection
- updated term editor sheet that includes tag creation/binding

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowDictionaryTests`
Expected: PASS

### Task 4: Verification

**Files:**
- Modify: `Sources/VoicePi/DictionaryModels.swift`
- Modify: `Sources/VoicePi/AppModel.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Modify: `Sources/VoicePi/SettingsWindowSupport.swift`
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Tests/VoicePiTests/DictionaryStoreTests.swift`
- Modify: `Tests/VoicePiTests/AppModelDictionaryTests.swift`
- Modify: `Tests/VoicePiTests/SettingsWindowDictionaryTests.swift`

**Step 1: Run targeted tests**

Run: `./Scripts/test.sh --filter DictionaryStoreTests`
Expected: PASS

**Step 2: Run targeted tests**

Run: `./Scripts/test.sh --filter AppModelDictionaryTests`
Expected: PASS

**Step 3: Run targeted tests**

Run: `./Scripts/test.sh --filter SettingsWindowDictionaryTests`
Expected: PASS

**Step 4: Run broader verification**

Run: `./Scripts/verify.sh`
Expected: PASS if the settings window still builds and packages correctly.
