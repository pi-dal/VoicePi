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

Current screenshot inventory is optimized for the landing page and stored as `.webp` assets where possible.

Refresh the source PNGs with:

```sh
./Scripts/swiftw test --filter SiteScreenshotExporterTests/exportGalleryAssetsWritesExpectedFilesForBothThemes
```

The test exports fresh PNGs into a temporary `voicepi-site-screenshots-*` directory. Convert those PNGs to `.webp` before replacing the checked-in website assets.

## Content Source

The changelog timeline is injected at build time from:

```text
../docs/changelogs/*.md
```

The landing page also includes product copy about VoicePi's file-first configuration model. Keep that copy aligned with the main repository README when config layout, prompt storage, or migration behavior changes.
