# VoicePi Testability And Coverage Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expand automated coverage around VoicePi's highest-risk behavior while refactoring tightly coupled code into smaller testable units.

**Architecture:** Extract pure logic and injectable seams from the app coordinator, settings window controller, and network clients so behavior can be tested without driving full AppKit or live network calls. Add a single repository-level verification entrypoint that runs both Swift tests and shell-based packaging tests.

**Tech Stack:** Swift 5.9, Swift Testing, AppKit, Foundation, shell scripts, Swift Package Manager

### Task 1: Add a repository-wide verification entrypoint

**Files:**
- Modify: `Makefile`
- Create: `Scripts/test.sh`
- Modify: `Scripts/verify.sh`

**Step 1: Write the failing shell-level expectation**

Define the behavior to add:
- one command should run `swift test`
- the same command should run `Tests/*.sh`
- `Scripts/verify.sh` should use the new entrypoint before app bundling

**Step 2: Run current verification to confirm the gap**

Run: `./Scripts/verify.sh`
Expected: PASS without running shell tests, confirming the gap still exists.

**Step 3: Implement the unified test entrypoint**

Add:
- a `test` target in `Makefile`
- a `Scripts/test.sh` wrapper
- `Scripts/verify.sh` calling the new test entrypoint before packaging/build confirmation

**Step 4: Verify the new entrypoint**

Run: `./Scripts/test.sh`
Expected: PASS after running both Swift and shell tests.

### Task 2: Cover network endpoint building, request shaping, and response sanitization

**Files:**
- Create: `Tests/VoicePiTests/TestURLProtocol.swift`
- Create: `Tests/VoicePiTests/LLMRefinerTests.swift`
- Create: `Tests/VoicePiTests/RemoteASRClientTests.swift`
- Modify: `Sources/VoicePi/LLMRefiner.swift`
- Modify: `Sources/VoicePi/RemoteASRClient.swift`

**Step 1: Write failing tests**

Add tests for:
- LLM endpoint normalization from bare host, `/v1`, and full chat-completions URLs
- LLM sanitize behavior for fenced output, JSON wrapped output, and empty/fallback output
- LLM request headers and JSON payload
- remote ASR endpoint normalization from bare host, `/v1`, and full transcription URLs
- remote ASR multipart body contents, including optional prompt omission
- remote ASR parsing for JSON response, raw text response, and empty transcription

**Step 2: Run the targeted tests to confirm RED**

Run: `swift test --filter LLMRefinerTests`
Expected: FAIL because helpers are private and request shaping is not exposed enough for direct testing.

Run: `swift test --filter RemoteASRClientTests`
Expected: FAIL because endpoint/body helpers are private and request parsing is not isolated enough.

**Step 3: Extract minimal pure helpers**

Implement:
- internal helper APIs for endpoint building and content sanitization
- internal helper APIs for multipart body building and response parsing
- URLSession injection support via a dedicated test URL protocol fixture

**Step 4: Verify GREEN**

Run: `swift test --filter LLMRefinerTests`
Expected: PASS

Run: `swift test --filter RemoteASRClientTests`
Expected: PASS

### Task 3: Refactor AppController workflow logic behind injectable collaborators

**Files:**
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Create: `Tests/VoicePiTests/AppControllerWorkflowTests.swift`

**Step 1: Write failing workflow tests**

Add tests for:
- remote ASR disabled or incomplete config falls back to local transcript and reports a transient error
- remote ASR empty result falls back to local transcript
- LLM disabled returns original text
- LLM failure returns original text and reports a transient error
- permission gating rejects recording when required permissions are missing

**Step 2: Run targeted tests to confirm RED**

Run: `swift test --filter AppControllerWorkflowTests`
Expected: FAIL because the current controller constructs concrete dependencies internally and workflow helpers are not injectable.

**Step 3: Add injectable seams with minimal surface area**

Implement:
- a dependency container or protocol-backed collaborators for speech recording, remote ASR, LLM refinement, text injection, status reporting, and permission checks
- preserve current runtime wiring in production init
- keep pure decision logic and async workflow behavior testable without the real UI stack

**Step 4: Verify GREEN**

Run: `swift test --filter AppControllerWorkflowTests`
Expected: PASS

### Task 4: Extract settings window presentation state and theme behavior

**Files:**
- Create: `Sources/VoicePi/SettingsPresentation.swift`
- Create: `Tests/VoicePiTests/SettingsPresentationTests.swift`
- Modify: `Sources/VoicePi/StatusBarController.swift`

**Step 1: Write failing presentation-state tests**

Add tests for:
- home section summary strings from model state and error state
- permission pill text and semantic color kind mapping
- about section metadata values
- selected theme index and navigation state mapping

**Step 2: Run targeted tests to confirm RED**

Run: `swift test --filter SettingsPresentationTests`
Expected: FAIL because these strings and mappings are currently embedded in AppKit controller code.

**Step 3: Extract pure presentation helpers**

Implement:
- a settings presentation/state builder for summary labels and about metadata
- small semantic enums for permission status appearance instead of testing raw `NSColor`
- controller code updated to render from the extracted presentation state

**Step 4: Verify GREEN**

Run: `swift test --filter SettingsPresentationTests`
Expected: PASS

### Task 5: Expand model and recorder/injector pure logic coverage

**Files:**
- Create: `Tests/VoicePiTests/AppModelPersistenceTests.swift`
- Create: `Tests/VoicePiTests/SpeechRecorderMathTests.swift`
- Create: `Tests/VoicePiTests/TextInjectorSupportTests.swift`
- Modify: `Sources/VoicePi/AppModel.swift`
- Modify: `Sources/VoicePi/SpeechRecorder.swift`
- Modify: `Sources/VoicePi/TextInjector.swift`

**Step 1: Write failing tests**

Add tests for:
- `AppModel` persistence of LLM config, remote ASR config, backend, shortcut, and readiness flags
- `OverlayState.statusText` and recording-state transitions
- speech recorder decibel normalization bounds and envelope behavior
- text injector input-source classification and MIME-independent clipboard guard helpers where practical

**Step 2: Run targeted tests to confirm RED**

Run: `swift test --filter AppModelPersistenceTests`
Expected: FAIL where coverage is currently missing or helper APIs are inaccessible.

Run: `swift test --filter SpeechRecorderMathTests`
Expected: FAIL because math helpers are private.

Run: `swift test --filter TextInjectorSupportTests`
Expected: FAIL because CJK classification helpers are private.

**Step 3: Extract or widen only pure helper access**

Implement:
- internal helper APIs for model persistence and readiness expectations where needed
- internal speech-recorder math helpers suitable for direct unit testing
- internal text-injector heuristics helper for input-source classification

**Step 4: Verify GREEN**

Run: `swift test --filter AppModelPersistenceTests`
Expected: PASS

Run: `swift test --filter SpeechRecorderMathTests`
Expected: PASS

Run: `swift test --filter TextInjectorSupportTests`
Expected: PASS

### Task 6: Run full verification

**Files:**
- No additional code changes expected

**Step 1: Run all Swift tests**

Run: `swift test`
Expected: PASS

**Step 2: Run unified repository tests**

Run: `./Scripts/test.sh`
Expected: PASS

**Step 3: Run verification workflow**

Run: `./Scripts/verify.sh`
Expected: PASS with debug app bundle generated after tests complete.
