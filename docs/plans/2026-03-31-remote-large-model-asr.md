
Tests/VoicePiTests/RemoteASRSupportTests.swift
docs/plans/2026-03-31-remote-large-model-asr.md
# Remote Large-Model ASR Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make VoicePi reliably support a remote OpenAI-compatible ASR backend so users can record locally, upload audio to a stronger remote model, and inject the returned transcript.

**Architecture:** Keep microphone capture inside `SpeechRecorder`, but switch it to capture-only mode whenever the app selects the remote backend. Use a single shared `RemoteASRConfiguration` model across `AppModel`, `AppController`, and `RemoteASRClient`, then expose the backend choice and remote credentials in the settings window.

**Tech Stack:** SwiftPM, AppKit, AVFoundation, Speech, Foundation networking, XCTest.

### Task 1: Add regression tests for backend selection and remote configuration

**Files:**
- Modify: `Package.swift`
- Create: `Tests/VoicePiTests/RemoteASRSupportTests.swift`

**Step 1: Write the failing tests**

```swift
func testRemoteBackendUsesCaptureOnlyRecorderMode()
func testRemoteConfigurationAcceptsHostWithoutScheme()
func testRemoteConfigurationRequiresBaseURLKeyAndModel()
```

**Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL because the test target is missing and the current ASR model surface is inconsistent.

**Step 3: Write minimal implementation**

Expose a pure mapping from `ASRBackend` to `SpeechRecorderMode` and a single shared `RemoteASRConfiguration` validation surface.

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS for the new regression tests.

### Task 2: Unify the remote ASR configuration model and client

**Files:**
- Modify: `Sources/VoicePi/AppModel.swift`
- Modify: `Sources/VoicePi/RemoteASRClient.swift`

**Step 1: Write the failing test**

Use the configuration tests from Task 1 to prove the shared model behavior.

**Step 2: Run test to verify it fails**

Run: `swift test --filter RemoteASRSupportTests`
Expected: FAIL until the duplicate config type is removed and validation helpers exist.

**Step 3: Write minimal implementation**

Keep one `RemoteASRConfiguration` type, add `validate()`, `normalizedBaseURL`, and prompt support, and update `RemoteASRClient` to consume that shared type.

**Step 4: Run test to verify it passes**

Run: `swift test --filter RemoteASRSupportTests`
Expected: PASS.

### Task 3: Reconnect recording flow to the remote backend

**Files:**
- Modify: `Sources/VoicePi/SpeechRecorder.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`

**Step 1: Write the failing test**

Use the recorder-mode mapping test from Task 1 to prove the backend switch selects capture-only recording for remote ASR.

**Step 2: Run test to verify it fails**

Run: `swift test --filter testRemoteBackendUsesCaptureOnlyRecorderMode`
Expected: FAIL until the backend mapping exists and `AppController` uses it.

**Step 3: Write minimal implementation**

Start `SpeechRecorder` in `.captureOnly` mode for the remote backend, use `latestAudioFileURL` after stop, pass remote prompt through, and fix the broken delegate method signatures.

**Step 4: Run test to verify it passes**

Run: `swift test --filter testRemoteBackendUsesCaptureOnlyRecorderMode`
Expected: PASS and `swift build` succeeds.

### Task 4: Restore remote ASR controls in settings

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`

**Step 1: Write the failing test**

Use `swift build` as the regression gate because the settings protocols currently reference missing remote-ASR types and handlers.

**Step 2: Run build to verify it fails**

Run: `swift build`
Expected: FAIL with missing remote settings types and mismatched delegate signatures.

**Step 3: Write minimal implementation**

Add an ASR settings section with backend selection, remote credential fields, test/save actions, and wire the delegate methods into `AppController`.

**Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS.

### Task 5: Verify the full app and docs

**Files:**
- Modify: `README.md`

**Step 1: Run verification**

Run: `swift test && swift build`
Expected: PASS.

**Step 2: Update docs**

Document that Apple Speech is optional, remote ASR uses capture-only recording, and prompt/model/base URL must be configured in settings.

**Step 3: Re-run verification**

Run: `./Scripts/verify.sh`
Expected: PASS if the local environment supports the full app bundle build.
