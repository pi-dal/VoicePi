# Usage Page Focused Expand Interaction — Before-Start Slice

> Task: #16 "Usage page focused expand interaction with charts"
> Gate: Cindy. Do NOT start implementation until this slice is approved.

## Locked Scope

From Cindy's brainstorming + pi-dal's confirmation:

- ✅ Top tab bar untouched
- ✅ Range selector stays at top in both overview and expanded modes
- ✅ Overview mode: current 4-card static dashboard (task #15 deliverable preserved)
- ✅ Tap any metric card → focused expand mode: other 3 cards hide, tapped card stretches to single-column main card
- ✅ Expanded mode: main card + line chart + heatmap below (reuses H4/H5 real chart pipeline)
- ✅ Explicit `← All Metrics` / `Back to Overview` back bar — exit does NOT rely on re-tapping the card
- ✅ Tapping a different metric while expanded: not supported (other cards are hidden); user returns to overview first, then taps another card
- ✅ Summary card: visible only in overview mode; hidden in expanded mode
- ✅ Reuse `HistoryUsageDetailCard`, `HistoryUsageLineChart`, `HistoryUsageHeatmap` — no new chart system

---

## 1. Files to Modify

| File | Change | Why |
|------|--------|-----|
| `VoicePiApp/Sources/HistoryUsageView.swift` | Add expand state machine, back bar, expanded layout; restore `filteredEntries` for chart data | Main view — orchestrates overview ↔ expanded transition |
| `VoicePiApp/Sources/HistoryUsageMetricCard.swift` | Add `onTap` callback parameter | Cards need to signal tap to parent |
| `VoicePiApp/Sources/HistoryUsageDetailCard.swift` | Remove internal `timeRangePicker` (duplicate of top range selector) | Range selector is now a top-level control, shared between modes |

**Only these 3 files modified. Zero other files touched.**

### Files reused without changes

| File | Role |
|------|------|
| `HistoryUsageLineChart.swift` | Line chart rendering — already works with `HistoryUsageVisualization` |
| `HistoryUsageHeatmap.swift` | Heatmap rendering — already works with `HistoryUsageVisualization` |
| `HistoryUsageVisualization` (in HistoryUsageView.swift) | Data computation — `compute(entries:metric:granularity:bucketCount:)` already works |
| `ProfileManagementView.swift` | Tab wiring — `HistoryUsageView()` unchanged |

---

## 2. State Machine

```
    tap card A
┌──────────────────┐
│                  │
▼                  │
┌────────┐     ┌───┴──────┐
│Overview│     │Expanded A│
│ 4-card │     │ 1 card   │
│ grid   │     │ + charts │
└────────┘     └──────────┘
    ▲                  │
    │    tap back bar  │
    └──────────────────┘
      ("All Metrics")
```

- **Overview → Expanded**: tap any metric card → set `expandedMetric = kind` (other 3 cards hide)
- **Expanded → Overview**: tap back bar → set `expandedMetric = nil` (4-card grid returns)
- **Expanded A → Expanded B**: NOT supported. In expanded state only one card is visible — no other cards to tap. User must tap `← All Metrics` to return to overview, then tap a different card.
- **Range selector**: always visible, changes apply to both modes immediately

### State in code

```swift
@State private var expandedMetric: HistoryUsageMetricKind? = nil
// nil → overview mode (4-card grid + summary)
// .some(.sessions) → expanded (single card + charts, other 3 cards hidden)
// Changing metrics requires: back to overview (nil) → tap new card
```

---

## 3. Overview Mode (Current Behavior Preserved)

Unchanged from task #15:
- Range selector at top
- 2×2 `LazyVGrid` with static `HistoryUsageMetricCard(kind:value:)` + new `onTap` callback
- Summary card at bottom (visible)

Only change: `HistoryUsageMetricCard` gets an `onTap: (() -> Void)?` parameter. The card itself stays visually identical — no selection border, same decorative elements.

---

## 4. Expanded Mode

### Layout (top → bottom)

```
┌─────────────────────────────────────────┐
│  Range Selector (1D/1W/2W/1M/6M/1Y 📅) │  ← stays, no change
├─────────────────────────────────────────┤
│  ← All Metrics    │  ● Sessions   12    │  ← back bar
├─────────────────────────────────────────┤
│  Main Card (full-width, single column)  │  ← stretched metric card
│  Icon + title + decoration + value      │
├─────────────────────────────────────────┤
│  Line Chart                             │  ← HistoryUsageLineChart
│  (180pt, accent color)                  │
├─────────────────────────────────────────┤
│  Heatmap                                │  ← HistoryUsageHeatmap
│  (160pt, 7×24, accent color)            │
└─────────────────────────────────────────┘
```

### Back bar

```
← All Metrics                    ● Sessions    12
```

- Left: `Button` with `HStack` of `Image(systemName: "chevron.left")` + `Text("All Metrics")`
  - Font: `.system(size: 15, weight: .medium)`
  - Color: `palette.accent`
  - Action: `expandedMetric = nil` with `.easeInOut(duration: 0.22)` animation
- Right: accent dot (8pt `Circle`) + metric title + aggregate value
  - Matches the old `metricHeader` style from `HistoryUsageDetailCard`

### Main card (stretched)

Same `HistoryUsageMetricCard` but rendered as a single full-width card instead of in a 2×2 grid cell. The card itself doesn't need a "stretched" variant — rendering it in a single-column `VStack` with `.frame(maxWidth: .infinity)` achieves the visual effect.

Alternatively: use a slightly larger variant (e.g., 200pt min height) in expanded mode. This can be done with a parameter or simply by the fact that it fills the full width.

For the slice: the card reuses the same `HistoryUsageMetricCard` component, rendered in a full-width container. No "expanded variant" plumbing needed — the width naturally stretches.

### Detail area (line chart + heatmap)

Reuses `HistoryUsageDetailCard` but with its internal `timeRangePicker` removed:

```swift
// HistoryUsageDetailCard — modified body:
var body: some View {
    VoicePiCard {
        VStack(alignment: .leading, spacing: 16) {
            metricHeader
            // timeRangePicker REMOVED — range selector at top is the single source of truth
            trendSection
            heatmapSection
        }
    }
}
```

The `selectedRange` binding is still passed through (needed for `visualization.compute()`), but the picker UI is removed.

### Transitions

```swift
// Expand: cards fade out + main card animates in
withAnimation(.easeInOut(duration: 0.22)) {
    expandedMetric = kind
}

// Collapse: chart area collapses, grid fades back in
withAnimation(.easeInOut(duration: 0.22)) {
    expandedMetric = nil
}
```

---

## 5. HistoryUsageDetailCard Trim

### What's removed

```swift
// REMOVED from body:
timeRangePicker

// REMOVED computed property:
private var timeRangePicker: some View { ... }
```

The picker inside the detail card was a duplicate of the top-level range selector. Since the range selector now lives at the top of the Usage page in both modes, the detail card's internal picker is dead weight.

### What stays

- `metricHeader` — accent dot + title + value (redundant with main card header, but slim enough to keep)
- `trendSection` → `HistoryUsageLineChart`
- `heatmapSection` → `HistoryUsageHeatmap`
- `visualization` computation
- `currentValue`, `accent`, `palette` helpers

---

## 6. Data Pipeline (Restored)

`filteredEntries` was removed in task #15. It is restored for chart data:

```swift
// Restored in loadHistory():
filteredEntries = filtered

// Passed to HistoryUsageDetailCard:
HistoryUsageDetailCard(
    metric: expandedMetric,
    stats: stats,
    entries: filteredEntries,
    selectedRange: $selectedRange
)
```

No other data pipeline changes. `HistoryStore`, `HistoryEntry`, `HistoryUsageStats`, `HistoryUsageVisualization` all untouched.

---

## 7. Summary Card Visibility

```swift
// In body:
if expandedMetric == nil {
    summaryCard
}
```

Summary card only renders in overview mode. In expanded mode it's absent, giving charts maximum vertical space.

---

## 8. What This Slice Does NOT Do

| Concern | Why Not | When |
|---------|---------|------|
| Touch top tab bar | Explicit scope boundary | Never in this line |
| Add new chart types | Reuses H4/H5 line chart + heatmap | N/A |
| Add new data pipeline | Restores `filteredEntries` — no new backend | N/A |
| Animate individual cards collapsing/expanding with matched geometry | Complex, fragile, not required by spec | Future polish |
| Add swipe-to-dismiss on expanded card | pi-dal explicitly wants a back component | N/A |
| Add new HistoryUsageTimeRange values | Reuses existing 6-range enum | N/A |
| Touch VoicePiCore | Pure Host App visual + interaction layer | N/A |

---

## 9. Build Verification (Exit Gate)

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

---

## 10. Estimated Diff Size

| File | Lines changed |
|------|---------------|
| `HistoryUsageView.swift` | ~100 lines (expand state, back bar, expanded layout, restore filteredEntries, conditional summary) |
| `HistoryUsageMetricCard.swift` | ~12 lines (add `onTap` callback, wire to button) |
| `HistoryUsageDetailCard.swift` | ~18 lines removed (internal timeRangePicker + property) |
| **Total** | ~130 lines net |

3 files modified. H4/H5 chart files reused without changes. VoicePiCore untouched. ProfileManagementView untouched.
