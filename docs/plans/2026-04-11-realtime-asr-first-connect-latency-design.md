# Realtime ASR First-Connect Latency Design

**Date:** 2026-04-11

**Status:** Proposed

## Goal

Reduce the user-visible delay at the start of realtime ASR sessions by removing the current connect-before-recording gate, while preserving transcript correctness and keeping failure handling predictable.

## Problem

Today VoicePi shows the recording UI immediately, but for realtime backends it does not actually start microphone capture until the websocket connection and provider-specific start ack have already completed.

That behavior comes from the current session flow:

1. user triggers recording
2. app enters realtime connect flow
3. websocket upgrade + provider start handshake complete
4. only then `SpeechRecorder.startRecording(mode: .captureOnly)` starts

This has two user-facing problems:

- first words can be missed if the user starts speaking as soon as the overlay appears
- startup latency feels worse than products that begin capturing immediately and hide the network handshake behind live recording

The previous realtime design explicitly accepted this trade-off. That assumption is now the thing to change.

## Constraints

- VoicePi must keep the current "press to start, press to stop, inject only final text" interaction model.
- Realtime backends are currently `remoteAliyunASR` and `remoteVolcengineASR`.
- The existing batch remote ASR path already exists and can transcribe the recorded audio file for remote backends after recording stops.
- Realtime partial transcript quality is useful, but preserving the user's speech is more important than guaranteeing realtime partials on every session.
- The implementation should avoid turning `AppCoordinator` into a large timing- and state-heavy blob.

## Options Considered

### Option A: Keep connect-before-recording

Pros:

- simplest state model
- existing tests and semantics mostly stay valid
- no buffering or replay logic

Cons:

- preserves the current user-visible latency
- risks losing speech at the start of a session
- still feels slower than products that begin capture immediately

### Option B: Start recording immediately and buffer indefinitely until realtime connect succeeds

Pros:

- best perceived responsiveness
- highest chance of keeping realtime partials for the entire utterance

Cons:

- unbounded memory growth on bad networks
- much harder cancellation and stop behavior
- worst failure mode complexity if connect never succeeds

### Option C: Start recording immediately, use a bounded preconnect PCM buffer, then fall back to batch ASR if realtime does not become usable

Pros:

- removes the visible startup stall
- preserves early speech
- keeps memory bounded
- degrades to an already-supported transcript path instead of throwing speech away

Cons:

- more state transitions than today
- some sessions will lose live partials and finish as batch transcription instead
- requires explicit semantics for stop-before-connect and connect-failure-during-recording

## Decision

Choose **Option C**.

This is the best balance between product quality and implementation risk. The key product requirement is not "realtime partials at all costs"; it is "the user can start speaking immediately without losing audio." A bounded preconnect buffer solves the first-word loss problem, and batch fallback avoids building a fragile always-retry streaming system inside the recording path.

## Product Rules

### Start Behavior

When the user starts a realtime recording session:

1. show the recording overlay immediately
2. start `SpeechRecorder` immediately in capture mode
3. start realtime websocket connect in parallel
4. store captured PCM frames in a bounded in-memory preconnect buffer until realtime streaming is ready

The user should be able to begin speaking as soon as the recording UI appears.

### Realtime Ready Behavior

When realtime connect succeeds:

1. flush buffered PCM frames to the realtime client in original capture order
2. switch subsequent frames to direct passthrough streaming
3. continue showing realtime partial transcript updates as they arrive

Realtime success is defined as:

- websocket upgraded successfully
- provider-specific start/control frame sent successfully
- provider-specific ready ack received successfully

### Fallback Behavior

If realtime connect fails or times out after recording has already begun:

1. do not discard the recording session
2. continue local audio capture normally
3. mark the session as batch-fallback mode
4. on stop, use the existing recorded audio file and the existing remote batch ASR path to produce the final transcript

This fallback is intentional degradation, not an error condition by itself.

### Stop Before Realtime Ready

If the user stops recording before realtime becomes ready:

- if no meaningful audio was captured, cancel silently
- if audio was captured, resolve the session through the batch remote ASR path

The session should prefer preserving the captured utterance over preserving realtime semantics.

### Error Surfacing

VoicePi should distinguish between:

- `realtime degraded to batch`: not a toast-worthy failure during the active session
- `final batch transcription failed`: user-visible error
- `microphone/permission/recorder failure`: user-visible error

This avoids punishing the user for an internal transport fallback that still produced a valid final transcript.

## Proposed Architecture

### 1. Realtime Session Model

Keep `RealtimeASRSessionCoordinator`, but expand it from a pure connect-then-stream gate into a session driver that can operate in two output modes:

- `streamingRealtime`
- `batchFallback`

It remains the owner of:

- realtime client lifecycle
- frame ordering rules
- terminal transcript resolution for realtime mode
- terminal error mapping

It should not own:

- final batch transcription HTTP requests
- post-processing
- injection

Those should stay in the existing app workflow path.

### 2. Preconnect Frame Buffer

Add a small dedicated frame buffer abstraction for captured PCM frames before realtime is ready.

Requirements:

- preserves frame order
- stores already-normalized PCM16LE frames
- bounded by duration or byte size
- supports `append(frame)`, `drainAll()`, and `reset()`
- exposes whether any meaningful audio was captured

Recommended initial limit:

- keep up to 5 seconds of PCM16LE mono 16 kHz audio
- this is about 160 KB, which is small enough to be safe and large enough to hide normal connect latency

When the cap is exceeded, drop the oldest frames rather than growing without bound. The goal is responsiveness and protection against pathological waits, not perfect infinite rewind.

### 3. Speech Recorder Contract

`SpeechRecorder` already supports capture-only frame callbacks and writes the recording to a file. That is enough for this design.

The new contract should be:

- recorder starts first
- every captured frame is forwarded to the coordinator immediately
- the coordinator decides whether the frame goes to:
  - preconnect buffer
  - realtime websocket send
  - no-op because the session already degraded to batch fallback

No second recording stack should be introduced.

### 4. Batch Fallback Reuse

Do not invent a new fallback transcription path.

When a realtime session degrades, the app should finish recording and then call the existing post-recording remote ASR workflow using:

- the selected backend
- the recorded audio file
- the saved remote configuration

This keeps the fallback logic aligned with existing backend-specific HTTP endpoint behavior and limits new protocol work.

## State Machine

The current state model is too narrow for this behavior. Replace it with a state model that explicitly captures capture-vs-transport progress.

Recommended states:

1. `idle`
2. `recordingAndConnecting`
3. `drainingBufferedAudio`
4. `recordingAndStreaming`
5. `recordingWithBatchFallback`
6. `stoppingAndAwaitingRealtimeFinal`
7. `stoppingAndAwaitingBatchFinal`
8. `completed`
9. `failed`
10. `cancelled`

State rules:

- `recordingAndConnecting`: recorder is active, realtime transport not yet ready
- `drainingBufferedAudio`: transport is ready and the coordinator is replaying buffered frames before direct passthrough
- `recordingAndStreaming`: new frames are sent directly to realtime transport
- `recordingWithBatchFallback`: recorder is active, realtime has been abandoned for this session
- `stoppingAndAwaitingRealtimeFinal`: stop was requested after realtime became active
- `stoppingAndAwaitingBatchFinal`: stop was requested while still connecting or after realtime degraded

## Runtime Flow

### Successful Realtime Session

1. start shortcut
2. overlay appears
3. recorder starts immediately
4. coordinator enters `recordingAndConnecting`
5. frames accumulate in preconnect buffer
6. realtime connect succeeds
7. coordinator enters `drainingBufferedAudio`
8. buffered frames are flushed in order
9. coordinator enters `recordingAndStreaming`
10. partial transcript events update overlay
11. user stops recording
12. recorder stops
13. coordinator sends realtime finish signal
14. final realtime result resolves
15. existing post-processing and injection flow continues

### Connect Timeout Or Failure During Recording

1. start shortcut
2. recorder starts immediately
3. realtime connect fails or exceeds timeout
4. coordinator enters `recordingWithBatchFallback`
5. recording continues without realtime partial transcript updates
6. user stops recording
7. app resolves transcript through existing batch remote ASR flow
8. existing post-processing and injection flow continues

### User Stops Before Realtime Ready

1. start shortcut
2. recorder starts immediately
3. connect is still in progress
4. user stops recording
5. connect task is cancelled
6. if audio is empty, session returns empty result silently
7. otherwise app resolves transcript through existing batch remote ASR flow

## UX Expectations

### Overlay

The overlay should continue to appear immediately when the session starts.

During `recordingAndConnecting`, it should behave like recording has started, because recording actually has started. Do not show an error-like "connecting failed" message during normal startup.

Recommended behavior:

- show waveform / recording state immediately
- keep transcript area empty until partial text arrives
- if the session degrades to batch fallback, keep the recording UI stable rather than surfacing transport noise
- after stop, the app may show the existing `Transcribing...` state because batch fallback is now effectively the same as non-realtime remote resolution

### Partial Transcript Trade-Off

Some sessions will no longer produce partial transcript updates if realtime connect does not become ready quickly enough. That is acceptable.

The priority order is:

1. preserve the utterance
2. keep start interaction instant
3. preserve partials when possible

## Timeout And Buffer Policy

Recommended initial values:

- realtime connect timeout: keep current 2.0 seconds
- preconnect buffer cap: 5.0 seconds of PCM audio
- realtime final timeout after stop: keep current 1.2 seconds

These values are intentionally conservative. The buffer cap should be larger than the normal connect timeout so short network stalls still retain the beginning of the utterance.

## Non-Goals

This design does not include:

- background prewarming of websocket sessions before the user starts recording
- keeping websocket sessions alive across recordings
- provider unification beyond what the current realtime abstraction already uses
- continuous injection of partial text into the frontmost app
- replacing batch fallback with a second realtime retry attempt

## Risks

### More State Complexity

This design adds genuine state complexity. The mitigation is to keep the branching inside the coordinator and to keep `AppCoordinator` focused on top-level routing.

### Partial Transcript Jumps

When buffered frames are replayed after connect success, the first partials may appear in a burst. That is acceptable as long as text ordering is correct.

### Silent Degradation Can Hide Transport Issues

If every realtime failure silently becomes batch fallback, regressions could hide for too long. The mitigation is internal logging and targeted tests, not user-facing transport noise.

### Buffer Truncation

If connect takes longer than the preconnect cap, very early speech may still be dropped from realtime replay. That is acceptable because the design already falls back to the full recorded file for final transcript preservation when realtime is not usable.

## Testing Strategy

Add focused tests around the new semantics:

- starting a realtime session starts the recorder before realtime connect completes
- frames captured before connect success are buffered and replayed in order
- connect success transitions buffered mode to direct streaming mode
- connect timeout during recording switches the session to batch fallback instead of failing the recording immediately
- stop before realtime ready cancels connect and uses batch fallback when audio exists
- stop before realtime ready returns empty result silently when no audio exists
- realtime final path still uses the existing finish/final timeout contract
- batch fallback path still routes through the existing remote ASR workflow

Verification should include the relevant focused Swift tests plus repository-level regression coverage.

## Open Questions

These are implementation-time questions, not blockers for the design:

1. Should the overlay show a subtle non-text transport indicator while still in `recordingAndConnecting`, or stay visually identical to normal recording?
2. Should the batch fallback path surface a quiet status line after stop such as `Transcribing...`, or remain visually indistinguishable from the current non-realtime flow?
3. Should the preconnect buffer cap be duration-based only, or duration plus hard byte ceiling for extra safety?

## Summary

The path forward is:

- start recording immediately
- connect realtime in parallel
- keep a bounded preconnect frame buffer
- flush that buffer if realtime becomes ready
- degrade to the existing batch remote ASR flow if realtime does not become usable

This changes the product from "realtime or fail fast" to "capture first, prefer realtime, preserve speech always." That is the right trade-off for VoicePi's recording UX.
