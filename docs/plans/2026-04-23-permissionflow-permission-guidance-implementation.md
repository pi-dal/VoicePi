# PermissionFlow Permission Guidance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate `PermissionFlow` so VoicePi provides a stronger guided authorization flow for `Accessibility` and `Input Monitoring` without changing the existing `Microphone` and `Speech Recognition` permission behavior.

**Architecture:** Keep VoicePi's current permission state checks and launch-time media/system prompt behavior. Add a small `PermissionFlow` bridge owned by `AppController`, route only the manual and follow-up `Accessibility` / `Input Monitoring` settings handoff through that bridge, and preserve existing AppKit settings UI plus refresh logic.

**Tech Stack:** SwiftPM, AppKit, SwiftUI-backed third-party package (`PermissionFlow`), `Testing`

### Task 1: Capture the new decision surface in tests

**Files:**
- Modify: `Tests/VoicePiTests/AppControllerInteractionTests.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`

**Step 1: Write the failing test**

Add tests that assert:
- `Accessibility` and `Input Monitoring` use a `PermissionFlow` transition style.
- `Microphone` and `Speech Recognition` continue using the existing custom prompt/settings flow.

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppControllerInteractionTests`
Expected: FAIL because the transition-style model still only exposes the current custom prompt behavior.

**Step 3: Write minimal implementation**

Extend the permission transition decision helpers in `AppCoordinator.swift` so the two drag-to-authorize permissions are modeled separately from media permissions.

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppControllerInteractionTests`
Expected: PASS

### Task 2: Add a minimal PermissionFlow bridge

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VoicePi/PermissionGuidanceFlow.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`

**Step 1: Write the failing test**

Add a focused test that asserts `Accessibility` and `Input Monitoring` map to `PermissionFlow` panes, while media permissions do not.

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppControllerInteractionTests`
Expected: FAIL because there is no pane-mapping bridge yet.

**Step 3: Write minimal implementation**

Add the SwiftPM dependency and implement a thin bridge that:
- owns a reusable `PermissionFlowController`
- maps VoicePi destinations to supported `PermissionFlowPane` values
- launches the flow with `Bundle.main.bundleURL`

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppControllerInteractionTests`
Expected: PASS

### Task 3: Route the existing settings handoff through PermissionFlow

**Files:**
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Test: `Tests/VoicePiTests/AppControllerInteractionTests.swift`

**Step 1: Write the failing test**

Add tests around the coordinator decision helpers so manual/follow-up `Accessibility` and `Input Monitoring` requests no longer depend on the legacy custom settings prompt path.

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppControllerInteractionTests`
Expected: FAIL because coordinator methods still always open the legacy alert-based prompt for those destinations.

**Step 3: Write minimal implementation**

Update the coordinator to:
- invoke the new `PermissionGuidanceFlow` for `Accessibility` / `Input Monitoring`
- keep system prompt behavior for launch-time `Accessibility` when `useSystemAccessibilityPrompt` is true
- keep existing media permission behavior untouched

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppControllerInteractionTests`
Expected: PASS

### Task 4: Verify package integration and regression coverage

**Files:**
- Modify only if needed during verification

**Step 1: Run targeted verification**

Run: `swift test --filter AppControllerInteractionTests`
Expected: PASS

**Step 2: Run package-level verification**

Run: `./Scripts/test.sh`
Expected: PASS

**Step 3: Build-level verification**

Run: `./Scripts/verify.sh`
Expected: PASS, including successful resolution/build of the new Swift package dependency
