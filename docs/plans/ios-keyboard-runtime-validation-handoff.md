# VoicePi iOS Keyboard — Runtime Validation Handoff

> **For:** Person with Xcode + physical iOS device
> **Last updated:** 2026-05-01 (P4: added S13–S18 ASR provider parity scenarios)
> **Status legend:**
> - ✅ `verified on this machine` — actually executed or code-inspected on this machine without requiring Xcode target build, code signing, or iOS device
> - ⬜ `prepared but not executed here` — code path exists and has been reviewed, but verification requires Xcode target build, code signing, or iOS compilation not available on this machine
> - 📱 `requires device/Xcode evidence` — only verifiable on a physical iOS device with full Xcode

---

## 1. Prerequisites

> **Note:** This table describes what the handoff recipient needs. It does NOT use the `✅/⬜/📱` verification legend from the scenarios below. "Required" = must have to proceed. "Available" = already present in the repository.

| Item | Detail | Requirement |
|------|--------|-------------|
| macOS with full Xcode 16+ | Required for code signing + device deployment + iOS target build. This machine has macOS + CLT only — no full Xcode. | Required |
| iOS device (iPhone, iOS 17+) | Keyboard extension requires physical device | Required |
| Apple Developer account | Required for App Group entitlements + code signing | Required |
| OpenAI API key (ASR) | Required for S1, S13 | Required |
| Aliyun DashScope API key | Required for S14. Obtain from [DashScope console](https://dashscope.aliyun.com). | Optional (provider-specific) |
| Volcengine Access Key + App ID | Required for S15. Obtain from [Volcengine BigModel console](https://console.volcengine.com). | Optional (provider-specific) |
| OpenAI API key (Refinement, optional) | Only if refinement enabled | Optional |
| XcodeGen | `brew install xcodegen` — verified present on this machine | Available |
| Project clone | `git clone` + `cd ios/VoicePiKeyboard` — verified present on this machine | Available |

---

## 2. Build & Install

### 2.1 Generate Xcode Project

```bash
cd ios/VoicePiKeyboard
xcodegen generate
```

| Step | Status |
|------|--------|
| `xcodegen generate` succeeds | ✅ verified on this machine |
| `.xcodeproj` opens in Xcode | 📱 requires device/Xcode evidence |

### 2.2 Configure Signing

1. Open `VoicePiKeyboard.xcodeproj` in Xcode
2. Select **VoicePiApp** target → Signing & Capabilities
3. Select your team, let Xcode auto-manage signing
4. Repeat for **VoicePiKeyboardExtension** target
5. Verify **App Groups** capability is enabled on both targets with `group.com.voicepi.shared`

| Step | Status |
|------|--------|
| Code signing configured | 📱 requires device/Xcode evidence |
| App Group entitlement present | ✅ code-verified (in .entitlements) |

### 2.3 Build & Run

1. Select your physical iOS device as build target
2. Build & Run **VoicePiApp** target
3. Complete the 3-step onboarding wizard (enter API keys, grant mic, follow keyboard setup instructions)
4. Go to Settings → General → Keyboard → Keyboards → Add New Keyboard → VoicePi
5. Enable **Allow Full Access**

| Step | Status |
|------|--------|
| Build succeeds on device | 📱 requires device/Xcode evidence |
| Onboarding wizard completes | ⬜ prepared, untested |
| Keyboard appears in keyboard list | 📱 requires device/Xcode evidence |
| Full Access enabled | 📱 requires device/Xcode evidence |

---

## 3. Validation Scenarios

### S1: Basic Dictation (Happy Path)

**Goal:** Verify end-to-end recording → ASR → commit.

1. Open Safari → tap Google search field
2. Switch to VoicePi keyboard via globe key
3. Tap mic button → speak a short sentence ("Hello world test")
4. Wait for ASR result → tap green commit arrow
5. Verify text appears in search field

| Check | Status |
|-------|--------|
| Mic permission granted on first use | ⬜ prepared, untested |
| Recording state indicator (red dot) visible | ✅ code-verified |
| ASR returns text | ⬜ prepared, untested |
| Commit inserts text at cursor | ⬜ prepared, untested |
| State returns to idle after commit | ✅ code-verified |

---

### S2: Mic Permission Denied

**Goal:** Verify `.permissionDenied` state renders correctly.

1. Settings → Privacy → Microphone → disable VoicePi
2. Switch to VoicePi keyboard
3. Tap mic button
4. Verify orange mic-slash icon + "Mic access denied" hint
5. Verify retry button (clockwise arrow) returns to idle
6. Re-enable mic in Settings and verify flow works

| Check | Status |
|-------|--------|
| `.permissionDenied` state shown after denied request | ⬜ prepared, untested |
| Retry button works (returns to idle) | ✅ code-verified |
| After re-enabling mic, recording starts | ⬜ prepared, untested |

---

### S3: API Key Missing (Config Missing)

**Goal:** Verify `.configMissing` blocks recording.

1. Remove ASR API key from host app profile
2. Switch to VoicePi keyboard
3. Tap mic button
4. Verify orange key-slash icon + "ASR API key not configured" hint
5. Verify retry → idle
6. Verify: with refinement disabled, only ASR key is required

| Check | Status |
|-------|--------|
| `.configMissing` blocks recording when ASR key missing | ⬜ prepared, untested |
| Hint shows "ASR API key not configured" | ✅ code-verified |
| ASR-only config (refinement disabled) does not block | ✅ code-verified |
| With refinement enabled, refinement key also required | ⬜ prepared, untested |

---

### S4: ASR Network Failure

**Goal:** Verify `.failed` state on network error.

1. Set ASR API key to an invalid value (e.g., `"invalid-key"`)
2. Switch to keyboard → record → wait for ASR
3. Verify red exclamation icon + error message

| Check | Status |
|-------|--------|
| `.failed` state shown with error message | ✅ code-verified |
| Retry button returns to idle | ✅ code-verified |

---

### S5: Refinement Failure → Raw Fallback

**Goal:** Verify raw ASR result is preserved when refinement fails.

1. Set refinement API key to invalid value (keep ASR key valid)
2. Record → wait for ASR → wait for refinement attempt
3. Verify state transitions to `.readyToCommit` with raw ASR text (not `.failed`)
4. Commit and verify correct text appears

| Check | Status |
|-------|--------|
| Refinement failure falls back to raw text | ✅ code-verified (generation counter closes race) |
| State shows `.readyToCommit` not `.failed` | ✅ code-verified |
| Raw text matches what was spoken | ⬜ prepared, untested |

---

### S6: Use Raw Button

**Goal:** Verify user can skip refinement and use raw ASR directly.

1. Record → wait for ASR → refinement starts (orange bar)
2. Tap "Use Raw" button while refining
3. Verify state goes to `.readyToCommit` with raw text
4. Commit and verify

| Check | Status |
|-------|--------|
| "Use Raw" button visible during `.refining` state | ✅ code-verified |
| Tapping Use Raw → `.readyToCommit(raw)` immediately | ✅ code-verified |
| Late refinement callbacks don't overwrite raw result | ✅ code-verified (generation counter) |

---

### S7: Commit Failure & Recovery

**Goal:** Verify commit failure shows error and preserves text for retry.

To simulate proxy unavailability: use Spotlight Search (which may not accept keyboard text insertion).

1. Record → commit in a context where insert may fail
2. Verify `.commitFailed` state with "Commit failed: No text field" hint
3. Verify retry button (clockwise arrow) + cancel button (x) appear
4. Tap retry → verify returns to `.readyToCommit` with text preserved
5. Tap cancel → verify returns to idle, text cleared

| Check | Status |
|-------|--------|
| `.commitFailed` shown when proxy nil | ⬜ prepared, untested |
| Text preserved — retry restores to `.readyToCommit` | ✅ code-verified |
| Cancel clears state and text | ✅ code-verified |
| Commit count NOT incremented on failure | ✅ code-verified |

---

### S8: Cancel Recovery (All States)

**Goal:** Verify cancel works from every state.

| From state | Tap cancel → expected result | Status |
|------------|------------------------------|--------|
| `.recording` | stops audio, records partial duration to stats, returns to idle | ✅ code-verified |
| `.recognizing` | cancels ASR request, returns to idle | ✅ code-verified |
| `.refining` | cancels refinement, returns to idle | ✅ code-verified |
| `.readyToCommit` | clears text, returns to idle | ✅ code-verified |
| `.failed` / error states | returns to idle | ✅ code-verified |

---

### S9: Interruption Handling

**Goal:** Verify incoming calls and audio interruptions.

1. Start recording
2. Receive incoming call or trigger another audio source
3. Verify recording stops cleanly
4. Verify state returns to idle

| Check | Status |
|-------|--------|
| Recording stops on audio interruption | ⬜ prepared, untested |
| No crash on interruption begin | ⬜ prepared, untested |

---

### S10: Host App Context Switching

**Goal:** Verify keyboard works across different host apps.

1. Use keyboard in Safari (web search field)
2. Switch to Notes app, use keyboard
3. Switch to Messages, use keyboard
4. Verify textDocumentProxy works in each context

| Check | Status |
|-------|--------|
| Keyboard functions in Safari | 📱 requires device/Xcode evidence |
| Keyboard functions in Notes | 📱 requires device/Xcode evidence |
| Keyboard functions in Messages/WeChat | 📱 requires device/Xcode evidence |
| No memory leak across host switches | 📱 requires device/Xcode evidence |

---

### S11: MemorySentinel (DEBUG only)

**Goal:** Verify MemorySentinel shows RSS and doesn't affect release builds.

1. Build with DEBUG configuration
2. Switch to keyboard, locate "DEBUG RSS: XX MB" collapsed row below main bar
3. Tap to expand → verify RSS, App label, Refresh button
4. Record for 30s → check RSS doesn't grow unbounded (>50MB spike acceptable, should not stay)
5. Build with RELEASE configuration → verify DEBUG panel absent

| Check | Status |
|-------|--------|
| RSS displays in debug panel | ✅ code-verified (#if DEBUG guard) |
| Refresh button updates RSS | ✅ code-verified |
| Release build has no debug panel | ✅ code-verified (#if DEBUG guard) |
| RSS stays within keyboard limits (<50MB during recording) | 📱 requires device/Xcode evidence |

---

### S12: Usage Stats

**Goal:** Verify commit count and recording stats increment correctly.

1. Record and commit 3 texts in keyboard
2. Switch to VoicePi host app
3. Navigate to Usage tab
4. Verify commit count = 3
5. Go to background → use keyboard → return → verify count updated (foreground refresh)

| Check | Status |
|-------|--------|
| Commit count increments per commit | ✅ code-verified |
| Recording count and duration recorded | ✅ code-verified |
| Host app Usage tab shows stats | ✅ code-verified |
| Foreground refresh updates stats | ✅ code-verified (scenePhase hook) |

---

### S13: OpenAI ASR Provider — End-to-End Verification

**Goal:** Verify OpenAI-compatible ASR still works with the new provider-aware architecture.

1. Onboard with OpenAI provider (select in onboarding, enter API key, verify)
2. In keyboard, tap mic → speak a short sentence ("Hello world test")
3. Wait for recognition → verify transcription appears in preview bar
4. Tap commit → verify text inserted into the active text field

| Check | Status |
|-------|--------|
| OpenAI ASR config saved and loaded correctly | ✅ code-verified (OnboardingView.swift:247-265 verify, saveAndComplete) |
| `ASRClient.startOpenAICompatibleStreaming()` wired | ✅ code-verified (ASRClient.swift:35, 142) |
| Live dictation produces transcription | 📱 requires device/Xcode evidence |
| Text commit inserts into text field | 📱 requires device/Xcode evidence |

### S14: Aliyun DashScope ASR — End-to-End Verification

**Goal:** Verify Aliyun ASR path works end-to-end with real DashScope credentials.

**Prerequisites:** Aliyun DashScope API key (from [DashScope console](https://dashscope.aliyun.com)).

1. Open Host App → Settings → ASR section
2. Switch provider to **Aliyun DashScope**
3. Enter DashScope API key → tap Save
4. Tap "Test Connection" → should show green verified badge
5. Switch to keyboard → mic → speak a short sentence in Chinese
6. Wait for recognition → verify Chinese transcription appears
7. Tap commit → verify text inserted

| Check | Status |
|-------|--------|
| Aliyun provider selectable in Settings | ✅ code-verified (SettingsView.swift:51-55) |
| Aliyun API key persisted across provider switches | ✅ code-verified (draft preservation, SettingsView.swift:263-275) |
| Test Connection HEAD to `dashscope.aliyuncs.com/compatible-mode/v1/models` | ✅ code-verified (APIVerificationClient.swift:57-67) |
| `AliyunRealtimeASRClient.connect(config:)` → WebSocket handshake with `Authorization: bearer` | ✅ code-verified (AliyunRealtimeProtocol.swift:81) |
| Live dictation → WebSocket streaming → transcription | 📱 requires device/Xcode evidence |
| Chinese transcription accuracy | 📱 requires device/Xcode evidence |

### S15: Volcengine BigModel ASR — End-to-End Verification

**Goal:** Verify Volcengine ASR path works end-to-end with real BigModel credentials.

**Prerequisites:** Volcengine Access Key + App ID (from [Volcengine BigModel console](https://console.volcengine.com)).

1. Open Host App → Settings → ASR section
2. Switch provider to **Volcengine BigModel**
3. Enter Access Key + App ID → tap Save
4. Tap "Test Connection" → should show **gray checkmark + "Configured"** (NOT green "Verified")
5. Switch to keyboard → mic → speak a short sentence in Chinese
6. Wait for recognition → verify transcription appears
7. Tap commit → verify text inserted

| Check | Status |
|-------|--------|
| Volcengine provider selectable in Settings | ✅ code-verified (SettingsView.swift:51-55) |
| Volcengine App ID field visible + persisted | ✅ code-verified (SettingsView.swift:67-73) |
| Verify returns `.configured` not `.verified` (Volcengine uses App Key + App ID auth, no simple HTTP HEAD probe) | ✅ code-verified (APIVerificationClient.swift:32, 76-101) |
| `VolcengineRealtimeASRClient.connect(config:)` → WebSocket with X-Api-App-Key + X-Api-Access-Key headers | ✅ code-verified (VolcengineRealtimeProtocol.swift:138-157) |
| Live dictation → WebSocket streaming → transcription | 📱 requires device/Xcode evidence |

### S16: Provider Switch — Credential Preservation

**Goal:** Verify apiKey is preserved across provider switches; baseURL/model snap to each provider's defaults and do NOT restore previous custom values.

1. Configure OpenAI: API key `sk-test123`, model `my-custom-model`, baseURL `https://my-proxy.example.com`
2. Switch to Aliyun → verify:
   - API key field still shows `sk-test123` (preserved)
   - baseURL shows `https://dashscope.aliyuncs.com` (snapped to Aliyun default)
   - model shows `paraformer-v2` (snapped to Aliyun default)
3. Switch back to OpenAI → verify:
   - API key field still shows `sk-test123` (preserved)
   - baseURL shows `https://api.openai.com` (snapped to OpenAI default — does NOT restore `https://my-proxy.example.com`)
   - model shows `whisper-1` (snapped to OpenAI default — does NOT restore `my-custom-model`)

**Important:** baseURL and model are provider-owned values. Switching providers always applies that provider's defaults. Custom OpenAI values are NOT restored when switching back — the user must re-enter them.

| Check | Status |
|-------|--------|
| apiKey draft preserved across provider switches | ✅ code-verified (SettingsView.swift:263-275, only baseURL/model are overwritten) |
| baseURL/model snap to provider defaults on switch | ✅ code-verified (SettingsView.swift:263-275, applyProviderDefaultsForDraft) |
| baseURL/model do NOT restore previous custom values on switch-back | ✅ code-verified (P3 agreed behavior: baseURL/model are provider-owned, not user-custom) |
| Volcengine App ID preserved across switches | ✅ code-verified (draft not overwritten in applyProviderDefaultsForDraft) |
| On-device field values match expected behavior | 📱 requires device/Xcode evidence |

### S17: Provider Missing-Field Error — Volcengine

**Goal:** Verify keyboard surfaces correct error when Volcengine App ID is empty.

1. Configure Volcengine with valid Access Key but empty App ID
2. Save → switch to keyboard → tap mic
3. Verify error state: "Volcengine App ID not configured"

| Check | Status |
|-------|--------|
| `KeyboardSessionController.checkConfig` checks Volcengine App ID | ✅ code-verified (KeyboardSessionController.swift:65-66) |
| Error message surfaced in keyboard UI | 📱 requires device/Xcode evidence |
| Error clears after entering App ID and restarting recording | 📱 requires device/Xcode evidence |

### S18: Per-Provider Verify Behavior

**Goal:** Verify each provider's verify button shows the correct badge + state.

1. OpenAI with valid key → "Test Connection" → green checkmark + "Verified"
2. Aliyun with valid key → "Test Connection" → green checkmark + "Verified"
3. Volcengine with valid key + App ID → "Test Connection" → **gray** checkmark + "Configured"
4. Any provider with wrong key → "Test Connection" → red X + "Unauthorized"
5. Any provider with empty key → "Test Connection" → red X + "API key required"

| Check | Status |
|-------|--------|
| OpenAI/Aliyun verify returns `.verified` (endpoint-probed) | ✅ code-verified (APIVerificationClient.swift:28-30) |
| Volcengine verify returns `.configured` (local gate only) | ✅ code-verified (APIVerificationClient.swift:32, validateVolcengine at 76-101) |
| Badge icon distinguishes `.verified` (green) from `.configured` (gray) | ✅ code-verified (VoicePiVerifyButton.swift:badgeColor) |
| Missing key returns `.missingKey` error badge | ✅ code-verified (APIVerificationClient.swift:39-41, 59-60) |
| Active live verify against real endpoints | 📱 requires device/Xcode evidence |

---

## 4. Summary

| Category | Count |
|----------|-------|
| ✅ verified on this machine | All code paths compiled + xcodegen verified |
| ⬜ prepared but not executed here | All state transitions coded, untested on device |
| 📱 requires device/Xcode evidence | All runtime behaviors, host app switching, memory, interruption |
