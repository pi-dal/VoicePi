import "./styles.css";

import { createSiteState, selectInstallTab, selectTheme, selectVersion, toggleExpandedVersion } from "./lib/site-state";
import type { ChangelogEntry, InstallTab, SiteTheme } from "./types";

const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("Expected #app root element.");
}

const root = app;
const changelogEntries = __VOICEPI_CHANGELOGS__;
const initialTheme: SiteTheme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "moon" : "sunny";

let state = createSiteState(changelogEntries, initialTheme);
let cleanupAtmosphere: (() => void) | undefined;

const installContent: Record<InstallTab, { title: string; detail: string; command: string; cta: string; href: string }> = {
  homebrew: {
    title: "Install with Homebrew",
    detail: "Recommended if you want the shortest install path and a package-managed update flow.",
    command: `brew tap pi-dal/voicepi https://github.com/pi-dal/VoicePi\nbrew install --cask pi-dal/voicepi/voicepi`,
    cta: "Open Homebrew Guide",
    href: "https://github.com/pi-dal/VoicePi#install-with-homebrew"
  },
  download: {
    title: "Install from GitHub Releases",
    detail: "Use the versioned zip archive when you want the direct-download build and in-app update support.",
    command: `1. Open the latest GitHub Release\n2. Download VoicePi-<version>.zip\n3. Move VoicePi.app into /Applications`,
    cta: "Open Releases",
    href: "https://github.com/pi-dal/VoicePi/releases"
  }
};

const highlights = [
  {
    title: "Menu bar first",
    body: "VoicePi stays close to the keyboard and does not force dictation into a separate editor or a floating transcript workspace."
  },
  {
    title: "Two transcription paths",
    body: "Choose Apple Speech for the local path or switch to a remote OpenAI-compatible ASR backend when stronger recognition matters."
  },
  {
    title: "Mode cycle on the shortcut path",
    body: "Raw, Refinement, and Translate stay visible and reachable from the same interaction loop instead of being buried in settings."
  },
  {
    title: "Safer final paste",
    body: "Clipboard restoration and input-method-aware handling make the last step feel reliable instead of opportunistic."
  }
];

const screenshotPairs = {
  sunny: {
    label: "Sunny Mode",
    image: "/media/screenshots/mode-switch-sunny.png"
  },
  moon: {
    label: "Moon Mode",
    image: "/media/screenshots/mode-switch-moon.png"
  }
} as const;

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;");
}

function renderSectionBody(body: string): string {
  const lines = body.split("\n").map((line) => line.trim()).filter(Boolean);

  if (lines.every((line) => line.startsWith("- "))) {
    return `<ul>${lines.map((line) => `<li>${escapeHtml(line.replace(/^- /, ""))}</li>`).join("")}</ul>`;
  }

  const blocks: string[] = [];
  let paragraph: string[] = [];
  let listItems: string[] = [];

  const flushParagraph = () => {
    if (paragraph.length > 0) {
      blocks.push(`<p>${escapeHtml(paragraph.join(" "))}</p>`);
      paragraph = [];
    }
  };

  const flushList = () => {
    if (listItems.length > 0) {
      blocks.push(`<ul>${listItems.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>`);
      listItems = [];
    }
  };

  for (const line of lines) {
    if (line.startsWith("- ")) {
      flushParagraph();
      listItems.push(line.replace(/^- /, ""));
    } else {
      flushList();
      paragraph.push(line);
    }
  }

  flushParagraph();
  flushList();

  return blocks.join("");
}

function renderReleaseSection(section: ChangelogEntry["sections"][number]): string {
  return `
    <section class="release-section">
      <div class="release-section-head">
        <p class="release-section-kicker">Section</p>
        <h3>${escapeHtml(section.title)}</h3>
      </div>
      <div class="release-copy">${renderSectionBody(section.body)}</div>
    </section>
  `;
}

function resolveThemeLabel(theme: SiteTheme): string {
  return theme === "sunny" ? "Sunny Mode" : "Moon Mode";
}

function mountAtmosphere(theme: SiteTheme): () => void {
  const canvas = document.querySelector<HTMLCanvasElement>("[data-atmosphere]");

  if (!canvas) {
    return () => undefined;
  }

  const context = canvas.getContext("2d");
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (!context) {
    return () => undefined;
  }

  const palette = theme === "sunny"
    ? {
        background: "#f7efdf",
        orbs: ["rgba(243, 174, 66, 0.42)", "rgba(255, 222, 161, 0.38)", "rgba(253, 244, 218, 0.95)"],
        shadow: "rgba(174, 118, 29, 0.12)"
      }
    : {
        background: "#08111d",
        orbs: ["rgba(95, 130, 245, 0.28)", "rgba(186, 219, 255, 0.18)", "rgba(12, 24, 42, 0.95)"],
        shadow: "rgba(4, 8, 15, 0.42)"
      };

  const particles = Array.from({ length: theme === "sunny" ? 4 : 5 }, (_, index) => ({
    x: theme === "sunny" ? 0.18 + index * 0.19 : 0.14 + index * 0.18,
    y: 0.18 + (index % 2) * 0.32,
    radius: theme === "sunny" ? 180 + index * 42 : 160 + index * 34,
    drift: 0.00022 + index * 0.00008,
    speed: 0.00014 + index * 0.00003,
    color: palette.orbs[index % palette.orbs.length]
  }));

  let frame = 0;
  let animationFrame = 0;

  const resize = () => {
    const ratio = window.devicePixelRatio || 1;
    canvas.width = Math.floor(window.innerWidth * ratio);
    canvas.height = Math.floor(window.innerHeight * ratio);
    canvas.style.width = `${window.innerWidth}px`;
    canvas.style.height = `${window.innerHeight}px`;
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
  };

  const draw = () => {
    frame += 1;
    context.clearRect(0, 0, window.innerWidth, window.innerHeight);
    context.fillStyle = palette.background;
    context.fillRect(0, 0, window.innerWidth, window.innerHeight);

    const wash = context.createLinearGradient(0, 0, window.innerWidth, window.innerHeight);
    wash.addColorStop(0, palette.shadow);
    wash.addColorStop(0.42, "rgba(0,0,0,0)");
    wash.addColorStop(1, palette.shadow);
    context.fillStyle = wash;
    context.fillRect(0, 0, window.innerWidth, window.innerHeight);

    particles.forEach((particle, index) => {
      const angle = frame * particle.speed + index * 1.8;
      const x = window.innerWidth * particle.x + Math.cos(angle) * particle.radius * particle.drift * 1300;
      const y = window.innerHeight * particle.y + Math.sin(angle * 1.1) * particle.radius * particle.drift * 950;
      const gradient = context.createRadialGradient(x, y, 0, x, y, particle.radius);
      gradient.addColorStop(0, particle.color);
      gradient.addColorStop(1, "rgba(0, 0, 0, 0)");
      context.fillStyle = gradient;
      context.beginPath();
      context.arc(x, y, particle.radius, 0, Math.PI * 2);
      context.fill();
    });

    if (!reducedMotion) {
      animationFrame = window.requestAnimationFrame(draw);
    }
  };

  resize();
  draw();
  window.addEventListener("resize", resize);

  return () => {
    window.removeEventListener("resize", resize);
    window.cancelAnimationFrame(animationFrame);
  };
}

function render(): void {
  const activeEntry = state.entries.find((entry) => entry.version === state.activeVersion) ?? state.entries[0];
  const install = installContent[state.installTab];

  document.body.dataset.theme = state.theme;
  document.documentElement.style.colorScheme = state.theme === "moon" ? "dark" : "light";

  root.innerHTML = `
    <canvas class="atmosphere-canvas" data-atmosphere aria-hidden="true"></canvas>
    <div class="noise-layer" aria-hidden="true"></div>
    <div class="beam-layer" aria-hidden="true"></div>
    <main class="page-shell">
      <section class="hero-shell">
        <section class="hero">
          <div class="hero-copy">
            <p class="eyebrow">Voice Input for macOS</p>
            <div class="hero-title-lockup">
              <img class="hero-icon" src="/media/icons/voicepi-icon.png" alt="VoicePi icon" />
              <div>
                <h1>VoicePi</h1>
                <p class="hero-intro">
                  Lightweight dictation that lives in the menu bar, captures speech from a shortcut,
                  optionally refines or translates it, and pastes the result back into the app you were already using.
                </p>
              </div>
            </div>
            <div class="hero-meta">
              <div class="theme-switcher" role="tablist" aria-label="Theme modes">
                <button class="theme-chip${state.theme === "sunny" ? " is-active" : ""}" data-theme="sunny" role="tab" aria-selected="${state.theme === "sunny"}">Sunny</button>
                <button class="theme-chip${state.theme === "moon" ? " is-active" : ""}" data-theme="moon" role="tab" aria-selected="${state.theme === "moon"}">Moon</button>
              </div>
              <p class="hero-theme-caption">${resolveThemeLabel(state.theme)} keeps the same information architecture, but the page changes light, density, shadow depth, and screenshot pairing.</p>
            </div>
          </div>

          <aside class="hero-stage">
            <div class="stage-head">
              <p class="eyebrow">Mode Surface</p>
              <p class="stage-caption">The same mode-switch panel, exported in both themes so the website can pair interface tone and page tone one to one.</p>
            </div>
            <div class="screenshot-pair">
              <figure class="stage-shot">
                <figcaption>${screenshotPairs.sunny.label}</figcaption>
                <img src="${screenshotPairs.sunny.image}" alt="VoicePi mode switch panel in a light appearance" />
              </figure>
              <figure class="stage-shot">
                <figcaption>${screenshotPairs.moon.label}</figcaption>
                <img src="${screenshotPairs.moon.image}" alt="VoicePi mode switch panel in a dark appearance" />
              </figure>
            </div>
          </aside>
        </section>

        <section class="install-strip">
          <div class="install-strip-head">
            <p class="eyebrow">Install</p>
            <h2>Pick the path you actually want.</h2>
          </div>
          <div class="install-tabs" role="tablist" aria-label="Install options">
            <button class="install-tab${state.installTab === "homebrew" ? " is-active" : ""}" data-install-tab="homebrew" role="tab" aria-selected="${state.installTab === "homebrew"}">Homebrew</button>
            <button class="install-tab${state.installTab === "download" ? " is-active" : ""}" data-install-tab="download" role="tab" aria-selected="${state.installTab === "download"}">Direct Download</button>
          </div>
          <div class="install-line">
            <div class="install-copy">
              <h3>${install.title}</h3>
              <p>${install.detail}</p>
            </div>
            <pre class="install-command"><code>${escapeHtml(install.command)}</code></pre>
            <div class="install-actions">
              <button class="copy-button" data-copy="${escapeHtml(install.command)}">Copy</button>
              <a class="link-button" href="${install.href}" target="_blank" rel="noreferrer">${install.cta}</a>
            </div>
          </div>
        </section>
      </section>

      <section class="highlights" aria-labelledby="highlights-title">
        <div class="section-heading">
          <p class="eyebrow">Highlights</p>
          <h2 id="highlights-title">Keep the page simple. Keep the product sharp.</h2>
          <p>VoicePi does not need a wall of feature cards. The useful part is the interaction model and the trustworthiness of the final paste path.</p>
        </div>
        <div class="highlights-list">
          ${highlights.map((highlight) => `
            <article class="highlight-row">
              <h3>${highlight.title}</h3>
              <p>${highlight.body}</p>
            </article>
          `).join("")}
        </div>
      </section>

      <section class="changelog" aria-labelledby="changelog-title">
        <div class="section-heading">
          <p class="eyebrow">Release Timeline</p>
          <h2 id="changelog-title">Every published change, kept inside one window.</h2>
          <p>The latest release opens first. Older releases stay in the rail until you switch or expand them, so the page stays compact instead of becoming a long stack of notes.</p>
        </div>

        <div class="release-window">
          <aside class="release-rail">
            <div class="release-rail-head">
              <p class="release-rail-kicker">Versions</p>
              <p class="release-rail-meta">${state.entries.length} releases</p>
            </div>
            <div class="release-rail-list">
              ${state.entries.map((entry) => {
                const isActive = entry.version === state.activeVersion;
                const isExpanded = state.expandedVersions.has(entry.version);
                const summary = entry.sections.find((section) => section.title === "Highlights")?.body ?? "";

                return `
                  <article class="release-pill${isActive ? " is-active" : ""}">
                    <button class="release-select" data-version="${entry.version}">
                      <span class="release-version">${entry.version}</span>
                      <span class="release-title">${escapeHtml(summary || entry.title)}</span>
                    </button>
                    <button class="release-toggle" data-toggle-version="${entry.version}" aria-expanded="${isExpanded}">
                      ${isExpanded ? "Collapse" : "Expand"}
                    </button>
                    ${isExpanded ? `<div class="release-pill-preview">${entry.sections.slice(0, 2).map((section) => `<p><strong>${escapeHtml(section.title)}:</strong> ${escapeHtml(section.body.replace(/^- /gm, "").split("\n")[0] ?? "")}</p>`).join("")}</div>` : ""}
                  </article>
                `;
              }).join("")}
            </div>
          </aside>

          <div class="release-panel">
            <div class="release-panel-head">
              <div>
                <p class="release-panel-kicker">Currently Open</p>
                <h3>${escapeHtml(activeEntry.title)}</h3>
              </div>
              <p class="release-panel-meta">${activeEntry.sections.length} sections</p>
            </div>
            <div class="release-panel-scroll">
              ${activeEntry.sections.map(renderReleaseSection).join("")}
            </div>
          </div>
        </div>
      </section>

      <footer class="footprint">
        <div class="footprint-copy">
          <p class="eyebrow">Footprint</p>
          <h2>Built with love by pi-dal.</h2>
          <p>VoicePi on GitHub Pages should read like a compact extension of the app: clear install paths, readable release notes, and obvious ownership.</p>
        </div>
        <dl class="footprint-list">
          <div class="footprint-item">
            <dt>Website</dt>
            <dd><a href="https://pi-dal.com" target="_blank" rel="noreferrer">pi-dal.com</a></dd>
          </div>
          <div class="footprint-item">
            <dt>GitHub</dt>
            <dd><a href="https://github.com/pi-dal" target="_blank" rel="noreferrer">@pi-dal</a></dd>
          </div>
          <div class="footprint-item">
            <dt>Repository</dt>
            <dd><a href="https://github.com/pi-dal/VoicePi" target="_blank" rel="noreferrer">VoicePi</a></dd>
          </div>
        </dl>
      </footer>
    </main>
  `;

  cleanupAtmosphere?.();
  cleanupAtmosphere = mountAtmosphere(state.theme);

  root.querySelectorAll<HTMLButtonElement>("[data-theme]").forEach((button) => {
    button.addEventListener("click", () => {
      state = selectTheme(state, button.dataset.theme as SiteTheme);
      render();
    });
  });

  root.querySelectorAll<HTMLButtonElement>("[data-install-tab]").forEach((button) => {
    button.addEventListener("click", () => {
      state = selectInstallTab(state, button.dataset.installTab as InstallTab);
      render();
    });
  });

  root.querySelectorAll<HTMLButtonElement>("[data-version]").forEach((button) => {
    button.addEventListener("click", () => {
      state = selectVersion(state, button.dataset.version ?? "");
      render();
    });
  });

  root.querySelectorAll<HTMLButtonElement>("[data-toggle-version]").forEach((button) => {
    button.addEventListener("click", () => {
      state = toggleExpandedVersion(state, button.dataset.toggleVersion ?? "");
      render();
    });
  });

  root.querySelectorAll<HTMLButtonElement>("[data-copy]").forEach((button) => {
    button.addEventListener("click", async () => {
      const text = button.dataset.copy ?? "";
      await navigator.clipboard.writeText(text);
      const original = button.textContent;
      button.textContent = "Copied";
      window.setTimeout(() => {
        button.textContent = original;
      }, 1400);
    });
  });
}

render();
