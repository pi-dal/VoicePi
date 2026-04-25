# Repository Guidelines

## Project Structure & Module Organization
`Sources/VoicePi/` contains the macOS menu-bar app code, including UI controllers, transcription clients, shortcut handling, and app coordination. Keep new production code in this module unless it is clearly test-only. `Tests/VoicePiTests/` holds Swift unit tests, and `Tests/*.sh` covers repository scripts and release helpers. `Scripts/` contains the supported developer and packaging entrypoints. Release metadata lives in `Casks/voicepi.rb`; release changelog files live in `docs/changelogs/`; and longer design notes belong in `docs/plans/`.

## Build, Test, and Development Commands
Use the checked-in scripts instead of ad hoc commands when possible.

- Swift toolchain: use the repo's mise-managed Swift 6.3 toolchain, not the system `swift`/`swiftc`. Prefer `./Scripts/swiftw`, `./Scripts/swiftcw`, or `mise exec -- swift ...` / `mise exec -- swiftc ...` when running direct Swift commands.

- `./Scripts/test.sh` or `make test`: run Swift tests and shell script tests.
- `./Scripts/verify.sh` or `make verify`: run tests, build the debug target, and assemble `dist/debug/VoicePi.app`.
- `./Scripts/benchmark.sh`: print the current performance benchmark snapshot, including deterministic legacy-vs-current budgets and lightweight microbenchmark samples for pure performance helpers.
- `./Scripts/package.sh` or `make package`: run verification, stamp bundle versions, and export `dist/release/VoicePi.app`.
- `./Scripts/package_zip.sh`: create `dist/release/VoicePi-<version>.zip` (versioned release archive).
- `make zip`: create `dist/release/VoicePi-macOS.zip` (internal testing archive).
- `make run`: open the debug app bundle.
- `make install`: copy the release app into `/Applications`.

## Coding Style & Naming Conventions
Follow the existing Swift style: four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties and methods, and small focused extensions or helper structs where they improve readability. Match the current file naming pattern such as `AppModel.swift` and `RemoteASRClient.swift`. Shell scripts use POSIX `sh`, start with `set -eu`, and should stay portable and explicit. No formatter or linter is configured, so keep diffs tidy and consistent with nearby code.

## Testing Guidelines
Swift tests use the `Testing` framework with `@Test` and `#expect`. Name Swift test files `*Tests.swift` and group test functions around observable behavior. Add shell regression tests in `Tests/` with a `_test.sh` suffix for script changes. Run `./Scripts/test.sh` before opening a PR; run `./Scripts/verify.sh` for changes that affect bundling, signing, or app startup.

For performance-sensitive changes, treat tests and benchmarks as a pair:

- Add behavior tests first for every new abstraction or refactor that changes latency-sensitive logic.
- Prefer deterministic performance budget tests for policy/value types such as timing plans, polling cadence, and routing decisions.
- When introducing or changing a benchmark entrypoint, add a shell regression test that locks the script contract and output shape.
- Run `./Scripts/benchmark.sh` after performance work and include the relevant budget deltas or microbenchmark samples in your notes, PR description, or handoff.

Interpret benchmark output conservatively:

- `Budgets` are the strongest signal. They compare the previous built-in latency or polling cost against the current implementation and can justify claims such as “this path now blocks 70% less by design.”
- `Recent sessions` summarize persisted successful runs from the in-app latency trace pipeline. Use them as the best available real-session signal for median first-partial, stop-to-transcript, and stop-to-delivery timings, but only after enough sessions have been recorded locally.
- `Microbenchmarks` are useful for catching regressions in pure helpers, but they are machine-dependent and should not be used alone to claim end-to-end UX improvements.
- Do not claim the whole app is faster unless the changed path is directly represented by a budget reduction or by end-to-end measurements gathered from the latency trace/logging pipeline.

Current benchmark scope:

- text injection blocking latency for ASCII and CJK paths
- modeled post-recording stop-to-delivery latency under fixed transcript-finalize and refine assumptions
- post-injection Accessibility polling load
- floating panel repeated-partial layout invalidations
- recent real-session latency summaries persisted from the recording trace reporter
- pure helper microbenchmarks such as latency trace reporting and execution-plan construction

## Commit & Pull Request Guidelines
Recent history uses Conventional Commit prefixes such as `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, and `chore:`; optional scopes like `refactor(SpeechRecorder):` are already in use. Keep commit subjects imperative and concise. PRs should explain user-facing impact, list verification steps, link related issues, and include screenshots when menu-bar UI, settings, or onboarding behavior changes. If a change affects releases, note updates to `Scripts/`, `.github/workflows/`, or `Casks/voicepi.rb`.

## Release Versioning
VoicePi uses Epoch Semantic Versioning inspired by Anthony Fu's proposal: `{epoch * 1000 + major}.minor.patch`. Treat the first numeric field as a combined public release channel and technical breaking-change counter. Use `PATCH` for backwards-compatible fixes, `MINOR` for backwards-compatible features, and increment the technical `major` for smaller incompatible changes that should still be progressive to adopt. Only bump the `epoch` for genuinely new eras of the product, which means a jump from `v999.x.x` to `v1000.0.0` or higher. The first public VoicePi release is `v1.0.0`, not `v0.x`, and all release tags must use the `v<version>` form so GitHub Actions can publish the release and refresh the Homebrew cask.

## AppUpdater Release Contract
For in-app updates to continue working from GitHub Releases, every release should follow this format:

- Tag format must be `v<version>` (example: `v1.4.0`), and app bundle version should match the same numeric version without the `v` prefix.
- Publish a zip asset containing the app bundle at the archive root (`VoicePi.app/...`), not nested in extra directories.
- Preferred asset name is `VoicePi-<version>.zip` (example: `VoicePi-1.4.0.zip`).
- `VoicePi-macOS.zip` is still supported as a compatibility alias, but use the versioned name as the default.
- Keep the asset type as a normal `.zip` (`application/zip`), because updater selection logic is zip-based.
- Use a published GitHub Release (not draft) on `pi-dal/VoicePi`; prereleases are not used for normal update flow.
- Release notes should stay in the GitHub Release body, because that text is surfaced in the in-app update panel.

## Release Changelog Workflow (Required)
Every tagged release must include human-readable changelog content.

1. Before tagging, copy `docs/changelogs/TEMPLATE.md` to `docs/changelogs/v<version>.md` (for example `docs/changelogs/v1.4.0.md`) and fill it with user-visible changes since the previous tag.
2. Use this minimum structure in the GitHub Release body:
   - `## Highlights`
   - `## Added`
   - `## Changed`
   - `## Fixed`
   - `## Breaking Changes` (omit only when none)
3. Keep items concise and user-facing (avoid internal refactor-only noise unless it changes behavior).
4. If a section has no items, write `- None` so the release note format stays consistent.
5. Publish the release (not draft) with tag `v<version>` and the matching zip asset required by the AppUpdater contract.
6. The GitHub `Release` workflow reads `docs/changelogs/v<version>.md` and fails if the file is missing.

## Security & Configuration Tips
Do not commit real API keys, signing identities, or notarization secrets. Remote ASR and LLM credentials stay in local app configuration, while release signing should use environment variables such as `CODESIGN_IDENTITY`, `PACKAGE_VERSION`, and `PACKAGE_BUILD_VERSION`.
