import type { ChangelogEntry, InstallTab, SiteState, SiteTheme } from "../types";

const installContent: Record<InstallTab, { title: string; detail: string; command: string; cta: string; href: string; followup: string; chipLabel: string; renderCommand: () => string }> = {
  homebrew: {
    title: "The simple path.",
    detail: "Two terminal lines. One tool. Always up to date.",
    command: `brew tap pi-dal/voicepi https://github.com/pi-dal/VoicePi\nbrew install --cask pi-dal/voicepi/voicepi`,
    cta: "Brew Guide",
    href: "https://github.com/pi-dal/VoicePi#install-with-homebrew",
    followup: "The faster route.",
    chipLabel: "Yep, Homebrew",
    renderCommand: () => `
      <span class="command-line">
        <span class="token-prompt">$</span>
        <span class="token-command">brew</span>
        <span class="token-subcommand">tap</span>
        <span class="token-value">pi-dal/voicepi \\</span>
      </span>
      <span class="command-line command-continuation">
        <span class="token-url">https://github.com/pi-dal/VoicePi</span>
      </span>
      <span class="command-line">
        <span class="token-prompt">$</span>
        <span class="token-command">brew</span>
        <span class="token-subcommand">install</span>
        <span class="token-flag">--cask \\</span>
      </span>
      <span class="command-line command-continuation">
        <span class="token-value">pi-dal/voicepi/voicepi</span>
      </span>
    `
  },
  download: {
    title: "Direct. Simple.",
    detail: "Grab the archive. Drop it in. Start speaking.",
    command: `1. Open the latest GitHub Release\n2. Download VoicePi-<version>.zip\n3. Move VoicePi.app into /Applications`,
    cta: "Releases",
    href: "https://github.com/pi-dal/VoicePi/releases",
    followup: "The classic way.",
    chipLabel: "Show me the zip",
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
    moonAlt: "VoicePi mode switch panel in Moonlight Mode",
    sunnyImage: "/media/screenshots/mode-switch-sunny.webp",
    moonImage: "/media/screenshots/mode-switch-moon.webp"
  },
  {
    id: "recording-overlay",
    navTitle: "Recording Overlay",
    navBody: "A compact floating capture surface stays close to the active app while transcript feedback updates live.",
    frameTitle: "Recording Overlay",
    frameBody: "A focused capture window with transcript feedback while you speak.",
    sunnyAlt: "VoicePi recording overlay in Sunny Mode",
    moonAlt: "VoicePi recording overlay in Moonlight Mode",
    sunnyImage: "/media/screenshots/recording-sunny.webp",
    moonImage: "/media/screenshots/recording-moon.webp"
  },
  {
    id: "settings-home",
    navTitle: "Settings Home",
    navBody: "Shortcuts, permissions, ASR, and text processing stay in one place without collapsing into a wall of subpanels.",
    frameTitle: "Settings Home",
    frameBody: "The main configuration surface for shortcuts, permissions, ASR, and text processing.",
    sunnyAlt: "VoicePi settings home in Sunny Mode",
    moonAlt: "VoicePi settings home in Moonlight Mode",
    sunnyImage: "/media/screenshots/settings-home-sunny.webp",
    moonImage: "/media/screenshots/settings-home-moon.webp"
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
  return theme === "sunny" ? "Sunny Mode" : "Moonlight Mode";
}

function resolveHeroSummary(theme: SiteTheme): string {
  if (theme === "sunny") {
    return "Clarity. Your thoughts, effortlessly present in the light.";
  }

  return "Focus. Turning whispers into wisdom in the quiet.";
}

function renderHighlightNav(activeHighlight: SiteState["activeHighlight"]): string {
  return highlightItems.map((item) => `
    <a
      class="highlight-nav-button${resolveHighlightClass(activeHighlight, item.id)}"
      href="#highlight-frame-${item.id}"
      data-highlight-link="${item.id}"
    >
      <span class="highlight-nav-title">${item.navTitle}</span>
      <span class="highlight-nav-body">${item.navBody}</span>
    </a>
  `).join("");
}

function renderGalleryFrames(activeHighlight: SiteState["activeHighlight"]): string {
  return highlightItems.map((frame) => `
    <article class="gallery-frame${resolveHighlightClass(activeHighlight, frame.id)}" id="highlight-frame-${frame.id}" data-highlight-frame="${frame.id}">
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
          <figcaption>Moonlight Mode</figcaption>
          <img src="${frame.moonImage}" alt="${frame.moonAlt}" />
        </figure>
      </div>
    </article>
  `).join("");
}

function resolveHighlightClass(
  activeHighlight: SiteState["activeHighlight"],
  id: typeof highlightItems[number]["id"]
): string {
  return activeHighlight === id ? " is-active" : "";
}

export function renderApp(state: SiteState): string {
  const activeEntry = state.entries.find((entry) => entry.version === state.activeVersion) ?? state.entries[0];
  const install = installContent[state.installTab];

  return `
    <main class="page-shell">
      <section class="hero" aria-labelledby="hero-title">
        <div class="hero-topline">
          <p class="eyebrow">Voice. Perfected.</p>
          <div class="theme-switcher" role="tablist" aria-label="Theme modes">
            <button class="theme-chip${state.theme === "sunny" ? " is-active" : ""}" data-theme="sunny" role="tab" aria-selected="${state.theme === "sunny"}">Sunny</button>
            <button class="theme-chip${state.theme === "moon" ? " is-active" : ""}" data-theme="moon" role="tab" aria-selected="${state.theme === "moon"}">Moonlight</button>
          </div>
        </div>

        <div class="hero-body">
          <div class="hero-copy">
            <div class="hero-title-lockup">
              <img class="hero-icon" src="/media/icons/voicepi-icon.webp" alt="VoicePi icon" />
              <div>
                <h1 id="hero-title">VoicePi</h1>
                <p class="hero-intro">
                  The most natural way to create on macOS.
                </p>
                <p class="hero-intro hero-intro-secondary">
                  Speak. It simply appears.
                </p>
              </div>
            </div>

            <p class="hero-summary">${resolveHeroSummary(state.theme)}</p>

            <div class="hero-actions">
              <a class="hero-button hero-button-primary" href="https://github.com/pi-dal/VoicePi/releases" target="_blank" rel="noreferrer">Download Latest Release</a>
              <a class="hero-button hero-button-secondary" href="https://github.com/pi-dal/VoicePi#install-with-homebrew" target="_blank" rel="noreferrer">Install Guide</a>
              <a class="hero-button hero-button-secondary" href="https://github.com/pi-dal/VoicePi" target="_blank" rel="noreferrer">View Repository</a>
            </div>
          </div>

          <div class="hero-scene" data-scene-theme="${state.theme}">
            <div class="scene-stage" aria-hidden="true">
              <span class="scene-window-light"></span>
              <span class="scene-window-cast"></span>
              <span class="scene-lamp"></span>
              <span class="scene-lamp-glow"></span>
              <span class="scene-stars"></span>

              <div class="scene-monitor">
                <span class="scene-monitor-line scene-monitor-line-1"></span>
                <span class="scene-monitor-line scene-monitor-line-2"></span>
                <span class="scene-monitor-line scene-monitor-line-3"></span>
                <span class="scene-monitor-cursor"></span>
              </div>

              <div class="scene-character">
                <span class="scene-character-hair"></span>
                <span class="scene-character-head"></span>
                <span class="scene-character-face"></span>
                <span class="scene-character-neck"></span>
                <span class="scene-character-torso"></span>
                <span class="scene-character-shoulder"></span>
                <span class="scene-character-upper-arm"></span>
                <span class="scene-character-forearm"></span>
                <span class="scene-character-hand"></span>
              </div>

              <div class="scene-chair">
                <span class="scene-chair-back"></span>
                <span class="scene-chair-seat"></span>
              </div>

              <div class="scene-coffee">
                <span class="scene-steam scene-steam-1"></span>
                <span class="scene-steam scene-steam-2"></span>
                <span class="scene-steam scene-steam-3"></span>
              </div>

              <div class="scene-voice-wave">
                <span></span>
                <span></span>
                <span></span>
                <span></span>
              </div>

              <p class="scene-fragment scene-fragment-1">voice captured</p>
              <p class="scene-fragment scene-fragment-2">inserting text...</p>
              <div class="scene-desk">
                <span class="scene-desk-surface"></span>
                <span class="scene-desk-front"></span>
                <span class="scene-desk-shadow"></span>
              </div>
            </div>

            <aside class="install-panel install-dialog" aria-label="Install options">
              ${state.installDialogStage === "prompt" ? `
                <div class="install-prompt">
                  <p class="eyebrow">VoicePi</p>
                  <p class="install-prompt-line">Become part of the flow.</p>
                  <div class="install-tabs" role="tablist" aria-label="Install options">
                    <button class="install-tab${state.installTab === "homebrew" ? " is-active" : ""}" data-install-tab="homebrew" role="tab" aria-selected="${state.installTab === "homebrew"}">${installContent.homebrew.chipLabel}</button>
                    <button class="install-tab${state.installTab === "download" ? " is-active" : ""}" data-install-tab="download" role="tab" aria-selected="${state.installTab === "download"}">${installContent.download.chipLabel}</button>
                  </div>
                </div>
              ` : `
                <div class="install-followup">
                  <div class="install-followup-info">
                    <p class="install-followup-kicker">${install.followup}</p>
                    <div class="install-copy">
                      <h3>${install.title}</h3>
                      <p>${install.detail}</p>
                    </div>
                  </div>
                  <div class="install-followup-interactive">
                    <pre class="install-command"><code>${install.renderCommand()}</code></pre>
                    <div class="install-actions">
                      <button class="copy-button" data-copy="${escapeHtml(install.command)}">Copy Command</button>
                      <a class="link-button" href="${install.href}" target="_blank" rel="noreferrer">${install.cta}</a>
                    </div>
                  </div>
                </div>
              `}
            </aside>
          </div>
        </div>

        <ul class="hero-points" aria-label="VoicePi highlights">
          <li>Always present.</li>
          <li>Safe paste.</li>
          <li>Private by design.</li>
          <li>Your voice, your choice.</li>
        </ul>
      </section>

      <section class="highlights" aria-labelledby="highlights-title">
        <div class="section-heading">
          <p class="eyebrow">The Essence</p>
          <h2 id="highlights-title">The power of simplicity.</h2>
          <p>
            One shortcut. Zero friction. Everything in its place.
          </p>
        </div>

        <div class="highlight-surface">
          <div class="feature-list">
            <div class="feature-list-head">
              <p class="gallery-window-kicker">The Interaction</p>
              <p>The rhythm of your work, captured.</p>
            </div>
            <nav class="highlight-nav" aria-label="Highlight sections">
              ${renderHighlightNav(state.activeHighlight)}
            </nav>
          </div>

          <div class="gallery-window">
            <div class="gallery-window-head">
              <p class="gallery-window-kicker">The Vision</p>
              <p>Focused UI. Daytime or night.</p>
            </div>
            <div class="gallery-track">
              ${renderGalleryFrames(state.activeHighlight)}
            </div>
          </div>
        </div>
      </section>

      <section class="changelog" aria-labelledby="changelog-title">
        <div class="section-heading">
          <p class="eyebrow">The Journey</p>
          <h2 id="changelog-title">The Art of Progress.</h2>
          <p>
            Progress is the art of subtraction. Every version, a bit more essential.
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
                const summary = entry.sections.find((section) => section.title === "Highlights")?.body ?? entry.title;
                const preview = entry.sections
                  .slice(0, 2)
                  .map((section) => `<p><strong>${escapeHtml(section.title)}:</strong> ${escapeHtml(section.body.replace(/^- /gm, "").split("\n")[0] ?? "")}</p>`)
                  .join("");

                return `
                  <article class="release-pill${isActive ? " is-active" : ""}">
                    <button class="release-select" data-version="${entry.version}">
                      <span class="release-version">${entry.version}</span>
                      <span class="release-title">${escapeHtml(summary)}</span>
                    </button>
                    ${isActive && preview ? `<div class="release-pill-preview">${preview}</div>` : ""}
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
          <h2>Mindfully Crafted.</h2>
          <p>
            VoicePi is a small tool for big ideas. Simple. Private. Human.
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
