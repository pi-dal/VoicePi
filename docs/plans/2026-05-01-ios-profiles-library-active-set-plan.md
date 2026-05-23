# iOS Profiles Library + Active Keyboard Set Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild the iOS Profiles page so it supports an unlimited profile library plus a fixed 5-position active keyboard set, while matching the new visual direction and preserving a clear path for keyboard-side profile selection.

**Architecture:** Replace the current slot-only mental model with a two-layer model: a profile library that can grow beyond five items, and a fixed ordered `keyboardActiveProfileIDs` array with exactly five positions for keyboard-visible profiles. Keep backward compatibility by decoding old 5-slot data into the new model, and keep the top tab unchanged while rebuilding only the Profiles page body and related shared model helpers.

**Tech Stack:** SwiftUI, VoicePiCore shared models/storage, App Group `UserDefaults`, existing iOS host app components (`VoicePiCard`, `VoicePiTheme`, `SharedDefaultsWrapper`), existing keyboard configuration pipeline.

## Locked Product Decisions

- Top navigation tab stays visually unchanged this round.
- Profiles page uses two sections:
  - `Active Profiles`: always shows 5 fixed positions.
  - `Profile Library`: shows all saved profiles and can exceed 5 items.
- Keyboard-visible profiles come only from the active section.
- Empty active positions remain visible as placeholders.
- Active-position order matters and is explicit.
- No fake “many profiles” UI on top of the old 5-slot-only model.
- No iCloud work in this slice.

## Data Model Direction

- Replace `slots + selectedSlotIndex` as the primary product model with:
  - `profiles: [PromptProfile]`
  - `keyboardActiveProfileIDs: [String?]` with fixed length `5`
  - `selectedKeyboardActiveIndex: Int`
- Preserve compatibility:
  - old stored `slots` decode into `profiles + keyboardActiveProfileIDs`
  - old `selectedSlotIndex` maps into `selectedKeyboardActiveIndex`
- Keep a computed `activeProfile` helper for current keyboard/runtime callers.

## Interaction Direction

- `New Profile` creates a library item.
- Tapping an active-position card marks that position as `In Use`.
- Library card actions:
  - edit
  - add to keyboard if not active
  - remove from keyboard if active
- When adding a library profile and there is no empty active position, show an explicit replace flow for one of the 5 fixed slots.
- This round does **not** need drag-and-drop reordering; slot position is the ordering mechanism.

### Task 1: Shared Model Migration

**Files:**
- Modify: `Packages/VoicePiCore/Sources/VoicePiCore/ProfileModels/ProfileModels.swift`
- Modify: `Packages/VoicePiCore/Sources/VoicePiCore/Storage/SharedProfileDefaults.swift`
- Modify: `Packages/VoicePiCore/Tests/VoicePiCoreTests/VoicePiCoreTests.swift`

**Steps:**
1. Introduce the new library + active-set fields in `VoicePiSharedConfig`.
2. Add compatibility decode logic so existing stored `slots` data migrates cleanly.
3. Keep a computed `activeProfile` and related convenience helpers so current keyboard/runtime callers do not break.
4. Add mutation helpers for:
   - creating/updating/removing a library profile
   - assigning/removing a profile from an active slot
   - marking an active slot as `In Use`
5. Update unit tests for:
   - default config shape
   - migration from old slot payloads
   - active-slot assignment/removal
   - selected active profile resolution

**Verification:**
- Run: `swift test --package-path Packages/VoicePiCore`
- Expected: all VoicePiCore tests pass except any already-known unrelated failures.

### Task 2: Host App State Wrapper Adaptation

**Files:**
- Modify: `ios/VoicePiKeyboard/VoicePiApp/Sources/ProfileManagementView.swift`

**Steps:**
1. Refactor `SharedDefaultsWrapper` methods away from `selectSlot` / `updateProfile(_:inSlot:)` assumptions.
2. Add wrapper methods for:
   - create profile
   - update profile by id
   - delete profile by id
   - assign/remove profile from active slot
   - mark active slot as in-use
3. Keep old callers compiling until the page body is replaced.

**Verification:**
- Run: `xcodegen generate`
- Run: `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Expected: build succeeds.

### Task 3: Profiles Page Visual Rebuild

**Files:**
- Modify: `ios/VoicePiKeyboard/VoicePiApp/Sources/ProfileManagementView.swift`
- Optional create: `ios/VoicePiKeyboard/VoicePiApp/Sources/ProfilesView.swift`
- Optional create: `ios/VoicePiKeyboard/VoicePiApp/Sources/ProfileCards.swift`

**Steps:**
1. Replace the current slot-list body with a new page shell matching the reference:
   - page title
   - short description
   - right-side `New Profile` CTA
2. Add `Active Profiles` section with 5 fixed cards:
   - occupied card: title, short prompt preview, active/in-use badges, edit/chevron affordances
   - empty card: placeholder state with add/assign affordance
3. Add `Profile Library` section below:
   - list/grid of all profiles
   - each card shows title, preview, whether it is active in keyboard, and actions
4. Preserve top tab visuals; do not redesign the tab strip.
5. Keep visual language aligned with the recent Settings / Usage refactors.

**Verification:**
- Build `VoicePiApp`
- Capture simulator screenshot of the new Profiles overview state.

### Task 4: Active-Set Interactions

**Files:**
- Modify: `ios/VoicePiKeyboard/VoicePiApp/Sources/ProfileManagementView.swift`
- Modify or create supporting small SwiftUI components in the same area if needed

**Steps:**
1. Wire `New Profile` to the editor flow.
2. Wire library-card actions:
   - `Add to Keyboard`
   - `Remove from Keyboard`
   - `Edit`
3. When all 5 active positions are full, present a replace chooser instead of silently failing.
4. Allow tapping an active-position card to mark it `In Use`.
5. Ensure placeholder cards can assign a library profile into that exact empty slot.

**Verification:**
- Build `VoicePiApp`
- Capture simulator evidence for:
  - library with more than 5 profiles
  - 5 fixed active positions
  - one active position marked `In Use`
  - replace/remove flow state if feasible

### Task 5: Keyboard Compatibility Audit

**Files:**
- Inspect: `Packages/VoicePiCore/Sources/VoicePiCore/Storage/SharedProfileDefaults.swift`
- Inspect any current keyboard/runtime consumers that read `activeProfile`

**Steps:**
1. Confirm current keyboard/runtime callers still compile against the migrated model.
2. If the keyboard currently only reads one active profile, keep that path stable through `selectedKeyboardActiveIndex`.
3. Do not expand keyboard UI in this task unless a compile/runtime dependency forces it.

**Verification:**
- Run: `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiKeyboardExtension -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Expected: extension still builds cleanly.

### Task 6: Final Evidence and Review Packet

**Files:**
- No required code changes

**Steps:**
1. Re-run fresh host-app and extension builds.
2. Count warnings exactly; do not paraphrase.
3. Provide simulator screenshots for the key states.
4. Explicitly call out any remaining boundary, especially if keyboard-side multi-profile switching is still data-ready but not yet visibly exposed in the extension UI.

**Verification:**
- `xcodegen generate`
- `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
- `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiKeyboardExtension -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
- `swift test --package-path Packages/VoicePiCore`

## Honesty Boundaries

- This task is not only a visual restyle; it changes the shared profile model.
- Keyboard UI for switching among the 5 active profiles is only in scope if required to keep the current runtime coherent.
- Do not claim “unlimited profiles fully work in keyboard” unless runtime evidence actually shows keyboard-side selection behavior, not just stored config support.
