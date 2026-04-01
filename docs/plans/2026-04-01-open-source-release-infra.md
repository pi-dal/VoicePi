# VoicePi Open Source Release Infrastructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add CI, tagged release automation, Homebrew cask publishing support, and open-source repository metadata for VoicePi.

**Architecture:** Keep the existing `make` and `Scripts/*.sh` entrypoints as the single source of truth, then layer GitHub Actions on top of them. Publish a versioned zip asset to GitHub Releases, generate a matching Homebrew cask file from that release artifact, and document the flow in the README together with the MIT license.

**Tech Stack:** GitHub Actions, Swift Package Manager, shell scripts, Homebrew cask, Markdown

### Task 1: Add release metadata tests first

**Files:**
- Create: `Tests/homebrew_cask_script_test.sh`
- Modify: `Scripts/test.sh`

**Step 1: Write the failing shell test**

Add a repository test that expects a release helper to:
- accept app name, version, release URL, and SHA256
- write a valid `Casks/voicepi.rb`
- include the expected `version`, `sha256`, `url`, `name`, `desc`, `homepage`, and `app` stanza

**Step 2: Run the targeted test to verify RED**

Run: `sh Tests/homebrew_cask_script_test.sh`
Expected: FAIL because the cask-generation helper does not exist yet.

**Step 3: Wire the test into repository-level tests**

Ensure `./Scripts/test.sh` will pick up the new shell test automatically.

### Task 2: Implement release helper scripts

**Files:**
- Create: `Scripts/write_homebrew_cask.sh`
- Create: `Scripts/prepare_release.sh`
- Modify: `Scripts/package_zip.sh`

**Step 1: Implement the minimal cask writer**

Add a script that writes `Casks/voicepi.rb` from environment variables or CLI args with stable formatting.

**Step 2: Implement the release preparation helper**

Add a script that:
- derives the semantic version from a tag like `v1.2.3`
- runs `./Scripts/package_zip.sh`
- computes the release asset SHA256
- writes simple outputs consumable by GitHub Actions

**Step 3: Verify GREEN**

Run:
- `sh Tests/homebrew_cask_script_test.sh`
- `./Scripts/test.sh`

Expected: PASS

### Task 3: Add GitHub Actions workflows

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release.yml`

**Step 1: Add pull request / push CI**

Run `./Scripts/test.sh` on macOS for pushes to `main` and pull requests.

**Step 2: Add tagged release workflow**

Trigger on `v*` tags and:
- check out the repo
- run the release preparation helper
- create or update the GitHub Release with the packaged zip asset
- optionally update a Homebrew tap repo when the required secret and variable are present

**Step 3: Verify config integrity**

Run a local YAML parse / lint command against `.github/workflows/*.yml`.
Expected: PASS

### Task 4: Add Homebrew cask scaffolding

**Files:**
- Create: `Casks/voicepi.rb`

**Step 1: Commit a bootstrap cask file**

Create a cask template that points at the release asset URL format and can be rewritten by automation on each release.

**Step 2: Verify the template shape**

Run: `sh Tests/homebrew_cask_script_test.sh`
Expected: PASS against the generated cask output.

### Task 5: Add MIT license and README open-source metadata

**Files:**
- Create: `LICENSE`
- Modify: `README.md`

**Step 1: Add repository metadata**

Add:
- CI badge
- latest release badge
- license badge
- Homebrew badge/link

**Step 2: Document installation and release flow**

Document:
- `brew tap ...`
- `brew install --cask ...`
- tagged release behavior
- required GitHub secret / variable for Homebrew tap publishing

**Step 3: Verify docs render cleanly**

Read the updated README and confirm links and command snippets are coherent.

### Task 6: Run end-to-end verification

**Files:**
- No additional code changes expected

**Step 1: Run repository tests**

Run: `./Scripts/test.sh`
Expected: PASS

**Step 2: Run a release dry-run helper**

Run: `TAG_NAME=v0.1.0 ./Scripts/prepare_release.sh`
Expected: PASS with a packaged zip, computed SHA256, and generated metadata outputs.

**Step 3: Run workflow syntax validation**

Run a local YAML parser over `.github/workflows/*.yml`.
Expected: PASS
