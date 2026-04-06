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

export interface SiteState {
  entries: ChangelogEntry[];
  theme: SiteTheme;
  installTab: InstallTab;
  activeVersion: string;
  expandedVersions: Set<string>;
}
