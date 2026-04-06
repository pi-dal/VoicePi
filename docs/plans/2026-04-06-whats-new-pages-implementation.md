# GitHub Pages What's New Site Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build and ship a single-page GitHub Pages site for VoicePi, starting with screenshot/static-asset organization and then adding the Vite-based landing page, changelog window, and deployment workflow.

**Architecture:** Add a standalone `site/` Vite application that builds to static assets for GitHub Pages. Keep release-note content sourced from `docs/changelogs/*.md`, store screenshots and other web assets in a dedicated static directory, and use a small tested data layer to parse changelog Markdown into the website UI.

**Tech Stack:** Vite, TypeScript, vanilla DOM/CSS, Vitest, GitHub Actions, existing repository Markdown assets

### Task 1: Create the website workspace and static asset layout

**Files:**
- Create: `site/package.json`
- Create: `site/package-lock.json`
- Create: `site/tsconfig.json`
- Create: `site/vite.config.ts`
- Create: `site/index.html`
- Create: `site/src/main.ts`
- Create: `site/src/styles.css`
- Create: `site/public/`
- Create: `site/public/media/`
- Create: `site/public/media/screenshots/`
- Create: `site/public/media/icons/`
- Create: `site/README.md`

**Step 1: Create the failing build scaffold**

Initialize the Vite app structure and add npm scripts for:

- `dev`
- `build`
- `preview`
- `test`

Do not implement the real page yet. Keep `main.ts` minimal enough that the project installs but does not yet satisfy product behavior.

**Step 2: Run install and verify baseline tooling**

Run: `cd site && npm install`
Expected: install succeeds and creates `package-lock.json`

**Step 3: Run the empty baseline tests/build**

Run: `cd site && npm run build`
Expected: PASS with a minimal starter build

**Step 4: Create static asset directories**

Add:

- `site/public/media/screenshots/`
- `site/public/media/icons/`

Copy the current VoicePi icon into the site media area so the website has a local static asset reference.

**Step 5: Commit**

```bash
git add site
git commit -m "feat(site): scaffold Vite workspace and asset layout"
```

### Task 2: Capture and organize initial screenshots

**Files:**
- Create: `site/public/media/screenshots/.gitkeep`
- Create: `docs/plans/2026-04-06-whats-new-screenshot-notes.md`
- Modify: `site/README.md`

**Step 1: Document the screenshot targets**

Write a short notes file listing:

- landing / primary product screenshot
- floating overlay screenshot
- mode switch screenshot
- settings screenshot

Include capture intent for each so replacement assets remain consistent later.

**Step 2: Capture the mode-switch screenshot**

Use local automation to:

- launch the debug app bundle if needed
- trigger or otherwise surface the mode-switch UI
- capture a clean screenshot to `site/public/media/screenshots/`

If fully automating the mode-switch state is not practical, capture the screenshot manually with terminal-assisted macOS automation and note the exact reproduction steps in the notes file.

**Step 3: Place any immediately available screenshots in the static directory**

Name files predictably, for example:

- `hero-app.png`
- `floating-overlay.png`
- `mode-switch.png`
- `settings-overview.png`

**Step 4: Update the website README**

Explain where screenshots live and which ones may still need replacement later.

**Step 5: Commit**

```bash
git add site/public/media/screenshots site/README.md docs/plans/2026-04-06-whats-new-screenshot-notes.md
git commit -m "chore(site): add screenshot asset inventory"
```

### Task 3: Add a tested changelog data pipeline

**Files:**
- Create: `site/src/lib/changelog.ts`
- Create: `site/src/lib/changelog.test.ts`
- Create: `site/src/types.ts`
- Modify: `site/package.json`
- Modify: `site/vite.config.ts`

**Step 1: Write the failing tests**

Add Vitest coverage for:

- discovering `docs/changelogs/v*.md`
- parsing title/version/sections from Markdown
- sorting releases newest first
- treating the newest release as the default active item

**Step 2: Run test to verify it fails**

Run: `cd site && npm test -- --run`
Expected: FAIL because the parser/data loader does not exist yet

**Step 3: Write minimal implementation**

Implement a small changelog loader that:

- reads markdown files at build time
- extracts version title and section bodies
- returns normalized release objects for UI rendering

**Step 4: Run tests and build**

Run:

- `cd site && npm test -- --run`
- `cd site && npm run build`

Expected: PASS

**Step 5: Commit**

```bash
git add site
git commit -m "feat(site): add changelog content pipeline"
```

### Task 4: Build the page shell and interaction state with tests first

**Files:**
- Create: `site/src/lib/site-state.ts`
- Create: `site/src/lib/site-state.test.ts`
- Modify: `site/src/main.ts`
- Modify: `site/src/styles.css`
- Modify: `site/index.html`

**Step 1: Write the failing tests**

Add tests for state behavior covering:

- default install tab is `Homebrew`
- theme resolves to `Sunny` or `Moon`
- newest changelog entry is active by default
- selecting a version updates the active release
- expanding/collapsing versions updates state correctly

**Step 2: Run test to verify it fails**

Run: `cd site && npm test -- --run`
Expected: FAIL because the state module and UI hooks do not exist yet

**Step 3: Write minimal implementation**

Implement the smallest state layer needed for:

- install tab switching
- explicit theme switching
- active changelog version selection
- release expansion/collapse behavior

**Step 4: Run tests**

Run: `cd site && npm test -- --run`
Expected: PASS

**Step 5: Commit**

```bash
git add site
git commit -m "feat(site): add landing and changelog interaction state"
```

### Task 5: Implement the final single-page design

**Files:**
- Modify: `site/index.html`
- Modify: `site/src/main.ts`
- Modify: `site/src/styles.css`
- Modify: `site/public/media/`

**Step 1: Implement the Landing section**

Add:

- icon
- product intro
- embedded install tabs
- explicit `Sunny` / `Moon` switcher
- highlights block

**Step 2: Implement the Changelog window**

Add:

- floating changelog frame
- version rail/list
- active release panel with independent scrolling
- animated transitions between versions

**Step 3: Implement the Footer / Footprint**

Add:

- author
- GitHub link
- repository link
- About-inspired small line

**Step 4: Add progressive atmospheric visuals**

Implement:

- theme-specific atmosphere
- lightweight motion
- reduced-motion fallback
- non-WebGL/CSS fallback when richer rendering is unavailable

**Step 5: Run tests and build**

Run:

- `cd site && npm test -- --run`
- `cd site && npm run build`

Expected: PASS

**Step 6: Commit**

```bash
git add site
git commit -m "feat(site): implement VoicePi what's new landing page"
```

### Task 6: Publish through GitHub Pages

**Files:**
- Create: `.github/workflows/pages.yml`
- Modify: `README.md`
- Modify: `site/README.md`

**Step 1: Write the workflow**

Add a dedicated GitHub Pages workflow that:

- installs site dependencies
- runs the site build
- uploads the static artifact
- deploys to GitHub Pages

**Step 2: Document local website commands**

Update docs with:

- where the site lives
- how to run it locally
- how changelog content is sourced

**Step 3: Run final verification**

Run:

- `cd site && npm test -- --run`
- `cd site && npm run build`

Expected: PASS

**Step 4: Commit**

```bash
git add .github/workflows/pages.yml README.md site/README.md
git commit -m "ci(site): add GitHub Pages deployment workflow"
```

### Task 7: Final repository verification

**Files:**
- Modify as needed based on verification results

**Step 1: Run targeted repository verification**

Run:

- `cd site && npm test -- --run`
- `cd site && npm run build`

**Step 2: Run existing repository tests if touched outside `site/`**

Run: `./Scripts/test.sh`
Expected: PASS

**Step 3: Review final git diff**

Confirm:

- screenshots are in the static asset directory
- site assets are named predictably
- changelog content is driven from `docs/changelogs/*.md`
- Pages workflow is isolated from the release workflow

**Step 4: Commit any follow-up fixes**

```bash
git add <files>
git commit -m "chore(site): polish what's new site integration"
```
