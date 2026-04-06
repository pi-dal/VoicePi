# VoicePi Site

Static website workspace for the GitHub Pages `What's New` page.

## Local Commands

```sh
cd site
pnpm install
pnpm dev
pnpm test -- --run
pnpm typecheck
pnpm build
```

## Media

- `public/media/icons/` stores the website-local icon assets
- `public/media/screenshots/` stores screenshots used by the landing page

Current screenshot inventory starts with the generated `mode-switch.png` asset.

## Content Source

The changelog timeline is injected at build time from:

```text
../docs/changelogs/*.md
```
