# VoicePi iOS Keyboard — Release Readiness Checklist

> **For:** Release manager / person signing off the build
> **Last updated:** 2026-04-30
> **Status legend:**
> - ✅ `verified on this machine` — actually executed or code-inspected on this machine without requiring Xcode target build, code signing, or iOS device
> - ⬜ `prepared but not executed here` — code path exists and has been reviewed, but verification requires Xcode target build, code signing, or iOS compilation not available on this machine
> - 📱 `requires device/Xcode evidence` — only verifiable on a physical iOS device with full Xcode

---

## 1. Code Quality

### 1.1 Build & Compilation

| Check | Criterion | Status |
|-------|-----------|--------|
| `swift build` passes (VoicePiCore) | Zero errors, zero warnings — executed on this machine | ✅ verified on this machine |
| `xcodegen generate` succeeds | Produces valid `.xcodeproj` — executed on this machine | ✅ verified on this machine |
| Xcode build: VoicePiApp target | Zero errors on device SDK | 📱 requires device/Xcode evidence |
| Xcode build: VoicePiKeyboardExtension target | Zero errors on device SDK | 📱 requires device/Xcode evidence |
| Release configuration builds | iOS target release build never executed on this machine (no full Xcode); `#if DEBUG` guards code-inspected | ⬜ prepared but not executed here |
| All `#if DEBUG` guards correct | Guards present in source (code-inspected); release exclusion not verified via actual release build | ⬜ prepared but not executed here |

### 1.2 Static Analysis

| Check | Criterion | Status |
|-------|-----------|--------|
| No force-unwrap (`!`) in keyboard extension | Tolerates nil gracefully | ✅ verified on this machine |
| No reference cycles | All capture lists use `[weak self]` | ✅ verified on this machine |
| Sendable conformance | KeyboardSessionState is `Sendable` | ✅ verified on this machine |
| Thread safety | `@unchecked Sendable` on controller; generation counter in RefinementClient | ✅ verified on this machine |
| MainActor usage | All UI updates dispatched to `DispatchQueue.main` | ✅ verified on this machine |

---

## 2. Architecture & Design

### 2.1 State Machine

| Check | Criterion | Status |
|-------|-----------|--------|
| All 10 states reachable | idle, recording, recognizing, refining, readyToCommit, failed, permissionDenied, configMissing, commitFailed | ✅ verified on this machine |
| All transitions defined | No dead-end states; cancel → idle from all states | ✅ verified on this machine |
| Race condition: Use Raw vs late refinement callback | Generation counter gates both success and failure | ✅ verified on this machine |
| Race condition: Cancel during recognition | `cancel()` increments generation counter | ✅ verified on this machine |
| Commit failure preserves text | `reportCommitFailed` does not clear `finalizedText` | ✅ verified on this machine |
| Commit failure → retry restores state | `retryCommit()` → `.readyToCommit` with preserved text | ✅ verified on this machine |
| Commit failure → cancel clears state | Cancel from `.commitFailed` → idle with empty text | ✅ verified on this machine |

### 2.2 Data Flow

| Check | Criterion | Status |
|-------|-----------|--------|
| SharedDefaults single source of truth | `sharedConfig` is canonical; `incrementCommitCount`/`recordRecording` write through it | ✅ verified on this machine |
| API key read path | `SharedProfileDefaults().sharedConfig` → `asrConfig` / `refinementConfig` | ✅ verified on this machine |
| Keyboard extension reads host app config | Via App Group `UserDefaults(suiteName:)` | ✅ verified on this machine |
| Usage stats write from extension, read from app | Same App Group store | ✅ verified on this machine |
| No duplicate stat counting | `confirmCommit()` only called on success; `commitFailed` does not increment | ✅ verified on this machine |

### 2.3 Module Boundaries

| Check | Criterion | Status |
|-------|-----------|--------|
| VoicePiCore has no UIKit/AppKit imports | Pure Swift package, no platform UI | ✅ verified on this machine |
| VoicePiKeyboardExtension depends on VoicePiCore | Via SPM, no direct UIKit in Core | ✅ verified on this machine |
| VoicePiApp depends on VoicePiCore | Via SPM | ✅ verified on this machine |
| Extension binary size under 50MB limit | Keyboard extensions have Apple-imposed limits | 📱 requires device/Xcode evidence |

---

## 3. Security

### 3.1 API Key Handling

| Check | Criterion | Status |
|-------|-----------|--------|
| API keys stored in App Group UserDefaults | Not in plaintext files, not in Keychain (MVP acceptable) | ✅ verified on this machine |
| API keys never logged | No `print()` of key values in any code path | ✅ verified on this machine |
| Keyboard extension reads keys via shared suite | No direct user input of keys inside extension | ✅ verified on this machine |
| Config missing blocks recording | `checkConfig()` validates before `startRecording()` | ✅ verified on this machine |
| Invalid key → `.failed` state with error | Error message shown, no key exposed in UI | ✅ verified on this machine |

### 3.2 Network

| Check | Criterion | Status |
|-------|-----------|--------|
| HTTPS only | All API calls use HTTPS endpoints | ✅ verified on this machine |
| ATS compliance | No `NSAppTransportSecurity` exceptions | ✅ verified on this machine |
| No hardcoded secrets | API keys come from UserDefaults, not source code | ✅ verified on this machine |
| Request timeout | URLSession configured with reasonable timeout | ✅ verified on this machine |

---

## 4. Privacy

### 4.1 Microphone

| Check | Criterion | Status |
|-------|-----------|--------|
| Microphone permission requested before recording | `requestPermission()` called in `startRecording()` | ✅ verified on this machine |
| Denied → `.permissionDenied` state | Clear visual feedback, retry button returns to idle | ✅ verified on this machine |
| No recording without permission | `startRecording()` gated on granted | ✅ verified on this machine |
| Audio stops on interruption | `AudioInterruptionCoordinator` calls `cancel()` on begin | ⬜ prepared but not executed here |
| `NSMicrophoneUsageDescription` in Info.plist | Required by iOS for mic access | ✅ verified on this machine |

### 4.2 Data Handling

| Check | Criterion | Status |
|-------|-----------|--------|
| Audio data not persisted to disk | In-memory PCM buffer, sent to ASR API only | ✅ verified on this machine |
| Transcribed text not persisted beyond session | Text cleared on cancel/commit; only stats counters survive | ✅ verified on this machine |
| No analytics frameworks | No third-party analytics SDKs | ✅ verified on this machine |
| Usage stats local-only | Counters in shared UserDefaults, never sent off-device | ✅ verified on this machine |
| Privacy manifest (`PrivacyInfo.xcprivacy`) | Required for App Store submission (API usage declarations) | 📱 requires device/Xcode evidence |

---

## 5. Performance & Memory

### 5.1 Keyboard Memory Budget

| Check | Criterion | Status |
|-------|-----------|--------|
| Idle RSS under 30MB | Keyboard extensions are killed above ~40-50MB on most devices | 📱 requires device/Xcode evidence |
| Recording RSS under 50MB | Audio buffer + network should not spike unrecoverably | 📱 requires device/Xcode evidence |
| No monotonic RSS growth | Repeated record → commit cycles should not leak | 📱 requires device/Xcode evidence |
| MemorySentinel uses correct Mach API | `Mach.task_info.resident_size` wired in debug builds (code-inspected); RSS value accuracy requires device runtime | ⬜ prepared but not executed here |

### 5.2 Responsiveness

| Check | Criterion | Status |
|-------|-----------|--------|
| Mic tap → recording indicator visible < 500ms | Permission check + AVAudioEngine start | 📱 requires device/Xcode evidence |
| ASR response time acceptable | Depends on network + API; no local bottleneck | 📱 requires device/Xcode evidence |
| UI thread never blocked | All network calls async; no synchronous I/O on main thread (code-inspected); Instruments trace requires device | ✅ verified on this machine |
| State transitions use `withAnimation` | SwiftUI `withAnimation` used where appropriate (code-inspected); runtime smoothness requires device verification | ⬜ prepared but not executed here |

---

## 6. UI/UX

### 6.1 Visual Design

| Check | Criterion | Status |
|-------|-----------|--------|
| All states have distinct icons + colors | Gray idle, red recording, blue recognizing, orange refining, green ready, red failed, orange perms/config, red commitFailed | ✅ verified on this machine |
| Recording pulse animation | Red dot opacity oscillates during recording | ✅ verified on this machine |
| "Use Raw" button visible during refinement | Secondary action, orange styling | ✅ verified on this machine |
| Commit failed: retry + cancel buttons | Both visible, distinct styling | ✅ verified on this machine |
| Error hints descriptive | "ASR API key not configured", "Mic access denied", "Commit failed: No text field" | ✅ verified on this machine |

### 6.2 Accessibility

| Check | Criterion | Status |
|-------|-----------|--------|
| Minimum touch target 44×44pt | All buttons meet Apple HIG minimum | ⬜ prepared but not executed here |
| VoiceOver labels on all buttons | Icons need accessibility labels | ⬜ prepared but not executed here |
| Dynamic Type support | Fonts scale with system setting | ⬜ prepared but not executed here |
| High contrast / color blind safe | States distinguishable beyond color alone (icons) | ✅ verified on this machine |

### 6.3 Dark Mode

| Check | Criterion | Status |
|-------|-----------|--------|
| All backgrounds use semantic colors | `Color(.systemBackground)`, not hardcoded white | ✅ verified on this machine |
| Text uses `primary`/`secondary` semantic colors | Adapts to dark mode automatically | ✅ verified on this machine |
| Debug panel uses semantic colors | Uses `systemGray6` background (code-inspected); actual dark mode readability requires visual verification on device | ⬜ prepared but not executed here |

---

## 7. Configuration & Entitlements

### 7.1 App Groups

| Check | Criterion | Status |
|-------|-----------|--------|
| `com.apple.security.application-groups` on both targets | VoicePiApp and VoicePiKeyboardExtension | ✅ verified on this machine |
| Group ID: `group.com.voicepi.shared` | Consistent across both `.entitlements` files | ✅ verified on this machine |
| UserDefaults suite matches | `UserDefaults(suiteName: "group.com.voicepi.shared")` | ✅ verified on this machine |

### 7.2 Keyboard Extension

| Check | Criterion | Status |
|-------|-----------|--------|
| `RequestsOpenAccess` in Info.plist | Required for mic + network access in keyboard | ✅ verified on this machine |
| `NSExtensionPrincipalClass` set correctly | Points to `KeyboardRootViewController` | ✅ verified on this machine |
| `CFBundleDisplayName` = `VoicePi` | User-visible name in keyboard list | ✅ verified on this machine |

### 7.3 Host App

| Check | Criterion | Status |
|-------|-----------|--------|
| Onboarding wizard: 3 steps | API key entry → mic permission → keyboard setup instructions | ⬜ prepared but not executed here |
| Usage tab: commit count + recording stats | Reads from shared UserDefaults | ✅ verified on this machine |
| Profile tab: API key management | Create/edit/delete API key config | ⬜ prepared but not executed here |
| Settings tab: refinement toggle | Enable/disable refinement with separate API key | ⬜ prepared but not executed here |

---

## 8. Error Handling

### 8.1 Recovery Paths

| Check | Criterion | Status |
|-------|-----------|--------|
| ASR failure → retry to idle | `.failed` → tap retry → `.idle` | ✅ verified on this machine |
| Permission denied → retry to idle | `.permissionDenied` → tap retry → `.idle` | ✅ verified on this machine |
| Config missing → retry to idle | `.configMissing` → tap retry → `.idle` | ✅ verified on this machine |
| Commit failed → retry to readyToCommit | `.commitFailed` → tap retry → `.readyToCommit(text preserved)` | ✅ verified on this machine |
| Commit failed → cancel to idle | `.commitFailed` → tap cancel → `.idle(text cleared)` | ✅ verified on this machine |
| Recording cancel → idle (partial stats recorded) | Duration recorded to stats before clearing | ✅ verified on this machine |
| Refinement failure → raw fallback | Failed refinement → `.readyToCommit(rawText)` | ✅ verified on this machine |
| Audio interruption → cancel → idle | Interruption begin → audio stopped → state idle | ⬜ prepared but not executed here |

### 8.2 User Feedback

| Check | Criterion | Status |
|-------|-----------|--------|
| Errors never silent | All error states have visible UI (icon + hint + action) | ✅ verified on this machine |
| Error messages user-appropriate | "Commit failed: No text field" not "proxy nil" | ✅ verified on this machine |
| No crash on unexpected input | Empty audio, network timeout, invalid API response all handled | ⬜ prepared but not executed here |

---

## 9. App Store Readiness (MVP)

| Check | Criterion | Status |
|-------|-----------|--------|
| App icon present for both targets | 1024×1024 for App Store + all required sizes | 📱 requires device/Xcode evidence |
| Launch screen / storyboard | Required for app submission | ⬜ prepared but not executed here |
| Privacy labels in App Store Connect | Declare mic + network data usage | 📱 requires device/Xcode evidence |
| No private API usage | No UIKit/AVFoundation private selectors | ✅ verified on this machine |
| Minimum deployment target ≥ iOS 17.0 | Matches `IPHONEOS_DEPLOYMENT_TARGET` | ✅ verified on this machine |
| `PrivacyInfo.xcprivacy` includes mic + network | Required by Apple for apps using these APIs | 📱 requires device/Xcode evidence |

---

## 10. Summary

| Category | ✅ verified on this machine | ⬜ prepared, not executed | 📱 requires device/Xcode |
|----------|---------------------------|--------------------------|--------------------------|
| Code Quality (11) | 7 | 2 | 2 |
| Architecture & Design (16) | 15 | 0 | 1 |
| Security (9) | 9 | 0 | 0 |
| Privacy (10) | 8 | 1 | 1 |
| Performance & Memory (8) | 1 | 2 | 5 |
| UI/UX (12) | 8 | 4 | 0 |
| Config & Entitlements (9) | 6 | 3 | 0 |
| Error Handling (11) | 9 | 2 | 0 |
| App Store Readiness (6) | 2 | 1 | 3 |
| **Total (92)** | **65** | **15** | **12** |

### Go/No-Go Gates

| Gate | Criterion | Status |
|------|-----------|--------|
| G1: Build passes on physical device | Xcode build → device, both targets | 📱 |
| G2: S1 (Basic Dictation) passes | End-to-end: mic → ASR → commit → text appears | 📱 |
| G3: S7 (Commit Failure Recovery) passes | Commit fails → retry → commit succeeds | 📱 |
| G4: No unbounded memory growth | 10-cycle record/commit loop, RSS stays under limits | 📱 |
| G5: Dark mode + accessibility review | All states readable, buttons reachable | 📱 |
| G6: Privacy labels + manifest complete | App Store Connect ready | 📱 |
