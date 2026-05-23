# B1 Before-Starting Slice

> **Scope locked:** VoicePiTheme tokens + OnboardingView alignment + API Verify flow
> **Hard constraints:** ProfileManagementView visual-only. No UI presentation in VoicePiCore.
> **Date:** 2026-04-30

---

## 1. Files to Change

### New files

| File | Purpose |
|------|---------|
| `VoicePiApp/Sources/VoicePiTheme.swift` | Color palette, surface styles (card/pill/row), button styles (primary/secondary), typography scale — SwiftUI-native port of `SettingsWindowTheme` |
| `VoicePiApp/Sources/VoicePiComponents.swift` | `VoicePiPrimaryButton`, `VoicePiSecondaryButton`, `VoicePiCard`, `VoicePiPill` — reusable styled views |
| `VoicePiApp/Sources/VoicePiVerifyButton.swift` | Verify button + `VoicePiVerificationBadge` — triggers probe, shows 4-state feedback |
| `VoicePiCore/Sources/VoicePiCore/Clients/APIVerificationClient.swift` | Headless probe client: `probeASR(key:)` / `probeRefinement(key:)` → lightweight HTTP test |
| `VoicePiCore/Sources/VoicePiCore/Models/VerificationModels.swift` | `VerificationState` enum (unverified/verifying/verified/failed), `VerificationError`, result mapper |

### Modified files

| File | Changes |
|------|---------|
| `VoicePiApp/Sources/OnboardingView.swift` | Replace page-swipe with scrollable section layout; apply VoicePiTheme; add Verify buttons per API key; gate completion on ASR verified |
| `VoicePiApp/Sources/ProfileManagementView.swift` | Visual-only: apply VoicePi colors/surfaces/buttons; no structural changes |
| `VoicePiApp/Sources/VoicePiAppApp.swift` | Inject `accentColor` from VoicePiTheme |
| `VoicePiKeyboard/VoicePiKeyboardExtension/Sources/PreviewBarView.swift` | **No changes in B1** |

---

## 2. Verify Flow Wiring

```
┌─────────────────────────────────────────────────────┐
│ OnboardingView                                      │
│                                                     │
│  ┌──────────────────────────────────────┐           │
│  │ ASR Configuration              [Card]│           │
│  │  ┌────────────────────────────┐      │           │
│  │  │ API Key: [sk-xxx       ]   │      │           │
│  │  │ Model:   Whisper-1         │      │           │
│  │  └────────────────────────────┘      │           │
│  │  [Verify]  ← VoicePiVerifyButton    │           │
│  │  ● unverified / ◌ verifying… /      │           │
│  │  ✓ verified  / ✗ failed: <msg>      │           │
│  │  └─ VoicePiVerificationBadge ─┘      │           │
│  └──────────────────────────────────────┘           │
│                                                     │
│  ┌──────────────────────────────────────┐           │
│  │ Refinement Configuration       [Card]│           │
│  │  ... same pattern as above ...       │           │
│  └──────────────────────────────────────┘           │
│                                                     │
│  [Save & Complete]  ← disabled until ASR .verified  │
└─────────────────────────────────────────────────────┘

Data flow:
  OnboardingView
    → VoicePiVerifyButton.onVerify
      → APIVerificationClient.probeASR(key:)  [in VoicePiCore]
        → HTTP probe to ASR endpoint
        → Result<Bool, VerificationError>
      → map to VerificationState
    → VoicePiVerificationBadge observes state
    → OnboardingView observes badge → enables Save button
```

**VoicePiCore boundary (headless only):**
```
VerificationModels.swift:
  enum VerificationState { case unverified, verifying, verified, failed(VerificationError) }
  struct VerificationError: Error { let message: String }

APIVerificationClient.swift:
  func probeASR(key: String) async -> Result<Void, VerificationError>
  func probeRefinement(key: String) async -> Result<Void, VerificationError>
```

**VoicePiApp layer (UI mapping, NOT in Core):**
```
VoicePiVerifyButton:
  - Maps VerificationState → icon (circle / ProgressView / checkmark.circle.fill / xmark.octagon.fill)
  - Maps VerificationState → color (gray / blue / green / red)
  - Maps VerificationError → user-friendly text

VoicePiVerificationBadge:
  - Inline label showing current verification status
  - Matches ConnectionFeedbackView pattern from macOS
```

---

## 3. Explicitly NOT in B1 (→ B2)

| Item | Why deferred |
|------|-------------|
| ProfileManagementView structural changes | Tab navigation, rich sections, chart cards → B2 |
| Prompt binding actions on iOS | New UX, needs design → B2 |
| Usage dashboard enrichment | Chart cards, export → B2 |
| Confetti celebration on verify success | Polish → B2 |
| Keyboard extension visual alignment | Scope creep → Plan C |
| Navigation sidebar (iPad) | Platform decision → B2 |
| Settings tab with collapsible sections | Information architecture → B2 |
| `ConnectionFeedbackPresentation` in VoicePiCore | Cindy's constraint — UI models stay in app layer |

---

## 4. Simulator Verification

**Pre-build checks (this machine):**
```bash
cd ios/VoicePiKeyboard
swift build --package-path ../../Packages/VoicePiCore   # Core compiles
swift build --target VoicePiCore                        # Alternative if Package.swift aligned
```

**Simulator build (this machine has full Xcode):**
```bash
cd ios/VoicePiKeyboard && xcodegen generate
xcodebuild -project VoicePiKeyboard.xcodeproj -scheme VoicePiApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```
(If iPhone 16 runtime not available, substitute `name=iPhone 16` with a simulator runtime present on this machine.)

**Smoke test checklist (simulator):**
1. App launches → themed onboarding (cream bg, green accents, not blue)
2. API key fields have `Verify` buttons next to them
3. Tap `Verify` with valid key → badge shows `verifying…` → `verified ✓`
4. Tap `Verify` with invalid key → badge shows `failed ✗` with message
5. `Save & Complete` disabled when ASR unverified
6. After ASR verified → `Save & Complete` enabled → completes onboarding
7. ProfileManagementView shows themed colors/surfaces (no structural changes)
8. Dark mode: toggle simulator appearance → colors switch to dark palette

**Regression check:**
- `swift build` on VoicePiCore still passes (no breakage)
- `xcodegen generate` still produces valid project
- Keyboard extension not affected (no files touched)
