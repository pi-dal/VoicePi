# Site Hero Character Refinement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refine the site hero desk-scene figure so the character reads as a normal minimalist seated person with a coherent head, hair, torso, and arm pose.

**Architecture:** Keep the existing hero scene in the site renderer and implement the refinement as a targeted DOM-plus-CSS update. Preserve the overall desk composition, but rebuild the character anatomy with a smaller set of stable layers and clearer z-ordering. Verify the result through render tests, typecheck, and site tests.

**Tech Stack:** TypeScript, Vite, Vitest, CSS

### Task 1: Lock the intended character structure in the renderer test

**Files:**
- Modify: `site/src/lib/render.test.ts`
- Modify: `site/src/lib/render.ts` if test expectations require new scene-character markup

**Step 1: Write the failing test**

Add or update the hero scene test so it asserts the refined character structure that the CSS will depend on. Keep coverage focused on DOM structure rather than visual details. The test should at minimum confirm:

- the hero still renders `class="scene-character"`
- the refined character still includes hair, head, neck, torso, upper arm, forearm, and hand layers
- any newly introduced layer for silhouette support is present exactly once

**Step 2: Run test to verify it fails**

Run:

```bash
cd site && pnpm test -- run site/src/lib/render.test.ts
```

Expected: FAIL because the expected hero scene structure does not match the current renderer output.

**Step 3: Write minimal implementation**

Update `site/src/lib/render.ts` so the `.scene-character` markup matches the intended refined structure while keeping the surrounding hero scene unchanged.

Guidelines:

- keep the current scene container and nearby scene elements untouched
- preserve existing class names where possible to minimize churn
- add at most one new character layer if needed for a stable silhouette

**Step 4: Run test to verify it passes**

Run:

```bash
cd site && pnpm test -- run site/src/lib/render.test.ts
```

Expected: PASS for the updated hero scene structure test.

**Step 5: Commit**

```bash
git add site/src/lib/render.test.ts site/src/lib/render.ts
git commit -m "test(site): lock refined hero character structure"
```

### Task 2: Rebuild the character anatomy in CSS

**Files:**
- Modify: `site/src/styles.css`

**Step 1: Write the failing test**

Use the renderer-level expectations from Task 1 as the guardrail. No CSS snapshot test is required. The failure condition here is the current visual implementation not matching the approved design.

**Step 2: Run test to verify the current scene still passes structural tests**

Run:

```bash
cd site && pnpm test -- run site/src/lib/render.test.ts
```

Expected: PASS, confirming DOM structure is stable before CSS work begins.

**Step 3: Write minimal implementation**

Refactor the `.scene-character*` rules in `site/src/styles.css` to produce the approved minimalist side-profile figure.

Required CSS outcomes:

- replace the blob-like hair with a coherent short-hair silhouette
- make the head shape read as one skull shape with a subtle face-plane treatment
- shorten and simplify the neck
- extend and rebalance the torso so the body does not feel compressed
- reconnect shoulder, upper arm, forearm, and hand into one believable forward-working pose
- remove the current hidden-forearm behavior
- keep the figure visually subordinate to the hero copy and install dialog

Guardrails:

- do not redesign the monitor, chair, desk, coffee, or install panel
- do not introduce decorative facial features
- do not add motion or flourish to compensate for anatomy

**Step 4: Run focused verification**

Run:

```bash
cd site && pnpm test -- run site/src/lib/render.test.ts
cd site && pnpm typecheck
cd site && pnpm test
```

Expected:

- render test PASS
- typecheck PASS
- full site test suite PASS

**Step 5: Commit**

```bash
git add site/src/styles.css
git commit -m "feat(site): refine hero character anatomy"
```

### Task 3: Final verification of the site hero scene

**Files:**
- No new files expected

**Step 1: Run final verification**

Run:

```bash
cd site && pnpm typecheck
cd site && pnpm test
```

Expected: PASS across the site checks.

**Step 2: Self-review against the design**

Validate manually in code against `docs/plans/2026-04-09-site-hero-character-refinement-design.md`:

- hair is coherent
- head/face read as one head
- forearm is visible
- torso/arm connection is believable
- character remains visually secondary

**Step 3: Commit**

```bash
git add site/src/lib/render.ts site/src/lib/render.test.ts site/src/styles.css
git commit -m "chore(site): verify hero character refinement"
```
