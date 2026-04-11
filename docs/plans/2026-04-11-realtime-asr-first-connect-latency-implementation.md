# Realtime ASR First-Connect Latency Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the realtime connect-before-recording gate so VoicePi starts capturing immediately, buffers early PCM frames, and falls back to batch remote ASR when realtime connect never becomes usable.

**Architecture:** Keep `SpeechRecorder` as the single capture pipeline. Expand `RealtimeASRSessionCoordinator` to own preconnect buffering and session-mode transitions, then update `AppCoordinator` to start recording first and resolve stop through either realtime finalization or the existing batch remote ASR flow.

**Tech Stack:** Swift, Testing framework, AVFoundation capture callbacks, websocket realtime ASR clients, existing `RemoteASRClient` batch transcription path.

### Task 1: Lock the New Coordinator Semantics in Tests

**Files:**
- Modify: `Tests/VoicePiTests/RealtimeASRSessionCoordinatorTests.swift`
- Create if needed: `Tests/VoicePiTests/RealtimeASRSessionCoordinatorBufferTests.swift`

**Step 1: Write failing tests for the new session semantics**

Add focused tests for:

- frames captured before connect success are buffered instead of dropped
- buffered frames flush in order once connect completes
- connect timeout/failure after capture degrades to batch fallback mode instead of immediately surfacing terminal error
- stop before connect success returns a batch-fallback resolution when audio exists
- stop before connect success stays silent when no audio exists

**Step 2: Run the focused tests and verify they fail for the expected reason**

Run: `swift test --filter RealtimeASRSessionCoordinatorTests`

Expected: FAIL because the current coordinator still requires connect to finish before capture and has no buffer/fallback states.

**Step 3: Keep the test scaffolding narrow**

Use stubs rather than real network or audio capture. The stub client should allow:

- suspending connect
- completing connect later
- recording flushed frame order
- simulating connect failure after capture begins

**Step 4: Re-run the focused tests after the red state is stable**

Run: `swift test --filter RealtimeASRSessionCoordinatorTests`

Expected: FAIL in the new assertions, with existing unrelated tests still green.

### Task 2: Implement Coordinator Buffering and Mode Transitions

**Files:**
- Modify: `Sources/VoicePi/RealtimeASRSessionCoordinator.swift`
- Create: `Sources/VoicePi/RealtimeASRPreconnectBuffer.swift`
- Modify if needed: `Sources/VoicePi/RemoteASRStreamingClient.swift`
- Test: `Tests/VoicePiTests/RealtimeASRSessionCoordinatorTests.swift`

**Step 1: Add the minimal buffering abstraction**

Implement a small helper that:

- appends PCM frames in order
- exposes whether any meaningful audio has been captured
- drains all buffered frames once realtime becomes ready
- enforces a bounded cap

Keep it intentionally small and coordinator-focused.

**Step 2: Expand coordinator state transitions minimally**

Add the states needed for:

- recording while connecting
- draining buffered frames
- recording with batch fallback
- differentiating realtime finalization from batch finalization

Avoid moving post-processing or HTTP transcription into the coordinator.

**Step 3: Change frame handling semantics**

Before realtime is ready:

- accept frames
- buffer them

After realtime connect succeeds:

- flush buffered frames in order
- send new frames directly

If realtime connect fails after recording has begun:

- transition to batch fallback mode
- stop trying to use realtime transport for the rest of the session

**Step 4: Make the focused tests pass**

Run: `swift test --filter RealtimeASRSessionCoordinatorTests`

Expected: PASS.

### Task 3: Integrate AppCoordinator Start/Stop Routing

**Files:**
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify if needed: `Sources/VoicePi/AppWorkflowSupport.swift`
- Modify if needed: `Tests/VoicePiTests/AppWorkflowSupportTests.swift`
- Modify if needed: `Tests/VoicePiTests/AppControllerInteractionTests.swift`

**Step 1: Write failing integration-level tests first**

Cover:

- realtime start path starts capture immediately instead of waiting for realtime connect to finish
- stop during preconnect capture resolves through existing batch remote ASR path when audio exists
- realtime degradation during capture does not drop the session on the floor

Keep mocks/stubs at the app workflow boundary instead of trying to drive real audio.

**Step 2: Run the targeted tests to verify the current app flow fails**

Run: `swift test --filter AppWorkflowSupportTests`

Expected: FAIL where the app still treats realtime connect as a gate before capture starts.

**Step 3: Implement the minimal routing changes**

Update `AppCoordinator` so realtime recording:

- starts `SpeechRecorder` immediately
- starts realtime connect in parallel
- routes stop through realtime finalization only if streaming became active
- otherwise falls back to the existing `resolveTranscriptAfterRecording` path with the recorded audio file

Do not rewrite unrelated post-processing or injection logic.

**Step 4: Re-run the targeted integration tests**

Run: `swift test --filter AppWorkflowSupportTests`

Expected: PASS.

### Task 4: End-to-End Verification

**Files:**
- Verify all files above

**Step 1: Run focused coordinator and workflow tests**

Run: `swift test --filter RealtimeASRSessionCoordinatorTests && swift test --filter AppWorkflowSupportTests`

Expected: PASS.

**Step 2: Run a broader regression slice for realtime paths**

Run: `swift test --filter AliyunRealtimeASRStreamingClientTests && swift test --filter VolcengineRealtimeASRStreamingClientTests && swift test --filter RemoteASRClientTests`

Expected: PASS.

**Step 3: Run repository verification if focused slices are clean**

Run: `./Scripts/test.sh`

Expected: PASS.

**Step 4: Review final diff**

Run: `git diff --stat`

Expected: only the planned coordinator, app flow, tests, and helper files changed.
