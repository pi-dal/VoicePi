import { describe, expect, test } from "vitest";

import {
  compareVersionsDescending,
  loadChangelogEntries,
  parseChangelogMarkdown
} from "./changelog";

describe("parseChangelogMarkdown", () => {
  test("extracts version metadata and sections from release markdown", () => {
    const entry = parseChangelogMarkdown(`# VoicePi v1.3.2

## Highlights
Short summary.

## Added
- One

## Fixed
- Two
`, "v1.3.2.md");

    expect(entry.version).toBe("1.3.2");
    expect(entry.slug).toBe("v1.3.2");
    expect(entry.title).toBe("VoicePi v1.3.2");
    expect(entry.sections.map((section) => section.title)).toEqual([
      "Highlights",
      "Added",
      "Fixed"
    ]);
  });
});

describe("compareVersionsDescending", () => {
  test("sorts newer releases before older ones", () => {
    const versions = ["1.1.0", "1.3.2", "1.3.0", "1.2.0"];
    versions.sort(compareVersionsDescending);

    expect(versions).toEqual(["1.3.2", "1.3.0", "1.2.0", "1.1.0"]);
  });
});

describe("loadChangelogEntries", () => {
  test("loads repository changelogs newest first and skips the template", async () => {
    const entries = await loadChangelogEntries("../docs/changelogs");
    const sortedVersions = entries.map((entry) => entry.version).sort(compareVersionsDescending);

    expect(entries.length).toBeGreaterThan(0);
    expect(entries[0]?.version).toBe(sortedVersions[0]);
    expect(entries.some((entry) => entry.slug === "TEMPLATE")).toBe(false);
    expect(entries[0]?.sections[0]?.title).toBe("Highlights");
  });
});
