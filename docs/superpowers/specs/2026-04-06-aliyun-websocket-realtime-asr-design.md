# Aliyun WebSocket Realtime ASR Design (VoicePi)

Date: 2026-04-06  
Scope owner: VoicePi app (`Sources/VoicePi`)

## 1. Problem Statement

VoicePi currently performs remote ASR in a capture-then-upload batch flow (`POST /audio/transcriptions`) after recording stops.  
This does not satisfy Aliyun realtime ASR expectations and does not provide incremental transcript updates during recording.

Required behavior for this iteration:

1. Follow Aliyun realtime ASR WebSocket usage model.
2. Start connection when user starts recording.
3. Stream audio continuously during recording.
4. Show incremental remote transcript in overlay while recording.
5. Inject text only once after stop (final transcript only).
6. On websocket/auth/protocol failure: fail fast and show error (no automatic Apple Speech fallback).

## 2. Goals and Non-Goals

### Goals

1. Add production-grade Aliyun realtime websocket ASR path using `wss://.../api-ws/v1/inference`.
2. Keep existing user interaction model (start recording, stop recording, then inject final text).
3. Preserve current non-realtime paths for OpenAI-compatible and Volcengine in this iteration.
4. Keep implementation modular so OpenAI/Volcengine realtime streaming can be added next.

### Non-Goals

1. No continuous incremental text injection into frontmost app.
2. No provider unification in this iteration beyond interface design.
3. No migration of OpenAI/Volcengine to realtime websocket in this iteration.

## 3. Candidate Approaches Considered

### A. Tap-driven realtime websocket streaming (Chosen)

Use audio tap buffers directly as the streaming source and push websocket frames while recording.

Pros:
- Lowest latency.
- Matches realtime provider contract.
- Clean separation between recording and provider protocol handling.

Cons:
- Requires moderate refactor in recording + workflow orchestration.

### B. File-based pseudo-streaming

Record to file, tail/read chunks, and push over websocket.

Pros:
- Smaller perceived change to recorder internals.

Cons:
- Fragile chunk boundaries.
- Higher latency and synchronization complexity.
- Worse correctness.

### C. Parallel recorder stack

Introduce a second dedicated realtime recorder module next to the existing recorder.

Pros:
- Strong isolation.

Cons:
- Largest footprint and duplicate audio pipeline logic.

Recommendation: **A**.

## 4. Proposed Architecture

### 4.1 New abstractions

1. `RemoteASRStreamingClient` protocol  
   - `connect(configuration:backend:language:) async throws`  
   - `sendAudioFrame(_ data: Data, isFinal: Bool) async throws`  
   - `finishAndAwaitFinal(timeout:) async throws -> String`  
   - callback/async stream for partial transcript events.

2. `AliyunRealtimeASRStreamingClient` concrete implementation  
   - owns `URLSessionWebSocketTask`.
   - provider-specific handshake/message envelope parsing.
   - emits partial/final transcript events.

3. `RealtimeASRSessionCoordinator` (light orchestration helper)  
   - lifecycle gate: connect -> stream -> finish -> resolve final transcript.
   - maps websocket events/errors into app-level presentation messages.

### 4.2 Changes in existing modules

1. `SpeechRecorder`
   - Add optional audio-frame callback in capture mode:
     - receives PCM audio chunks directly from tap.
     - called only when remote realtime streaming is active.
   - Keep existing recording file output unchanged for compatibility.

2. `AppCoordinator` / `AppWorkflowSupport`
   - For Aliyun backend, enter realtime streaming path on start.
   - On partial transcript events, update floating panel and model overlay text.
   - On stop, call `finishAndAwaitFinal(timeout: 1.2s)` and proceed to existing post-processing + inject pipeline.

3. `RemoteASRClient`
   - Keep existing HTTP batch path as fallback for non-Aliyun providers in this iteration.

## 5. Runtime State Machine

States:

1. `idle`
2. `connectingRealtimeASR`
3. `recordingAndStreaming`
4. `stoppingAndAwaitingFinal`
5. `completed(finalTranscript)`
6. `failed(error)`

Transitions:

1. Start shortcut -> `connectingRealtimeASR`.
2. Connect success -> start recorder -> `recordingAndStreaming`.
3. Connect failure -> `failed`.
4. While recording: audio frame -> websocket send; partial result -> overlay update.
5. Stop shortcut -> send final frame + stop -> `stoppingAndAwaitingFinal`.
6. Final result before timeout -> `completed`.
7. Timeout/disconnect/protocol/auth error -> `failed`.

Failure policy:

1. No automatic Apple Speech fallback for realtime failures.
2. Error surfaced immediately via existing transient error path.

## 6. Aliyun Protocol Alignment

This implementation follows Aliyun realtime ASR documentation model:

1. WebSocket endpoint uses `/api-ws/v1/inference` (regional host chosen by Base URL).
2. Auth uses bearer API key.
3. Session starts before audio streaming.
4. Audio is sent in segmented frames while recording.
5. Stop frame is sent when recording ends.
6. Partial and final transcript events are consumed from websocket server events.

Model default for Aliyun settings will be `fun-asr-realtime`.

## 7. UI/UX Behavior

During recording with Aliyun realtime:

1. Overlay transcript shows remote incremental text updates only.
2. No extra status copy is added to overlay beyond transcript text.
3. Injection remains final-only after stop.

Settings:

1. No new “realtime mode” visual tag in ASR settings.
2. Existing ASR backend selector remains unchanged.

## 8. Error Handling

Categorized errors:

1. `connectFailed`
2. `authenticationFailed`
3. `protocolError`
4. `streamSendFailed`
5. `finalTimeout`
6. `serverClosed`

User-facing behavior:

1. Fail current recording session immediately.
2. Surface concise error text via current `presentTransientError`.
3. Reset recorder/streaming state cleanly to `idle`.

## 9. Testing Strategy

Unit tests:

1. websocket session lifecycle (connect/send/finish/timeout).
2. Aliyun endpoint normalization to websocket host/path.
3. state machine transitions and timeout behavior.
4. partial transcript propagation to overlay/model update hooks.

Integration-style tests (mock websocket transport):

1. Start -> partial events -> stop -> final text resolved.
2. Mid-stream disconnect -> immediate failure, no fallback.
3. Final timeout -> failure path triggered in <= configured timeout.

Regression tests:

1. OpenAI-compatible and Volcengine non-realtime batch ASR remains unchanged.

## 10. Implementation Boundaries for Next Phase

This spec intentionally limits implementation to Aliyun realtime websocket.  
Provider-general interfaces introduced here will be reused in a follow-up spec to migrate OpenAI/Volcengine to realtime streaming where provider APIs support it.
