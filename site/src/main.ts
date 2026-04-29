import "./styles.css";

import { createSiteState } from "./lib/site-state";
import { startApp } from "./lib/app-controller";
import type { SiteTheme } from "./types";

const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("Expected #app root element.");
}

const changelogEntries = __VOICEPI_CHANGELOGS__;
const initialTheme: SiteTheme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "moon" : "sunny";

const initialState = createSiteState(changelogEntries, initialTheme);

startApp(app, initialState);
