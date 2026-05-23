# VoicePi iOS Keyboard — Evidence Checklist

> **For:** Person with Xcode + physical iOS device
> **Last updated:** 2026-05-01 (P4: added Section 10 ASR Provider Parity — 29 checks EP1–EP29)
> **Goal:** Produce a reproducible evidence packet that proves the keyboard works end-to-end, handles all error states, and is release-ready.
>
> **Status legend:**
> - ✅ `verified on this machine` — checked locally, no device needed
> - ⬜ `prepared but not executed here` — code exists, waits for device
> - 📱 `requires device/Xcode evidence` — only verifiable on device

---

## Before You Start

### Required
- [ ] iPhone (iOS 17+) connected to Mac via USB
- [ ] Xcode 16+ with provisioning profile for the device
- [ ] Apple Developer account with App Group capability
- [ ] OpenAI API key (ASR) configured in onboarding
- [ ] (Optional) Second OpenAI API key for refinement

### Provider Credentials (for EP24-EP29)
- [ ] Aliyun DashScope API key (for Aliyun ASR testing)
- [ ] Volcengine Access Key + App ID (for Volcengine ASR testing)

### Setup (~5 min)

1. Clone: `git clone <repo-url> && cd ios/VoicePiKeyboard`
2. Generate: `xcodegen generate` → opens `VoicePiKeyboard.xcodeproj`
3. Configure signing on both targets (VoicePiApp + VoicePiKeyboardExtension)
4. Build & Run VoicePiApp on device
5. Complete onboarding wizard (enter API key, grant mic, follow setup instructions)
6. Settings → General → Keyboard → Keyboards → Add VoicePi → Enable Full Access

**Pre-flight evidence:** Screenshot the keyboard appearing in the keyboard list with Full Access enabled.

---

## Evidence Collection: What to Capture

For each scenario below, collect:

| Artifact | Format | How |
|----------|--------|-----|
| **Screenshot** | PNG, full device resolution | Side button + volume up, or Xcode "Take Screenshot" |
| **Screen recording** | MOV, device native | Control Center → Screen Recording, or `xcrun simctl io booted recordVideo` (sim only) |
| **Xcode console log** | Text file | Copy from Xcode debug console, or `idevicesyslog` |
| **Memory report** | Text file | Open debug panel (tap "DEBUG RSS:"), expand, screenshot or transcribe RSS values |
| **Evidence log entry** | Markdown table row | Fill in the table in Section 8 as you go |

Store all files in `evidence/` directory, named as `S{N}-{description}.{ext}` (e.g., `S1-dictation-commit.png`, `S1-screen-recording.mov`).

---

## S1: Basic Dictation (Happy Path) 📱

**Priority: GO/NO-GO**

### Steps
1. Open Safari → tap Google search field (or any text field)
2. Switch to VoicePi keyboard via globe key
3. Verify idle state: gray dot + "Tap to record"
4. Tap mic button → verify red dot appears, "Recording..."
5. Speak clearly: "Hello world this is a test of VoicePi dictation"
6. Stop recording (tap stop or wait for auto-stop)
7. Verify "Recognizing..." appears with spinner
8. Wait for ASR result to appear as preview text
9. If refinement enabled, verify "Refining..." appears with orange bar
10. When green checkmark + "Tap to commit" appears, tap commit arrow
11. Verify text "Hello world this is a test of VoicePi dictation" appears in the Safari search field

### Collect
- [ ] Screenshot: Idle state with "Tap to record"
- [ ] Screenshot: Recording state with red dot + "Recording..."
- [ ] Screenshot: Ready to commit with green checkmark + recognized text
- [ ] Screenshot: Text inserted into Safari search field
- [ ] **Screen recording**: Full flow from idle → record → commit → text appears (15-30s)
- [ ] Console log: ASR request/response (if visible)

### Expected Result
```
State flow: idle → recording → recognizing → (refining) → readyToCommit → idle
Text matches what was spoken.
```

---

## S2: Mic Permission Denied 📱

### Steps
1. Settings → Privacy & Security → Microphone → disable VoicePi
2. Switch to VoicePi keyboard in any app
3. Tap mic button
4. Verify orange mic-slash icon appears
5. Verify hint text: "Mic access denied"
6. Tap retry button (clockwise arrow) → verify returns to idle state
7. Re-enable mic in Settings → Privacy
8. Switch back to keyboard → tap mic → verify recording starts normally

### Collect
- [ ] Screenshot: `.permissionDenied` state (orange mic-slash, hint, retry button)
- [ ] Screenshot: After re-enabling mic, recording starts (red dot)
- [ ] Console log: Permission denied error (if logged)

### Expected Result
```
Permission denied → .permissionDenied shown → retry → idle
After re-enable → recording starts normally
```

---

## S3: API Key Missing 📱

### Steps
1. Open VoicePi host app → Profile tab
2. Remove/clear the ASR API key → save
3. Switch to keyboard → tap mic
4. Verify orange key-slash icon + "ASR API key not configured" hint
5. Verify retry button returns to idle
6. If refinement is disabled: verify only ASR key is checked (re-enter ASR key, leave refinement blank → mic works)
7. If refinement is enabled: clear refinement key too, verify "Refinement API key not configured"

### Collect
- [ ] Screenshot: `.configMissing` with ASR key message
- [ ] Screenshot: `.configMissing` with refinement key message (if enabled)
- [ ] Screenshot: After re-entering only ASR key (refinement off), recording works

### Expected Result
```
Missing ASR key → .configMissing("ASR API key not configured") → retry → idle
Refinement disabled → only ASR key required
Refinement enabled → both keys required
```

---

## S4: ASR Network Failure 📱

### Steps
1. Open VoicePi host app → Profile tab
2. Set ASR API key to `sk-invalid-test-key-12345`
3. Switch to keyboard → record a short phrase
4. Wait for ASR attempt to fail
5. Verify red exclamation icon appears
6. Verify error message shown (e.g. "Error: ...")
7. Tap retry → verify returns to idle

### Collect
- [ ] Screenshot: `.failed` state with error message + red exclamation icon
- [ ] Console log: Full error from the ASR API call

### Expected Result
```
Recording → recognizing → .failed("...") → retry → idle
Error message shown, not silent. No crash.
```

---

## S5: Refinement Failure → Raw Fallback 📱

### Steps
1. Set ASR key to valid, set refinement key to `sk-invalid`
2. Ensure refinement is enabled in host app
3. Switch to keyboard → record a short phrase
4. ASR should succeed → state goes to `.refining`
5. Refinement should fail → verify fallback to `.readyToCommit` with raw ASR text
6. Verify state did NOT go to `.failed` — raw text is preserved
7. Commit the raw text → verify it appears correctly

### Collect
- [ ] Screenshot: `.readyToCommit(raw)` after refinement failure (green checkmark, raw text)
- [ ] Console log: Refinement error + "falling back to raw" trace

### Expected Result
```
Refinement fails → .readyToCommit(rawText), not .failed
Text matches what was spoken (minus refinement polish)
```

---

## S6: Use Raw During Refinement 📱

### Steps
1. Set both API keys to valid
2. Switch to keyboard → record a longer sentence
3. When state shows "Refining..." (orange bar), immediately tap "Use Raw" button
4. Verify state immediately jumps to `.readyToCommit` with raw ASR text
5. Wait a few seconds — verify no late refinement callback overwrites the text
6. Commit the raw text

### Collect
- [ ] Screenshot: "Use Raw" button visible during `.refining` state
- [ ] Screenshot: After tapping Use Raw → green checkmark with raw text
- [ ] Screen recording: Full flow showing the instant transition

### Expected Result
```
.refining → tap "Use Raw" → .readyToCommit(rawText) immediately
Late refinement callbacks do NOT overwrite (generation counter)
```

---

## S7: Commit Failure & Recovery 📱

### Steps
1. Record → wait for `.readyToCommit`
2. Find a context where text insertion might fail:
   - Try Spotlight Search (swipe down on home screen)
   - Or a read-only text field
3. Tap commit
4. If commit fails: verify `.commitFailed` state with "Commit failed: No text field" hint
5. Verify TWO buttons appear: retry (clockwise arrow) + cancel (X)
6. Tap **retry**: verify returns to `.readyToCommit` with text preserved
7. Switch to a real text field (e.g., Notes) → tap commit → verify text inserts
8. Repeat steps 1-3, then tap **cancel**: verify returns to idle, text cleared

### Collect
- [ ] Screenshot: `.commitFailed` state with both retry + cancel buttons
- [ ] Screenshot: After retry → `.readyToCommit` with same text
- [ ] Screenshot: After cancel → idle state, empty text
- [ ] Console log: "No text field" / proxy nil log

### Expected Result
```
Commit fails → .commitFailed("No text field") → retry → .readyToCommit(same text) → commit succeeds
Commit fails → cancel → .idle, text cleared
Commit count NOT incremented on failure
```

---

## S8: Cancel from All States 📱

### Steps
For each state below, get into that state, then tap cancel (X/stop button). Verify the result.

| From State | How to reach | Tap | Expected | Done |
|------------|-------------|-----|----------|------|
| `.recording` | Tap mic, start speaking | Stop button | Returns to idle | ⬜ |
| `.recognizing` | Record → stop (auto-transition) | X button | Returns to idle | ⬜ |
| `.refining` | Record with refinement on | X button | Returns to idle | ⬜ |
| `.readyToCommit` | Wait for full pipeline | Use cancel in nav area | Returns to idle, text cleared | ⬜ |
| `.failed` | Use invalid key | Retry or cancel | Returns to idle | ⬜ |
| `.permissionDenied` | Deny mic | Retry | Returns to idle | ⬜ |
| `.configMissing` | Remove API key | Retry | Returns to idle | ⬜ |
| `.commitFailed` | Commit to no field | Cancel button | Returns to idle, text cleared | ⬜ |

### Collect
- [ ] Screen recording: Cancel from 3-4 representative states (especially `.recording` and `.commitFailed`)
- [ ] Console log: Any state transition anomalies

---

## S9: Audio Interruption 📱

### Steps
1. Start recording in keyboard
2. While recording, trigger an audio interruption:
   - Have someone call you, OR
   - Ask Siri something (hold side button), OR
   - Play a video in another app
3. Verify recording stops cleanly — no crash, no hang
4. Verify state returns to idle (or to a safe state)
5. Switch back to the app → verify keyboard is responsive

### Collect
- [ ] Screen recording: Shows keyboard state before, during, and after interruption
- [ ] Console log: AVAudioSession interruption notification traces
- [ ] Note: Which interruption method was used and what state resulted

### Expected Result
```
Recording → interruption → audio stops → state returns to idle
No crash. Keyboard responsive after interruption.
```

---

## S10: Host App Context Switching 📱

### Steps
1. Use keyboard in **Safari** (web search field) → record + commit
2. Switch to **Notes** app → use keyboard → record + commit
3. Switch to **Messages** → use keyboard → record + commit
4. Switch back to Safari → record + commit again
5. Observe: does textDocumentProxy work in each context?

### Collect
- [ ] Screenshot: Successful commit in Safari
- [ ] Screenshot: Successful commit in Notes
- [ ] Screenshot: Successful commit in Messages
- [ ] Memory report: RSS after 4+ host switches (open debug panel, note RSS value)
- [ ] Note: Any host app where commit consistently fails

### Expected Result
```
Each host app → keyboard works, text inserts, no crash
RSS does not grow unbounded across host switches
```

---

## S11: MemorySentinel (DEBUG) 📱

### Steps
1. Build with **DEBUG** configuration (default in Xcode Run)
2. Switch to keyboard → locate "DEBUG RSS: XX MB" collapsed row below main bar
3. Tap to expand → verify RSS, "VoicePi v1" label, and Refresh button are visible
4. Record for 30s continuous (say a long sentence or keep talking) → tap Refresh → note RSS
5. Record + commit 5 times in a row → tap Refresh after each → note RSS trend
6. RSS should not grow unbounded (>60MB sustained is a red flag; <50MB is ideal)
7. Build with **RELEASE** configuration → verify DEBUG panel is completely absent

### Collect
- [ ] Screenshot: Debug panel collapsed (RSS value visible in collapsed row)
- [ ] Screenshot: Debug panel expanded (RSS + App + Refresh)
- [ ] Text file: RSS values taken every 5 cycles during the 5-cycle test
- [ ] Screenshot: Release build — no debug panel visible
- [ ] Console log: Any memory warnings

### Expected Result
```
DEBUG: panel visible, RSS shows, Refresh works
5-cycle: RSS stable (no monotonic leak), stays under 50MB
RELEASE: panel absent entirely
```

**RSS Data Template (fill in):**
```
Cycle 0 (idle):     ___ MB
Cycle 1 (after commit): ___ MB
Cycle 2 (after commit): ___ MB
Cycle 3 (after commit): ___ MB
Cycle 4 (after commit): ___ MB
Cycle 5 (after commit): ___ MB
```

---

## S12: Usage Stats Accuracy 📱

### Steps
1. Note current commit count from Usage tab in host app: ___
2. Record + commit 3 texts in the keyboard
3. Switch to VoicePi host app → Usage tab
4. Verify commit count increased by exactly 3
5. Verify recording count and total duration updated
6. Go to background (swipe home) → use keyboard again → commit 1 more
7. Return to host app → verify count updates on foreground (scenePhase active)

### Collect
- [ ] Screenshot: Usage tab before (baseline)
- [ ] Screenshot: Usage tab after 3 commits (verify +3)
- [ ] Screenshot: Usage tab after background → keyboard use → foreground refresh (verify +1)

### Expected Result
```
Commit count = baseline + 3 after keyboard commits
Foreground refresh picks up background keyboard usage
Recording count and audio duration also increment
```

---

## Evidence Packet Assembly

When all 12 scenarios are complete, assemble:

```
evidence/
├── README.md                   # This checklist with filled-in results
├── S1-dictation-happy-path/
│   ├── S1-idle.png
│   ├── S1-recording.png
│   ├── S1-ready-to-commit.png
│   ├── S1-committed-text.png
│   └── S1-full-flow.mov
├── S2-mic-denied/
│   ├── S2-permission-denied.png
│   └── S2-after-reenable.png
├── S3-config-missing/
│   ├── S3-asr-key-missing.png
│   └── S3-refinement-key-missing.png
├── S4-asr-failure/
│   ├── S4-failed-state.png
│   └── S4-console-error.txt
├── S5-refinement-fallback/
│   └── S5-raw-fallback.png
├── S6-use-raw/
│   ├── S6-use-raw-button.png
│   ├── S6-after-use-raw.png
│   └── S6-use-raw-flow.mov
├── S7-commit-failure/
│   ├── S7-commit-failed.png
│   ├── S7-retry-restored.png
│   └── S7-cancel-cleared.png
├── S8-cancel-all-states/
│   └── S8-cancel-flow.mov
├── S9-interruption/
│   ├── S9-interruption.mov
│   └── S9-console.txt
├── S10-host-switching/
│   ├── S10-safari.png
│   ├── S10-notes.png
│   ├── S10-messages.png
│   └── S10-rss-after-switches.txt
├── S11-memory-sentinel/
│   ├── S11-debug-collapsed.png
│   ├── S11-debug-expanded.png
│   ├── S11-release-no-debug.png
│   └── S11-rss-trend.txt
├── S12-usage-stats/
│   ├── S12-baseline.png
│   ├── S12-after-3.png
│   └── S12-after-foreground.png
├── release-gates/
│   ├── G1-build-success.txt (Xcode build log)
│   ├── G2-S1-pass.txt (confirmation)
│   ├── G3-S7-pass.txt (confirmation)
│   ├── G4-rss-stable.txt (S11 RSS trend)
│   ├── G5-dark-mode-accessibility.png
│   └── G6-privacy-manifest.txt
└── SUMMARY.md                   # Completed results table with pass/fail
```

---

## Summary: Results Log

⚠️ **Fill this in as you run the scenarios.** This is the primary deliverable.

| Scenario | Pass/Fail | Screenshots | Recording | Console Log | Notes |
|----------|-----------|-------------|-----------|-------------|-------|
| S1: Basic Dictation | ⬜ | ⬜ | ⬜ | ⬜ | |
| S2: Mic Denied | ⬜ | ⬜ | — | ⬜ | |
| S3: Config Missing | ⬜ | ⬜ | — | — | |
| S4: ASR Failure | ⬜ | ⬜ | — | ⬜ | |
| S5: Refinement Fallback | ⬜ | ⬜ | — | ⬜ | |
| S6: Use Raw | ⬜ | ⬜ | ⬜ | — | |
| S7: Commit Failure | ⬜ | ⬜ | — | ⬜ | |
| S8: Cancel All States | ⬜ | — | ⬜ | ⬜ | |
| S9: Interruption | ⬜ | — | ⬜ | ⬜ | |
| S10: Host Switching | ⬜ | ⬜ | — | — | |
| S11: MemorySentinel | ⬜ | ⬜ | — | — | |
| S12: Usage Stats | ⬜ | ⬜ | — | — | |

### Go/No-Go Gates

| Gate | Pass/Fail | Evidence |
|------|-----------|----------|
| G1: Build on device | ⬜ | Xcode build log |
| G2: S1 passes | ⬜ | S1 screen recording |
| G3: S7 passes | ⬜ | S7 screenshots |
| G4: RSS stable | ⬜ | S11 RSS trend |
| G5: Dark mode + a11y | ⬜ | Screenshots |
| G6: Privacy manifest | ⬜ | PrivacyInfo.xcprivacy |

---

## 10. ASR Provider Parity (P4 — added 2026-05-01)

> Code-static verification done on build machine. Device runtime checks require Xcode + physical device.
> Status legend: ✅ `code-static` = code path inspected and verified; 📱 `device` = requires physical device.

### Schema + Config

| # | Check | Status |
|---|-------|--------|
| EP1 | `ASRProvider` enum with 3 cases (`openAICompatible`, `aliyun`, `volcengine`) exists in VoicePiCore | ✅ code-static (ProfileModels.swift:93-105) |
| EP2 | `ASRConfig.volcengineAppID` field exists and is Codable | ✅ code-static (ProfileModels.swift:114, 207) |
| EP3 | Backward decode: old configs without `volcengineAppID` → default `""` | ✅ test-verified (VoicePiCoreTests testMissingVolcengineAppIDKeyDecodesAsEmpty) |
| EP4 | Backward decode: old `"openai"` provider → `.openAICompatible` | ✅ test-verified (VoicePiCoreTests testLegacyOpenAIProviderDecodesToOpenAICompatible) |
| EP5 | `isConfigured(for: .volcengine)` additionally requires non-empty `volcengineAppID` | ✅ code-static (ProfileModels.swift:170-178) |

### Keyboard Runtime

| # | Check | Status |
|---|-------|--------|
| EP6 | `ASRClient.startStreaming()` dispatches by `config.provider` | ✅ code-static (ASRClient.swift:33-40) |
| EP7 | `ASRClient.startOpenAICompatibleStreaming()` exists (REST multipart path) | ✅ code-static (ASRClient.swift:142) |
| EP8 | `ASRClient.startAliyunStreaming()` exists (WebSocket path → `AliyunRealtimeASRClient`) | ✅ code-static (ASRClient.swift:214) |
| EP9 | `ASRClient.startVolcengineStreaming()` exists (WebSocket path → `VolcengineRealtimeASRClient`) | ✅ code-static (ASRClient.swift:265) |
| EP10 | `KeyboardSessionController.checkConfig` validates Volcengine App ID | ✅ code-static (KeyboardSessionController.swift:65-66) |
| EP11 | `KeyboardRootViewController.startRecording()` passes provider + appID to checkConfig | ✅ code-static (KeyboardRootViewController.swift:137-142) |
| EP12 | Aliyun WebSocket uses `Authorization: bearer {apiKey}` header | ✅ code-static (AliyunRealtimeProtocol.swift:81) |
| EP13 | Volcengine WebSocket uses `X-Api-App-Key` + `X-Api-Access-Key` headers | ✅ code-static (VolcengineRealtimeProtocol.swift:152-153) |

### Host App UI + Verify

| # | Check | Status |
|---|-------|--------|
| EP14 | Provider picker shows 3 options (OpenAI / Aliyun / Volcengine) | ✅ code-static (VoicePiComponents.swift:331-335) |
| EP15 | Aliyun/Volcengine show read-only endpoint info (not editable baseURL/model) | ✅ code-static (SettingsView.swift:250-252, VoicePiComponents.swift:387-407) |
| EP16 | OpenAI baseURL/model editable | ✅ code-static (SettingsView.swift:239-249) |
| EP17 | `APIVerificationClient.probeASR` dispatches by provider | ✅ code-static (APIVerificationClient.swift:25-33) |
| EP18 | Volcengine verify uses `isConfigured(for: .volcengine)` gate → `.configured` result | ✅ code-static (APIVerificationClient.swift:77-101) |
| EP19 | Per-provider onboarding gate: OpenAI/Aliyun → `.verified`, Volcengine → `.configured` | ✅ code-static (OnboardingView.swift:200-208) |
| EP20 | Settings Save includes provider + volcengineAppID fields | ✅ code-static (SettingsView.swift:201-209) |
| EP21 | Settings `onReceive` sync covers all 5 ASR fields + provider | ✅ code-static (SettingsView.swift:166-178) |
| EP22 | About card reads live `provider.displayName` | ✅ code-static (SettingsView.swift:155) |
| EP23 | Draft apiKey preserved across provider switches | ✅ code-static (SettingsView.swift:263-275, only baseURL/model snap) |

### Runtime (device only)

| # | Check | Status |
|---|-------|--------|
| EP24 | OpenAI ASR dictation → transcription → commit works on device | 📱 device |
| EP25 | Aliyun ASR dictation → WebSocket streaming → transcription works on device | 📱 device |
| EP26 | Volcengine ASR dictation → WebSocket streaming → transcription works on device | 📱 device |
| EP27 | Keyboard shows "Volcengine App ID not configured" error when App ID empty | 📱 device |
| EP28 | Provider switch preserves apiKey across all 3 providers | 📱 device |
| EP29 | Verify button shows green Verified (OpenAI/Aliyun) vs gray Configured (Volcengine) | 📱 device |

---

### How to Report Back

1. **Zip the evidence directory** and share it
2. **Fill in the SUMMARY.md** with pass/fail for each scenario
3. **For each failure**: include the state observed, expected state, and any console error
4. **For each pass**: a single screenshot or recording is sufficient; mark done in the table
5. **Tag critical issues**: If any GO/NO-GO gate fails, flag it immediately — don't wait to finish all scenarios

### Time Estimate

| Item | Time |
|------|------|
| Setup | 10 min |
| S1-S7 (core flows) | 30 min |
| S8-S10 (edge cases) | 20 min |
| S11 (memory) | 15 min |
| S12 (stats) | 10 min |
| EP24-EP29 (provider runtime) | 30 min |
| Assembly + summary | 15 min |
| **Total** | **~130 min** |
