# Input Fallback Service Panel Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Preserve recognized text when VoicePi cannot find an editable input target, then present a fallback service panel that lets the user copy the full result.

**Architecture:** Add a small delivery-routing layer that decides between direct paste injection and a fallback panel. Keep accessibility focus inspection separate from `TextInjector`, and keep the fallback panel's summary, expansion, and theme state testable with pure support types before wiring it into AppKit controllers.

**Tech Stack:** Swift, AppKit, ApplicationServices, Testing

### Task 1: Capture delivery routing in tests

**Files:**
- Create: `Tests/VoicePiTests/TranscriptDeliveryTests.swift`
- Create: `Sources/VoicePi/TranscriptDelivery.swift`

**Step 1: Write the failing test**

Add tests for:

- empty final text routes to `.emptyResult`
- editable target routes to `.injectableTarget`
- missing or unreadable target routes to `.fallbackPanel`

**Step 2: Run test to verify it fails**

Run: `swift test --filter TranscriptDeliveryTests`
Expected: FAIL because `TranscriptDelivery` types do not exist.

**Step 3: Write minimal implementation**

Create `TranscriptDelivery.swift` with a small routing enum and helper that trims text and resolves the delivery path.

**Step 4: Run test to verify it passes**

Run: `swift test --filter TranscriptDeliveryTests`
Expected: PASS.

### Task 2: Capture fallback panel content behavior in tests

**Files:**
- Create: `Tests/VoicePiTests/InputFallbackPanelSupportTests.swift`
- Create: `Sources/VoicePi/InputFallbackPanelSupport.swift`

**Step 1: Write the failing test**

Add tests for:

- short text stays collapsed and does not expose expand/collapse
- long text starts collapsed and exposes expand/collapse
- summary text is shorter than the full text
- copy action always uses the full text
- light and dark appearance palettes resolve to different chrome/text values

**Step 2: Run test to verify it fails**

Run: `swift test --filter InputFallbackPanelSupportTests`
Expected: FAIL because the support types do not exist.

**Step 3: Write minimal implementation**

Create support types for:

- pending fallback payload
- summary/expansion presentation state
- palette mapping for light vs dark mode

**Step 4: Run test to verify it passes**

Run: `swift test --filter InputFallbackPanelSupportTests`
Expected: PASS.

### Task 3: Build editable target inspection

**Files:**
- Create: `Tests/VoicePiTests/EditableTextTargetInspectorTests.swift`
- Create: `Sources/VoicePi/EditableTextTargetInspector.swift`

**Step 1: Write the failing test**

Add tests for a pure helper that classifies accessibility role metadata as editable or not editable.

**Step 2: Run test to verify it fails**

Run: `swift test --filter EditableTextTargetInspectorTests`
Expected: FAIL because the inspector and helper do not exist.

**Step 3: Write minimal implementation**

Implement:

- an inspector protocol the app can call
- a production accessibility-backed inspector
- a pure role/value classifier used by tests

**Step 4: Run test to verify it passes**

Run: `swift test --filter EditableTextTargetInspectorTests`
Expected: PASS.

### Task 4: Build the fallback panel controller

**Files:**
- Create: `Tests/VoicePiTests/InputFallbackPanelControllerTests.swift`
- Create: `Sources/VoicePi/InputFallbackPanelController.swift`

**Step 1: Write the failing test**

Add controller tests that:

- load the panel and verify collapsed state content
- verify expand/collapse changes the visible transcript
- verify the panel accepts both light and dark appearance updates

**Step 2: Run test to verify it fails**

Run: `swift test --filter InputFallbackPanelControllerTests`
Expected: FAIL because the controller does not exist.

**Step 3: Write minimal implementation**

Implement a dedicated interactive `NSPanel` controller that:

- presents the fallback payload
- toggles expand/collapse
- copies the full text through `NSPasteboard`
- closes after copy

**Step 4: Run test to verify it passes**

Run: `swift test --filter InputFallbackPanelControllerTests`
Expected: PASS.

### Task 5: Wire delivery routing into `AppController`

**Files:**
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Tests/VoicePiTests/AppControllerInteractionTests.swift`

**Step 1: Write the failing test**

Add focused tests around the new delivery decision helper used by `AppController`.

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppControllerInteractionTests`
Expected: FAIL because the new delivery helper or behavior is missing.

**Step 3: Write minimal implementation**

Update `AppController` to:

- resolve delivery route after post-processing
- inject only for editable targets
- otherwise present the fallback panel
- hide the recording panel before showing the fallback panel

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppControllerInteractionTests`
Expected: PASS.

### Task 6: Verify the full change

**Files:**
- Verify all changed source and test files

**Step 1: Run focused verification**

Run:

- `swift test --filter TranscriptDeliveryTests`
- `swift test --filter InputFallbackPanelSupportTests`
- `swift test --filter EditableTextTargetInspectorTests`
- `swift test --filter InputFallbackPanelControllerTests`
- `swift test --filter AppControllerInteractionTests`

Expected: PASS.

**Step 2: Run repository verification**

Run: `./Scripts/test.sh`
Expected: PASS.
