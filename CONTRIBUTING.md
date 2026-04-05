# Contributing to VoicePi

Thanks for helping improve VoicePi.

## Development setup

1. Fork and clone the repository.
2. Work from the project root.
3. Run:

```sh
./Scripts/verify.sh
```

## Coding expectations

- Follow existing Swift and shell style used in this repository.
- Keep changes focused and avoid unrelated refactors in the same PR.
- Add or update tests for behavior changes.
- Prefer repository scripts (`./Scripts/test.sh`, `./Scripts/verify.sh`) over ad hoc commands.

## Pull request checklist

- Use a clear, imperative commit message (Conventional Commit style is preferred).
- Explain user-facing impact in the PR description.
- List the commands you ran for verification.
- Include screenshots when UI behavior changes.

## Release-related contributions

- If your change should appear in the next release notes, coordinate with maintainers to include it in `docs/changelogs/v<version>.md`.
