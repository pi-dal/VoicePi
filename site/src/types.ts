export interface ChangelogSection {
  title: string;
  body: string;
}

export interface ChangelogEntry {
  slug: string;
  version: string;
  title: string;
  sections: ChangelogSection[];
}

export type SiteTheme = "sunny" | "moon";

export type InstallTab = "homebrew" | "download";

export type HighlightId = "mode-cycle" | "recording-overlay" | "settings-home";

export interface SiteState {
  entries: ChangelogEntry[];
  theme: SiteTheme;
  installTab: InstallTab;
  activeHighlight: HighlightId;
  activeVersion: string;
  expandedVersions: Set<string>;
}
