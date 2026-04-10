import type { ChangelogEntry, HighlightId, InstallTab, SiteState, SiteTheme } from "../types";

export function createSiteState(
  entries: ChangelogEntry[],
  initialTheme: SiteTheme
): SiteState {
  const latestVersion = entries[0]?.version ?? "";

  return {
    entries,
    theme: initialTheme,
    installTab: "homebrew",
    installDialogStage: "prompt",
    activeHighlight: "mode-cycle",
    activeVersion: latestVersion
  };
}

export function selectInstallTab(state: SiteState, installTab: InstallTab): SiteState {
  return {
    ...state,
    installTab,
    installDialogStage: "followup"
  };
}

export function selectTheme(state: SiteState, theme: SiteTheme): SiteState {
  return {
    ...state,
    theme
  };
}

export function selectHighlight(state: SiteState, highlight: HighlightId): SiteState {
  return {
    ...state,
    activeHighlight: highlight
  };
}

export function selectVersion(state: SiteState, version: string): SiteState {
  return {
    ...state,
    activeVersion: version
  };
}
