# External Processor Refinement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a generic external-processor refinement architecture to VoicePi with `Alma CLI` as the first backend, a centered result review panel, and a scrollable sheet-based processor manager that supports backend-specific args and a test action.

**Architecture:** Extend the current post-processing model with a provider family split between built-in LLM refinement and external processors. Keep prompt resolution inside the existing prompt workspace, add a command-backed refiner abstraction for one-shot CLI tools, route successful external results through a new centered review panel, and persist multiple processor profiles so the settings UI can manage them as sheet entries instead of one global advanced form.

**Tech Stack:** Swift 5.9, AppKit, Foundation `Process`, Swift Testing, SwiftPM

## Confirmed Constraint

Local verification on 2026-04-10 confirmed that the Alma backend in this plan must stay pure CLI and one-shot:

- `alma run` is the supported Alma integration contract for Phase 1
- `alma run` does not provide a documented reusable multi-turn session contract for this feature
- Alma's persistent thread behavior exists behind local APIs and WebSocket flows, but this implementation must not depend on them
- VoicePi must not call Alma local HTTP APIs or WebSocket endpoints directly for the Alma CLI backend

As a result, this plan does not include persistent conversation state, thread reuse, or session resurrection across refinement calls.

### Task 1: Add pure models and persistence for external processors

**Files:**
- Modify: `Sources/VoicePi/AppModel.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Test: `Tests/VoicePiTests/AppModelPersistenceTests.swift`
- Test: `Tests/VoicePiTests/SettingsPresentationTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:

- refinement provider defaults to `llm`
- external processor backend defaults are stable
- multiple processor entries persist across reloads
- additional args persist in stable order
- home summary reflects `External Processor • Backend Alma CLI`

Suggested test names:

```swift
func externalProcessorSettingsPersistAcrossReloads()
func legacyDefaultsFallBackToLLMRefinementProvider()
func homePresentationReflectsExternalProcessorBackend()
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter 'AppModelPersistenceTests|SettingsPresentationTests'
```

Expected: FAIL because the model has no external processor state yet.

**Step 3: Write minimal implementation**

Add pure storage types in `AppModel.swift`:

```swift
enum RefinementProvider: String, Codable {
    case llm
    case externalProcessor
}

enum ExternalProcessorKind: String, Codable {
    case almaCLI
}

struct ExternalProcessorArgument: Codable, Equatable, Identifiable {
    var id: UUID
    var value: String
}

struct ExternalProcessorEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var kind: ExternalProcessorKind
    var executablePath: String
    var additionalArguments: [ExternalProcessorArgument]
    var isEnabled: Bool
}
```

Persist:

- selected `RefinementProvider`
- selected processor entry ID for refinement
- processor entry list

Update settings/home presentation helpers to summarize the selected processor backend.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter 'AppModelPersistenceTests|SettingsPresentationTests'
```

Expected: PASS

### Task 2: Add argument validation and Alma CLI command building

**Files:**
- Create: `Sources/VoicePi/ExternalProcessorSupport.swift`
- Create: `Sources/VoicePi/ExternalProcessorRefiner.swift`
- Test: `Tests/VoicePiTests/ExternalProcessorSupportTests.swift`

**Step 1: Write the failing tests**

Add pure tests for:

- parsing one-arg-per-entry values into argv items
- Alma CLI command merge order
- incompatible Alma flags being rejected
- required prompt and stdin wiring metadata
- session-oriented or undocumented flags being rejected for the Alma CLI backend

Suggested test names:

```swift
func almaCLICommandIncludesRequiredFlagsBeforeUserArgs()
func almaCLIValidationRejectsListAndHelpFlags()
func externalProcessorEntryProducesExpectedArgumentVector()
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter ExternalProcessorSupportTests
```

Expected: FAIL because the support surface does not exist.

**Step 3: Write minimal implementation**

Create pure support types:

```swift
enum ExternalProcessorValidationError: LocalizedError, Equatable
struct ExternalProcessorInvocation: Equatable
struct AlmaCLIInvocationBuilder
```

Model the Alma invocation as:

```swift
["run", "--raw", "--no-stream", /* validated user args */, resolvedPrompt]
```

Reject flags such as:

- `--help`
- `-h`
- `-l`
- `--list-models`
- `-v`
- `--verbose`

Also reject session-oriented or undocumented flags for this backend contract. The Alma integration in this plan is intentionally limited to documented one-shot CLI refinement.

Do not use a shell string. Build argv arrays only.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter ExternalProcessorSupportTests
```

Expected: PASS

### Task 3: Add command execution and test action for external processors

**Files:**
- Create: `Sources/VoicePi/ExternalProcessorRunner.swift`
- Modify: `Sources/VoicePi/AppWorkflowSupport.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Test: `Tests/VoicePiTests/AppWorkflowSupportTests.swift`
- Test: `Tests/VoicePiTests/ExternalProcessorRunnerTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:

- refinement mode dispatches to LLM when provider is `.llm`
- refinement mode dispatches to the external runner when provider is `.externalProcessor`
- Alma runner writes transcript to stdin and returns trimmed stdout
- empty stdout falls back to original text
- non-zero exit, missing executable, and timeout return failure
- settings-level test action uses the same validation and runner path
- repeated Alma runner invocations are treated as independent one-shot executions

Suggested test names:

```swift
func refinementUsesExternalProcessorWhenSelected()
func almaRunnerReturnsTrimmedStdout()
func almaRunnerFallsBackOnEmptyOutput()
func almaRunnerReportsMissingExecutable()
func almaRunnerReportsTimeout()
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter 'AppWorkflowSupportTests|ExternalProcessorRunnerTests'
```

Expected: FAIL because workflow routing and runner abstractions are missing.

**Step 3: Write minimal implementation**

Add injectable process seams:

```swift
protocol ExternalProcessorRunning {
    func run(invocation: ExternalProcessorInvocation, stdin: String, timeout: Duration) async throws -> String
}
```

Update `AppWorkflowSupport.postProcessIfNeeded` to accept:

- refinement provider
- selected external processor entry
- external runner/refiner

Keep translation behavior unchanged.

Add a processor test path in `AppCoordinator` that reuses the same validation and runner pipeline with a fixed test prompt and short stdin payload.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter 'AppWorkflowSupportTests|ExternalProcessorRunnerTests'
```

Expected: PASS

### Task 4: Add centered result review panel support

**Files:**
- Create: `Sources/VoicePi/ResultReviewPanelSupport.swift`
- Create: `Sources/VoicePi/ResultReviewPanelController.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Test: `Tests/VoicePiTests/ResultReviewPanelSupportTests.swift`
- Test: `Tests/VoicePiTests/TranscriptDeliveryTests.swift`

**Step 1: Write the failing tests**

Add tests for:

- review payload creation from non-empty external output
- insert/copy/dismiss actions preserving correct text
- external processor path no longer auto-injecting on success
- insert action sending reviewed text back through the existing injector path

Suggested test names:

```swift
func resultReviewPayloadRequiresNonEmptyText()
func externalProcessorSuccessRoutesToReviewPanel()
func insertActionUsesReviewedTextForInjection()
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter 'ResultReviewPanelSupportTests|TranscriptDeliveryTests'
```

Expected: FAIL because there is no review-panel flow yet.

**Step 3: Write minimal implementation**

Follow the existing panel-controller pattern from `InputFallbackPanelController`, but create a centered review window sized around one-third of the visible screen.

Support actions:

- `Insert`
- `Copy`
- `Retry`
- `Dismiss`

Use a pure payload/state helper:

```swift
struct ResultReviewPanelPayload: Equatable
struct ResultReviewPanelPresentationState: Equatable
```

Update `AppCoordinator` so successful external refinement shows the review panel. Only `Insert` triggers `TextInjector.injectAndRecord`.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter 'ResultReviewPanelSupportTests|TranscriptDeliveryTests'
```

Expected: PASS

### Task 5: Add processor manager settings UI and sheet interactions

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Sources/VoicePi/SettingsPresentation.swift`
- Test: `Tests/VoicePiTests/StatusBarLLMFeedbackTests.swift`
- Test: `Tests/VoicePiTests/SettingsWindowPromptTemplateTests.swift`
- Create: `Tests/VoicePiTests/ExternalProcessorManagerTests.swift`

**Step 1: Write the failing tests**

Add tests that lock:

- feedback text for external processor selection
- adding a processor entry from the manager
- adding an argument row with `+`
- selecting a processor entry for refinement
- invoking the processor `Test` action

Suggested test names:

```swift
func externalProcessorFeedbackReportsUnavailableBackend()
func processorManagerAddsEntryWhenPlusIsPressed()
func processorManagerAddsArgumentRowWhenPlusIsPressed()
func selectingProcessorEntryUpdatesDraftSelection()
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter 'StatusBarLLMFeedbackTests|SettingsWindowPromptTemplateTests|ExternalProcessorManagerTests'
```

Expected: FAIL because the settings UI has no processor manager or review of external processor state.

**Step 3: Write minimal implementation**

Add:

- `Refinement Provider` popup with `LLM` and `External Processor`
- backend selector when `External Processor` is active
- button to open a scrollable processor-manager sheet

Inside the sheet, implement an entry list where:

- top-level `+` adds a processor entry
- each entry can edit name, backend, executable path, enabled state
- each entry contains an args list
- args-list `+` adds a new argument row
- each entry has `Test` and `Delete`

Keep the first implementation inside `StatusBarController` if necessary, but use pure helper methods for draft-state transitions so tests do not depend on full AppKit event driving.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter 'StatusBarLLMFeedbackTests|SettingsWindowPromptTemplateTests|ExternalProcessorManagerTests'
```

Expected: PASS

### Task 6: Wire end-to-end coordinator behavior and run full verification

**Files:**
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Sources/VoicePi/StatusBarController.swift`
- No new files expected

**Step 1: Run focused verification**

Run:

```bash
swift test --filter 'AppModelPersistenceTests|SettingsPresentationTests|ExternalProcessorSupportTests|ExternalProcessorRunnerTests|AppWorkflowSupportTests|ResultReviewPanelSupportTests|ExternalProcessorManagerTests'
```

Expected: PASS

**Step 2: Run full test suite**

Run:

```bash
./Scripts/test.sh
```

Expected: PASS

**Step 3: Run verification build**

Run:

```bash
./Scripts/verify.sh
```

Expected: PASS with a debug app bundle build.

**Step 4: Manual smoke check**

Verify manually:

1. choose `External Processor`
2. add an `Alma CLI` entry in the sheet
3. add a safe argument such as `-m <provider:model>` if desired
4. press `Test` and confirm success or actionable validation error
5. record a short phrase
6. confirm the centered result review panel appears
7. confirm `Insert` writes reviewed text back to the original input target
8. confirm `Copy`, `Retry`, and `Dismiss` behave correctly
9. confirm repeated runs behave as independent one-shot refinements rather than a shared Alma conversation
