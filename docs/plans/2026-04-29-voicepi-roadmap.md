# VoicePi Improvement Roadmap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move VoicePi from a well-tested personal-power-user app into a more maintainable and more productized macOS application without losing delivery speed.

**Architecture:** Prioritize foundation work first so every later change lands in a stronger verification and release system. Then reduce orchestration complexity in the desktop app, harden end-user distribution, and finally simplify the `site/` rendering model before it grows into a second maintenance hotspot.

**Tech Stack:** SwiftPM, Swift 6, AppKit, GitHub Actions, POSIX shell tests, Vite, TypeScript, Vitest

## Phase Order

1. **Phase 1: Verification and repo hygiene**
2. **Phase 2: App orchestration refactor**
3. **Phase 4: Website maintainability**

## Deferred Work

- **Deferred: former Phase 3 distribution hardening**
- Reason: not in current scope; keep the app focused on engineering quality and maintainability first.

### Task 1: Bring `site/` into the main verification contract

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `Scripts/test.sh`
- Modify: `README.md`
- Modify: `site/README.md`
- Create: `Tests/test_script_site_workspace.sh`

**Step 1:** Add a repository-level shell regression test that asserts `Scripts/test.sh` also runs `site` verification commands when the workspace is present.

**Step 2:** Update `Scripts/test.sh` so it runs:
- `pnpm test -- --run`
- `pnpm typecheck`
- `pnpm build`

inside `site/` after the Swift and shell suites pass.

**Step 3:** Update `.github/workflows/ci.yml` only as needed so CI still calls one canonical entrypoint (`./Scripts/test.sh`) rather than duplicating logic in YAML.

**Step 4:** Refresh `README.md` and `site/README.md` so the repository-level verification flow explicitly includes the website workspace.

**Step 5:** Run:
- `./Scripts/test.sh`
- `cd site && pnpm test -- --run && pnpm typecheck && pnpm build`

Expected: PASS for both the root test entrypoint and the direct site workspace verification.

### Task 2: Remove package-manager ambiguity in `site/`

**Files:**
- Delete: `site/package-lock.json`
- Modify: `site/README.md`
- Modify: `README.md`

**Step 1:** Decide that `site/` is pnpm-only, because `site/package.json` already declares `packageManager: pnpm@10.15.0`.

**Step 2:** Remove `site/package-lock.json` so contributors do not accidentally drift between npm and pnpm lockfiles.

**Step 3:** Update contributor-facing docs so every site command uses `pnpm`, not a mixed package-manager story.

**Step 4:** Run:
- `cd site && pnpm install --frozen-lockfile`
- `cd site && pnpm test -- --run && pnpm typecheck && pnpm build`

Expected: PASS with no npm lockfile remaining in the workspace.

### Task 3: Split `AppController` into explicit coordinators

**Files:**
- Modify: `Sources/VoicePi/App/AppCoordinator.swift`
- Create: `Sources/VoicePi/App/RecordingSessionCoordinator.swift`
- Create: `Sources/VoicePi/App/PermissionBootstrapCoordinator.swift`
- Create: `Sources/VoicePi/App/ReviewPanelCoordinator.swift`
- Modify: `Sources/VoicePi/App/AppController+RecordingLifecycle.swift`
- Modify: `Sources/VoicePi/App/AppController+PermissionsAndUpdates.swift`
- Modify: `Sources/VoicePi/App/AppController+PanelFlows.swift`
- Modify: `Tests/VoicePiTests/AppControllerInteractionTests.swift`
- Modify: `Tests/VoicePiTests/AppControllerUpdateDeliveryTests.swift`

**Step 1:** Extract recording startup, stop, cancellation, and active-session state transitions into `RecordingSessionCoordinator`.

**Step 2:** Extract launch permission planning, refresh sequencing, and update/bootstrap flows into `PermissionBootstrapCoordinator`.

**Step 3:** Extract result review, external-processor result presentation, and panel dismissal/session bookkeeping into `ReviewPanelCoordinator`.

**Step 4:** Keep `AppController` as the app-facing composition root that wires dependencies together and forwards user actions, instead of continuing to own every workflow directly.

**Step 5:** Add or update focused tests so each extracted coordinator has behavior coverage around the edge cases that are currently only protected indirectly through `AppController` integration tests.

**Step 6:** Run:
- `./Scripts/test.sh --filter AppControllerInteractionTests`
- `./Scripts/test.sh --filter AppControllerUpdateDeliveryTests`
- `./Scripts/test.sh`

Expected: PASS, with lower orchestration density in `AppController` and no feature regression.

### Task 4: Replace the `site/src/main.ts` full-rerender loop with a stable view model

**Files:**
- Modify: `site/src/main.ts`
- Create: `site/src/lib/app-controller.ts`
- Create: `site/src/lib/dom-bindings.ts`
- Modify: `site/src/lib/render.ts`
- Modify: `site/src/lib/site-state.ts`
- Modify: `site/src/lib/render.test.ts`
- Modify: `site/src/lib/site-state.test.ts`

**Step 1:** Move interaction wiring and state transitions out of `site/src/main.ts` into a small controller layer that can update only the affected DOM regions.

**Step 2:** Preserve the current design language and behavior, but stop rebuilding `root.innerHTML` on every state change.

**Step 3:** Keep the canvas atmosphere and hero-mask logic isolated behind explicit mount/unmount hooks so visual effects do not depend on full-page rerenders.

**Step 4:** Add regression tests around theme switching, install dialog transitions, highlight selection, and version selection so the new rendering model is protected by behavior rather than manual inspection.

**Step 5:** Run:
- `cd site && pnpm test -- --run`
- `cd site && pnpm typecheck`
- `cd site && pnpm build`

Expected: PASS, with simpler event wiring and lower risk when future page interactions are added.

## Recommended Execution Strategy

- **First milestone:** finish Task 1 and Task 2 together, because they are small, high-leverage, and reduce the chance of silent frontend regressions.
- **Second milestone:** do Task 3 before adding major new desktop workflows.
- **Third milestone:** do Task 4 when the marketing/documentation surface is about to expand again.

## Definition of Done

- Root CI validates both the Swift app and `site/`.
- `site/` has one package-manager story.
- `AppController` stops being the long-term maintenance bottleneck.
- `site` interaction logic no longer depends on whole-page rerender and mass event rebinding.
