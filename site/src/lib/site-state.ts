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
    activeVersion: latestVersion,
    expandedVersions: new Set(latestVersion ? [latestVersion] : [])
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
  const expandedVersions = new Set(state.expandedVersions);
  expandedVersions.add(version);

  return {
    ...state,
    activeVersion: version,
    expandedVersions
  };
}

export function toggleExpandedVersion(state: SiteState, version: string): SiteState {
  if (version === state.activeVersion) {
    return state;
  }

  const expandedVersions = new Set(state.expandedVersions);

  if (expandedVersions.has(version)) {
    expandedVersions.delete(version);
  } else {
    expandedVersions.add(version);
  }

  return {
    ...state,
    expandedVersions
  };
}
