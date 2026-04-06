import "./styles.css";

import { selectInstallTab, selectTheme, selectVersion, toggleExpandedVersion, createSiteState } from "./lib/site-state";
import { renderApp } from "./lib/render";
import type { InstallTab, SiteTheme } from "./types";

const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("Expected #app root element.");
}

const root = app;
const changelogEntries = __VOICEPI_CHANGELOGS__;
const initialTheme: SiteTheme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "moon" : "sunny";

let state = createSiteState(changelogEntries, initialTheme);
let cleanupAtmosphere: (() => void) | undefined;

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
        background: "#f6eddd",
        shadow: "rgba(168, 110, 22, 0.12)",
        orbs: ["rgba(255, 209, 128, 0.55)", "rgba(242, 171, 55, 0.36)", "rgba(255, 247, 226, 0.92)"]
      }
    : {
        background: "#07111c",
        shadow: "rgba(2, 8, 18, 0.44)",
        orbs: ["rgba(121, 153, 255, 0.3)", "rgba(187, 217, 255, 0.16)", "rgba(9, 19, 36, 0.96)"]
      };

  const particles = Array.from({ length: theme === "sunny" ? 5 : 6 }, (_, index) => ({
    x: theme === "sunny" ? 0.12 + index * 0.18 : 0.08 + index * 0.16,
    y: 0.14 + (index % 3) * 0.22,
    radius: theme === "sunny" ? 160 + index * 34 : 140 + index * 26,
    drift: 0.00016 + index * 0.00005,
    speed: 0.00011 + index * 0.00003,
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
    wash.addColorStop(0.4, "rgba(0, 0, 0, 0)");
    wash.addColorStop(1, palette.shadow);
    context.fillStyle = wash;
    context.fillRect(0, 0, window.innerWidth, window.innerHeight);

    particles.forEach((particle, index) => {
      const angle = frame * particle.speed + index * 1.4;
      const x = window.innerWidth * particle.x + Math.cos(angle) * particle.radius * particle.drift * 1100;
      const y = window.innerHeight * particle.y + Math.sin(angle * 1.14) * particle.radius * particle.drift * 960;
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
  document.body.dataset.theme = state.theme;
  document.documentElement.style.colorScheme = state.theme === "moon" ? "dark" : "light";

  root.innerHTML = `
    <canvas class="atmosphere-canvas" data-atmosphere aria-hidden="true"></canvas>
    <div class="noise-layer" aria-hidden="true"></div>
    <div class="beam-layer" aria-hidden="true"></div>
    ${renderApp(state)}
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
