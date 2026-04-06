import { describe, expect, test } from "vitest";

import { createSiteState } from "./site-state";
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
    expect(html).toContain("Install with Homebrew");
    expect(html).toContain("Download Latest Release");

    expect(html).toContain('id="highlights-title"');
    expect(html).toContain("Sunny Mode");
    expect(html).toContain("Moon Mode");
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

  test("opens the latest version by default and keeps its expanded state in the timeline rail", () => {
    const state = createSiteState(entries, "moon");
    const html = renderApp(state);

    expect(html).toContain('data-version="1.3.2"');
    expect(html).toContain('data-toggle-version="1.3.2" aria-expanded="true"');
    expect(html).toContain("Latest release summary.");
  });
});
