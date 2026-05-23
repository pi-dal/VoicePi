# P1: Runtime Boundary + Shared Schema — Before-Start Slice

> Part of [iOS ASR Provider Parity Plan](./2026-05-01-ios-asr-provider-parity-plan.md)
> Gate: Cindy. Do NOT start implementation until this slice is approved.

## Goal

Expand `ASRConfig` (VoicePiCore shared schema) so the keyboard runtime can distinguish provider paths, and ensure old stored configs decode without breakage. Zero runtime behavior changes in P1 — schema + boundary only.

---

## 1. Files to Modify

| File | Change | Why |
|------|--------|-----|
| `Packages/VoicePiCore/Sources/VoicePiCore/ProfileModels/ProfileModels.swift` | Add `ASRProvider` enum, constrain `ASRConfig.provider` type, add `volcengineAppID`, add `isConfigured(for:)`, add compatibility `init(provider: String, ...)` | Schema is the root of truth. Compatibility init prevents existing call sites from breaking at compile time. |
| `Packages/VoicePiCore/Tests/VoicePiCoreTests/VoicePiCoreTests.swift` | Add decode-compat tests | Verify old configs (no `volcengineAppID`, provider `"openai"`) still decode |

**Only these 2 files. Zero other files touched.**

### Compile-boundary fix: compatibility init

`ASRConfig.provider` changes type from `String` → `ASRProvider`. Existing call sites construct `ASRConfig(provider: "openai", ...)` — these would fail to compile against the new type. Confirmed affected sites (Cindy's review):

- `OnboardingView.swift:188` — `ASRConfig(provider: "openai", baseURL: asrBaseURL, apiKey: asrAPIKey, model: asrModel)`
- `OnboardingView.swift:216` — `RefinementConfig(provider: "openai", ...)` *(not affected — RefinementConfig.provider stays String)*
- `SettingsView.swift:254` — `ASRConfig(provider: "openai", baseURL: asrBaseURLDraft, apiKey: asrKeyDraft, model: asrModelDraft)`
- `VoicePiCoreTests.swift:68-74, 82-90` — test fixtures with `provider: "openai"`

**Solution: keep a String-accepting convenience init alongside the canonical enum init.** The compatibility init maps `"openai"` → `.openAICompatible`, any unknown string → `.openAICompatible`. It is explicitly documented as transitional and will be removed in P3 when UI call sites move to the enum directly.

This preserves the "P1 = schema only, 2 files" boundary. No call site in any other file needs to change.

### NOT in P1

- `ASRClient.swift` — runtime branching is P2
- `KeyboardRootViewController.swift` — config wiring is P2
- `APIVerificationClient.swift` — verify branching is P3
- `OnboardingView.swift`, `SettingsView.swift`, `VoicePiComponents.swift`, `ProfileManagementView.swift` — UI is P3

---

## 2. `asrConfig.provider` Constraint

### Current state

```swift
public struct ASRConfig: Codable, Sendable {
    public var provider: String   // freeform, default "openai"
    public var baseURL: String
    public var apiKey: String
    public var model: String
}
```

`provider` is an unconstrained `String`. Keyboard runtime never reads it — `ASRStream.startStreaming()` hardcodes OpenAI-compatible behavior regardless.

### Proposed: Constrained enum in VoicePiCore

```swift
/// ASR provider identifier — shared between Host App and keyboard runtime.
/// Mirrors macOS ASRBackend remote cases (minus appleSpeech, which has no iOS runtime path).
public enum ASRProvider: String, CaseIterable, Codable, Sendable {
    case openAICompatible = "openai-compatible"
    case aliyun = "aliyun"
    case volcengine = "volcengine"
}
```

**Why a VoicePiCore enum, not just reuse macOS `ASRBackend`:**

1. macOS `ASRBackend` has `appleSpeech` — no iOS equivalent (no `SFSpeechRecognizer` in keyboard extension).
2. macOS `ASRBackend` imports `AppKit` / `ApplicationServices` — not available in iOS keyboard extension.
3. `ASRProvider` is a focused subset: only the providers whose protocol semantics differ at the request level. OpenAI-compatible baseURL reuse (e.g., pointing `https://api.openai.com` to a proxy) is NOT a distinct provider — it's just the `openAICompatible` case with a different baseURL.

**Provider behavior matrix (P1 defines schema; P2 implements):**

| Provider | Protocol | Extra Fields Required | consumes `model` | uses `volcengineAppID` |
|----------|----------|----------------------|------------------|----------------------|
| `openAICompatible` | REST multipart (`/v1/audio/transcriptions`) | none | yes | no |
| `aliyun` | WebSocket realtime (DashScope) | none beyond baseURL/apiKey/model | yes | no |
| `volcengine` | WebSocket realtime (BigModel) | `volcengineAppID` | yes | yes |

### `ASRConfig` change

```swift
public struct ASRConfig: Codable, Sendable {
    public var provider: ASRProvider   // was: String
    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var volcengineAppID: String // NEW

    /// Canonical init — canonical form going forward.
    public init(
        provider: ASRProvider = .openAICompatible,
        baseURL: String = "https://api.openai.com",
        apiKey: String = "",
        model: String = "whisper-1",
        volcengineAppID: String = ""
    ) { ... }

    /// Compatibility init — transitional bridge for existing call sites
    /// that still pass `provider: "openai"` as a String.
    /// Maps "openai" → .openAICompatible, any unknown → .openAICompatible.
    /// REMOVE in P3 when Host App UI moves to ASRProvider enum directly.
    public init(
        provider: String,
        baseURL: String = "https://api.openai.com",
        apiKey: String = "",
        model: String = "whisper-1",
        volcengineAppID: String = ""
    ) {
        self.provider = ASRProvider(rawValue: provider) ?? {
            if provider == "openai" { return .openAICompatible }
            return .openAICompatible
        }()
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.volcengineAppID = volcengineAppID
    }
}
```

**Placeholders per provider (for Host App UI in P3):**

| Provider | baseURL placeholder | model placeholder |
|----------|-------------------|-------------------|
| `openAICompatible` | `https://api.openai.com` | `whisper-1` |
| `aliyun` | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `fun-asr-realtime` |
| `volcengine` | `wss://openspeech.bytedance.com/api/v3/sauc/bigmodel` | `bigmodel` |

These match macOS `ASRBackend.remoteBaseURLPlaceholder` and `remoteModelPlaceholder`.

---

## 3. `volcengineAppID` — Yes, Add It

### Rationale

macOS `RemoteASRConfiguration` already has `volcengineAppID`. macOS `isConfigured(for: .remoteVolcengineASR)` requires it non-empty. Volcengine's WebSocket handshake (see `VolcengineRealtimeProtocol.makeHandshakeHeaders`) consumes App ID for auth signing.

Without `volcengineAppID` in the shared schema:
- Host App can't persist it (P3)
- Keyboard runtime can't read it (P2)
- Volcengine ASR can't function on iOS

### Schema placement

Added directly to `ASRConfig`, NOT as a separate structure. Reasoning:
- Only Volcengine needs it among the three ASR providers
- `RefinementConfig` doesn't need it (refinement stays OpenAI-compatible only)
- macOS puts it in `RemoteASRConfiguration`, which is the ASR-specific config struct — iOS follows the same pattern

### Validation parity with macOS

Macro `isConfigured(for:)` added to `ASRConfig`:

```swift
extension ASRConfig {
    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func isConfigured(for provider: ASRProvider) -> Bool {
        switch provider {
        case .volcengine:
            return isConfigured && !volcengineAppID.trimmingCharacters(in: .whitespaces).isEmpty
        case .openAICompatible, .aliyun:
            return isConfigured
        }
    }
}
```

This directly mirrors macOS `RemoteASRConfiguration.isConfigured(for:)`.

---

## 4. Backward Decode Compatibility

### The risk

Current stored configs in App Group `UserDefaults` have:
```json
{
  "asrConfig": {
    "provider": "openai",
    "baseURL": "https://api.openai.com",
    "apiKey": "sk-...",
    "model": "whisper-1"
  }
}
```

If `provider` changes from `String` to `ASRProvider` enum, decoding `"openai"` (old value) against the new enum (whose raw values are `"openai-compatible"`, `"aliyun"`, `"volcengine"`) will **fail**.

### Strategy

**Custom `Decodable` conformance for `ASRConfig`:**

```swift
extension ASRConfig {
    enum CodingKeys: String, CodingKey {
        case provider, baseURL, apiKey, model, volcengineAppID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // provider: accept old "openai" → .openAICompatible
        let providerString = try container.decodeIfPresent(String.self, forKey: .provider) ?? "openai-compatible"
        self.provider = ASRProvider(rawValue: providerString) ?? {
            // Legacy migration: "openai" was the old default
            if providerString == "openai" { return .openAICompatible }
            return .openAICompatible
        }()

        self.baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "https://api.openai.com"
        self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        self.model = try container.decodeIfPresent(String.self, forKey: .model) ?? "whisper-1"

        // volcengineAppID: not present in old configs → default ""
        self.volcengineAppID = try container.decodeIfPresent(String.self, forKey: .volcengineAppID) ?? ""
    }
}
```

**Encode** always writes the canonical rawValue:
```swift
public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(provider.rawValue, forKey: .provider)
    try container.encode(baseURL, forKey: .baseURL)
    try container.encode(apiKey, forKey: .apiKey)
    try container.encode(model, forKey: .model)
    try container.encode(volcengineAppID, forKey: .volcengineAppID)
}
```

### Test coverage (P1)

Added to `VoicePiCoreTests`:

1. **Old config decodes to openAICompatible** — JSON with `"provider": "openai"` and no `volcengineAppID` key → decodes with `provider == .openAICompatible`, `volcengineAppID == ""`
2. **New config round-trips** — `ASRConfig(provider: .volcengine, volcengineAppID: "123")` → encode → decode → fields match
3. **Missing volcengineAppID key** — JSON without `volcengineAppID` → decodes with `volcengineAppID == ""` (no crash, no optional unwrap failure)
4. **Unknown provider string** — `"provider": "some-future-provider"` → falls back to `.openAICompatible`

---

## 5. What P1 Does NOT Do

| Concern | Why Not | Which Slice |
|---------|---------|-------------|
| Branch inside `ASRStream.startStreaming()` | Runtime behavior change — needs P1 schema approved first | P2 |
| Create Aliyun/Volcengine streaming clients for iOS | Adapter port from macOS — significant new code | P2 |
| Change `KeyboardRootViewController.setupSession()` | Config wiring — depends on P2 runtime | P2 |
| Add provider selector to Host App UI | UI before runtime is rejected by plan rules | P3 |
| Make `APIVerificationClient.probeASR()` provider-aware | Verify branching — needs P1 schema + P2 runtime context | P3 |
| Touch `RefinementConfig` | Out of scope per plan — refinement stays OpenAI-compatible | N/A |
| Add `prompt`, `enableThinking`, `autoCommitDelaySeconds` fields | Already rejected by Cindy in B3 — not consumed by runtime | N/A |

---

## 6. Build Verification (P1 Exit Gate)

After P1 changes, before claiming P1 complete:

```bash
# VoicePiCore compiles with new schema
swift build --package-path Packages/VoicePiCore

# Tests pass (decode compat)
swift test --package-path Packages/VoicePiCore

# iOS project builds with updated VoicePiCore
cd ios/VoicePiKeyboard && xcodegen generate
xcodebuild -project VoicePiKeyboard.xcodeproj \
  -scheme VoicePiApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

---

## 7. Estimated Diff Size

| File | Lines changed |
|------|---------------|
| `ProfileModels.swift` | ~55 added (enum, CodingKeys, custom Decodable/Encodable, canonical init, compatibility init, `isConfigured(for:)`) |
| `VoicePiCoreTests.swift` | ~30 added (4 decode-compat tests) |
| **Total** | ~85 lines |

No other files touched. Compatibility init removes as a single block in P3.
