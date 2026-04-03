# Floating Panel Transcript Overflow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the newest transcript characters visible in the floating panel once the panel reaches its maximum width.

**Architecture:** Keep the existing single-line floating panel layout and change its overflow behavior so the head of the string is truncated instead of the tail. Cover the behavior with a focused controller test that locks the label configuration used for live transcription updates.

**Tech Stack:** Swift, AppKit, Testing

### Task 1: Capture the overflow behavior in tests

**Files:**
- Modify: `Tests/VoicePiTests/FloatingPanelControllerTests.swift`
- Test: `Tests/VoicePiTests/FloatingPanelControllerTests.swift`

**Step 1: Write the failing test**

Add a test that creates `FloatingPanelController`, loads the view hierarchy, finds the transcript label, and expects `lineBreakMode == .byTruncatingHead` with `maximumNumberOfLines == 1`.

**Step 2: Run test to verify it fails**

Run: `swift test --filter FloatingPanelControllerTests`
Expected: FAIL because the current label uses `.byTruncatingTail`.

**Step 3: Write minimal implementation**

Update `Sources/VoicePi/FloatingPanelController.swift` so the transcript label truncates from the head while keeping the single-line configuration.

**Step 4: Run test to verify it passes**

Run: `swift test --filter FloatingPanelControllerTests`
Expected: PASS.

### Task 2: Verify the change against the broader app target

**Files:**
- Modify: `Sources/VoicePi/FloatingPanelController.swift`
- Test: `Tests/VoicePiTests/FloatingPanelControllerTests.swift`

**Step 1: Run focused verification**

Run: `swift test --filter FloatingPanelControllerTests`
Expected: PASS with the new overflow behavior assertion.

**Step 2: Run repository verification for confidence**

Run: `./Scripts/test.sh`
Expected: PASS.
