# Repository Guidelines

## Project Structure & Module Organization
`Sources/VoicePi/` contains the macOS menu-bar app code, including UI controllers, transcription clients, shortcut handling, and app coordination. Keep new production code in this module unless it is clearly test-only. `Tests/VoicePiTests/` holds Swift unit tests, and `Tests/*.sh` covers repository scripts and release helpers. `Scripts/` contains the supported developer and packaging entrypoints. Release metadata lives in `Casks/voicepi.rb`, and longer design notes belong in `docs/plans/`.

## Build, Test, and Development Commands
Use the checked-in scripts instead of ad hoc commands when possible.

- `./Scripts/test.sh` or `make test`: run Swift tests and shell script tests.
- `./Scripts/verify.sh` or `make verify`: run tests, build the debug target, and assemble `dist/debug/VoicePi.app`.
- `./Scripts/package.sh` or `make package`: run verification, stamp bundle versions, and export `dist/release/VoicePi.app`.
- `./Scripts/package_zip.sh` or `make zip`: create `dist/release/VoicePi-macOS.zip`.
- `make run`: open the debug app bundle.
- `make install`: copy the release app into `/Applications`.

## Coding Style & Naming Conventions
Follow the existing Swift style: four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties and methods, and small focused extensions or helper structs where they improve readability. Match the current file naming pattern such as `AppModel.swift` and `RemoteASRClient.swift`. Shell scripts use POSIX `sh`, start with `set -eu`, and should stay portable and explicit. No formatter or linter is configured, so keep diffs tidy and consistent with nearby code.

## Testing Guidelines
Swift tests use the `Testing` framework with `@Test` and `#expect`. Name Swift test files `*Tests.swift` and group test functions around observable behavior. Add shell regression tests in `Tests/` with a `_test.sh` suffix for script changes. Run `./Scripts/test.sh` before opening a PR; run `./Scripts/verify.sh` for changes that affect bundling, signing, or app startup.

## Commit & Pull Request Guidelines
Recent history uses Conventional Commit prefixes such as `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, and `chore:`; optional scopes like `refactor(SpeechRecorder):` are already in use. Keep commit subjects imperative and concise. PRs should explain user-facing impact, list verification steps, link related issues, and include screenshots when menu-bar UI, settings, or onboarding behavior changes. If a change affects releases, note updates to `Scripts/`, `.github/workflows/`, or `Casks/voicepi.rb`.

## Release Versioning
VoicePi uses Epoch Semantic Versioning inspired by Anthony Fu's proposal: `{epoch * 1000 + major}.minor.patch`. Treat the first numeric field as a combined public release channel and technical breaking-change counter. Use `PATCH` for backwards-compatible fixes, `MINOR` for backwards-compatible features, and increment the technical `major` for smaller incompatible changes that should still be progressive to adopt. Only bump the `epoch` for genuinely new eras of the product, which means a jump from `v999.x.x` to `v1000.0.0` or higher. The first public VoicePi release is `v1.0.0`, not `v0.x`, and all release tags must use the `v<version>` form so GitHub Actions can publish the release and refresh the Homebrew cask.

## Security & Configuration Tips
Do not commit real API keys, signing identities, or notarization secrets. Remote ASR and LLM credentials stay in local app configuration, while release signing should use environment variables such as `CODESIGN_IDENTITY`, `PACKAGE_VERSION`, and `PACKAGE_BUILD_VERSION`.
