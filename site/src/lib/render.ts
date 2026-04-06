import type { ChangelogEntry, InstallTab, SiteState, SiteTheme } from "../types";

const installContent: Record<InstallTab, { title: string; detail: string; command: string; cta: string; href: string; renderCommand: () => string }> = {
  homebrew: {
    title: "Install with Homebrew",
    detail: "Recommended if you want the shortest install path and a package-managed update flow.",
    command: `brew tap pi-dal/voicepi https://github.com/pi-dal/VoicePi\nbrew install --cask pi-dal/voicepi/voicepi`,
    cta: "Open Homebrew Guide",
    href: "https://github.com/pi-dal/VoicePi#install-with-homebrew",
    renderCommand: () => `
      <span class="command-line">
        <span class="token-prompt">$</span>
        <span class="token-command">brew</span>
        <span class="token-subcommand">tap</span>
        <span class="token-value">pi-dal/voicepi</span>
        <span class="token-url">https://github.com/pi-dal/VoicePi</span>
      </span>
      <span class="command-line">
        <span class="token-prompt">$</span>
        <span class="token-command">brew</span>
        <span class="token-subcommand">install</span>
        <span class="token-flag">--cask</span>
        <span class="token-value">pi-dal/voicepi/voicepi</span>
      </span>
    `
  },
  download: {
    title: "Install from GitHub Releases",
    detail: "Use the versioned zip archive when you want the direct-download build and in-app update support.",
    command: `1. Open the latest GitHub Release\n2. Download VoicePi-<version>.zip\n3. Move VoicePi.app into /Applications`,
    cta: "Open Releases",
    href: "https://github.com/pi-dal/VoicePi/releases",
    renderCommand: () => `
      <span class="command-line">
        <span class="token-step">1.</span>
        <span class="token-subcommand">Open</span>
        <span class="token-value">the latest GitHub Release</span>
      </span>
      <span class="command-line">
        <span class="token-step">2.</span>
        <span class="token-subcommand">Download</span>
        <span class="token-value">VoicePi-&lt;version&gt;.zip</span>
      </span>
      <span class="command-line">
        <span class="token-step">3.</span>
        <span class="token-subcommand">Move</span>
        <span class="token-value">VoicePi.app</span>
        <span class="token-subcommand">into</span>
        <span class="token-value">/Applications</span>
      </span>
    `
  }
};

const highlightItems = [
  {
    id: "mode-cycle",
    navTitle: "Mode Cycle",
    navBody: "Switch between Disabled, Refinement, and Translate from the same shortcut path.",
    frameTitle: "Mode Cycle",
    frameBody: "The shortcut surface for Disabled, Refinement, and Translate.",
    sunnyAlt: "VoicePi mode switch panel in Sunny Mode",
    moonAlt: "VoicePi mode switch panel in Moon Mode",
    sunnyImage: "/media/screenshots/mode-switch-sunny.png",
    moonImage: "/media/screenshots/mode-switch-moon.png"
  },
  {
    id: "recording-overlay",
    navTitle: "Recording Overlay",
    navBody: "A compact floating capture surface stays close to the active app while transcript feedback updates live.",
    frameTitle: "Recording Overlay",
    frameBody: "A focused capture window with transcript feedback while you speak.",
    sunnyAlt: "VoicePi recording overlay in Sunny Mode",
    moonAlt: "VoicePi recording overlay in Moon Mode",
    sunnyImage: "/media/screenshots/recording-sunny.png",
    moonImage: "/media/screenshots/recording-moon.png"
  },
  {
    id: "settings-home",
    navTitle: "Settings Home",
    navBody: "Shortcuts, permissions, ASR, and text processing stay in one place without collapsing into a wall of subpanels.",
    frameTitle: "Settings Home",
    frameBody: "The main configuration surface for shortcuts, permissions, ASR, and text processing.",
    sunnyAlt: "VoicePi settings home in Sunny Mode",
    moonAlt: "VoicePi settings home in Moon Mode",
    sunnyImage: "/media/screenshots/settings-home-sunny.png",
    moonImage: "/media/screenshots/settings-home-moon.png"
  }
] as const;

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;");
}

function renderSectionBody(body: string): string {
  const lines = body
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);

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
      continue;
    }

    flushList();
    paragraph.push(line);
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

function renderHighlightNav(): string {
  return highlightItems.map((item, index) => `
    <a
      class="highlight-nav-button${index === 0 ? " is-active" : ""}"
      href="#highlight-frame-${item.id}"
      data-highlight-link="${item.id}"
    >
      <span class="highlight-nav-title">${item.navTitle}</span>
      <span class="highlight-nav-body">${item.navBody}</span>
    </a>
  `).join("");
}

function renderGalleryFrames(): string {
  return highlightItems.map((frame, index) => `
    <article class="gallery-frame${index === 0 ? " is-active" : ""}" id="highlight-frame-${frame.id}" data-highlight-frame="${frame.id}">
      <header class="gallery-frame-head">
        <div>
          <p class="gallery-kicker">Capture</p>
          <h3>${frame.frameTitle}</h3>
        </div>
        <p>${frame.frameBody}</p>
      </header>
      <div class="gallery-pair">
        <figure class="gallery-shot">
          <figcaption>Sunny Mode</figcaption>
          <img src="${frame.sunnyImage}" alt="${frame.sunnyAlt}" />
        </figure>
        <figure class="gallery-shot">
          <figcaption>Moon Mode</figcaption>
          <img src="${frame.moonImage}" alt="${frame.moonAlt}" />
        </figure>
      </div>
    </article>
  `).join("");
}

export function renderApp(state: SiteState): string {
  const activeEntry = state.entries.find((entry) => entry.version === state.activeVersion) ?? state.entries[0];
  const install = installContent[state.installTab];

  return `
    <main class="page-shell">
      <section class="hero" aria-labelledby="hero-title">
        <div class="hero-topline">
          <p class="eyebrow">Voice Input for macOS</p>
          <div class="theme-switcher" role="tablist" aria-label="Theme modes">
            <button class="theme-chip${state.theme === "sunny" ? " is-active" : ""}" data-theme="sunny" role="tab" aria-selected="${state.theme === "sunny"}">Sunny</button>
            <button class="theme-chip${state.theme === "moon" ? " is-active" : ""}" data-theme="moon" role="tab" aria-selected="${state.theme === "moon"}">Moon</button>
          </div>
        </div>

        <div class="hero-body">
          <div class="hero-copy">
            <div class="hero-title-lockup">
              <img class="hero-icon" src="/media/icons/voicepi-icon.png" alt="VoicePi icon" />
              <div>
                <h1 id="hero-title">VoicePi</h1>
                <p class="hero-intro">
                  A menu bar dictation app for macOS that captures speech from a shortcut,
                  optionally refines or translates it, and pastes the result back into the app you were already using.
                </p>
              </div>
            </div>

            <p class="hero-summary">
              ${resolveThemeLabel(state.theme)} keeps the same product structure while changing the page atmosphere,
              screenshot pairing, shadow weight, and light direction.
            </p>

            <div class="hero-actions">
              <a class="hero-button hero-button-primary" href="https://github.com/pi-dal/VoicePi/releases" target="_blank" rel="noreferrer">Download Latest Release</a>
              <a class="hero-button hero-button-secondary" href="https://github.com/pi-dal/VoicePi#install-with-homebrew" target="_blank" rel="noreferrer">Install Guide</a>
              <a class="hero-button hero-button-secondary" href="https://github.com/pi-dal/VoicePi" target="_blank" rel="noreferrer">View Repository</a>
            </div>

            <div class="hero-points" aria-label="VoicePi highlights">
              <p>Floating overlay</p>
              <p>Clipboard restoration</p>
              <p>Input-method-safe paste flow</p>
              <p>Apple Speech or remote ASR</p>
            </div>
          </div>

          <aside class="install-panel" aria-label="Install options">
            <div class="install-panel-head">
              <p class="eyebrow">Install</p>
              <h2>Pick the path you actually want.</h2>
            </div>

            <div class="install-tabs" role="tablist" aria-label="Install options">
              <button class="install-tab${state.installTab === "homebrew" ? " is-active" : ""}" data-install-tab="homebrew" role="tab" aria-selected="${state.installTab === "homebrew"}">Homebrew</button>
              <button class="install-tab${state.installTab === "download" ? " is-active" : ""}" data-install-tab="download" role="tab" aria-selected="${state.installTab === "download"}">Direct Download</button>
            </div>

            <div class="install-copy">
              <h3>${install.title}</h3>
              <p>${install.detail}</p>
            </div>

            <pre class="install-command"><code>${install.renderCommand()}</code></pre>

            <div class="install-actions">
              <button class="copy-button" data-copy="${escapeHtml(install.command)}">Copy Command</button>
              <a class="link-button" href="${install.href}" target="_blank" rel="noreferrer">${install.cta}</a>
            </div>
          </aside>
        </div>
      </section>

      <section class="highlights" aria-labelledby="highlights-title">
        <div class="section-heading">
          <p class="eyebrow">Highlights</p>
          <h2 id="highlights-title">A simpler page, with the product details doing the real work.</h2>
          <p>
            Instead of stacking cards, the site now uses a left-side jump list and a single explanation window:
            click a section, then read its paired Sunny / Moon view on the right.
          </p>
        </div>

        <div class="highlight-surface">
          <div class="feature-list">
            <div class="feature-list-head">
              <p class="gallery-window-kicker">Jump Between Views</p>
              <p>Each section on the left maps to one explanation surface on the right.</p>
            </div>
            <nav class="highlight-nav" aria-label="Highlight sections">
              ${renderHighlightNav()}
            </nav>
          </div>

          <div class="gallery-window">
            <div class="gallery-window-head">
              <p class="gallery-window-kicker">Windowed Gallery</p>
              <p>Click any section on the left to scroll this window to its paired explanation.</p>
            </div>
            <div class="gallery-track">
              ${renderGalleryFrames()}
            </div>
          </div>
        </div>
      </section>

      <section class="changelog" aria-labelledby="changelog-title">
        <div class="section-heading">
          <p class="eyebrow">Release Timeline</p>
          <h2 id="changelog-title">Every published change, kept in one window.</h2>
          <p>
            The latest version opens first. Older versions stay available in the rail so the page can show the full timeline
            without turning into a very long document.
          </p>
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
                const summary = entry.sections.find((section) => section.title === "Highlights")?.body ?? entry.title;

                return `
                  <article class="release-pill${isActive ? " is-active" : ""}">
                    <button class="release-select" data-version="${entry.version}">
                      <span class="release-version">${entry.version}</span>
                      <span class="release-title">${escapeHtml(summary)}</span>
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
          <p>
            VoicePi is maintained as a compact macOS tool: menu bar first, shortcut driven,
            with readable release notes and a public home for every shipped version.
          </p>
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
          <div class="footprint-item">
            <dt>X</dt>
            <dd><a href="https://x.com/pidal20" target="_blank" rel="noreferrer">@pidal20</a></dd>
          </div>
        </dl>
      </footer>
    </main>
  `;
}
