# Usage Page Visual Refactor — Before-Start Slice

> Task: #15 "Usage page visual refactor without tab overhaul"
> Gate: Cindy / Hesse. Do NOT start implementation until this slice is approved.

## Locked Scope

From Hesse's brainstorming + pi-dal's confirmation:

- ✅ Rewrite Usage page as static dashboard homepage
- ✅ Top range selector → larger rounded pill style (not compact segmented picker)
- ✅ 4 metric cards → lighter, larger overview cards with decorative visual language (lines / dot matrix / small bars per Hesse's extraction from reference)
- ✅ Bottom summary card → pure info card, non-interactive (Option A)
- ✅ Keep data pipeline (HistoryStore, HistoryUsageStats, HistoryUsageTimeRange)
- ❌ Do NOT touch the top tab bar
- ❌ Do NOT carry over old expand/collapse detail interaction
- ❌ Do NOT carry over chart rendering (line chart, heatmap)

---

## 1. Files to Modify

| File | Change | Why |
|------|--------|-----|
| `VoicePiApp/Sources/HistoryUsageView.swift` | Major rewrite: new range selector, new card layout, add summary card, remove detail/expand/chart references | This is the main Usage page view — all visual changes converge here |
| `VoicePiApp/Sources/HistoryUsageMetricCard.swift` | Redesign: remove selection state, make cards larger, add decorative visual elements per metric | Cards are the primary visual target from the reference design |

**Only these 2 files modified. Zero other files touched. Zero files moved, archived, or deleted.**

### Files Left in Place (Not Touched This Round)

| File | Why left alone |
|------|---------------|
| `HistoryUsageDetailCard.swift` | H4/H5 deliverable — stays in source tree and build target. `HistoryUsageView` simply stops rendering it. |
| `HistoryUsageLineChart.swift` | H5 deliverable — stays. No longer referenced from `HistoryUsageView`. |
| `HistoryUsageHeatmap.swift` | H5 deliverable — stays. No longer referenced from `HistoryUsageView`. |

These 3 files remain compilable in the target. `HistoryUsageView` stops importing or instantiating them, but nothing is moved, pruned, or archived. This is a rendering change, not a source-graph teardown.

### Files Unchanged

| File | Why |
|------|-----|
| `ProfileManagementView.swift` | `HistoryUsageView()` remains the `.usage` tab content — no wiring changes needed |
| `VoicePiCore`: `HistoryEntry.swift`, `HistoryStore.swift`, `HistoryUsageStats` | Data pipeline is read-only — untouched |

---

## 2. Range Selector Redesign

### Current state

```swift
Picker("Time Range", selection: $selectedRange) {
    ForEach(HistoryUsageTimeRange.allCases, id: \.self) { range in
        Text(range.shortLabel).tag(range)
    }
}
.pickerStyle(.segmented)
```

Compact native segmented control with abbreviated labels (1D/1W/2W/1M/6M/1Y).

### Proposed: Large Rounded Container with Range Pills + Calendar Affordance

```
┌───────────────────────────────────────────────┐
│   1D    1W    2W    1M    6M    1Y       📅   │
└───────────────────────────────────────────────┘
```

**Container:**
- Single large rounded rect: `VoicePiTheme.surfaceChrome(style: .pill)` background + border, or a dedicated `RoundedRectangle(cornerRadius: 16)` with `palette.subtitleText.opacity(0.06)` fill + `palette.subtitleText.opacity(0.10)` border
- Horizontal padding: ~8–10pt
- Height: ~48pt

**Range pills (inside container):**
- 6 text buttons: 1D / 1W / 2W / 1M / 6M / 1Y (existing `HistoryUsageTimeRange.shortLabel`)
- Selected: `palette.accent` background (rounded capsule behind text) + white text, `.font(.system(size: 13, weight: .semibold))`
- Unselected: `palette.subtitleText` text, clear background
- Pill internal padding: `.padding(.horizontal, 10).padding(.vertical, 5)`
- Animation: `.easeInOut(duration: 0.18)` on selection change
- Evenly distributed across the container via `.frame(maxWidth: .infinity)`

**Calendar affordance (trailing edge):**
- `Image(systemName: "calendar")` icon, 15pt, `palette.subtitleText.opacity(0.4)`
- Non-interactive in this round (visual affordance only, no date picker)
- Separated from pills by a thin vertical divider or 8pt spacing

No new types needed — reuses `HistoryUsageTimeRange` and its existing properties.

---

## 3. Metric Cards Redesign

### Current state

`HistoryUsageMetricCard`: 42×42 icon square + title/value/subtitle, 132pt min height, `VoicePiRow` surface, selection border (1.0pt / 1.8pt), tap interaction with `.buttonStyle(.plain)`.

### Proposed: Larger Overview Cards with Decorative Elements

**Structural changes:**
- Remove `isSelected`, `action` — cards are non-interactive
- Remove `Button` wrapper — plain `VStack` in a `VoicePiCard`
- Larger canvas: ~160pt min height (was 132pt)
- Icon: keep 42×42 accent-tinted square (brand-consistent with Settings cards)
- Typography: same sizes (13.5pt title, 17pt value, 12.5pt subtitle) — already works
- Surface: `VoicePiCard` (card chrome — warmer, larger radius, softer border) instead of `VoicePiRow`

**Decorative elements per metric (Hesse's "lines / dot matrix / small bars"):**

Each card gets a subtle decorative strip above or beside the value, using the metric's accent color at low opacity:

| Metric | Decoration | Implementation |
|--------|-----------|----------------|
| Sessions | Horizontal dash/line pattern | `HStack(spacing: 4)` of 5–6 `RoundedRectangle` bars (2×16pt, 0.3 opacity) — mimics a pulse/activity indicator |
| Characters | Dot matrix / staggered dots | `VStack(spacing: 4)` of 3 `HStack` rows, each with 5–6 `Circle` dots (4pt diameter, staggered), 0.25 opacity |
| Words | Small vertical bars | `HStack(spacing: 3)` of 6–8 `RoundedRectangle` bars (8×4→8×24pt range, varying heights), 0.3 opacity — mini bar chart |
| Recording Duration | Concentric arcs or clock-like rings | `ZStack` of 3 `Circle().stroke()` rings (different diameters, 2pt lineWidth, 0.2→0.4 opacity) |

All decorations use `kind.accentColor(for: colorScheme)` and sit in a fixed ~40pt decorative area above the value, keeping the value prominent. Decorations are purely visual — no data binding, no animation.

---

## 4. Bottom Summary Card

### New component (inline in `HistoryUsageView`)

A `VoicePiCard` at the bottom of the scroll view containing:

- Title: "Summary" (or similar) in `VoicePiTheme.Typography.heading`
- Body: Natural-language overview text generated from `HistoryUsageStats`
  - Format: "You recorded **12** dictation sessions this week, totaling **4 minutes 5 seconds** of audio."
  - Varies by selected time range (uses `selectedRange.title` — "this week", "today", "this month", etc.)
  - Uses existing `formatDuration()` helper already in `HistoryUsageView`

No new data pipeline — reads from the same `stats: HistoryUsageStats` state already computed in `loadHistory()`.

---

## 5. Removed from HistoryUsageView Rendering

### State removed
- `@State private var selectedMetric: HistoryUsageMetricKind?` — no selection
- `@State private var filteredEntries: [HistoryEntry]` — no chart data needed

### Views stopped rendering
- `detailArea` (`@ViewBuilder` with `if let metric` → `HistoryUsageDetailCard`) — removed from `body`
- `selectMetric()` method — removed
- All `HistoryUsageDetailCard`, `HistoryUsageLineChart`, `HistoryUsageHeatmap` instantiations — removed from `body`

### What stays on disk and in build
- `HistoryUsageDetailCard.swift`, `HistoryUsageLineChart.swift`, `HistoryUsageHeatmap.swift` — untouched. They remain compilable in the Xcode target. `HistoryUsageView` simply stops referencing them.

### Imports
- `import Charts` — removed from `HistoryUsageView.swift` (no longer needed)
- `import VoicePiCore` — stays (HistoryEntry, HistoryStore, HistoryUsageStats still used)

### What stays
- `loadHistory()` data pipeline
- `HistoryUsageTimeRange`, `HistoryUsageTimelineGranularity`, `HistoryUsageVisualization` types
- `formatDuration()` helper
- `@State private var stats`, `selectedRange`, `loadError`

---

## 6. What This Slice Does NOT Do

| Concern | Why Not | When |
|---------|---------|------|
| Touch the top tab bar | Explicit scope boundary from pi-dal | Future round |
| Carry over expand/collapse chart interaction | pi-dal chose A (static dashboard) | If ever re-added |
| Render real data-driven charts | Static decorations only — no SwiftUI Charts dependency | Future round |
| Add new backend or data pipeline | Data pipeline is read-only — HistoryStore/HistoryUsageStats untouched | N/A |
| Change `ProfileManagementView` tab wiring | HistoryUsageView() still the same entry point | N/A |
| Add new HistoryUsageTimeRange values | Reuses existing 6-range enum | N/A |
| Touch VoicePiCore | Pure Host App visual layer change | N/A |

---

## 7. Build Verification (Exit Gate)

```bash
cd ios/VoicePiKeyboard
xcodegen generate --spec project.yml
xcodebuild -project VoicePiKeyboard.xcodeproj \
  -scheme VoicePiApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

Success criteria: BUILD SUCCEEDED, 0 errors. Pre-existing AppIntents warnings (2) acceptable.

`swift build --package-path Packages/VoicePiCore` should still pass (VoicePiCore is untouched).

---

## 8. Estimated Diff Size

| File | Lines changed |
|------|---------------|
| `HistoryUsageView.swift` | ~220 lines net change (rewrite range selector + card layout body + add summary card + remove detail/expand/chart rendering) |
| `HistoryUsageMetricCard.swift` | ~80 lines net change (remove selection state/action, add decorative elements, resize) |
| **Total** | ~300 lines net change |

**Zero files moved, archived, or deleted.** `HistoryUsageDetailCard.swift`, `HistoryUsageLineChart.swift`, `HistoryUsageHeatmap.swift` remain untouched in the source tree and build target. VoicePiCore untouched. `ProfileManagementView` untouched.
