# VoicePi Epoch SemVer And First Release Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Adopt Epoch Semantic Versioning guidance for VoicePi, document it in repository instructions, and publish the first public release.

**Architecture:** Keep the existing tag-driven release workflow, but define a clear versioning contract for humans and agents. Treat the normal SemVer `MAJOR` position as `epoch * 1000 + technical_major`, start the project at `v1.0.0`, and reserve `v1000.0.0+` for future epoch shifts.

**Tech Stack:** Markdown, shell scripts, Git, GitHub Actions Releases

### Task 1: Document the versioning contract

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`

**Step 1: Add Epoch SemVer guidance to agent instructions**

Document:
- the numeric mapping `{epoch * 1000 + major}.minor.patch`
- when to bump epoch, major, minor, and patch
- the instruction that VoicePi starts at `v1.0.0`

**Step 2: Reflect the same strategy in user-facing docs**

Update release documentation so examples and release instructions use `v1.0.0` and explain why.

### Task 2: Verify docs and release entrypoints

**Files:**
- No additional files expected

**Step 1: Run workflow syntax validation**

Run: `ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].sort.each { |file| YAML.load(File.read(file)); puts "OK #{file}" }'`
Expected: PASS

**Step 2: Run release dry-run**

Run: `TAG_NAME=v1.0.0 ./Scripts/prepare_release.sh`
Expected: PASS and print release metadata for `v1.0.0`

### Task 3: Publish the first version

**Files:**
- No additional files expected

**Step 1: Commit the documentation changes**

Commit the versioning policy update with a docs-focused commit message.

**Step 2: Create the first release tag**

Create and push `v1.0.0`.

**Step 3: Confirm remote release status**

Inspect the GitHub Release and report the final published version URL.
