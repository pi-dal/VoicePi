# AppUpdater Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Route non-Homebrew VoicePi installs through `AppUpdater` for direct in-app updates while preserving the Homebrew upgrade path for Homebrew-managed installs.

**Architecture:** Keep the existing GitHub release check as the source of truth for update availability and release notes, then add a small decision layer that chooses between the Homebrew flow and an `AppUpdater`-backed install flow. Update the release packaging so the published archive name matches the asset convention that `AppUpdater` expects.

**Tech Stack:** Swift 5.9, AppKit, SwiftPM, shell release scripts, `s1ntoneli/AppUpdater`

### Task 1: Lock the behavior with tests

**Files:**
- Modify: `Tests/VoicePiTests/AppControllerInteractionTests.swift`
- Modify: `Tests/package_zip_script_test.sh`
- Modify: `Tests/prepare_release_script_test.sh`

**Step 1: Write the failing tests**

- Add a pure decision test for update delivery selection:
  - Homebrew-managed installs choose the Homebrew flow.
  - Direct and unknown installs choose the in-app installer flow.
- Update shell tests to expect a versioned release asset name (`VoicePi-<version>.zip`) instead of the old fixed name.

**Step 2: Run the targeted tests to verify they fail**

Run: `swift test --filter AppControllerInteractionTests && sh Tests/package_zip_script_test.sh && sh Tests/prepare_release_script_test.sh`

Expected:
- Swift test compile or assertions fail because the new decision API does not exist yet.
- Shell tests fail because the scripts still emit `VoicePi-macOS.zip`.

### Task 2: Implement update-path selection and AppUpdater install flow

**Files:**
- Modify: `Package.swift`
- Modify: `Sources/VoicePi/AppUpdateChecker.swift`
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Optionally create: `Sources/VoicePi/HomebrewInstallationDetector.swift`

**Step 1: Add the dependency**

- Add `https://github.com/s1ntoneli/AppUpdater.git` to SwiftPM.

**Step 2: Add a pure delivery decision model**

- Introduce a small enum/model for installation source and update delivery selection.
- Keep it side-effect free so it stays cheap to test.

**Step 3: Detect Homebrew-managed installs**

- Implement a detector that checks for a usable `brew` executable and whether the `voicepi` cask is installed.
- Treat failures conservatively so non-Homebrew installs still get the in-app flow.

**Step 4: Wire in `AppUpdater`**

- Add a lazy `AppUpdater` wrapper configured for `pi-dal/VoicePi`.
- Use it only when the decision layer selects the in-app installer path.
- Preserve the existing Homebrew prompt for Homebrew-managed installs.

### Task 3: Make published assets AppUpdater-compatible

**Files:**
- Modify: `Scripts/package_zip.sh`
- Modify: `Scripts/prepare_release.sh`
- Modify: `Scripts/write_homebrew_cask.sh` if needed
- Modify: `Casks/voicepi.rb`
- Modify: `Tests/VoicePiTests/AppUpdateCheckerTests.swift`

**Step 1: Rename the release archive**

- Publish the ZIP as `VoicePi-<version>.zip`.
- Continue using the same app bundle contents.

**Step 2: Update consumers**

- Make the cask point to the renamed asset.
- Make the update checker prefer the versioned asset while remaining tolerant of older releases if needed.

### Task 4: Verify end to end

**Files:**
- No new files expected

**Step 1: Run targeted verification**

Run: `swift test --filter AppUpdateCheckerTests`
Run: `swift test --filter AppControllerInteractionTests`
Run: `sh Tests/package_zip_script_test.sh`
Run: `sh Tests/prepare_release_script_test.sh`

**Step 2: Run broader verification**

Run: `./Scripts/test.sh`

Expected:
- Swift tests pass.
- Shell script tests pass.
- No update-related regressions remain in the packaging pipeline.
