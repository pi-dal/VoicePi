import "./styles.css";

import { createSiteState, selectInstallTab, selectTheme, selectVersion, toggleExpandedVersion } from "./lib/site-state";
import type { ChangelogEntry, InstallTab, SiteState, SiteTheme } from "./types";

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
    detail: "Recommended for macOS users who want an update path that stays close to the system package flow.",
    command: `brew tap pi-dal/voicepi https://github.com/pi-dal/VoicePi\nbrew install --cask pi-dal/voicepi/voicepi`,
    cta: "Open Homebrew",
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
    kicker: "Menu bar first",
    title: "Shortcut in, transcript out.",
    body: "VoicePi stays out of the Dock, records from a keyboard trigger, and pastes into the active field without turning dictation into a separate workspace."
  },
  {
    kicker: "Dual ASR",
    title: "Apple Speech or remote large-model ASR.",
    body: "Stay local when that is enough, or route audio to a remote OpenAI-compatible transcription endpoint when you want stronger recognition."
  },
  {
    kicker: "Mode cycle",
    title: "Raw, Refinement, Translate.",
    body: "Cycle text-processing modes from the keyboard and keep the output path visible instead of hidden behind a settings detour.",
    image: "/media/screenshots/mode-switch.png"
  },
  {
    kicker: "Paste pipeline",
    title: "Clipboard restore and input-method-safe injection.",
    body: "VoicePi restores the clipboard and handles ASCII switching for CJK input methods so the final paste step feels deliberate rather than fragile."
  }
];

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
        background: "#fbf5ea",
        orbs: ["rgba(235, 177, 84, 0.35)", "rgba(254, 213, 132, 0.22)", "rgba(182, 225, 201, 0.18)"]
      }
    : {
        background: "#08111d",
        orbs: ["rgba(121, 151, 255, 0.22)", "rgba(177, 210, 255, 0.18)", "rgba(93, 123, 158, 0.16)"]
      };

  const particles = Array.from({ length: theme === "sunny" ? 5 : 6 }, (_, index) => ({
    x: (index + 1) * 0.14,
    y: 0.2 + (index % 3) * 0.18,
    radius: 140 + index * 36,
    drift: 0.0004 + index * 0.00012,
    speed: 0.00018 + index * 0.00005,
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

    particles.forEach((particle, index) => {
      const angle = frame * particle.speed + index * 1.4;
      const x = window.innerWidth * particle.x + Math.cos(angle) * particle.radius * particle.drift * 1200;
      const y = window.innerHeight * particle.y + Math.sin(angle * 1.2) * particle.radius * particle.drift * 800;
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
    <main class="page-shell">
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
            <p class="hero-theme-caption">${resolveThemeLabel(state.theme)} keeps the same content but shifts the page into a warmer day-state or a cooler night-state.</p>
          </div>
        </div>

        <aside class="install-panel">
          <div class="install-tabs" role="tablist" aria-label="Install options">
            <button class="install-tab${state.installTab === "homebrew" ? " is-active" : ""}" data-install-tab="homebrew" role="tab" aria-selected="${state.installTab === "homebrew"}">Homebrew</button>
            <button class="install-tab${state.installTab === "download" ? " is-active" : ""}" data-install-tab="download" role="tab" aria-selected="${state.installTab === "download"}">Direct Download</button>
          </div>
          <div class="install-card">
            <p class="install-kicker">Install</p>
            <h2>${install.title}</h2>
            <p class="install-detail">${install.detail}</p>
            <pre class="install-command"><code>${escapeHtml(install.command)}</code></pre>
            <div class="install-actions">
              <button class="copy-button" data-copy="${escapeHtml(install.command)}">Copy</button>
              <a class="link-button" href="${install.href}" target="_blank" rel="noreferrer">${install.cta}</a>
            </div>
          </div>
        </aside>
      </section>

      <section class="highlights" aria-labelledby="highlights-title">
        <div class="section-heading">
          <p class="eyebrow">Highlights</p>
          <h2 id="highlights-title">The fast path from speech to final text.</h2>
          <p>VoicePi is deliberately compact, but the core path is opinionated: keep dictation close to the keyboard, keep correction conservative, and keep the last paste step trustworthy.</p>
        </div>
        <div class="highlight-grid">
          ${highlights.map((highlight) => `
            <article class="highlight-card${highlight.image ? " has-image" : ""}">
              <p class="highlight-kicker">${highlight.kicker}</p>
              <h3>${highlight.title}</h3>
              <p>${highlight.body}</p>
              ${highlight.image ? `<img class="highlight-image" src="${highlight.image}" alt="${highlight.title}" />` : ""}
            </article>
          `).join("")}
        </div>
      </section>

      <section class="changelog" aria-labelledby="changelog-title">
        <div class="section-heading">
          <p class="eyebrow">Release Timeline</p>
          <h2 id="changelog-title">Every published change, kept inside one window.</h2>
          <p>The latest release opens first. Older releases stay in the rail until you switch or expand them, so the page does not turn into one endless patch note scroll.</p>
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
        <div>
          <p class="eyebrow">Footprint</p>
          <h2>Built with love by pi-dal.</h2>
          <p>Repository: VoicePi. GitHub Pages for release notes, install paths, and the product surface that sits beside the app instead of competing with it.</p>
        </div>
        <div class="footprint-links">
          <a href="https://pi-dal.com" target="_blank" rel="noreferrer">pi-dal</a>
          <a href="https://github.com/pi-dal" target="_blank" rel="noreferrer">@pi-dal</a>
          <a href="https://github.com/pi-dal/VoicePi" target="_blank" rel="noreferrer">VoicePi repository</a>
        </div>
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
