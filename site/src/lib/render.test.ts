import { describe, expect, test } from "vitest";

import { createSiteState, selectHighlight, selectVersion } from "./site-state";
import { renderApp } from "./render";
import type { ChangelogEntry } from "../types";

const entries: ChangelogEntry[] = [
  {
    slug: "v1.3.2",
    version: "1.3.2",
    title: "VoicePi v1.3.2",
    sections: [
      {
        title: "Highlights",
        body: "Latest release summary."
      },
      {
        title: "Fixed",
        body: "- Improved export flow"
      }
    ]
  },
  {
    slug: "v1.3.1",
    version: "1.3.1",
    title: "VoicePi v1.3.1",
    sections: [
      {
        title: "Highlights",
        body: "Previous release summary."
      }
    ]
  }
];

describe("renderApp", () => {
  test("renders the simplified landing structure with hero, highlights, changelog, and footprint", () => {
    const state = createSiteState(entries, "sunny");
    const html = renderApp(state);

    expect(html).toContain('class="hero"');
    expect(html).toContain("Become part of the flow.");
    expect(html).not.toContain("Homebrew keeps it easy.");
    expect(html).toContain("Download Latest Release");
    expect(html).toContain(">Sunny<");
    expect(html).toContain(">Moonlight<");
    expect(html).not.toContain('class="token-command"');
    expect(html).not.toContain('class="token-subcommand"');
    expect(html).not.toContain('class="token-flag"');

    expect(html).toContain('id="highlights-title"');
    expect(html).toContain('data-highlight-link="mode-cycle"');
    expect(html).toContain('data-highlight-link="recording-overlay"');
    expect(html).toContain('data-highlight-frame="mode-cycle"');
    expect(html).toContain('data-highlight-frame="recording-overlay"');
    expect(html).toContain('href="#highlight-frame-mode-cycle"');
    expect(html).toContain("/media/screenshots/mode-switch-sunny.png");
    expect(html).toContain("/media/screenshots/mode-switch-moon.png");

    expect(html).toContain('id="changelog-title"');
    expect(html).toContain("VoicePi v1.3.2");
    expect(html).toContain('data-version="1.3.1"');
    expect(html).toContain("release-panel-scroll");

    expect(html).toContain(">Website<");
    expect(html).toContain(">GitHub<");
    expect(html).toContain(">Repository<");
  });

  test("shows the latest version by default without rendering expand or collapse controls", () => {
    const state = createSiteState(entries, "moon");
    const html = renderApp(state);

    expect(html).toContain('data-version="1.3.2"');
    expect(html).toContain("Latest release summary.");
    expect(html).toContain('class="release-pill-preview"');
    expect(html).not.toContain('data-toggle-version="1.3.2"');
    expect(html).not.toContain(">Expand<");
    expect(html).not.toContain(">Collapse<");
  });

  test("moves the inline release preview with the active version", () => {
    const state = selectVersion(createSiteState(entries, "sunny"), "1.3.1");
    const html = renderApp(state);

    expect(html.match(/class="release-pill-preview"/g)?.length).toBe(1);
    expect(html).toContain('<article class="release-pill is-active">');
    expect(html).toContain("Previous release summary.");
    expect(html).toContain("<strong>Highlights:</strong> Previous release summary.");
  });

  test("marks the first highlight button and frame as active by default", () => {
    const state = createSiteState(entries, "sunny");
    const html = renderApp(state);

    expect(html).toContain('highlight-nav-button is-active');
    expect(html).toContain('gallery-frame is-active');
    expect(html.match(/gallery-frame is-active/g)?.length).toBe(1);
  });

  test("uses product-facing copy in the highlights navigation and gallery header", () => {
    const state = createSiteState(entries, "sunny");
    const html = renderApp(state);

    expect(html).toContain("The rhythm of your work, captured.");
    expect(html).toContain("Focused UI. Daytime or night.");
    expect(html).not.toContain("Each section on the left maps to one explanation surface on the right.");
    expect(html).not.toContain("Click any section on the left to scroll this window to its paired explanation.");
  });

  test("renders the redesigned hero as a desk scene with a floating install dialog", () => {
    const state = createSiteState(entries, "sunny");
    const html = renderApp(state);

    expect(html).toContain('class="hero-scene" data-scene-theme="sunny"');
    expect(html).toContain('class="scene-stage" aria-hidden="true"');
    expect(html).toContain('class="scene-window-light"');
    expect(html).toContain('class="scene-lamp"');
    expect(html).toContain('class="scene-character"');
    expect(html).toContain('class="scene-character-face"');
    expect(html).toContain('class="scene-character-forearm"');
    expect(html).toContain('class="scene-chair"');
    expect(html).toContain('class="scene-voice-wave"');
    expect(html).toContain('class="scene-desk-surface"');
    expect(html).toContain('class="install-panel install-dialog"');
    expect(html).toContain('class="install-prompt"');
    expect(html).not.toContain('class="install-followup"');
    expect(html).toContain('class="hero-points" aria-label="VoicePi highlights"');
    expect(html).toContain("<li>Always present.</li>");
  });

  test("uses theme-specific hero summary copy for window light and lamp-lit night work", () => {
    const sunnyHtml = renderApp(createSiteState(entries, "sunny"));
    const moonHtml = renderApp(createSiteState(entries, "moon"));

    expect(sunnyHtml).toContain("in the light.");
    expect(sunnyHtml).toContain("Clarity.");
    expect(moonHtml).toContain("in the quiet.");
    expect(moonHtml).toContain("Focus.");
  });

  test("uses a playful install opener and compact follow-up choices in the hero dialog", () => {
    const sunnyHtml = renderApp(createSiteState(entries, "sunny"));
    const homebrewFollowupHtml = renderApp({ ...createSiteState(entries, "sunny"), installDialogStage: "followup", installTab: "homebrew" });
    const downloadFollowupHtml = renderApp({ ...createSiteState(entries, "sunny"), installDialogStage: "followup", installTab: "download" });

    expect(sunnyHtml).toContain("Become part of the flow.");
    expect(sunnyHtml).toContain(">Yep, Homebrew<");
    expect(sunnyHtml).toContain(">Show me the zip<");
    expect(sunnyHtml).not.toContain("Nice. Here’s the fast lane.");
    expect(homebrewFollowupHtml).toContain("The faster route.");
    expect(homebrewFollowupHtml).toContain("The simple path.");
    expect(downloadFollowupHtml).toContain("The classic way.");
    expect(downloadFollowupHtml).toContain("Direct. Simple.");
  });

  test("switching highlights only activates the selected gallery frame", () => {
    const state = selectHighlight(createSiteState(entries, "sunny"), "recording-overlay");
    const html = renderApp(state);

    expect(html).toContain('data-highlight-link="recording-overlay"');
    expect(html).toContain('data-highlight-frame="recording-overlay"');
    expect(html).toContain('highlight-nav-button is-active"');
    expect(html).toContain('gallery-frame is-active" id="highlight-frame-recording-overlay"');
    expect(html.match(/gallery-frame is-active/g)?.length).toBe(1);
  });
});
