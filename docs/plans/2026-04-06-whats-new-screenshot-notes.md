# What's New Screenshot Notes

Static screenshots for the GitHub Pages site live under `site/public/media/screenshots/`.

## Current Site Assets

The site now uses paired Sunny / Moon exports for the screenshot gallery:

1. `mode-switch-sunny.png`
2. `mode-switch-moon.png`
3. `recording-sunny.png`
4. `recording-moon.png`
5. `settings-home-sunny.png`
6. `settings-home-moon.png`

## Current Status

- The page currently displays the mode-switch panel, recording overlay, and settings home in both supported themes.
- The export pipeline now renders the floating panels off-screen and composes the settings overview from real settings window captures.
- If another product-facing capture is needed later, the next useful additions would be a dedicated permissions collage or an update panel export.

## Snapshot Export

`SiteScreenshotExporterTests` now exercises the reusable screenshot exporter and writes the current PNG gallery set into a temporary directory.

Generate the current site gallery set with:

```sh
./Scripts/swiftw test \
  --filter SiteScreenshotExporterTests/exportGalleryAssetsWritesExpectedFilesForBothThemes
```

The test creates a fresh `voicepi-site-screenshots-*` directory under the system temporary folder containing:

1. `mode-switch-sunny.png`
2. `mode-switch-moon.png`
3. `recording-sunny.png`
4. `recording-moon.png`
5. `settings-home-sunny.png`
6. `settings-home-moon.png`

Convert those PNGs to `.webp` before replacing the checked-in website assets under `site/public/media/screenshots/`.
