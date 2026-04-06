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

Additional exported assets kept in the same directory:

1. `settings-about-sunny.png`
2. `settings-about-moon.png`

## Current Status

- The page currently displays the mode-switch panel, recording overlay, and settings home in both supported themes.
- The About panel is also exported in both themes for future use or replacement shots.
- If another product-facing capture is needed later, the next useful addition would be the permissions page or the update panel.

## Snapshot Export

`FloatingPanelSnapshotTests` now supports a generalized export entrypoint:

- `VOICEPI_SNAPSHOT_PATH`
- `VOICEPI_SNAPSHOT_THEME`
- `VOICEPI_SNAPSHOT_KIND`

Supported kinds:

- `mode-switch`
- `recording`
- `settings-home`
- `settings-about`

Generate a single snapshot with:

```sh
VOICEPI_SNAPSHOT_PATH=/tmp/voicepi-mode-switch-sunny.png \
VOICEPI_SNAPSHOT_THEME=light \
VOICEPI_SNAPSHOT_KIND=mode-switch \
swift test --filter FloatingPanelSnapshotTests
```

Generate the current site gallery set with:

```sh
for theme in light dark; do
  case "$theme" in
    light) suffix="sunny" ;;
    dark) suffix="moon" ;;
  esac

  for kind in mode-switch recording settings-home settings-about; do
    VOICEPI_SNAPSHOT_PATH="site/public/media/screenshots/${kind}-${suffix}.png" \
    VOICEPI_SNAPSHOT_THEME="$theme" \
    VOICEPI_SNAPSHOT_KIND="$kind" \
    swift test --filter FloatingPanelSnapshotTests
  done
done
```
