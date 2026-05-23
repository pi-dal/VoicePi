# P2: VoicePiCore + Keyboard Runtime Provider-Aware ASR — Before-Start Slice (v2)

> Part of [iOS ASR Provider Parity Plan](./2026-05-01-ios-asr-provider-parity-plan.md)
> Depends on: P1 (completed — `ASRProvider` enum + `volcengineAppID` in shared schema)
> Gate: Cindy. Do NOT start implementation until this slice is approved.

## Goal

Make the iOS keyboard runtime consume `asrConfig.provider`. After P2, `ASRStream` branches on provider at request time: OpenAI-compatible stays REST multipart, Aliyun and Volcengine use real WebSocket streaming. Keyboard extension interface stays unchanged.

## Split: P2a → P2b

P2 is split into two sub-slices per Cindy's recommendation:

| Slice | Scope | Gate |
|-------|-------|------|
| **P2a** | Port macOS realtime infra + provider clients into VoicePiCore. Package compiles. No keyboard runtime changes. | `swift build` passes |
| **P2b** | Wire `ASRClient` provider branch + keyboard config validation. Full build passes. | `xcodebuild` passes |

This keeps review blast radius manageable: P2a is pure porting (can be diffed against macOS originals), P2b is the wiring.

---

## 1. Architecture Decision

**Keep `ASRStream.startStreaming(audioData:)` API unchanged** — branch internally on `config.provider`.

```
KeyboardSessionController.stopRecording(audioData:)
  → asrStream.startStreaming(audioData:)         // unchanged API
    → switch config.provider:
        case .openAICompatible → current REST path
        case .aliyun            → WebSocket: connect → chunk+PCM → send frames → finish → await result
        case .volcengine        → WebSocket: connect → chunk+PCM → send frames → finish → await result
    → delegate.asrStream(didReceiveFinalText:)    // unchanged delegate
```

`startStreaming` internally wraps async WebSocket work in `Task {}` and bridges back to delegate callbacks. Public delegate protocol unchanged.

---

## 2. P2a: VoicePiCore Realtime Infra + Provider Clients

### Complete dependency closure (verified from macOS source)

The Aliyun and Volcengine client files reference these types. Every one is accounted for:

| Dependency | macOS location | iOS action |
|---|---|---|
| `RealtimeClock` / `SystemRealtimeClock` | `Core/Processing/RealtimeClock.swift` (12 lines) | Direct port — Foundation only (`Task.sleep`) |
| `RealtimePCMChunker` | `Core/Processing/RealtimePCMChunker.swift` (30 lines) | Direct port — operates on `Data`, Foundation only |
| `WebSocketTransport` + `URLSessionWebSocketTransportFactory` | `Adapters/ASR/WebSocketTransport.swift` (46 lines) | Direct port — `URLSessionWebSocketTask` available on iOS |
| `RemoteASRStreamingError` / `RemoteASRStreamEvent` | In `Adapters/ASR/RemoteASRStreamingClient.swift` | New iOS version — stripped of `ASRBackend`/`SupportedLanguage` |
| `RealtimeASRStreamingErrorMapper` | `Adapters/ASR/RealtimeASRStreamingErrorMapper.swift` (33 lines) | Direct port — static error mapping |
| `AliyunRealtimeProtocol` | `Adapters/ASR/AliyunRealtimeProtocol.swift` (200 lines) | Port with adaptation (see below) |
| `VolcengineRealtimeProtocol` | `Adapters/ASR/VolcengineRealtimeProtocol.swift` (591 lines) | Port with adaptation (see below) |
| `RemoteASRClientError` (`.notConfigured`, `.invalidBaseURL`) | In `Adapters/ASR/RemoteASRClient.swift` | **Not ported in full.** Replaced inline in adapted clients with `RemoteASRStreamingError.connectFailed(...)` + literal messages |
| `RemoteASRConfiguration` | `Core/Models/AppModelConfigurationAndStateTypes.swift` | **Not ported.** All references replaced with `ASRConfig` (from P1) |
| `ASRBackend` | `Core/Models/AppModelLanguageAndProcessingTypes.swift` | **Not ported.** All references replaced with `ASRProvider` (from P1) |
| `SupportedLanguage` | `Core/Models/AppModelLanguageAndProcessingTypes.swift` | **Not ported.** Dropped from iOS `connect(...)` signature. macOS clients already ignore it (`_ = language`). iOS hardcodes language at the protocol level. |

### Files to create (VoicePiCore `Clients/`)

| # | File | Lines | Type | Notes |
|---|------|-------|------|-------|
| 1 | `RealtimeClock.swift` | 12 | Direct port | `RealtimeClock` protocol + `SystemRealtimeClock`. Foundation `Task.sleep`. |
| 2 | `RealtimePCMChunker.swift` | 30 | Direct port | Static `appendAndChunk(pending:incoming:chunkSize:flushTail:)`. Operates on `Data`. |
| 3 | `WebSocketTransport.swift` | 46 | Direct port | `WebSocketTransport` protocol + `URLSessionWebSocketTransport` + factory. `URLSessionWebSocketTask` available on iOS. |
| 4 | `RealtimeASRStreamingErrorMapper.swift` | 33 | Direct port | Maps `URLError` / generic `Error` to `RemoteASRStreamingError`. |
| 5 | `RemoteASRStreamingClient.swift` | ~60 | New (modeled on macOS) | Protocol + `RemoteASRStreamEvent` + `RemoteASRStreamingError`. **iOS-native signatures** using `ASRConfig`/`ASRProvider` (no `ASRBackend`/`SupportedLanguage`/`RemoteASRConfiguration`). |
| 6 | `AliyunRealtimeProtocol.swift` | ~200 | Adapted port | Replace `RemoteASRConfiguration` → `ASRConfig` in `makeHandshakeHeaders`. Replace `RemoteASRClientError` → literal messages. `RealtimePCMChunker` call unchanged (same signature). |
| 7 | `VolcengineRealtimeProtocol.swift` | ~590 | Adapted port | Same adaptations as Aliyun. Additionally consumes `ASRConfig.volcengineAppID` via `makeHandshakeHeaders`. |
| 8 | `AliyunRealtimeASRClient.swift` | ~470 | Adapted port | Key adaptations: `connect(configuration:backend:language:)` → `connect(config:)`. Remove `ASRBackend` guard (redundant — client is provider-specific). `configuration.isConfigured` → `config.isConfigured`. `RemoteASRClientError` refs → `RemoteASRStreamingError.connectFailed("...")`. |
| 9 | `VolcengineRealtimeASRClient.swift` | ~500 | Adapted port | Same adaptations. Additionally reads `config.volcengineAppID`. |

**P2a total: 9 new files, ~1,941 lines.**

### macOS `RemoteASRStreamingClient` protocol — iOS rewrite

```swift
// macOS (existing)
protocol RemoteASRStreamingClient: AnyObject {
    var events: AsyncStream<RemoteASRStreamEvent> { get }
    func connect(configuration: RemoteASRConfiguration, backend: ASRBackend, language: SupportedLanguage) async throws
    func sendPCM16LEFrame(_ frame: Data) async throws
    func finishInput() async throws
    func awaitFinalResult(timeoutSeconds: Double) async throws -> String
    func close() async
}

// iOS (new)
protocol RemoteASRStreamingClient: AnyObject {
    var events: AsyncStream<RemoteASRStreamEvent> { get }
    func connect(config: ASRConfig) async throws
    func sendPCM16LEFrame(_ frame: Data) async throws
    func finishInput() async throws
    func awaitFinalResult(timeoutSeconds: Double) async throws -> String
    func close() async
}
```

`connect` only takes `ASRConfig` — provider type is self-evident from the concrete client class. `language` dropped (macOS already ignores it for Aliyun/Volcengine). `backend` dropped (redundant with client type).

### P2a exit gate

```bash
swift build --package-path Packages/VoicePiCore    # 9 new files compile into VoicePiCore library
```

No keyboard extension or Host App target involved. VoicePiCore only.

---

## 3. P2b: ASRClient Bridge + Keyboard Config Wiring

### Files to modify

| # | File | Change | Lines |
|---|------|--------|-------|
| 10 | `Clients/ASRClient.swift` | Add `streamingTask: Task<Void, Never>?` property. Add provider switch in `startStreaming()`. Add `startAliyunStreaming()` / `startVolcengineStreaming()` methods. Add `convertFloatSamplesToInt16PCM()` (produces raw PCM for WebSocket, additive to existing WAV encoder). Extend `cancel()` to cancel `streamingTask`. | +80 |
| 11 | `KeyboardSessionController.swift` | Extend `checkConfig` signature to accept `asrProvider: ASRProvider` and `volcengineAppID: String?`. Add Volcengine AppID emptiness check when provider is `.volcengine`. | +10 |
| 12 | `KeyboardRootViewController.swift` | In `startRecording()`, read `asrConfig.provider` / `asrConfig.volcengineAppID` from `sharedDefaults` and pass to the updated `checkConfig(...)` call. | ~5 |

**P2b total: 3 modified files, ~95 lines.**

### Call chain fix (replaces prior "0-change" claim)

Current `startRecording()` call:
```swift
// KeyboardRootViewController.swift:136-141 (current)
if let keyMissing = sessionController?.checkConfig(
    asrKey: config.asrConfig.apiKey,
    refinementKey: config.refinementConfig.apiKey,
    refinementEnabled: config.refinementConfig.enabled
) { ... }
```

P2b change:
```swift
if let keyMissing = sessionController?.checkConfig(
    asrKey: config.asrConfig.apiKey,
    refinementKey: config.refinementConfig.apiKey,
    refinementEnabled: config.refinementConfig.enabled,
    asrProvider: config.asrConfig.provider,              // NEW
    volcengineAppID: config.asrConfig.volcengineAppID    // NEW
) { ... }
```

5 lines. Reads from `sharedDefaults` which is already loaded in `startRecording()`. No new property, no new import.

### PCM conversion for WebSocket

Current `ASRClient.encodePCMToWAV()` converts Float samples → WAV (RIFF-wrapped). Aliyun/Volcengine WebSocket protocols send raw Int16 PCM, not WAV. Add:

```swift
/// Convert Float PCM samples to raw Int16 PCM (no WAV header).
/// Used by Aliyun/Volcengine WebSocket streaming clients.
private func convertFloatSamplesToInt16PCM(_ pcmData: Data) -> Data {
    let floatCount = pcmData.count / MemoryLayout<Float>.size
    var int16Data = Data(capacity: floatCount * 2)
    pcmData.withUnsafeBytes { rawBuffer in
        let floatBuffer = rawBuffer.bindMemory(to: Float.self)
        for i in 0..<floatCount {
            let clamped = max(-1.0, min(1.0, floatBuffer[i]))
            var intSample = Int16(clamped * Float(Int16.max))
            int16Data.append(Data(bytes: &intSample, count: 2))
        }
    }
    return int16Data
}
```

Existing `encodePCMToWAV` is unchanged — OpenAI-compatible still needs it.

### P2b exit gate

```bash
# Full iOS project builds both targets with provider-aware ASR
cd ios/VoicePiKeyboard && xcodegen generate
xcodebuild -project VoicePiKeyboard.xcodeproj \
  -scheme VoicePiApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

---

## 4. What P2 Does NOT Do

| Concern | Why Not | Which Slice |
|---------|---------|-------------|
| Add provider selector to Host App UI | UI before runtime verified = rejected | P3 |
| Make `APIVerificationClient.probeASR()` provider-aware | Verify branching — needs P2 runtime confirmed | P3 |
| Dynamic UI fields per provider (e.g., show/hide App ID field) | UI logic | P3 |
| Touch `RefinementConfig` or `RefinementClient` | Out of scope per plan | N/A |
| Port `RealtimeASRSessionCoordinator` (332 lines) | Concurrent recording+streaming state machine — overkill for iOS MVP record-then-stream | Deferred |
| Port `RealtimeAudioFramePump` (85 lines) | Backpressure management for live streaming — iOS sends all audio at once | Not needed |
| Port `RemoteASRClient` (578 lines) | macOS batch ASR client using audio files on disk — iOS `ASRStream` handles this role | Not needed |
| Port `SpeechRecorder` (436 lines) | Imports AppKit — iOS uses `KeyboardAudioCapture` | Not needed |
| Port `RemoteASRConfiguration` (full struct) | iOS `ASRConfig` already covers needed fields (P1) | Not needed |

---

## 5. Files NOT Touched

| File | Reason |
|------|--------|
| `OnboardingView.swift` | UI — P3 |
| `SettingsView.swift` | UI — P3 |
| `VoicePiComponents.swift` | UI — P3 |
| `ProfileManagementView.swift` | UI — P3 |
| `VoicePiTheme.swift` | UI — P3 |
| `VoicePiVerifyButton.swift` | UI — P3 |
| `APIVerificationClient.swift` | Verify branching — P3 |
| `ProfileModels.swift` | Schema — done in P1 |
| `RefinementClient.swift` | Refinement — out of scope |
| `PreviewBarView.swift` | UI — P3 |
| `KeyboardAudioCapture.swift` | Audio capture — unchanged |
| `KeyboardTextCommitter.swift` | Text commit — unchanged |
| `MemorySentinel.swift` | Memory — unchanged |
| `AudioInterruptionCoordinator.swift` | Audio — unchanged |

---

## 6. Summary

| Metric | P2a | P2b | Total |
|--------|-----|-----|-------|
| New files | 9 | 0 | 9 |
| Modified files | 0 | 3 | 3 |
| Total lines | ~1,941 | ~95 | ~2,036 |
| Host App UI changes | 0 | 0 | 0 |
| Keyboard Extension changes | 0 | 2 files | 2 files |
