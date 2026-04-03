# GitHub Update Checker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a GitHub-release-backed update checker that can run at launch, expose a manual check action in the About section, and prompt users to install updates via Homebrew commands.

**Architecture:** Keep network and version-comparison logic in a small `Foundation`-only update service so it can be tested without AppKit. Let `AppController` own automatic checks and the update prompt, while `StatusBarController` only hosts the About button and status text for manual checks.

**Tech Stack:** Swift 5.9, AppKit, Foundation, URLSession, Testing

### Task 1: Add update checker tests

**Files:**
- Create: `Tests/VoicePiTests/AppUpdateCheckerTests.swift`
- Modify: `Tests/VoicePiTests/AppControllerInteractionTests.swift`

**Step 1: Write the failing tests**

Cover:
- parsing GitHub `releases/latest` payload into an update candidate
- comparing local bundle version against release tag versions
- generating the Homebrew install and upgrade instructions
- suppressing repeated automatic prompts for the same release while allowing manual checks

**Step 2: Run tests to verify they fail**

Run: `swift test --filter AppUpdateCheckerTests`

Expected: FAIL because the update checker types do not exist yet.

### Task 2: Implement the pure update logic

**Files:**
- Create: `Sources/VoicePi/AppUpdateChecker.swift`

**Step 1: Write the minimal implementation**

Add:
- GitHub release decoding structs
- semantic version parsing/comparison
- update result model
- GitHub latest release fetcher using `URLSession`
- Homebrew command copy builder
- prompt suppression helper for automatic checks

**Step 2: Run tests to verify they pass**

Run: `swift test --filter AppUpdateCheckerTests`

Expected: PASS

### Task 3: Wire the feature into startup and About

**Files:**
- Modify: `Sources/VoicePi/AppCoordinator.swift`
- Modify: `Sources/VoicePi/StatusBarController.swift`

**Step 1: Write the failing integration tests**

Add a test covering the prompt suppression policy in `AppControllerInteractionTests.swift`.

**Step 2: Implement the UI integration**

Add:
- automatic startup check task in `AppController.start()`
- delegate action for manual checks from the About section
- About section button and status label
- AppKit alert that recommends Homebrew and offers command copying plus release-page opening

**Step 3: Run targeted tests**

Run: `swift test --filter AppControllerInteractionTests`

Expected: PASS

### Task 4: Verify end to end

**Files:**
- Modify: `README.md` only if the new update behavior needs user-facing documentation

**Step 1: Run focused and full verification**

Run:
- `swift test --filter AppUpdateCheckerTests`
- `swift test --filter AppControllerInteractionTests`
- `./Scripts/test.sh`

Expected: PASS
