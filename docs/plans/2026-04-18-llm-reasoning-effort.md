# LLM Thinking Toggle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an optional `enable_thinking` setting for LLM refinement so the field is omitted by default and sent only when the user explicitly selects `On` or `Off`.

**Architecture:** Extend `LLMConfiguration` with an optional thinking toggle, thread it through settings persistence and the settings window, and encode it into the chat completions payload only when present. Use a tri-state UI model: unset means omit the field, `On` encodes `true`, and `Off` encodes `false`.

**Tech Stack:** Swift, AppKit, Foundation, Testing

### Task 1: Persist Optional Thinking Toggle

**Files:**
- Modify: `Sources/VoicePi/AppModel.swift`
- Test: `Tests/VoicePiTests/AppModelPersistenceTests.swift`

**Step 1: Write the failing test**

Add a persistence test that saves an `LLMConfiguration` with `enable_thinking: false` and verifies it survives reload. Add a second assertion path that default configuration keeps the field unset.

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppModelPersistenceTests`

Expected: FAIL because `LLMConfiguration` does not yet store or decode the new field.

**Step 3: Write minimal implementation**

Add an optional `enable_thinking` property plus Codable support and thread it through `saveLLMConfiguration`.

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppModelPersistenceTests`

Expected: PASS for the new persistence assertions.

### Task 2: Encode Optional Thinking Toggle In Requests

**Files:**
- Modify: `Sources/VoicePi/LLMRefiner.swift`
- Test: `Tests/VoicePiTests/LLMRefinerTests.swift`

**Step 1: Write the failing test**

Add one test asserting the request payload omits `enable_thinking` when unset, and two tests asserting it is present when explicitly set to `false` and `true`.

**Step 2: Run test to verify it fails**

Run: `swift test --filter LLMRefinerTests`

Expected: FAIL because the payload type has no optional thinking field.

**Step 3: Write minimal implementation**

Make the chat completion request payload encode `enable_thinking` only when the configuration carries a selection.

**Step 4: Run test to verify it passes**

Run: `swift test --filter LLMRefinerTests`

Expected: PASS for the new request-encoding assertions.

### Task 3: Add Settings UI For Explicit Thinking Selection

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Test: `Tests/VoicePiTests/AppModelPersistenceTests.swift`

**Step 1: Write the failing test**

Cover the saved configuration path so an explicitly selected thinking toggle persists through the existing settings save flow.

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppModelPersistenceTests`

Expected: FAIL until save wiring includes the new field.

**Step 3: Write minimal implementation**

Add a `Thinking` popup with `Not Set`, `On`, and `Off`, load it from model state, and ensure save/test delegates receive the selected value only when explicitly chosen.

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppModelPersistenceTests`

Expected: PASS.

### Task 4: Verify Touched Areas

**Files:**
- Test: `Tests/VoicePiTests/AppModelPersistenceTests.swift`
- Test: `Tests/VoicePiTests/LLMRefinerTests.swift`

**Step 1: Run targeted tests**

Run: `swift test --filter AppModelPersistenceTests`

Run: `swift test --filter LLMRefinerTests`

**Step 2: Run broader suite if targeted tests stay green**

Run: `./Scripts/test.sh`

Expected: PASS, or a clearly isolated unrelated failure to report.
