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

1. `RemoteASRStreamEvent` (strict event contract)
   - `.partial(text: String)`
   - `.final(text: String)`
   - `.timeout(kind: String)`  // used for deterministic timeout signaling
   - `.closedByServer(code: URLSessionWebSocketTask.CloseCode, reason: String?)`
   - `.protocolError(message: String)`

2. `RemoteASRStreamingClient` protocol (strict API shape)  
   - `var events: AsyncStream<RemoteASRStreamEvent> { get }`
   - `connect(configuration: RemoteASRConfiguration, backend: ASRBackend, language: SupportedLanguage) async throws`
   - `sendPCM16LEFrame(_ frame: Data) async throws`
   - `finishInput() async throws`
   - `awaitFinalResult(timeoutSeconds: Double) async throws -> String`
   - `close() async`
   - call-order contract:
     - allowed order: `connect` -> `sendPCM16LEFrame*` -> `finishInput` -> `awaitFinalResult` -> `close`
     - `connect` when already connected: throws `protocolError(invalidState)`
     - `sendPCM16LEFrame` before `connect` or after `finishInput`: throws `protocolError(invalidState)`
     - `finishInput` is idempotent (first call sends stop frame, later calls no-op)
     - `awaitFinalResult` requires `finishInput` has been called; second and later calls return cached final
     - `close` is idempotent and can be called from any state

3. `AliyunRealtimeASRStreamingClient` concrete implementation  
   - owns `URLSessionWebSocketTask`.
   - provider-specific handshake/message envelope parsing.
   - emits partial/final transcript events on `events`.

4. `RealtimeASRSessionCoordinator` (light orchestration helper)  
   - lifecycle gate: connect -> stream -> finish -> resolve final transcript.
   - maps websocket events/errors into app-level presentation messages.
   - consumes `events` in background, then dispatches UI updates on `MainActor`.
   - `events` vs `awaitFinalResult` contract:
     - partial events can occur zero or more times.
     - final success emits exactly one `.final(text)` event.
     - `awaitFinalResult` resolves to the same final text emitted in `.final(text)`.
     - if `.final(text)` is never emitted before timeout/close/error, `awaitFinalResult` throws.
   - failure signaling contract:
     - `connect` throws directly on handshake failure, start-frame send failure, or missing `task-started` ack within connect timeout.
     - receive-loop errors emit terminal event (`.protocolError` or `.closedByServer`) first, then `awaitFinalResult` throws the mapped error.
     - final-timeout emits `.timeout(kind: "final")` before `awaitFinalResult` throws `finalTimeout`.
     - `events` stream always finishes after terminal event (success or failure).

5. `WebSocketTransport` test seam  
   - `sendText(_:) async throws`
   - `sendBinary(_:) async throws`
   - `receive() async throws -> URLSessionWebSocketTask.Message`
   - `cancel(code:reason:)`
   - production implementation wraps `URLSessionWebSocketTask`; tests use deterministic mock transport.

### 4.2 Changes in existing modules

1. `SpeechRecorder`
   - Add optional audio-frame callback in capture mode:
     - receives PCM audio chunks directly from tap.
     - called only when remote realtime streaming is active.
   - Keep existing recording file output unchanged for compatibility.

2. `AppCoordinator` / `AppWorkflowSupport`
   - For Aliyun backend, enter realtime streaming path on start.
   - Connect websocket first (`connect timeout = 2.0s`), and only start recorder after connect success (`task-started` ack received).
   - Speech spoken during `connectingRealtimeASR` is intentionally not captured; capture starts only after ack.
   - On partial transcript events, update floating panel and model overlay text.
   - On stop, call `finishInput()`, then `awaitFinalResult(timeout: 1.2s)`, then proceed to existing post-processing + inject pipeline.
   - If user stops while still `connectingRealtimeASR`, cancel connect and return `idle` without error or injection.

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
7. `cancelled`

Transitions:

1. Start shortcut -> `connectingRealtimeASR`.
2. Connect success within 2.0s (`ws upgraded + run-task sent + task-started received`) -> start recorder -> `recordingAndStreaming`.
3. Connect timeout/failure -> `failed` (recorder not started).
4. While recording: audio frame -> websocket send; partial result -> overlay update.
5. Stop shortcut -> send stop control frame -> `stoppingAndAwaitingFinal`.
6. Final result before 1.2s timeout -> `completed`.
7. Timeout/disconnect/protocol/auth error -> `failed`.
8. Stop shortcut during `connectingRealtimeASR` -> cancel connect -> `cancelled` -> `idle`.
9. Stop shortcut during `stoppingAndAwaitingFinal` -> ignored (already finalizing).

Failure policy:

1. No automatic Apple Speech fallback for realtime failures.
2. Error surfaced immediately via existing transient error path.
3. `cancelled` is silent (no error toast).

## 6. Aliyun Protocol Alignment

This implementation follows Aliyun realtime ASR documentation model:

1. WebSocket endpoint uses `/api-ws/v1/inference` (regional host chosen by Base URL).
2. Auth uses bearer API key in handshake headers.
3. Session starts with a text JSON start frame before audio binary frames.
4. Audio is sent as **PCM 16kHz / mono / 16-bit little-endian** in segmented binary frames.
   - target chunk: ~100ms (`3200` bytes) per frame.
5. Stop frame is sent as text JSON control message when recording ends.
6. Partial and final transcript events are consumed from websocket server text messages.

Concrete normalization contract:

1. `https://dashscope.aliyuncs.com/compatible-mode/v1` -> `wss://dashscope.aliyuncs.com/api-ws/v1/inference`
2. `https://dashscope-intl.aliyuncs.com/compatible-mode/v1` -> `wss://dashscope-intl.aliyuncs.com/api-ws/v1/inference`
3. Existing `wss://.../api-ws/v1/inference` input is accepted directly.
4. Canonical normalization algorithm:
   - trim input string.
   - if scheme is `wss` and path is exactly `/api-ws/v1/inference`, accept as-is.
   - if scheme is `http/https`, rewrite to `wss://<same-host>/api-ws/v1/inference` (ignore original path).
   - if scheme/path is none of above, fail with `connectFailed(invalidEndpoint)`.

Concrete message envelope contract used by VoicePi (matching DashScope websocket protocol constants):

1. Start frame (text JSON, required):

   ```json
   {
     "header": {
       "streaming": "duplex",
       "task_id": "<uuid-hex>",
       "action": "run-task"
     },
     "payload": {
       "model": "fun-asr-realtime",
       "task_group": "audio",
       "task": "asr",
       "function": "recognition",
       "input": {},
       "parameters": {
         "format": "pcm",
         "sample_rate": 16000
       }
     }
   }
   ```

   Handshake headers (required):
   - `Authorization: bearer <apiKey>`
   - optional passthrough: `X-DashScope-WorkSpace: <workspace>` when workspace is configured.

2. Continue audio frame (binary, required):
   - raw PCM16LE bytes only.
   - no JSON wrapper per frame in binary-input duplex mode.
   - segmentation algorithm:
     - append incoming tap bytes to `pendingPCMBuffer`.
     - while `pendingPCMBuffer.count >= 3200`, send first `3200` bytes as one frame.
     - on stop: if `pendingPCMBuffer` has remainder (`1...3199` bytes), send exactly one tail frame, then clear buffer.
     - never send empty binary frames.

3. Stop frame (text JSON, required):

   ```json
   {
     "header": {
       "task_id": "<same-task-id>",
       "action": "finish-task"
     },
     "payload": {
       "input": {}
     }
   }
   ```

4. Server events (text JSON):
   - `header.event = "task-started"`: start ack.
   - `header.event = "result-generated"`: incremental payload.
   - `header.event = "task-finished"`: end-of-task payload.
   - `header.event = "task-failed"` with `header.error_code` + `header.error_message`: fail immediately.

5. Result payload parsing contract:
   - primary sentence object: `payload.output.sentence`
   - partial text source: `payload.output.sentence.text` when non-empty
   - sentence-end condition: `payload.output.sentence.end_time != null`
   - heartbeat frame: `payload.output.sentence.heartbeat == true` -> ignore for UI/finalization

6. Final transcript resolution contract:
   - keep an ordered list of sentence-end items by `end_time` (dedupe same `end_time`).
   - on each `result-generated`: emit `.partial(text)` if text is non-empty.
   - on sentence-end: emit `.finalCandidate(text,end_time)` internally (not user-visible event).
   - on `task-finished`:
     - if one or more sentence-end items exist, final text = join sentence-end `text` by ascending `end_time`.
     - else if latest non-empty partial exists, final text = latest partial.
     - else throw `protocolError(emptyFinal)`.
   - close/disconnect before `task-finished` with no resolved final => fail.

7. Language parameter handling:
   - `connect(... language: SupportedLanguage)` is accepted for interface consistency.
   - For Aliyun realtime in this iteration, language is **not** sent in websocket payload (no `language_hints` field).
   - this is intentional and tested as an explicit “ignored” behavior.

Model default for Aliyun settings will be `fun-asr-realtime`.

## 7. UI/UX Behavior

During recording with Aliyun realtime:

1. Overlay transcript shows remote incremental text updates only.
2. No extra status copy is added to overlay beyond transcript text.
3. Injection remains final-only after stop.
4. While `connectingRealtimeASR`, overlay text stays empty (no “connecting…” text).
5. Overlay clears on `completed`, `failed`, and `cancelled`.

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

Error mapping matrix:

1. WebSocket handshake `401/403` -> `authenticationFailed`.
2. WebSocket handshake `404` / invalid host/path / DNS / connection refused / connect timeout -> `connectFailed`.
3. Received `header.event = task-failed` -> `protocolError` (include `error_code` and `error_message`).
4. Unexpected frame shape (missing `header.event` / missing `payload.output.sentence` when required) -> `protocolError`.
5. send binary/text failure while running -> `streamSendFailed`.
6. socket close/error before final resolution -> `serverClosed`.
7. no final resolved within `awaitFinalResult(1.2s)` after stop -> `finalTimeout`.

Error propagation ordering contract:

1. `connectFailed` / `authenticationFailed`
   - emission: no `events` emission required (connection may not be established).
   - throw site: `connect`.
2. `protocolError` from receive loop
   - emission: `.protocolError(message)` on `events`.
   - throw site: `awaitFinalResult` (if waiting) or next API call touching terminal state.
3. `serverClosed`
   - emission: `.closedByServer(code, reason)` on `events`.
   - throw site: `awaitFinalResult`.
4. `streamSendFailed`
   - emission: optional `.protocolError(message)` if session is transitioned terminal.
   - throw site: `sendPCM16LEFrame` / `finishInput`.
5. `finalTimeout`
   - emission: `.timeout(kind: "final")`.
   - throw site: `awaitFinalResult`.

## 9. Testing Strategy

Unit tests:

1. websocket session lifecycle (connect/send/finish/timeout).
2. Aliyun endpoint normalization to websocket host/path.
3. state machine transitions and timeout behavior.
4. partial transcript propagation to overlay/model update hooks.
5. connect-before-recording gate (recorder starts only after connect success).
6. method call-order/idempotency rules for `RemoteASRStreamingClient`.
7. final transcript resolution truth table (sentence-end list / latest partial / empty final failure).

Integration-style tests (mock websocket transport):

1. Start -> partial events -> stop -> final text resolved.
2. Mid-stream disconnect -> immediate failure, no fallback.
3. Final timeout -> failure path triggered in <= configured timeout.
4. Stop during connect -> cancelled path, no error toast, no injection.
5. Duplicate sentence-end events (same `end_time`) -> deduped final output.

Deterministic test boundaries:

1. `WebSocketTransport` mock drives inbound event order and failure injection.
2. `RealtimeClock` (or injected sleep function) controls connect/final timeout tests without flaky sleeps.
3. `MainActor` UI update assertions verify only transcript text is shown during streaming.

Regression tests:

1. OpenAI-compatible and Volcengine non-realtime batch ASR remains unchanged.

## 10. Implementation Boundaries for Next Phase

This spec intentionally limits implementation to Aliyun realtime websocket.  
Provider-general interfaces introduced here will be reused in a follow-up spec to migrate OpenAI/Volcengine to realtime streaming where provider APIs support it.
