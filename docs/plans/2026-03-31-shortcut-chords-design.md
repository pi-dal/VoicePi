# Shortcut Chords Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Support activation shortcuts with one to three simultaneous non-modifier keys instead of only a single key.

**Architecture:** Extend `ActivationShortcut` from a single optional key into an ordered key-code list with backward-compatible decoding. Add small pure state helpers so the recorder UI and global monitor use the same chord semantics and can be tested without synthesizing AppKit event loops.

**Tech Stack:** Swift 5.9, AppKit, Carbon, Swift Testing

### Task 1: Add failing tests for chord storage and capture semantics

**Files:**
- Create: `Tests/VoicePiTests/ShortcutChordTests.swift`
- Modify: `Sources/VoicePi/AppModel.swift`
- Create: `Sources/VoicePi/ShortcutChordSupport.swift`

**Step 1: Write the failing tests**

Add tests for:
- legacy decoding from a single stored `keyCode`
- multi-key display/menu formatting
- recorder state preserving multiple simultaneous keys until commit
- monitor state activating only when all expected keys are down

**Step 2: Run test to verify it fails**

Run: `swift test --filter ShortcutChordTests`
Expected: FAIL because the current implementation stores one key and lacks chord state helpers.

### Task 2: Implement the minimal chord model and shared state

**Files:**
- Modify: `Sources/VoicePi/AppModel.swift`
- Create: `Sources/VoicePi/ShortcutChordSupport.swift`

**Step 1: Extend `ActivationShortcut`**

Implement:
- ordered `keyCodes: [UInt16]`
- compatibility init for `keyCode`
- backward-compatible `Codable`
- multi-key display/menu helpers

**Step 2: Add pure recorder and monitor state helpers**

Implement:
- recorder state that tracks current pressed keys and commits on final release
- monitor state that tracks expected key sets and active state transitions

**Step 3: Run test to verify it passes**

Run: `swift test --filter ShortcutChordTests`
Expected: PASS

### Task 3: Wire the UI recorder and global monitor to the shared state

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/FnKeyMonitor.swift`

**Step 1: Replace one-key capture logic in `ShortcutRecorderField`**

Use the recorder state helper for:
- modifier preview updates
- key-down accumulation
- key-up commit

**Step 2: Replace one-key monitor tracking**

Use the monitor state helper so the activation shortcut presses when the full chord is held and releases when any required key or modifier is released.

**Step 3: Run targeted verification**

Run: `swift test --filter ShortcutChordTests`
Expected: PASS

### Task 4: Run full verification

**Files:**
- No additional code changes expected

**Step 1: Run the full test suite**

Run: `swift test`
Expected: PASS

**Step 2: Run the app verification build**

Run: `./Scripts/verify.sh`
Expected: successful debug app bundle build
