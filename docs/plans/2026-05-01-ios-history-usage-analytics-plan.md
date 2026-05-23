# iOS History & Usage Analytics — Before-Start Plan (v3)

> **Goal:** Align iOS Usage dashboard to macOS's 4-metric history system with expandable charts.
> **Current state:** iOS has 3 bare aggregate values (`commitCount`, `recordingCount`, `totalAudioSeconds`) with no per-recording history, no persistence, no charts.
> **Gate:** Cindy. Do NOT start implementation until this plan is approved.
> **Revision:** v3 — duration carry-over, exact macOS range/bucket/granularity tables, maximumEntryCount behavior.

## Architecture Decision: Port macOS Model, Rebuild iOS UI Natively

Port `HistoryEntry` + `HistoryUsageStats` + `HistoryStore` (full storage layer, both `jsonFile` and `monthlyJSONL` modes) to VoicePiCore. iOS default to `monthlyJSONL` (current macOS production path). Rebuild iOS UI natively in SwiftUI (macOS charts are AppKit `draw(_:)` — not portable).

**Local file-first only.** No iCloud in this phase.

## Data Model

### HistoryEntry, HistoryJSONLRecord, HistoryDocument, HistoryStoring, HistoryStore, HistoryUsageStats, HistoryTextUsageCounter

Port from `Sources/VoicePi/Adapters/Persistence/HistoryStore.swift`. All structs unchanged. `HistoryJSONLRecord` uses macOS snake_case keys: `created_at`, `character_count`, `word_count`, `recording_duration_milliseconds`. `HistoryTextUsageCounter.count(in:)` uses macOS CJK + Latin algorithm.

### Storage Location

App Group container `History/` directory → `yyyy-MM.jsonl` per month.

### maximumEntryCount (200)

Copied from macOS `HistoryStore.maximumEntryCount` = 200. Enforced in `loadMonthlyHistory()` — after loading all entries from JSONL files, in-memory array is truncated to 200. The on-disk monthly JSONL files are NOT trimmed on append. This matches macOS behavior exactly: `HistoryStore.swift:349-351`.

## Visual Parity Rules (all slices)

| Element | macOS | iOS (adapted) |
|---------|-------|---------------|
| Metric order | Sessions → Chars → Words → Duration | Same |
| Accent colors | Blue / Green / Purple / Orange | Same |
| Icon container | 42pt rounded square, accent border | Adaptive (scaled from 42pt macOS) |
| Selected border | 1.8pt vs 1.0pt | Same |
| Detail structure | Trend (line chart) on top, Heatmap below | Same |
| Time range picker | Segmented dropdown | Segmented control (HIG for iOS) |
| 4-card layout | Horizontal row (equal width) | Portrait: 2×2 grid. Landscape: single row |

## Slice Plan

### Slice H1: Shared Schema + Persistence Model

**Scope:** Port the full macOS `HistoryStore` to VoicePiCore. Zero data model changes.

**Files to create (VoicePiCore `Sources/VoicePiCore/History/`):**
- `HistoryEntry.swift` — `HistoryEntry` + `HistoryDocument` structs
- `HistoryStore.swift` — `HistoryStoring` protocol + `HistoryJSONLRecord` + `HistoryStore` class (both storage modes) + `HistoryUsageStats` + `HistoryTextUsageCounter`

**Adaptations from macOS:**
- `HistoryStorePaths` → replace Application Support with App Group container URL
- `VoicePiConfigPaths.historyMonthString(for:)` → port or inline
- Add `Sendable` conformance where needed
- Everything else: identical `Codable` keys, same counting algorithm, same monthly directory structure

**Exit gate:** `swift build --package-path Packages/VoicePiCore` passes.

---

### Slice H2: Keyboard Write Path

**Scope:** Keyboard extension writes a `HistoryEntry` on each successful commit. Recording duration is captured at `stopRecording()` (before `recordingStartTime` is nil'd) and carried forward to `commitAction()`.

**Duration problem (v3 fix):** Current iOS code sets `recordingStartTime = nil` in `stopRecording()` at `KeyboardRootViewController.swift:177`. By the time `commitAction()` runs (line 206), `recordingStartTime` is already `nil`. Computing duration in `commitAction()` would always produce `0ms`.

**Solution:** Add `lastRecordingDurationMilliseconds: Int = 0` property to `KeyboardRootViewController`. Set it in `stopRecording()` BEFORE nil-ing `recordingStartTime`:

```swift
// KeyboardRootViewController.swift — stopRecording() (line 169)
private func stopRecording() {
    guard case .recording = currentState else { return }
    guard let audioCapture else { return }

    if let startTime = recordingStartTime {
        let duration = Date().timeIntervalSince(startTime)
        SharedProfileDefaults().recordRecording(audioSeconds: duration)
        lastRecordingDurationMilliseconds = Int(duration * 1000)  // 🆕 H2
        recordingStartTime = nil
    }

    let audioData = audioCapture.stopRecording()
    sessionController?.stopRecording(audioData: audioData)
}
```

Then in `commitAction()`, read `lastRecordingDurationMilliseconds`:

```swift
// KeyboardRootViewController.swift — commitAction() (line 206)
private func commitAction() {
    ...
    guard committer.commit(text) else { ... return }

    _ = sessionController?.confirmCommit()
    SharedProfileDefaults().incrementCommitCount()

    // 🆕 H2 — write history entry using carried duration
    let durationMs = lastRecordingDurationMilliseconds
    lastRecordingDurationMilliseconds = 0  // consume once
    try? historyStore.appendEntry(text: text, recordingDurationMilliseconds: durationMs)
}
```

**Files:**
- Modify: `KeyboardRootViewController.swift` — add `lastRecordingDurationMilliseconds` property, set in `stopRecording()`, consume in `commitAction()`

**Edge cases:**
- `cancelAction()` also nils `recordingStartTime` — `lastRecordingDurationMilliseconds` is NOT set on cancel (correct: no commit follows cancel)
- Write fails → silently skip, don't block commit
- `maximumEntryCount` is NOT enforced on write — it's enforced on load (matching macOS `appendMonthlyJSONLEntry` behavior)

**Exit gate:** `xcodebuild -scheme VoicePiApp` passes. Code-static trace: `stopRecording()` → duration captured → `commitAction()` → `HistoryStore.appendEntry(text:text, recordingDurationMilliseconds:durationMs)`.

---

### Slice H3: Host App Aggregation + 4 Metric Cards

**Scope:** Host App reads history entries from App Group, computes `HistoryUsageStats`, renders 4 metric cards. Replaces `UsageDashboardTab` entirely.

**Files:**
- Modify: `ProfileManagementView.swift` → replace `UsageDashboardTab` with new `HistoryUsageView`
- Create: `HistoryUsageView.swift` (VoicePiApp)
- Create: `HistoryUsageMetricCard.swift` (VoicePiApp)

**Data pipeline:**
```
HistoryStore.loadHistory()
  → entries filtered by HistoryUsageTimeRange
  → HistoryUsageStats(entries: filteredEntries)
  → 4 metric cards
```

**6 Time Ranges — exact macOS table (from `SettingsWindowPresentations.swift:119-189`):**

| Range | `trailingDays` | `timelineGranularity` | `timelineBucketCount` |
|-------|---------------|----------------------|----------------------|
| `.oneDay` | 1 | `.hour` | 24 |
| `.oneWeek` | 7 | `.day` | 7 |
| `.twoWeeks` | 14 | `.day` | 14 |
| `.oneMonth` | 30 | `.day` | 30 |
| `.sixMonths` | 182 | `.week` | 26 |
| `.oneYear` | 365 | `.month` | 12 |

**UI layout:**
- 4 `HistoryUsageMetricCard` in 2×2 grid (portrait), single row (landscape)
- Metric order: Sessions / Chars / Words / Duration
- Colors: Blue / Green / Purple / Orange
- Tappable → H4 adds selection + detail

**Exit gate:** `xcodebuild` passes. 4 metric cards render values from real `HistoryEntry` data.

---

### Slice H4: Expand/Collapse + Selection Interaction

**Scope:** Tapping metric card selects it (1.8pt accent border), expands detail section with time range picker + chart placeholders.

**Files:**
- Modify: `HistoryUsageView.swift` — `@State selectedMetric` + expand/collapse
- Modify: `HistoryUsageMetricCard.swift` — `isSelected` visual state
- Create: `HistoryUsageDetailCard.swift` (VoicePiApp)

**Interaction:**
1. Tap card → `withAnimation(.easeInOut(duration: 0.22))` expand detail below grid
2. Selected: 1.8pt accent border vs 1.0pt default (matches macOS)
3. Tap same card → collapse
4. Tap different card → switch metric, stay expanded
5. Detail card: time range segmented picker + "Trend" label + chart placeholder + "Heatmap" label + heatmap placeholder

**Exit gate:** `xcodebuild` passes. Tap/switch/deselect transitions work.

---

### Slice H5: Chart Rendering + Heatmap

**Scope:** SwiftUI Charts line chart + heatmap. 6 ranges with exact macOS granularity/bucket values from H3 table.

**Files:**
- Create: `HistoryUsageLineChart.swift` (VoicePiApp) — SwiftUI `Chart` with `LineMark`
- Create: `HistoryUsageHeatmap.swift` (VoicePiApp) — SwiftUI `Chart` with `RectangleMark`
- Modify: `HistoryUsageDetailCard.swift` — wire real charts

**Line chart granularity (from macOS):**
- 1 Day → `.hour` (24 buckets)
- 1/2 Weeks, 1 Month → `.day` (7/14/30 buckets)
- 6 Months → `.week` (26 buckets)
- 1 Year → `.month` (12 buckets)

**Heatmap:**
- X-axis: day of week (Mon–Sun)
- Y-axis: hour of day (0–23)
- Cell intensity: metric value at (day, hour)
- Accent color: per metric

**Time range picker:** Segmented `Picker` with 6 options. Changing range recomputes both charts.

**SwiftUI Charts:** iOS target 17.0, Charts available since 16.0.

**Exit gate:** `xcodebuild` passes. Line chart + heatmap render. Time range changes update both charts with correct granularity.

---

## Scope Boundaries

### In Scope
- `HistoryEntry` + `HistoryStore` (monthly JSONL, full macOS storage model)
- `HistoryTextUsageCounter` (CJK + Latin, same algorithm)
- `lastRecordingDurationMilliseconds` carry-over (stopRecording → commitAction)
- Keyboard writes on successful commit only (not on cancel)
- `maximumEntryCount` = 200 enforced on load (in-memory), not on append (matches macOS)
- 4 metric cards, 4 accent colors, macOS order
- 6 time ranges with exact macOS `trailingDays`/`granularity`/`bucketCount`
- Expand/collapse detail with line chart + heatmap
- Visual parity per rules table

### Out of Scope
- iCloud sync (separate future phase)
- Export / share / deletion
- Background click to deselect
- `UsageStats` changes (existing struct left untouched)

### Hard Boundaries
- No fake charts before real history data
- No renaming `UsageStats.commitCount` as `sessionCount`
- H2 duration must survive across stopRecording → commitAction (additional property, not recomputed at commit time)
- Storage must be monthly JSONL directory, not single `History.json`

## File Plan

| Slice | New Files | Modified Files |
|-------|-----------|---------------|
| H1 | `History/HistoryEntry.swift`, `History/HistoryStore.swift` (VoicePiCore) | 0 |
| H2 | 0 | `KeyboardRootViewController.swift` |
| H3 | `HistoryUsageView.swift`, `HistoryUsageMetricCard.swift` | `ProfileManagementView.swift` |
| H4 | `HistoryUsageDetailCard.swift` | `HistoryUsageView.swift`, `HistoryUsageMetricCard.swift` |
| H5 | `HistoryUsageLineChart.swift`, `HistoryUsageHeatmap.swift` | `HistoryUsageDetailCard.swift` |

**Total across all slices: 7 new files, 3 unique modified files (`KeyboardRootViewController.swift` in H2, `ProfileManagementView.swift` in H3, detail/view files touched across H3–H5).**

## Acceptance
1. Duration captured in `stopRecording()`, carried via `lastRecordingDurationMilliseconds`, consumed in `commitAction()`
2. Storage is monthly JSONL in App Group container `History/` directory
3. `maximumEntryCount` = 200 in-memory truncation on load (not on-disk on write)
4. 4 metric cards in macOS order + colors
5. 6 time ranges with exact macOS granularity/bucket values
6. Expand/collapse detail with line chart + heatmap
7. All values from real `HistoryEntry` data
