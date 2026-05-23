# VoicePi iOS Keyboard MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a keyboard-first iOS MVP for VoicePi that supports voice dictation, optional prompt-based refinement, five prompt profiles, and low-intrusion final text insertion.

**Architecture:** Treat this as a new iOS product, not a direct macOS port. Start with a vertical spike inside a keyboard extension to prove the runtime can survive audio capture, remote ASR preview, and final text commit. Only after the spike is stable should the team extract shared logic into a reusable core module and then add prompt refinement and host-app management flows.

**Tech Stack:** Swift, SwiftUI, UIKit keyboard extension APIs, AVFoundation, URLSession, App Groups `UserDefaults`, Xcode project targets, optional Swift Package for shared core logic

## Product Boundary

This plan assumes the agreed v1 product shape:

- `Keyboard-first`, not a macOS-equivalent system utility
- `Preview flows live`, but final text is inserted once
- `Five prompt profiles` managed in the host app
- `Remote ASR first`
- `Optional prompt refinement`
- `No local CLI processors`
- `No true streaming writes into the host text field`
- `No history browser in v1`

## Proposed Repository Layout

Create and keep this structure stable from the start:

- `ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj`
- `ios/VoicePiKeyboard/VoicePiApp/`
- `ios/VoicePiKeyboard/VoicePiKeyboardExtension/`
- `Packages/VoicePiCore/`
- `docs/plans/2026-04-30-voicepi-ios-keyboard-mvp-roadmap.md`

## Phase Exit Criteria

### Phase 0 Exit Criteria

- Keyboard extension launches reliably
- Recording can start and stop
- Remote ASR preview appears in the preview bar
- Final text can be inserted through `textDocumentProxy`
- Audio interruptions and host-context loss are observable and handled without frequent crashes
- Debug-only memory sentinel is available during spike work

### Phase 1 Exit Criteria

- Shared configuration is no longer hardcoded
- Host app can manage five profiles and write them through App Groups
- Keyboard extension can switch profiles and consume shared config
- A stable `VoicePiCore` module exists for shared clients and models

### Phase 2 Exit Criteria

- Prompt refinement is optional and profile-driven
- `Use Raw` fallback exists during refinement wait time
- Failure paths are explicit and non-destructive
- Dashboard shows successful committed text counts

## Implementation Tasks

### Task 1: Bootstrap The iOS Workspace

**Files:**
- Create: `ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj`
- Create: `ios/VoicePiKeyboard/VoicePiApp/`
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/`
- Modify: `README.md`
- Modify: `.gitignore`

**Step 1:** Create the Xcode project with two targets:
- `VoicePiApp`
- `VoicePiKeyboardExtension`

**Step 2:** Configure the extension target with App Group entitlements and microphone usage descriptions.

**Step 3:** Add repo-level README notes that this iOS workspace is keyboard-first and separate from the macOS app.

**Step 4:** Add build artifact ignores for the new Xcode workspace.

**Step 5:** Run:
- `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -list`

Expected: both app and extension targets appear.

### Task 2: Establish Shared App Group Configuration

**Files:**
- Create: `ios/VoicePiKeyboard/VoicePiApp/AppGroups/AppGroupIdentifiers.swift`
- Create: `ios/VoicePiKeyboard/VoicePiApp/AppGroups/SharedProfileDefaults.swift`
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/AppGroups/SharedProfileDefaults.swift`
- Test: `ios/VoicePiKeyboard/VoicePiAppTests/SharedProfileDefaultsTests.swift`

**Step 1:** Define one canonical App Group identifier and one canonical shared defaults suite name.

**Step 2:** Add storage models for:
- five prompt profile slots
- selected default profile
- remote ASR configuration
- refinement configuration

**Step 3:** Write tests that verify profile serialization and deserialization through App Group defaults.

**Step 4:** Run:
- `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiApp -destination 'platform=iOS Simulator,name=iPhone 16' test`

Expected: shared-config tests pass.

### Task 3: Build The Keyboard Vertical Spike Shell

**Files:**
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/KeyboardRootViewController.swift`
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/KeyboardRootView.swift`
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/KeyboardSessionController.swift`
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/PreviewBarView.swift`
- Test: `ios/VoicePiKeyboard/VoicePiKeyboardExtensionTests/KeyboardSessionControllerTests.swift`

**Step 1:** Create the extension root controller and mount a minimal SwiftUI keyboard shell.

**Step 2:** Implement a simple keyboard session state machine:
- `idle`
- `recording`
- `recognizing`
- `refining`
- `readyToCommit`
- `failed`

**Step 3:** Add a preview bar that can render:
- idle hint
- live ASR text
- refining state
- final pending commit state
- error state

**Step 4:** Add tests for state transitions before wiring real audio or networking.

**Step 5:** Run:
- `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiKeyboardExtension -destination 'platform=iOS Simulator,name=iPhone 16' test`

Expected: state-machine tests pass.

### Task 4: Prove Audio Capture And Interruption Handling

**Files:**
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/Audio/KeyboardAudioCapture.swift`
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/Audio/AudioInterruptionCoordinator.swift`
- Test: `ios/VoicePiKeyboard/VoicePiKeyboardExtensionTests/KeyboardAudioCaptureTests.swift`
- Test: `ios/VoicePiKeyboard/VoicePiKeyboardExtensionTests/AudioInterruptionCoordinatorTests.swift`

**Step 1:** Configure `AVAudioSession` for the extension runtime and document the chosen category/options inline.

**Step 2:** Capture audio frames without buffering unbounded PCM in memory.

**Step 3:** Handle interruption notifications:
- incoming call
- route change
- competing audio session

**Step 4:** Add tests for interruption state transitions and cleanup behavior.

**Step 5:** Run:
- `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiKeyboardExtension -destination 'platform=iOS Simulator,name=iPhone 16' test`

Expected: audio-state tests pass and no unbounded buffer design remains.

### Task 5: Prove Remote ASR Preview And Final Commit

**Files:**
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/ASR/RemoteASRStreamAdapter.swift`
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/Text/KeyboardTextCommitter.swift`
- Create: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/Debug/KeyboardDebugOverlay.swift`
- Test: `ios/VoicePiKeyboard/VoicePiKeyboardExtensionTests/RemoteASRStreamAdapterTests.swift`
- Test: `ios/VoicePiKeyboard/VoicePiKeyboardExtensionTests/KeyboardTextCommitterTests.swift`

**Step 1:** Stream captured audio to remote ASR and surface partial text into the preview bar.

**Step 2:** Commit final text once through `textDocumentProxy`.

**Step 3:** Add fallback behavior for:
- ASR request failure
- lost host context
- commit failure

**Step 4:** Add a debug-only memory sentinel that exposes current RSS and state while the spike is under validation.

**Step 5:** Run:
- `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiKeyboardExtension -destination 'platform=iOS Simulator,name=iPhone 16' test`

Expected: preview/commit tests pass and debug overlay can be enabled in local builds.

### Task 6: Validate The Spike In Real Host Contexts

**Files:**
- Create: `docs/plans/ios-keyboard-spike-validation-notes.md`
- Modify: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/Debug/KeyboardDebugOverlay.swift`

**Step 1:** Run the extension in at least these host environments:
- Safari web text field
- Chrome web text field
- one chat-style app with a custom input field

**Step 2:** Record the observed behavior for:
- focus retention
- text commit correctness
- interruption recovery
- memory growth during 60-second capture

**Step 3:** Write the findings into the validation notes file.

**Step 4:** Treat Phase 0 as blocked if the extension cannot reliably survive the above environments.

### Task 7: Extract Shared Core After The Spike Is Proven

**Files:**
- Create: `Packages/VoicePiCore/Package.swift`
- Create: `Packages/VoicePiCore/Sources/VoicePiCore/ProfileModels/`
- Create: `Packages/VoicePiCore/Sources/VoicePiCore/Clients/`
- Create: `Packages/VoicePiCore/Sources/VoicePiCore/Storage/`
- Create: `Packages/VoicePiCore/Tests/VoicePiCoreTests/`

**Step 1:** Move only validated shared logic into `VoicePiCore`:
- profile models
- remote ASR client
- refinement client contract
- shared config models
- App Group config access

**Step 2:** Do not move keyboard-specific UI state or `AVAudioSession` orchestration into the package.

**Step 3:** Add unit tests for model serialization, config access, and network request shaping.

**Step 4:** Run:
- `swift test --package-path Packages/VoicePiCore`

Expected: shared package tests pass.

### Task 8: Build The Host App Management Surface

**Files:**
- Create: `ios/VoicePiKeyboard/VoicePiApp/Onboarding/`
- Create: `ios/VoicePiKeyboard/VoicePiApp/Profiles/`
- Create: `ios/VoicePiKeyboard/VoicePiApp/Settings/`
- Create: `ios/VoicePiKeyboard/VoicePiApp/Usage/`
- Test: `ios/VoicePiKeyboard/VoicePiAppTests/ProfileManagerViewModelTests.swift`

**Step 1:** Build onboarding screens for:
- microphone permission
- full access enablement
- network/privacy explanation

**Step 2:** Build five fixed profile slots with:
- name
- prompt body
- default profile selection

**Step 3:** Build ASR configuration screens:
- provider
- base URL
- API key
- model

**Step 4:** Build a minimal usage dashboard with one metric:
- successful committed text count

**Step 5:** Run:
- `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiApp -destination 'platform=iOS Simulator,name=iPhone 16' test`

Expected: host-app view-model tests pass.

### Task 9: Wire Keyboard Profile Switching

**Files:**
- Modify: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/KeyboardRootView.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/KeyboardSessionController.swift`
- Test: `ios/VoicePiKeyboard/VoicePiKeyboardExtensionTests/ProfileSelectionTests.swift`

**Step 1:** Add a lightweight five-slot profile switcher to the keyboard UI.

**Step 2:** Ensure the selected profile changes the refinement request configuration, not the raw ASR transport.

**Step 3:** Keep v1 interaction simple:
- `tap to start`
- `tap to stop`
- `tap to switch profile`

**Step 4:** Explicitly defer long-press and drag gestures to v1.1.

**Step 5:** Run:
- `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiKeyboardExtension -destination 'platform=iOS Simulator,name=iPhone 16' test`

Expected: profile-selection tests pass.

### Task 10: Add Prompt Refinement With Raw Fallback

**Files:**
- Modify: `Packages/VoicePiCore/Sources/VoicePiCore/Clients/RefinementClient.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/KeyboardSessionController.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/PreviewBarView.swift`
- Test: `ios/VoicePiKeyboard/VoicePiKeyboardExtensionTests/RefinementFlowTests.swift`

**Step 1:** After ASR finalization, optionally run refinement for the selected profile.

**Step 2:** Show `Refining…` inside the preview bar rather than blocking silently.

**Step 3:** Add a `Use Raw` fallback so users can bypass the wait and commit the ASR result directly.

**Step 4:** Add a short final commit window before automatic insertion.

**Step 5:** Run:
- `swift test --package-path Packages/VoicePiCore`
- `xcodebuild -project ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj -scheme VoicePiKeyboardExtension -destination 'platform=iOS Simulator,name=iPhone 16' test`

Expected: refinement flow tests pass.

### Task 11: Stabilize Error Handling And Final UX

**Files:**
- Modify: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/PreviewBarView.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiKeyboardExtension/KeyboardSessionController.swift`
- Modify: `ios/VoicePiKeyboard/VoicePiApp/Onboarding/`
- Modify: `docs/plans/ios-keyboard-spike-validation-notes.md`

**Step 1:** Add user-facing error states for:
- no full access
- missing microphone permission
- unreachable ASR endpoint
- invalid credentials
- failed commit

**Step 2:** Tune the preview-to-commit timing and make cancel behavior explicit.

**Step 3:** Re-run the host-environment validation from Phase 0 after refinement is in place.

**Step 4:** Update onboarding copy if the validation shows recurring user confusion.

## Rough Schedule

- `Phase 0`: 1-2 weeks
- `Phase 1`: 1-2 weeks
- `Phase 2`: 1-2 weeks
- `Stabilization`: ~1 week

Working estimate:

- `4-7 weeks` for one experienced iOS engineer
- longer if Phase 0 exposes severe keyboard-extension runtime constraints

## Non-Goals For v1

- Local `SFSpeechRecognizer` path
- More than five prompt profiles
- Keyboard-side history browsing
- True streaming writes into the host input field
- Complex gestures like long-press profile scrubbing
- Local CLI processors

## Definition Of Success

- The keyboard extension survives real host environments
- Users can see live ASR progress without intrusive text churn in the host field
- Final text can be inserted once, reliably
- Prompt refinement is optional and does not block raw submission
- The host app manages five profiles, onboarding, and basic usage stats
