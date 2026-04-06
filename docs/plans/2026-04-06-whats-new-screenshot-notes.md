# What's New Screenshot Notes

Static screenshots for the GitHub Pages site live under `site/public/media/screenshots/`.

## Planned Assets

1. `hero-app.png`
   - A polished product-facing screenshot suitable for the landing section.
2. `floating-overlay.png`
   - The live recording capsule with transcript and waveform visible.
3. `mode-switch.png`
   - The mode-switch floating panel.
   - This is currently generated through `FloatingPanelSnapshotTests` by setting `VOICEPI_MODE_SWITCH_SNAPSHOT_PATH`.
4. `settings-overview.png`
   - A settings screenshot that captures the prompt workspace and remote ASR / LLM configuration area in one frame.

## Current Status

- `mode-switch.png` is available and exported into the site media directory.
- The other screenshots still need to be captured or replaced with final selections.

## Mode-Switch Export

Generate the current mode-switch snapshot with:

```sh
VOICEPI_MODE_SWITCH_SNAPSHOT_PATH=/tmp/voicepi-mode-switch.png swift test --filter FloatingPanelSnapshotTests
```

Then copy the exported file into:

```text
site/public/media/screenshots/mode-switch.png
```
