import { describe, expect, test } from "vitest";

import type { ChangelogEntry } from "../types";
import {
  createSiteState,
  selectInstallTab,
  selectHighlight,
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
    expect(state.installDialogStage).toBe("prompt");
    expect(state.theme).toBe("sunny");
    expect(state.activeHighlight).toBe("mode-cycle");
    expect(state.activeVersion).toBe("1.3.2");
    expect("expandedVersions" in state).toBe(false);
  });
});

describe("site state transitions", () => {
  test("switches install tabs and themes", () => {
    const state = createSiteState(entries, "moon");
    const next = selectInstallTab(state, "download");

    expect(next.installTab).toBe("download");
    expect(next.installDialogStage).toBe("followup");
    expect(selectTheme(state, "sunny").theme).toBe("sunny");
  });

  test("switches the active highlight panel", () => {
    const state = createSiteState(entries, "moon");

    expect(selectHighlight(state, "recording-overlay").activeHighlight).toBe("recording-overlay");
  });

  test("selecting a version only changes the active release", () => {
    const state = createSiteState(entries, "moon");
    const next = selectVersion(state, "1.3.1");

    expect(next.activeVersion).toBe("1.3.1");
    expect("expandedVersions" in next).toBe(false);
  });
});
