# Performance Response Pipeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce VoicePi's perceived response latency by moving realtime streaming off the main actor, shrinking injection delays, isolating panel sizing and post-injection polling policies behind small abstractions, adding deterministic latency diagnostics for the recording-to-delivery path, persisting recent real-session samples for median summaries, and shipping a repeatable benchmark report so regressions are visible instead of anecdotal.

**Architecture:** The realtime ASR path should own its transport and buffering state inside an actor so audio capture no longer queues behind UI work. UI-facing code should consume compact state snapshots and throttled updates instead of mutating layout on every partial transcript. Injection and post-injection monitoring should use explicit policy/value types so timing choices stop being magic numbers embedded inside long controller methods. The recording path should also emit a compact latency trace so performance regressions can be tied to concrete milestones instead of anecdotal “it feels slow” reports, and successful sessions should be persisted as a capped local history so benchmark output can surface recent medians. Performance-sensitive abstractions should pair behavior tests with either a deterministic budget comparison or a microbenchmark entry so future refactors can be judged against a baseline.

**Tech Stack:** Swift Concurrency, AppKit, AVFoundation, Accessibility APIs, Swift Testing

### Task 1: Realtime session state abstraction

**Files:**
- Modify: `Sources/VoicePi/RealtimeASRSessionCoordinator.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Test: `Tests/VoicePiTests/RealtimeASRSessionCoordinatorTests.swift`

**Step 1: Write the failing test**

Add coverage for a `statusSnapshot()` API so callers stop reading coordinator state directly from the main actor.

**Step 2: Run test to verify it fails**

Run: `swift test --filter RealtimeASRSessionCoordinatorTests`
Expected: compile failure because `statusSnapshot()` does not exist and actor access is not wired.

**Step 3: Write minimal implementation**

Convert the coordinator into an actor, add a `StatusSnapshot` value type, and switch `AppCoordinator` to consume the snapshot instead of reading actor state ad hoc.

**Step 4: Run test to verify it passes**

Run: `swift test --filter RealtimeASRSessionCoordinatorTests`
Expected: PASS

### Task 2: Injection timing abstraction

**Files:**
- Create: `Sources/VoicePi/TextInjectionTiming.swift`
- Modify: `Sources/VoicePi/TextInjector.swift`
- Test: `Tests/VoicePiTests/TextInjectionExecutionPlanTests.swift`

**Step 1: Write the failing test**

Add a test that codifies the desired latency budget for ASCII and CJK injection paths.

**Step 2: Run test to verify it fails**

Run: `swift test --filter TextInjectionExecutionPlanTests`
Expected: compile failure because the timing abstraction does not exist.

**Step 3: Write minimal implementation**

Introduce `TextInjectionTiming` and `TextInjectionExecutionPlan`, replace inline sleeps with the plan, and remove blocking `Thread.sleep`.

**Step 4: Run test to verify it passes**

Run: `swift test --filter TextInjectionExecutionPlanTests`
Expected: PASS

### Task 3: Floating panel sizing abstraction

**Files:**
- Modify: `Sources/VoicePi/FloatingPanelSupport.swift`
- Modify: `Sources/VoicePi/FloatingPanelController.swift`
- Test: `Tests/VoicePiTests/FloatingPanelSizingStateTests.swift`

**Step 1: Write the failing test**

Add a test that proves recording width locks for the session while refining remains elastic.

**Step 2: Run test to verify it fails**

Run: `swift test --filter FloatingPanelSizingStateTests`
Expected: compile failure because the sizing state object does not exist.

**Step 3: Write minimal implementation**

Move panel width policy into `FloatingPanelSizingState` and feed it from the content controller.

**Step 4: Run test to verify it passes**

Run: `swift test --filter FloatingPanelSizingStateTests`
Expected: PASS

### Task 4: Post-injection polling policy

**Files:**
- Create: `Sources/VoicePi/PostInjectionLearningLoopPolicy.swift`
- Modify: `Sources/VoicePi/PostInjectionLearning.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Test: `Tests/VoicePiTests/PostInjectionLearningLoopPolicyTests.swift`
- Test: `Tests/VoicePiTests/PostInjectionLearningTests.swift`

**Step 1: Write the failing test**

Add policy coverage for the new polling cadence and adapt learning tests to async actor access.

**Step 2: Run test to verify it fails**

Run: `swift test --filter PostInjectionLearningLoopPolicyTests`
Expected: compile failure because the loop policy type does not exist.

**Step 3: Write minimal implementation**

Move the coordinator to an actor, create a polling policy value type, and run snapshot collection off the main actor with only UI application hopping back to `MainActor`.

**Step 4: Run test to verify it passes**

Run: `swift test --filter PostInjectionLearningTests`
Expected: PASS

### Task 5: Recording latency diagnostics

**Files:**
- Create: `Sources/VoicePi/RecordingLatencyTrace.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Test: `Tests/VoicePiTests/RecordingLatencyTraceTests.swift`

**Step 1: Write the failing test**

Add coverage for a small, pure latency trace abstraction that records milestone offsets, keeps the first partial timestamp stable, and formats a deterministic summary string for logs.

**Step 2: Run test to verify it fails**

Run: `swift test --filter RecordingLatencyTraceTests`
Expected: compile failure because the trace abstraction does not exist.

**Step 3: Write minimal implementation**

Introduce `RecordingLatencyTrace` plus a lightweight reporter abstraction backed by unified logging. Wire the trace into the recording pipeline at these milestones:

- recording requested
- recorder started
- first partial transcript observed
- stop requested
- transcript resolved
- refinement completed
- injection completed

The `AppController` integration should only mark milestones and report a final outcome (`success`, `cancelled`, `failed`) so diagnostic behavior stays outside the already-large controller methods.

**Step 4: Run test to verify it passes**

Run: `swift test --filter RecordingLatencyTraceTests`
Expected: PASS

### Task 6: Benchmark reporting workflow

**Files:**
- Create: `Sources/VoicePi/PerformanceBenchmarkReport.swift`
- Create: `Scripts/benchmark.sh`
- Create: `Scripts/benchmark_main.swift`
- Test: `Tests/VoicePiTests/PerformanceBenchmarkReportTests.swift`
- Test: `Tests/benchmark_script_test.sh`

**Step 1: Write the failing test**

Add a test for a report abstraction that compares legacy and current performance budgets for the recent abstractions, and lock the benchmark text format so the script output remains easy to diff.

**Step 2: Run test to verify it fails**

Run: `swift test --filter PerformanceBenchmarkReportTests`
Expected: compile failure because the benchmark report type does not exist.

**Step 3: Write minimal implementation**

Create a benchmark report that covers:

- legacy vs current text injection blocking latency
- modeled stop-to-delivery latency under fixed upstream transcript/refine assumptions
- legacy vs current post-injection Accessibility polling load
- legacy vs current floating-panel layout invalidations under repeated identical realtime partials
- recent real-session latency medians loaded from persisted recording traces when available
- lightweight microbenchmark samples for pure performance helpers

Expose the report through `Scripts/benchmark.sh`, which should compile a temporary benchmark binary and print the current benchmark snapshot in plain text.

**Step 4: Run test to verify it passes**

Run:
- `swift test --filter PerformanceBenchmarkReportTests`
- `sh Tests/benchmark_script_test.sh`

Expected: PASS

### Task 7: Full verification

**Files:**
- Verify: `./Scripts/test.sh`

**Step 1: Run focused suites**

Run:
- `swift test --filter RealtimeASRSessionCoordinatorTests`
- `swift test --filter TextInjectionExecutionPlanTests`
- `swift test --filter FloatingPanelSizingStateTests`
- `swift test --filter PostInjectionLearningTests`
- `swift test --filter RecordingLatencyTraceTests`
- `swift test --filter PerformanceBenchmarkReportTests`
- `./Scripts/benchmark.sh`

**Step 2: Run repository tests**

Run: `./Scripts/test.sh`
Expected: all tests pass
