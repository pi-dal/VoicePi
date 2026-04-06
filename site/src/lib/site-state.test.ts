import { describe, expect, test } from "vitest";

import type { ChangelogEntry } from "../types";
import {
  createSiteState,
  toggleExpandedVersion,
  selectInstallTab,
  selectTheme,
  selectVersion
} from "./site-state";

const entries: ChangelogEntry[] = [
  {
    slug: "v1.3.2",
    version: "1.3.2",
    title: "VoicePi v1.3.2",
    sections: []
  },
  {
    slug: "v1.3.1",
    version: "1.3.1",
    title: "VoicePi v1.3.1",
    sections: []
  }
];

describe("createSiteState", () => {
  test("defaults to homebrew and latest release", () => {
    const state = createSiteState(entries, "sunny");

    expect(state.installTab).toBe("homebrew");
    expect(state.theme).toBe("sunny");
    expect(state.activeVersion).toBe("1.3.2");
    expect([...state.expandedVersions]).toEqual(["1.3.2"]);
  });
});

describe("site state transitions", () => {
  test("switches install tabs and themes", () => {
    const state = createSiteState(entries, "moon");

    expect(selectInstallTab(state, "download").installTab).toBe("download");
    expect(selectTheme(state, "sunny").theme).toBe("sunny");
  });

  test("selecting a version activates and expands it", () => {
    const state = createSiteState(entries, "moon");
    const next = selectVersion(state, "1.3.1");

    expect(next.activeVersion).toBe("1.3.1");
    expect(next.expandedVersions.has("1.3.1")).toBe(true);
  });

  test("toggleExpandedVersion collapses inactive versions and preserves the active one", () => {
    const state = createSiteState(entries, "moon");
    const expanded = toggleExpandedVersion(state, "1.3.1");
    const collapsed = toggleExpandedVersion(expanded, "1.3.1");

    expect(collapsed.expandedVersions.has("1.3.1")).toBe(false);
    expect(toggleExpandedVersion(state, "1.3.2").expandedVersions.has("1.3.2")).toBe(true);
  });
});
