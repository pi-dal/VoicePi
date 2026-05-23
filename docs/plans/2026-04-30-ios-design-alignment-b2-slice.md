# B2 Before-Starting Slice (Revised)

> **Scope:** Structural alignment only — no new backend, no fake UI, no charts, no animation
> **Precedes from:** B1 (design tokens + onboarding + verify)
> **Date:** 2026-04-30

---

## 1. What's Pure Structural Alignment

These are changes that reorganize existing views and capabilities into a macOS-aligned information architecture:

| Change | Type | Backend exists? |
|--------|------|----------------|
| Tab bar replacing page-swipe in ProfileManagementView | Structural | Yes (tabs already work) |
| Settings tab with API key view/edit/verify | Reorganize existing | Yes (keys + verify from B1) |
| Refinement enable/disable toggle in Settings | Reorganize existing | Yes (`RefinementConfig.enabled`) |

## 2. What's Existing Capability Reorganized

| Feature | Where it lives now | Where it moves in B2 |
|---------|-------------------|---------------------|
| ASR key view/edit/verify | OnboardingView only | → Settings tab (persistent access) |
| Refinement key view/edit/verify | OnboardingView only | → Settings tab (persistent access) |
| Profile slots list | Page 1 of swipe TabView | → Profiles tab in segmented picker |
| Usage dashboard | Page 2 of swipe TabView | → Usage tab in segmented picker |
| Refinement toggle | Not exposed on iOS | → Settings tab (reads `RefinementConfig.enabled`) |

## 3. What's NOT in B2 — Placeholder or Deferred

| Feature | B2 treatment | Why |
|---------|-------------|-----|
| Prompt binding actions | "Coming Next" placeholder pill on slot rows | No backend — `PromptBindingActions` is macOS-only, no iOS equivalent yet |
| Charts / graphs | Deferred | Cindy: "不要新增图表库" |
| Confetti | Deferred | Cindy: "不要新增动画系统" |
| Weekly trend / new stats | Deferred | Cindy: "不要新增统计口径" |
| Export / sharing | Deferred | No backend |
| History tab | Deferred | Needs local persistence |
| Dictionary tab | Deferred | macOS-only feature |

---

## 4. Files to Change

### New files

| File | Purpose |
|------|---------|
| `VoicePiApp/Sources/SettingsView.swift` | API key management (ASR + Refinement with B1 verify), refinement toggle, model info, app version |

### Modified files

| File | Changes |
|------|---------|
| `VoicePiApp/Sources/ProfileManagementView.swift` | Replace `.tabViewStyle(.page)` with `VoicePiNavigationTab` segmented picker; add Settings tab; add "Coming Next" placeholder on slot rows for binding |
| `VoicePiApp/Sources/VoicePiComponents.swift` | Add `VoicePiNavigationTab` component (segmented picker styled with macOS navigation chrome) |

### No changes

| File | Reason |
|------|--------|
| `VoicePiCore/*` | Only structure reorganization — zero new capability |
| `OnboardingView.swift` | B1 version already complete |
| Keyboard extension files | Plan C |

---

## 5. Navigation Tab Component Design

```
┌───────────────────────────────────────┐
│  [Profiles]  [Usage]  [Settings]      │  ← VoicePiNavigationTab
│   ──────                          ← accent indicator bar under selected
├───────────────────────────────────────┤
│                                       │
│  selected tab content                 │
│                                       │
└───────────────────────────────────────┘
```

Chrome: matches macOS `SettingsWindowTheme.buttonChrome(role: .navigation)`:
- Selected: accent text + accent indicator bar
- Unselected: subtitle text, no indicator
- Hover/press: subtle background fill

---

## 6. Simulator Verification

```bash
cd /Users/pi-dal/Developer/VoicePi && swift build --package-path Packages/VoicePiCore
cd ios/VoicePiKeyboard && xcodegen generate
xcodebuild -project VoicePiKeyboard.xcodeproj -scheme VoicePiApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Smoke checklist

1. App launches → themed tab bar (Profiles | Usage | Settings)
2. Profiles tab: slot list renders with VoicePiTheme, "Coming Next" pill visible
3. Usage tab: existing stat cards render, themed correctly
4. Settings tab: ASR key field + verify (reuses B1 components), refinement toggle
5. Refinement toggle off → key field dims/hides
6. Dark mode: tab bar + all three tabs adapt
7. Onboarding → complete → lands on tabbed ProfileManagementView
8. Keyboard extension: zero changes, build not affected
