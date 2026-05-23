# P4: Provider Parity Validation Evidence — Before-Start Slice

> Part of [iOS ASR Provider Parity Plan](./2026-05-01-ios-asr-provider-parity-plan.md)
> Depends on: P1 ✅, P2 ✅, P3 ✅ (all three slices closed)
> Gate: Cindy. Do NOT start implementation until this slice is approved.

## Goal

Produce compile-level validation evidence that the full ASR provider chain — VoicePiCore → keyboard runtime → Host App → verify flow — is wired correctly across all three providers. Then extend the existing handoff documents with ASR provider parity scenarios for device-based validation.

This is a **validation + handoff** slice. Zero new code. Zero new features. 100% evidence.

## What This Machine Can Actually Deliver

| Capability | Available? | Note |
|------------|-----------|------|
| `swift build` + `xcodegen` + `xcodebuild` | ✅ | CLT + Xcode 16 CLI tools |
| `swift test` (VoicePiCore) | ✅ | 16/19, 3 pre-existing App Group failures |
| Code-static path trace | ✅ | grep/diff across all provider-relevant files |
| Simulator launch (VoicePiApp) | ✅ | `xcodebuild` passes, but no interaction testing |
| iOS device deployment | ❌ | No physical device |
| Keyboard extension runtime | ❌ | No device, no Full Access entitlement, no code signing |
| Live endpoint ASR verify | ❌ | No API keys configured on this machine |
| Live WebSocket handshake | ❌ | Requires real Aliyun/Volcengine credentials + endpoint |

**Honesty rule (Cindy-enforced):** Every piece of evidence is tagged `✅ code-static` when verified by code inspection on this machine, `📱 device` when it requires a real iOS device. No `✅` for runtime evidence that hasn't been executed.

## Deliverables

### D1: Fresh Build Evidence (~10 min)

Run all 4 build stages from a clean slate and capture output with timestamps:

| # | Command | Expectation |
|---|---------|-------------|
| 1 | `swift build --package-path Packages/VoicePiCore` | 0 errors, 0 warnings |
| 2 | `swift test --package-path Packages/VoicePiCore` | 16 passed, 3 failed (pre-existing) |
| 3 | `xcodegen generate` (in `ios/VoicePiKeyboard`) | Project created |
| 4 | `xcodebuild -scheme VoicePiApp -sdk iphonesimulator` | BUILD SUCCEEDED, 2 pre-existing warnings |

Output will be captured inline in the completion report with UTC timestamps. This is the same evidence format as P1–P3 gates.

### D2: Code-Static Provider Path Audit (~20 min)

Systematically trace each provider from Host App config → VoicePiCore runtime → keyboard extension, verifying that every branch exists and is wired.

**Audit matrix (6 scenarios from master plan Task 7 Step 2):**

| # | Scenario | Audit Method | Evidence |
|---|----------|-------------|----------|
| S1 | OpenAI-compatible ASR path still works | Trace `ASRClient.startOpenAICompatibleStreaming()` → REST multipart path unchanged from Phase 0 | code-static |
| S2 | Aliyun ASR config is selectable and saved | Trace `OnboardingView.verifyASR()` → `ASRConfig.provider = .aliyun` → `saveAndComplete()` writes to App Group | code-static |
| S3 | Volcengine ASR config is selectable and saved | Same path for `.volcengine`, additionally trace `volcengineAppID` field through save/load | code-static |
| S4 | Keyboard runtime instantiates expected provider path | Trace `KeyboardRootViewController.startRecording()` → `KeyboardSessionController.checkConfig(asrProvider:volcengineAppID:)` → `ASRClient.startStreaming()` `switch config.provider` → correct streaming method | code-static |
| S5 | Provider-specific missing-field errors surfaced | Trace `checkConfig` for Volcengine App ID emptiness; trace `APIVerificationClient.validateVolcengine` → `isConfigured(for:)` gate → specific `.missingKey`/.network errors; trace Host App error badge states | code-static |
| S6 | Verify path doesn't claim success for unsupported probe shapes | Trace `APIVerificationClient.probeASR` → Volcengine `.configured` (not `.verified`); Aliyun HEAD to DashScope fixed endpoint; OpenAI HEAD to user baseURL | code-static |

Each scenario will map to specific file:line references with one-sentence verification of the code path.

**Files covered by the audit:**
- `VoicePiCore/Clients/ASRClient.swift` (33, 142, 214, 265)
- `VoicePiCore/Clients/APIVerificationClient.swift` (25-34, 57-67, 76-101)
- `VoicePiCore/Clients/AliyunRealtimeASRClient.swift` (connect + sendPCM16LEFrame)
- `VoicePiCore/Clients/VolcengineRealtimeASRClient.swift` (connect + sendPCM16LEFrame)
- `KeyboardSessionController.swift` (checkConfig provider params)
- `KeyboardRootViewController.swift` (startRecording provider pass-through)
- `OnboardingView.swift` (provider picker + verify + save)
- `SettingsView.swift` (provider picker + per-provider dirty + save)

### D3: Handoff Document Updates (~15 min)

Extend two existing handoff docs with ASR provider parity scenarios. These are **prepared but marked `📱 device`** — the recipient performs them.

**3a. `ios-keyboard-runtime-validation-handoff.md`**

Add provider-specific validation scenarios:

| Scenario | Description | Status |
|----------|-------------|--------|
| S12: OpenAI ASR end-to-end | Onboard with OpenAI provider → dictation → ASR → commit | 📱 device |
| S13: Aliyun ASR end-to-end | Select Aliyun provider in Settings → configure DashScope key → switch to keyboard → dictation → ASR → commit | 📱 device |
| S14: Volcengine ASR end-to-end | Select Volcengine provider → configure Access Key + App ID → dictation → ASR → commit | 📱 device |
| S15: Provider switch persistence | Configure OpenAI → switch to Aliyun → verify apiKey preserved (not lost on switch) → switch back → verify baseURL/model restored | 📱 device |
| S16: Provider missing-field error | Configure Volcengine with App ID empty → attempt dictation → verify "Volcengine App ID not configured" error | 📱 device |
| S17: Verify per-provider behavior | Verify OpenAI returns "Verified", Volcengine returns "Configured" (not "Verified"), missing-key returns red error | 📱 device |

**3b. `ios-keyboard-evidence-checklist.md`**

Add provider-specific check items under a new category "ASR Provider Parity":

| # | Check | Status |
|---|-------|--------|
| EP1 | `ASRProvider` enum with 3 cases exists in VoicePiCore | ✅ code-static |
| EP2 | `ASRConfig.volcengineAppID` field exists and is Codable | ✅ code-static |
| EP3 | Backward decode of old configs (no volcengineAppID) → "" | ✅ test-verified |
| EP4 | `isConfigured(for: .volcengine)` gate checks App ID | ✅ code-static |
| EP5 | `ASRClient.startStreaming()` branches on provider | ✅ code-static |
| EP6 | Aliyun streaming uses `Authorization: bearer` header | ✅ code-static |
| EP7 | Volcengine streaming uses HMAC-SHA256 + App ID | ✅ code-static |
| EP8 | Host App provider picker shows 3 options | ✅ code-static |
| EP9 | Host App field visibility responds to provider switch | ✅ code-static |
| EP10 | Onboarding per-provider gate (OpenAI: verified, Volcengine: configured) | ✅ code-static |
| EP11 | Volcengine verify returns `.configured` not `.verified` | ✅ code-static |
| EP12 | Settings draft behavior: apiKey preserved on switch | ✅ code-static |
| EP13 | Settings draft behavior: baseURL/model snap on switch | ✅ code-static |
| EP14 | Settings About card shows live provider displayName | ✅ code-static |
| EP15 | OpenAI ASR still works (dictation → text) | 📱 device |
| EP16 | Aliyun ASR works (WebSocket handshake → transcription) | 📱 device |
| EP17 | Volcengine ASR works (HMAC-signed WebSocket → transcription) | 📱 device |
| EP18 | Keyboard shows provider-specific error for missing field | 📱 device |

## Scope Boundaries

**In P4:**
- Fresh build evidence (4 stages, timestamps)
- Code-static provider-path audit (6 scenarios, file:line references)
- Handoff document updates (provider scenarios, marked 📱)
- Evidence checklist additions (18 checks, marked ✅/📱)

**Not in P4 (no new code):**
- No new .swift files
- No config changes
- No test additions
- No runtime execution

**Machine-honest boundary:**
- Everything tagged `✅ code-static` means: "code path inspected and verified on this machine"
- Everything tagged `📱 device` means: "prepared for device validation, not executed here"
- Nothing tagged `✅` for runtime behavior

## Acceptance

P4 is complete when:
1. All 4 build stages re-run fresh and pass
2. All 6 code-static scenarios traced with file:line references
3. Both handoff docs updated with provider scenarios
4. Evidence checklist extended with provider checks
5. Completion report sent to Cindy with all evidence inline

This slice does NOT claim provider runtime parity. It claims: **the code is wired, the build passes, and the handoff docs are ready for someone with a device.**
