# iOS ASR Provider Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add real iOS ASR provider support for OpenAI-compatible, Aliyun ASR, and Volcengine ASR instead of only exposing OpenAI-compatible fields.

**Architecture:** Keep the current keyboard-first iOS MVP boundary, but extend only the ASR path. Do not add fake provider UI before the keyboard runtime can actually consume it. Treat refinement as a separate concern; this plan does not add Aliyun/Volcengine refinement providers.

**Tech Stack:** Swift, SwiftUI, XcodeGen, VoicePiCore package, iOS keyboard extension, shared App Group defaults.

## Scope Lock

### In Scope
- ASR provider selection on iOS Host App.
- Shared config support for ASR provider-specific fields needed by keyboard runtime.
- Keyboard runtime branching based on ASR provider.
- Real Aliyun / Volcengine ASR request path support in iOS runtime.
- Verify flow branching by selected ASR provider.

### Out of Scope
- Refinement provider selector.
- Aliyun / Volcengine LLM/refinement support.
- Generic “all advanced settings parity” claim.
- Prompt workspace, translation, post-processing, or macOS-only text pipeline controls.

## Known Constraints

- Current iOS Host App only exposes runtime-backed OpenAI-compatible ASR/refinement fields.
- Current iOS keyboard ASR path is implemented in `Packages/VoicePiCore/Sources/VoicePiCore/Clients/ASRClient.swift` and is not provider-aware.
- macOS already has provider/back-end logic and provider-specific ASR adapters under `Sources/VoicePi/Adapters/ASR/`.
- Volcengine support likely needs an extra stored field beyond the current iOS shared schema: `volcengineAppID`.
- Do not present provider options in UI until the keyboard runtime can actually consume them.

### Task 1: Define iOS ASR Provider Boundary

**Files:**
- Read: `Sources/VoicePi/Core/Models/AppModelLanguageAndProcessingTypes.swift`
- Read: `Sources/VoicePi/Adapters/ASR/RemoteASRClient.swift`
- Read: `Sources/VoicePi/Adapters/ASR/AliyunRealtimeASRStreamingClient.swift`
- Read: `Sources/VoicePi/Adapters/ASR/VolcengineRealtimeProtocol.swift`
- Modify: `docs/plans/2026-05-01-ios-asr-provider-parity-plan.md`

**Step 1: Confirm which macOS provider concepts map cleanly to iOS MVP**

Document:
- which ASR providers exist on macOS
- which ones are protocol-level, not just baseURL-level
- which extra fields are required per provider

**Step 2: Freeze the iOS v1 boundary**

Record these decisions:
- ASR only: `openai-compatible`, `aliyun`, `volcengine`
- refinement stays OpenAI-compatible only
- no refinement provider selector in this phase

### Task 2: Expand Shared Schema Only for Runtime-Needed ASR Fields

**Files:**
- Modify: `Packages/VoicePiCore/Sources/VoicePiCore/ProfileModels/ProfileModels.swift`
- Modify: `Packages/VoicePiCore/Tests/VoicePiCoreTests/VoicePiCoreTests.swift`

**Step 1: Add explicit ASR provider semantics**

Prefer:
- a constrained enum or clearly documented string domain for `asrConfig.provider`

**Step 2: Add provider-specific stored fields only if runtime needs them**

Likely:
- `asrConfig.volcengineAppID`

Do not add speculative fields.

**Step 3: Add backward-compatible decode defaults**

Verify older stored configs still decode to the existing OpenAI-compatible default.

### Task 3: Make VoicePiCore ASR Runtime Provider-Aware

**Files:**
- Modify: `Packages/VoicePiCore/Sources/VoicePiCore/Clients/ASRClient.swift`
- Create or port provider helpers under `Packages/VoicePiCore/Sources/VoicePiCore/Clients/`
- Read for reference:
  - `Sources/VoicePi/Adapters/ASR/RemoteASRClient.swift`
  - `Sources/VoicePi/Adapters/ASR/AliyunRealtimeASRStreamingClient.swift`
  - `Sources/VoicePi/Adapters/ASR/VolcengineRealtimeProtocol.swift`

**Step 1: Choose the iOS runtime shape**

Decide whether to:
- branch inside `ASRStream`, or
- introduce provider-specific ASR client types behind a common interface

**Step 2: Implement provider-specific request construction**

Requirements:
- OpenAI-compatible keeps current behavior
- Aliyun path uses actual Aliyun protocol semantics
- Volcengine path uses actual Volcengine protocol semantics plus App ID if required

**Step 3: Preserve iOS MVP output behavior**

Even if a provider client is streaming-capable internally, the public keyboard behavior can stay:
- record
- stop
- receive final text
- preview
- commit

### Task 4: Wire Keyboard Runtime to Provider-Aware ASR Config

**Files:**
- Modify: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/Sources/KeyboardRootViewController.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/Sources/KeyboardSessionController.swift`

**Step 1: Ensure session setup reads the full ASR provider config**

The keyboard should instantiate the correct ASR runtime path from `SharedProfileDefaults().sharedConfig.asrConfig`.

**Step 2: Add provider-aware config validation**

Examples:
- OpenAI-compatible requires baseURL/apiKey/model
- Volcengine may require App ID
- error states must stay explicit and user-visible

### Task 5: Add Host App ASR Provider UI

**Files:**
- Modify: `ios/VoicePiKeyboard/VoicePiApp/Sources/OnboardingView.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiApp/Sources/SettingsView.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiApp/Sources/VoicePiComponents.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiApp/Sources/ProfileManagementView.swift`

**Step 1: Add ASR provider selector**

Only after Task 3 and Task 4 compile.

**Step 2: Make fields dynamic by provider**

Examples:
- OpenAI-compatible: baseURL, model, apiKey
- Aliyun: provider-specific required fields
- Volcengine: include App ID if runtime requires it

**Step 3: Keep refinement settings unchanged**

Do not add a generic provider selector to refinement just to mirror the ASR UI.

### Task 6: Make Verify Flow Provider-Aware

**Files:**
- Modify: `Packages/VoicePiCore/Sources/VoicePiCore/Clients/APIVerificationClient.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiApp/Sources/OnboardingView.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiApp/Sources/SettingsView.swift`

**Step 1: Stop assuming OpenAI-compatible verify for all ASR providers**

Branch verify behavior by ASR provider.

**Step 2: Keep error reporting honest**

If a provider cannot be safely verified with the current lightweight probe shape, the UI must say that explicitly instead of returning fake success.

### Task 7: Verification

**Files:**
- Modify if needed: `docs/plans/ios-keyboard-runtime-validation-handoff.md`
- Modify if needed: `docs/plans/ios-keyboard-evidence-checklist.md`

**Step 1: Fresh build verification**

Run:
- `swift build --package-path Packages/VoicePiCore`
- `cd ios/VoicePiKeyboard && xcodegen generate`
- `xcodebuild -project VoicePiKeyboard.xcodeproj -scheme VoicePiApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`

**Step 2: Runtime validation matrix**

Minimum scenarios:
- OpenAI-compatible ASR still works
- Aliyun ASR config is selectable and saved
- Volcengine ASR config is selectable and saved
- keyboard runtime instantiates the expected provider path
- provider-specific missing-field errors are surfaced
- verify path does not claim success for unsupported probe shapes

## Recommended Slice Order

### Slice P1: Runtime Boundary + Shared Schema
- Task 1
- Task 2

### Slice P2: VoicePiCore + Keyboard Runtime
- Task 3
- Task 4

### Slice P3: Host App UI + Verify Branching
- Task 5
- Task 6

### Slice P4: Validation Evidence
- Task 7

## Acceptance Rule

Do not claim “macOS-style provider parity” until:
- the keyboard runtime can actually use the selected ASR provider
- the Host App can persist all runtime-required ASR fields
- verify behavior is provider-aware or explicitly marked unsupported

