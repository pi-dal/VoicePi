# VoicePi iOS Design Alignment Plan

> **Scope:** Plan B — visual language + interaction structure (not keyboard extension)
> **Last updated:** 2026-04-30
> **Reference:** macOS design system in `Sources/VoicePi/UI/Settings/SettingsWindowSupport.swift`

---

## 1. Gap Analysis: macOS vs iOS

### 1.1 Color Palette

| Element | macOS | iOS (current) | Gap |
|---------|-------|---------------|-----|
| Page background | `#F6F0E8` light / `#161A1C` dark | Default `.systemBackground` | No brand color |
| Accent | `#3E644A` light / `#76E789` dark | `.accentColor` (system blue) | Wrong hue |
| Title text | `#1D2C24` light / `#EEF4EF` dark | Default `.primary` | Close enough |
| Subtitle text | `#636860` light / `#B7C0B9` dark | Default `.secondary` | Close but not tinted |
| Accent glow | `#4AF272` | None | Missing |
| Error/warning | `#C96A10` / `#FFC46B` | System red/orange | No brand error colors |

### 1.2 Surface System

| Surface | macOS spec | iOS (current) | Gap |
|---------|-----------|---------------|-----|
| Card | radius 14, 94% alpha, shadow | `.systemGray6`, radius 12-16, no alpha | No layered transparency |
| Header | radius 0, 98.5% alpha | Not used | Missing concept |
| Pill | radius 11, 86-95% alpha | Not used | Missing concept |
| Row | radius 12, 86-90% alpha | List rows (default) | No custom row styling |
| Borders | 3-4.5% alpha (light/dark) | None | Missing subtle borders |

### 1.3 Button System

| Role | macOS spec | iOS (current) | Gap |
|------|-----------|---------------|-----|
| Primary | Green fill, white text, radius 12, shadow | `.borderedProminent` (blue fill) | Wrong color, no shadow |
| Secondary | White overlay, dark text, radius 12 | `.bordered` | Close, missing radius brand |
| Navigation | Subtle fill, accent text when active | TabView (default) | Missing custom nav |

### 1.4 Typography

| Element | macOS | iOS (current) | Gap |
|---------|-------|---------------|-----|
| Titles | System, semibold | `.title2`, `.headline` | Missing weight specification |
| Body | System, medium | `.subheadline`, `.body` | No consistent scale |
| Captions | System, 11.5pt medium | `.caption`, `.caption2` | Close enough |
| Buttons | 12-13pt semibold | Default button font | No weight control |

### 1.5 Interaction Structure (Scope B specific)

| Aspect | macOS | iOS (current) | Gap |
|--------|-------|---------------|-----|
| Onboarding | Tab-based settings with permission guidance flow | Page-swipe wizard (3 steps) | Different paradigm |
| Profile mgmt | Rich settings window with sections, navigation sidebar, prompt binding | Simple list + sheet editor | Very minimal |
| Usage stats | Integrated into settings (history tab, export) | Standalone dashboard card | Less integrated |
| Info density | Multi-section settings with collapsible groups | Single-level navigation | Much lower density |

### 1.6 API Verification UX (per pi-dal + Cindy)

| Aspect | macOS | iOS (current) | Gap |
|--------|-------|---------------|-----|
| ASR key test | Explicit "Test" button → `ConnectionFeedbackView` (neutral/loading/success/error) | None — save only | Missing entirely |
| Refinement key test | Explicit "Test" button → same feedback pattern | None — save only | Missing entirely |
| Verification states | `unverified → verifying → verified/failed` with icon + text | No concept of verification | Missing |
| Success feedback | Confetti burst + checkmark + "Test succeeded" | None | Missing |
| Error feedback | Friendly HTTP code messages (401→"credentials rejected", etc.) | None | Missing |
| Guard on completion | Can save regardless, but feedback shows status | Onboarding completes regardless of API validity | No guard |

**Decision (per Cindy):** Option A — explicit `Verify` button per API key, with `unverified / verifying / verified / failed` status. Onboarding not considered complete until verified.

---

## 2. Alignment Plans

### Plan A: Color-Only (Minimal)

**What:** Port only the macOS color palette into the existing iOS SwiftUI views. Keep all layouts, interactions, and structures as-is.

**Changes:**
- Define `VoicePiColor` asset catalog or Swift constants matching macOS palette
- Replace `.accentColor` → custom green, `.systemGray6` → custom cream, button tints → green
- Add dark mode variants matching macOS dark palette
- ~30 lines of new color definition code, ~15 lines changed in views

**Pros:**
- Lowest risk, fastest (1 session)
- Instantly recognizable as "same product" via color alone
- No UX retraining needed
- Can ship immediately

**Cons:**
- Interaction patterns still diverge from macOS
- Profile management remains minimal
- Onboarding is still a mobile wizard, not aligned with macOS's settings-first approach
- Feels like "reskin" not "alignment"

**Best for:** Quick win, immediate recognition. Good first step before deeper restructuring.

---

### Plan B: Visual System + Structural Polish (Recommended)

**What:** Port the full visual language (colors, surfaces, buttons, typography) AND restructure the host app to match macOS's information architecture — while respecting iOS platform conventions.

**Changes:**

*Layer 1 — Design tokens (shared asset):*
- `VoicePiTheme.swift` — SwiftUI-native port of `SettingsWindowTheme`
- Color palette, surface styles, button styles, typography scale
- Used by both onboarding and profile views

*Layer 2 — Onboarding restructure:*
- Replace page-swipe wizard with a single scrollable setup flow (closer to macOS's tab-based approach)
- Keep 3 logical steps but present as sections within one scrollable view
- Use macOS-style card surfaces, primary/secondary buttons
- Step indicator becomes a progress bar or section headers
- **API verification integrated:** Each API key field gets a `Verify` button with status feedback
  - `VoicePiVerifyButton` — triggers lightweight probe call (matching macOS `ConnectionTestFeedback`)
  - `VoicePiVerificationBadge` — shows `unverified / verifying… / verified ✓ / failed ✗`
  - Onboarding "Complete" blocked until ASR key verified (matches macOS guard pattern)
  - Port `ConnectionFeedbackPresentation` model to shared VoicePiCore package

*Layer 3 — Profile management enrichment:*
- Restructure from simple List to a more macOS-like layout:
  - Navigation sidebar (or top tab bar on iPhone) for: Profiles | Usage | Settings
  - Each section uses card-based layouts matching macOS surface styles
  - Usage dashboard gets the macOS stats treatment (chart cards, not just numbers)
  - Add prompt binding actions (currently missing on iOS)

*Layer 4 — Shared components:*
- `VoicePiPrimaryButton`, `VoicePiSecondaryButton` — reusable styled buttons
- `VoicePiCard`, `VoicePiPill` — reusable surface containers
- `VoicePiNavigationTab` — custom tab style matching macOS nav pill colors
- `VoicePiVerifyButton` — "Verify" action button with loading/result states
- `VoicePiVerificationBadge` — inline status: unverified / verifying / verified / failed
- `ConnectionFeedbackPresentation` — model ported to VoicePiCore (shared by both platforms)

**Pros:**
- Feels like "the same product" not just "the same colors"
- Information architecture matches macOS expectations (profiles, usage, settings tabs)
- Still respects iOS platform (no force-fitting AppKit patterns)
- Incremental: can ship Layer 1 first, then Layers 2-4
- Profile management becomes genuinely useful (not just placeholder)

**Cons:**
- Larger scope (~3-4 sessions)
- Requires rethinking some iOS-specific patterns (onboarding wizard, list-based editing)
- Profile management enrichment needs design decisions (what prompt binding actions to expose on mobile)

**Best for:** The intent Cindy described — make iOS feel like the same product, not just branded with the same colors. This is the recommended plan.

---

### Plan C: Full Parity (Maximum)

**What:** Plan B + also redesign the keyboard extension preview bar to use the same design language, replacing iOS-native keyboard styling with a custom VoicePi look.

**Additional changes (beyond Plan B):**
- `PreviewBarView` surfaces use VoicePi palette instead of system colors
- Error state icons use brand colors (green accents for success, warm orange for warnings)
- Debug panel styling matches macOS debug overlays
- Keyboard bar backgrounds use semi-transparent VoicePi surfaces

**Pros:**
- Complete brand consistency across both host app and keyboard
- Keyboard looks deliberately different from system keyboard (product differentiation)
- Most thorough alignment

**Cons:**
- Keyboard extensions have severe constraints (memory, performance)
- Custom surfaces in keyboard can feel out of place among system keyboards
- Risk: Apple may reject keyboards that deviate too far from system keyboard appearance
- 1-2 additional sessions beyond Plan B
- The keyboard is a system-level UI — heavy branding can feel intrusive

**Best for:** If the product vision is a premium, branded keyboard that stands out. Not recommended for MVP.

---

## 3. Recommendation: Plan B in 2 Phases

```
Phase B1 (immediate): Design tokens + onboarding polish
  - VoicePiTheme.swift with full color/surface/button system
  - Apply to existing views (onboarding, profile, usage)
  - ~1 session

Phase B2 (follow-up): Profile management enrichment
  - Tab-based navigation (Profiles | Usage | Settings)
  - Card-based layouts, prompt binding actions
  - ~2 sessions
```

---

## 4. Key Design Decisions to Resolve

| Decision | Option A | Option B | Recommend |
|----------|----------|----------|-----------|
| Onboarding format | Keep page-swipe, apply new colors | Single scrollable view with sections | B — closer to macOS flow |
| Navigation style | Top tab bar (iOS standard) | Sidebar (iPad) / tab bar (iPhone) | A for iPhone, consider B for iPad |
| Profile binding on mobile | Read-only prompt list | Full prompt CRUD + binding | B — matches macOS capability |
| Keyboard preview bar | Keep iOS-native look | Apply VoicePi palette minimally | Leave for Plan C consideration |
| Dark mode assets | Generate from macOS palette | Let SwiftUI auto-adapt | Generate — exact match to macOS |
