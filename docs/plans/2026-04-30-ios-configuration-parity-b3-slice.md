# B3 Configuration Parity Slice (Before-Starting)

> **Scope:** Expose baseURL + model in iOS UI; expand schema with ASR prompt + enableThinking
> **Precedes from:** B2 (structural alignment + Settings tab)
> **Date:** 2026-04-30

---

## 1. Gap Analysis

### Shared schema already supports — UI doesn't expose

The `VoicePiCore` schema (`ASRConfig` / `RefinementConfig`) already has `baseURL` and `model` as stored fields. The iOS UI hardcodes them and never writes them to `SharedProfileDefaults`.

| Field | In VoicePiCore schema? | In iOS UI? | macOS equivalent |
|-------|----------------------|------------|-----------------|
| `asrConfig.baseURL` | ✅ `String` | ❌ Hardcoded `"https://api.openai.com"` in 4 places | `RemoteASRConfiguration.baseURL` — text field |
| `asrConfig.model` | ✅ `String` | ❌ Hardcoded `"whisper-1"` in 2 places | `RemoteASRConfiguration.model` — text field |
| `refinementConfig.baseURL` | ✅ `String` | ❌ Hardcoded `"https://api.openai.com"` in 4 places | `LLMConfiguration.baseURL` — text field |
| `refinementConfig.model` | ✅ `String` | ❌ Hardcoded `"gpt-4o-mini"` in 2 places | `LLMConfiguration.model` — text field |
| `asrConfig.provider` | ✅ `String` | ❌ Hardcoded `"openai"` | `RemoteASRProvider` popup — defer (only OpenAI on iOS) |

### macOS has — iOS schema doesn't

| Field | macOS source | iOS treatment |
|-------|-------------|--------------|
| `prompt` (ASR bias hints) | `RemoteASRConfiguration.prompt` — text field in ASR section | **B3: add to ASRConfig** |
| `enableThinking` | `LLMConfiguration.enableThinking` (`enable_thinking`) — toggle in Text tab | **B3: add to RefinementConfig** |
| `volcengineAppID` | `RemoteASRConfiguration.volcengineAppID` — conditional field | **Defer** — Volcengine-specific, no iOS backend |
| Post-processing mode | Popup (disabled/refinement/translation) | **Defer** — macOS-only feature |
| Translation provider + target language | Popups | **Defer** — macOS-only feature |
| Prompt workspace (edit/new/bind/delete) | Full prompt management UI | **Defer** — `PromptBindingActions` is macOS-only |
| ASR backend mode (Local/Remote cards) | Card selector | **Defer** — iOS only supports remote |

---

## 2. Scope Lock

### In B3

| Change | Type | Why |
|--------|------|-----|
| Expose `baseURL` field for ASR + Refinement | Fill existing schema | Schema already stores it; UI just needs a text field |
| Expose `model` field for ASR + Refinement | Fill existing schema | Schema already stores it; UI just needs a text field |
| Add `prompt` to `ASRConfig` | Schema expansion | macOS has `RemoteASRConfiguration.prompt` for ASR bias hints |
| Add `enableThinking` to `RefinementConfig` | Schema expansion | macOS has `LLMConfiguration.enableThinking` toggle |
| Expose `prompt` field in UI (optional, ASR only) | New UI | Matches macOS "Optional add-on hints" field |
| Expose `enableThinking` toggle in UI (Refinement only) | New UI | Matches macOS thinking toggle |
| Verify flow uses configured baseURL/model (not hardcoded) | Fix | Existing verify methods hardcode these |
| Onboarding and Settings stay consistent | Constraint | Same fields, same save semantics, same draft discipline |
| Read existing values from SharedProfileDefaults on load | Fix | `saveAndComplete()` only writes apiKey today; baseURL/model stay at defaults |

### Out of B3

| Feature | Why deferred |
|---------|-------------|
| Provider selector (OpenAI / Aliyun / Volcengine) | Only OpenAI supported on iOS; adding a popup with 1 option is noise |
| Volcengine App ID field | No Volcengine backend on iOS |
| Post-processing mode selector | macOS-only feature; no translation/refinement routing on iOS |
| Translation config | macOS-only feature |
| Prompt workspace (new/edit/bind) | `PromptBindingActions` is macOS-only |
| ASR backend mode cards (Local/Remote) | iOS only supports remote |

---

## 3. Files to Change

### Schema changes (VoicePiCore)

| File | Changes |
|------|---------|
| `Packages/VoicePiCore/Sources/VoicePiCore/ProfileModels/ProfileModels.swift` | Add `prompt: String` to `ASRConfig`; add `enableThinking: Bool` to `RefinementConfig` |

### UI changes (VoicePiApp)

| File | Changes |
|------|---------|
| `VoicePiApp/Sources/OnboardingView.swift` | Add baseURL + model fields in both API config sections; add optional ASR prompt field; verify methods use field values (not hardcoded); `saveAndComplete()` writes all fields |
| `VoicePiApp/Sources/SettingsView.swift` | Add baseURL + model fields; add ASR prompt field; add enableThinking toggle; verify methods use draft values; save writes all fields |

### No changes

| File | Reason |
|------|--------|
| `VoicePiComponents.swift` | No new components needed — existing `VoicePiAPIConfigSection` wraps key+verify, new fields are plain `TextField`s |
| `VoicePiVerifyButton.swift` | `VoicePiAPIConfigSection` unchanged — new fields sit outside the section |
| `ProfileManagementView.swift` | Unchanged — Settings tab already wired |
| Keyboard extension files | Unchanged |

---

## 4. UX Layout

### OnboardingView — each API section expands to:

```
┌─────────────────────────────────────┐
│  VoicePiCard                        │
│                                     │
│  Speech Recognition (ASR)           │  ← section header
│  Model: Whisper-1                   │
│                                     │
│  API Base URL                       │  ← NEW TextField
│  ┌─────────────────────────────┐    │
│  │ https://api.openai.com      │    │
│  └─────────────────────────────┘    │
│                                     │
│  Model                             │  ← NEW TextField
│  ┌─────────────────────────────┐    │
│  │ whisper-1                   │    │
│  └─────────────────────────────┘    │
│                                     │
│  API Key                           │  ← existing SecureField
│  ┌─────────────────────────────┐    │
│  │ ••••••••••••••••           │    │
│  └─────────────────────────────┘    │
│                                     │
│  Prompt (optional)                 │  ← NEW TextField
│  ┌─────────────────────────────┐    │
│  │ Add-on hints for ASR bias   │    │
│  └─────────────────────────────┘    │
│                                     │
│  [Verify]   ● unverified            │  ← existing
└─────────────────────────────────────┘
```

### SettingsView — existing sections expand with same fields:

```
Same fields as onboarding, plus:
- Refinement section gains enableThinking toggle
- All fields use draft discipline (B2 fix): local @State + explicit Save
```

### enableThinking toggle placement:

In the Refinement config section, between the refinement toggle and the key field:

```
┌─────────────────────────────────────┐
│  Text Refinement                    │
│  [Enable Refinement ●━━━━━○]        │  ← existing
│                                     │
│  [Enable Thinking ●━━━━━○]          │  ← NEW
│   When enabled, the model uses      │
│   extended reasoning for complex    │
│   disfluency patterns.              │
└─────────────────────────────────────┘
```

---

## 5. Schema Expansion Detail

### ASRConfig change

```swift
// Before
public struct ASRConfig: Codable, Sendable {
    public var provider: String
    public var baseURL: String
    public var apiKey: String
    public var model: String
}

// After — add one field
public struct ASRConfig: Codable, Sendable {
    public var provider: String
    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var prompt: String   // ← NEW: optional ASR bias hints (default "")
}
```

Backward compatible: `Codable` with new optional field defaulting to `""`.

### RefinementConfig change

```swift
// Before
public struct RefinementConfig: Codable, Sendable {
    public var provider: String
    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var enabled: Bool
    public var autoCommitDelaySeconds: Double
}

// After — add one field
public struct RefinementConfig: Codable, Sendable {
    public var provider: String
    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var enabled: Bool
    public var autoCommitDelaySeconds: Double
    public var enableThinking: Bool  // ← NEW: matches macOS enable_thinking (default false)
}
```

Backward compatible: `Codable` with new optional field defaulting to `false`.

---

## 6. Onboarding / Settings Consistency

Both views use **identical field sets and save semantics**:

| Aspect | OnboardingView | SettingsView |
|--------|---------------|-------------|
| baseURL field | TextField, loaded from defaults | TextField, draft + Save |
| model field | TextField, loaded from defaults | TextField, draft + Save |
| apiKey field | SecureField | SecureField, draft + Save |
| prompt field (ASR only) | TextField, loaded from defaults | TextField, draft + Save |
| enableThinking toggle | N/A (in onboarding, refinement is optional/advanced) | Toggle, immediate write |
| Verify | Uses field values (not hardcoded) | Uses draft values |
| Save | `saveAndComplete()` writes all fields | Explicit Save button per dirty section |

Onboarding is "setup" (one-shot, save on complete). Settings is "persistent" (draft + explicit commit). Both write to the same `SharedProfileDefaults` keys.

---

## 7. Build Verification

```bash
cd /Users/pi-dal/Developer/VoicePi && swift build --package-path Packages/VoicePiCore
cd ios/VoicePiKeyboard && xcodegen generate
xcodebuild -project VoicePiKeyboard.xcodeproj -scheme VoicePiApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Smoke checklist

1. Onboarding: ASR section shows baseURL, model, API key, prompt fields
2. Onboarding: Refinement section shows baseURL, model, API key fields
3. Onboarding: Verify uses typed baseURL/model (not hardcoded)
4. Onboarding: Save writes all fields to SharedProfileDefaults
5. Settings: all fields load from SharedProfileDefaults on appear
6. Settings: drafts write on explicit Save only (B2 discipline maintained)
7. Settings: enableThinking toggle visible in Refinement section
8. App cold restart: all fields survive (read from defaults)
9. Dark mode: all new fields adapt
10. Keyboard extension: zero changes, build not affected
