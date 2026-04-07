# Menubar Prompt Binding Design

**Date:** 2026-04-07

## Goal

Move app and website binding capture out of the settings-only prompt editor flow and make it usable from the menu bar, while keeping the existing prompt binding rules consistent across all entry points.

## Problem

Today `Capture Frontmost App` and `Capture Current Website` only exist inside the settings prompt editor sheet. That makes the feature hard to discover and effectively unavailable during normal menu-bar use. The current implementation also keeps capture-and-merge behavior close to UI text fields, which makes it easy for a future menubar flow to drift from the settings flow.

## UX Direction

The menubar becomes the primary quick-entry surface for prompt bindings:

- Add capture actions under `Text Processing -> Refinement Prompt`
- Capture the current frontmost app bundle ID or current browser host first
- Immediately present a lightweight picker popup after capture
- Let the picker bind to the active prompt, choose another prompt, or create a new prompt

Settings stays as the full editor for prompt title, body, and bulk binding editing.

## Binding Rules

Both settings and menubar must follow the same write path:

- `user` prompt: append the normalized binding directly
- `starter` prompt: duplicate to a new `user` prompt, then append the binding
- `builtInDefault`: create a new `user` prompt, then append the binding
- existing bindings are normalized and deduplicated before saving

This keeps the behavior aligned with the current source-of-truth rules and avoids mutating non-user presets.

## Architecture

Introduce a small prompt binding helper layer that owns:

- binding kind normalization (`appBundleID` vs `websiteHost`)
- merge and dedupe behavior
- rules for selecting or creating the final editable `user` prompt
- user-facing status payloads for success, duplicate, and capture failure

`StatusBarController` uses that helper for menubar actions. `SettingsWindowController` uses the same helper instead of re-implementing merge logic around text fields.

## Menubar Flow

1. User opens `Text Processing -> Refinement Prompt`
2. User chooses `Capture Frontmost App` or `Capture Current Website`
3. VoicePi captures and normalizes the binding through `PromptDestinationInspector`
4. If capture succeeds, VoicePi immediately opens a lightweight picker popup
5. Choosing a target runs the shared binding helper and refreshes menu/settings state

If capture fails, VoicePi does not enter binding mode and instead shows a transient status message.

## Constraints

- Menubar capture actions are disabled while the settings prompt editor sheet is open, so `promptWorkspaceDraft` never races the live model state
- Website capture support remains limited to the current Safari and Chromium-family browser URL readers
- The new flow should avoid introducing AppKit-heavy logic into unit tests; most new behavior should stay in pure model/helper code

## Verification

The change should be verified with:

- new prompt binding helper tests for user/starter/default behavior
- menu presentation tests for new capture action titles
- settings tests confirming shared merge behavior still normalizes and deduplicates values
- targeted Swift test runs for the changed areas
- repository test script before completion
