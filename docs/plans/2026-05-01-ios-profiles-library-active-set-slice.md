# Profiles Page — Library + Active Set Before-Start Slice

> Task: #17 "Profiles page visual refactor and active keyboard subset"
> Gate: Cindy. Do NOT start implementation until this slice is approved.
> Plan: `docs/plans/2026-05-01-ios-profiles-library-active-set-plan.md`

## Locked Scope

From pi-dal's mockup + Hesse's design lock:

- ✅ Top tab bar untouched
- ✅ Profiles page becomes two layers:
  - **Active Profiles**: always 5 fixed positions, filled slots show profile card, empty slots show placeholder
  - **Profile Library**: all saved profiles, can exceed 5, each card shows title + preview + actions
- ✅ Keyboard-visible profiles come only from the active section
- ✅ Fixed 5 positions express ordering (no drag-and-drop this round)
- ✅ `New Profile` → creates library entry
- ✅ Library card → `Add to Keyboard` (assigns to empty slot) / `Remove from Keyboard`
- ✅ Tapping active-position card → marks `In Use`
- ✅ When all 5 active slots full, `Add to Keyboard` presents replace chooser
- ✅ Old 5-slot model migrates to new library + active-set on decode
- ✅ Keyboard extension: profile name visible in bar, tap-to-cycle among active profiles, `promptBody` wired to `refinementStream.refine(text:prompt:)`

---

## 1. Data Model Migration (VoicePiCore)

### Current model

```swift
public struct VoicePiSharedConfig {
    public var slots: [ProfileSlot]           // 5 fixed, each has optional profile + isActive
    public var selectedSlotIndex: Int         // which slot is "active"
    // ... asrConfig, refinementConfig, usageStats
}
```

### New model

```swift
public struct VoicePiSharedConfig {
    public var profiles: [PromptProfile]               // full library, ordered by creation
    public var keyboardActiveProfileIDs: [String?]     // exactly 5, nil = empty slot
    public var selectedKeyboardActiveIndex: Int        // 0..4, which index is "in use"
    // ... asrConfig, refinementConfig, usageStats unchanged
}
```

### Compatibility decode strategy

Custom `Decodable` on `VoicePiSharedConfig`:

1. Try decoding new keys (`profiles`, `keyboardActiveProfileIDs`, `selectedKeyboardActiveIndex`)
2. If those are absent, fall back to old keys (`slots`, `selectedSlotIndex`)
3. Migration: old `slots[i].profile` → `profiles` + set `keyboardActiveProfileIDs[i] = profile.id`; old `selectedSlotIndex` → `selectedKeyboardActiveIndex`
4. Default `init()`: empty `profiles`, 5 nil slots, `selectedKeyboardActiveIndex = 0`, built-in default profile pre-populated in profiles[0]

### Mutation helpers (on VoicePiSharedConfig)

```swift
// Library CRUD
mutating func createProfile(_ profile: PromptProfile)
mutating func updateProfile(_ profile: PromptProfile)
mutating func deleteProfile(by id: String)  // also removes from keyboardActiveProfileIDs if present

// Active set management
mutating func assignProfileToKeyboard(id: String, at slotIndex: Int)
mutating func removeProfileFromKeyboard(at slotIndex: Int)
mutating func markKeyboardActiveIndex(_ index: Int)

// Computed
var activeProfile: PromptProfile?   // profile at selectedKeyboardActiveIndex
var keyboardActiveProfiles: [(index: Int, profile: PromptProfile?)]  // enumerated for UI
```

### Deletion of old model

- `ProfileSlot` struct: **remove** from `ProfileModels.swift`
- `selectSlot(at:)` / `updateProfile(_:inSlot:)` methods: **remove**
- `buildInProfileSlotDefault()` if exists: **remove**

### Files

| File | Change |
|------|--------|
| `VoicePiCore/ProfileModels/ProfileModels.swift` | Replace slots + ProfileSlot with profiles + keyboardActiveProfileIDs + helpers |
| `VoicePiCore/Storage/SharedProfileDefaults.swift` | Replace slot-based wrappers with new helpers |
| `VoicePiCore/Tests/VoicePiCoreTests.swift` | Update tests for new model; add migration decode tests |

---

## 2. Host App State Wrapper (SharedDefaultsWrapper)

### Replace old slot-based methods

Remove:
- `selectSlot(at:)` / `updateProfile(_:inSlot:)`

Add:
```swift
func createProfile(_ profile: PromptProfile)
func updateProfile(_ profile: PromptProfile)
func deleteProfile(by id: String)
func assignProfileToKeyboard(id: String, at slotIndex: Int)
func removeProfileFromKeyboard(at slotIndex: Int)
func markKeyboardActiveIndex(_ index: Int)
```

Each reads `config`, calls the corresponding `VoicePiSharedConfig` mutating method, writes back. Same atomic pattern as existing wrapper methods.

### ProfileEditorView — real changes required

Current editor is slot-based:
```swift
ProfileEditorView(
    profile: ...,
    slotIndex: selectedSlotIndex,          // ← removed
    onSave: { newProfile in
        sharedDefaults.updateProfile(newProfile, inSlot: selectedSlotIndex)  // ← changed
    },
    ...
)
```

Changes:
1. **Remove `slotIndex` parameter** from `ProfileEditorView` (editor should not know about slots — it edits a profile)
2. **Change `onSave` caller**: wrapper checks if profile ID already exists in library and calls `createProfile` or `updateProfile` accordingly
3. **New vs Edit context**: caller passes `editingProfile` (existing library profile) or a fresh `PromptProfile()` (new creation); the wrapper method decides create/update by checking `config.profiles.contains(where: { $0.id == profile.id })`

The `onSave` closure signature stays `(PromptProfile) -> Void` — no change there. The difference is only in the wrapper method it calls.

### Files

| File | Change |
|------|--------|
| `ProfileManagementView.swift` | Replace slot-based wrapper methods; update editor call site (remove `slotIndex`); update `ProfileSlotsTab` body → `ProfilesView()`; remove old slot UI (ProfileSlotRow, ComingNextPill, etc.) |

---

## 3. Profiles Page Visual Rebuild (ProfileManagementView + new components)

### New file: `ProfilesView.swift`

Extracted from `ProfileManagementView` to keep the tab view clean. Contains:

```
┌────────────────────────────────────────┐
│  Profiles          [+ New Profile]     │  ← page header with CTA
│  Manage your prompt profiles           │  ← subtitle
├────────────────────────────────────────┤
│  Active Profiles                       │  ← section header
│  ┌──────────┐ ┌──────────┐ ...         │
│  │ Slot 1   │ │ Slot 2   │  (5 cards)  │  ← horizontal ScrollView or grid
│  │ General  │ │ Empty    │             │
│  │ In Use ✓ │ │ + Add    │             │
│  └──────────┘ └──────────┘             │
├────────────────────────────────────────┤
│  Profile Library                       │  ← section header
│  ┌──────────────────────────────────┐  │
│  │ Meeting     Edit  Add to Keyboard│  │  ← library card
│  ├──────────────────────────────────┤  │
│  │ Casual      Edit  Add to Keyboard│  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

### Active Profiles section

- 5 fixed cards, rendered in a horizontal or wrapped layout
- Occupied card: colored icon circle (matching mockup), title, short prompt preview, `In Use` badge if selected, tap to mark `In Use`
- Empty card: dashed border / lighter surface, `+ Add` affordance
- When tapped, empty slot presents profile picker (library profiles not already active)

### Profile Library section

- Vertical list/scroll of all `profiles`
- Each card: title, promptBody preview (1-2 lines), action buttons
- Action buttons per plan: Edit, Add/Remove from Keyboard
- `+ New Profile` → opens `ProfileEditorView` (existing sheet, already wired)

### Components

Reuse existing `VoicePiCard`, `VoicePiTheme` tokens. New small components as needed (active slot card, library profile card) — prefer inline structs in `ProfilesView.swift` unless they grow >50 lines, then extract to `ProfileCards.swift`.

### Files

| File | Change |
|------|--------|
| `ProfileManagementView.swift` | Replace `ProfileSlotsTab` body with `ProfilesView()`; update wrapper methods; remove old slot UI |
| `ProfilesView.swift` (new) | Active Profiles section + Profile Library section + New Profile CTA |
| `ProfileCards.swift` (new, optional) | Extracted card components if they exceed 50 lines |

---

## 4. Keyboard Extension: Minimal Profile Selector + Prompt Wiring

pi-dal's requirement: "默认的可以选择5个 active 的来作为 keyboard 可选项。" The keyboard extension currently has **zero** profile consumption — `PromptProfile.promptBody` is never passed to `refinementStream.refine()`. This section adds minimal profile visibility and switching.

### Current state

- `KeyboardRootViewController.setupSession()` reads `sharedConfig.asrConfig` and `refinementConfig` only — never reads profiles
- `KeyboardSessionController.refine(text:)` is called WITHOUT the `prompt:` parameter → profile's `promptBody` is unused
- No profile name/selector visible in the keyboard bar

### Changes

#### 4a. PreviewBarView + KeyboardContentView

Add profile name display + tap-to-cycle:

```swift
// PreviewBarView: new optional parameters
var activeProfileName: String? = nil       // display name, nil = hidden
var onProfileTap: (() -> Void)? = nil      // tap to cycle to next profile
```

When `activeProfileName` is non-nil, show a small tappable label between the state indicator and hint text:
```
● [General ▾]  Tap to record         🎤
```

Tap calls `onProfileTap` which cycles to the next active profile. No picker UI — single tap = next profile (simple cycling, minimal footprint).

#### 4b. KeyboardRootViewController

- Add `private var activeProfileNames: [(index: Int, name: String)] = []` 
- `setupSession()` → read `sharedConfig.keyboardActiveProfileIDs` + `profiles` → build `activeProfileNames`
- Add `cycleToNextProfile()` → increments `selectedKeyboardActiveIndex` (wrapping at next non-nil slot), writes to shared config
- `rebuildView()` → pass current profile name + tap handler to `KeyboardContentView`
- Before calling `sessionController.startRecording()`, read `activeProfile?.promptBody` and set it on the session controller

#### 4c. KeyboardSessionController

- Add `public var profilePrompt: String? = nil` property
- In `asrStream(_:didReceiveFinalText:)`, change `self.refinementStream?.refine(text: text)` → `self.refinementStream?.refine(text: text, prompt: profilePrompt)`

This is the one-line change that actually wires the profile prompt into refinement.

### Files

| File | Change |
|------|--------|
| `PreviewBarView.swift` (keyboard ext) | +`activeProfileName` + `onProfileTap` parameters; add tappable profile label in body |
| `KeyboardRootViewController.swift` (keyboard ext) | Read active profiles, `cycleToNextProfile()`, pass to view, pass prompt to session controller |
| `KeyboardSessionController.swift` (keyboard ext) | +`profilePrompt` property; pass to `refine(text:prompt:)` |

### Verification

```bash
xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj \
  -scheme VoicePiKeyboardExtension \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

Expected: extension builds cleanly. Zero runtime evidence for keyboard selector (simulator keyboard extensions have limited interaction surface).

---

## 5. Test Strategy

### VoicePiCore tests to update

| Test | Change |
|------|--------|
| `testPromptProfileDefaults` | Keep — PromptProfile unchanged |
| `testPromptProfileBuiltInDefault` | Keep |
| `testProfileSlot` | Remove — ProfileSlot deleted |
| `testVoicePiSharedConfig` | Rewrite for new model shape (profiles + keyboardActiveProfileIDs + selectedKeyboardActiveIndex) |
| `testUpdateProfile` | Rewrite for `updateProfile(_:)` not `updateProfile(_:inSlot:)` |
| `testActiveProfile` | Rewrite for new `activeProfile` computed property |

### New tests to add

- `testDefaultConfigShape` — empty profiles, 5 nil keyboard slots, index 0
- `testMigrationFromOldSlotsPayload` — JSON with `slots` key decodes into new fields
- `testAssignProfileToKeyboard` — assign fills slot, remove clears it
- `testDeleteProfileRemovesFromKeyboard` — deleting a profile clears its keyboard slot
- `testKeyboardActiveProfilesHelper` — enumerated array correct
- `testReplaceFlowWhenFull` — assigning when all 5 full errors or replaces

---

## 6. What This Slice Does NOT Do

| Concern | Why Not | When |
|---------|---------|------|
| Touch top tab bar | Explicit scope boundary | Never |
| Drag-and-drop reorder of active slots | Explicitly excluded this round | Future |
| Full keyboard profile picker UI (dropdown/menu) | Simple tap-to-cycle, not a designed picker | Future keyboard task |
| iCloud sync | Explicitly excluded | Never in this line |
| Change VoicePiCore beyond ProfileModels.swift + SharedProfileDefaults.swift | Other models (ASRConfig, RefinementConfig, UsageStats) unchanged | N/A |
| Remove `ComingNextPill` | Profile slot rows deleted entirely, pill goes with them | N/A |

---

## 7. Build Verification (Exit Gate)

```bash
# VoicePiCore tests
swift test --package-path Packages/VoicePiCore

# Host app
xcodegen generate --spec ios/VoicePiKeyboard/project.yml
xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj \
  -scheme VoicePiApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Keyboard extension
xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj \
  -scheme VoicePiKeyboardExtension \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

Success criteria: all 3 stages pass. Host app + extension build 0 errors. VoicePiCore tests: all pass except pre-existing App Group failures (3).

---

## 8. Estimated Diff Size

| File | Lines changed |
|------|---------------|
| `ProfileModels.swift` | ~80 lines (+profiles/keyboardActiveProfileIDs fields, +compat decode, +mutation helpers, -ProfileSlot, -slot methods) |
| `SharedProfileDefaults.swift` | ~30 lines (-selectSlot/-updateProfile wrappers, +new wrappers) |
| `VoicePiCoreTests.swift` | ~60 lines (-3 slot tests, +6 new tests) |
| `ProfileManagementView.swift` | ~50 lines (-ProfileSlotsTab body, -old wrapper methods, +ProfilesView() reference, +new wrappers) |
| `ProfilesView.swift` (new) | ~250 lines (header + Active Profiles section + Profile Library section) |
| `PreviewBarView.swift` (keyboard ext) | ~15 lines (+`activeProfileName` + `onProfileTap` params, profile label in body) |
| `KeyboardRootViewController.swift` (keyboard ext) | ~30 lines (read active profiles, `cycleToNextProfile()`, pass to view, pass prompt) |
| `KeyboardSessionController.swift` (keyboard ext) | ~5 lines (+`profilePrompt` property, pass to `refine(text:prompt:)`) |
| **Total** | ~520 lines |

VoicePiCore schema change: 3 files. Host App: 2 files (1 new). Keyboard extension: 3 files modified.
