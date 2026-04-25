# About Tab Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refresh the Settings About tab so the brand card is more readable, the credits note reuses the legacy copy, and the page footer exposes open-source metadata links.

**Architecture:** Keep the change local to the existing AppKit About-tab builders in `StatusBarController.swift`. Lock the user-visible copy and footer actions with focused layout tests so the page can keep evolving without regressing on this specific composition.

**Tech Stack:** Swift 6, AppKit, Testing

### Task 1: Lock the requested About-tab copy in tests

**Files:**
- Modify: `Tests/VoicePiTests/SettingsWindowLayoutTests.swift`

**Step 1: Write the failing test**

Add a layout test that shows the About section and expects:
- the legacy credits paragraph from the old About note
- the legacy attribution lines (`Built With Love By`, `Inspired by`, `this tweet`)
- footer links for `License (MIT)` and the repository link

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests/aboutSectionUsesLegacyCreditsCopyAndOpenSourceFooter`

Expected: FAIL because the current About section still shows the newer credits copy and has no footer links.

**Step 3: Write minimal implementation**

Update the About builders in `Sources/VoicePi/StatusBarController.swift` so the credits card and footer render the requested text and links.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests/aboutSectionUsesLegacyCreditsCopyAndOpenSourceFooter`

Expected: PASS

### Task 2: Lock the brand-card readability adjustment

**Files:**
- Modify: `Tests/VoicePiTests/SettingsWindowLayoutTests.swift`

**Step 1: Write the failing test**

Add a layout test that shows the About section and expects the brand card icon width to be at least `88` and the `VoicePi` title font size to be at least `34`.

**Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests/aboutSectionUsesLargerBrandTreatment`

Expected: FAIL because the current icon is `72` and the title font is `30`.

**Step 3: Write minimal implementation**

Increase the brand icon size, improve the title styling, and preserve the existing buttons/version metadata.

**Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests/aboutSectionUsesLargerBrandTreatment`

Expected: PASS

### Task 3: Run focused verification

**Files:**
- Modify: `Sources/VoicePi/StatusBarController.swift`
- Verify: `Tests/VoicePiTests/SettingsWindowLayoutTests.swift`

**Step 1: Run the focused About layout tests**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests/aboutSection`

Expected: PASS for the new About-specific coverage.

**Step 2: Run the broader settings layout slice if the focused tests are clean**

Run: `./Scripts/test.sh --filter SettingsWindowLayoutTests`

Expected: PASS
