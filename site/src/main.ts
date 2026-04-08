import "./styles.css";

import { resolveHeroMaskVars } from "./lib/hero-mask";
import { selectHighlight, selectInstallTab, selectTheme, selectVersion, toggleExpandedVersion, createSiteState } from "./lib/site-state";
import { renderApp } from "./lib/render";
import type { HighlightId, InstallTab, SiteTheme } from "./types";

const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("Expected #app root element.");
}

const root = app;
const changelogEntries = __VOICEPI_CHANGELOGS__;
const initialTheme: SiteTheme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "moon" : "sunny";

let state = createSiteState(changelogEntries, initialTheme);
let cleanupAtmosphere: (() => void) | undefined;
let cleanupHeroMask: (() => void) | undefined;
let cleanupOutsideClick: (() => void) | undefined;

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

function mountHeroAtmosphereMask(): () => void {
  const hero = document.querySelector<HTMLElement>(".hero");
  const atmosphere = document.querySelector<HTMLElement>(".theme-atmosphere");

  if (!hero || !atmosphere) {
    return () => undefined;
  }

  let animationFrame = 0;

  const syncMask = () => {
    const rect = hero.getBoundingClientRect();
    const vars = resolveHeroMaskVars(rect, window.innerWidth, window.innerHeight);

    atmosphere.classList.add("has-hero-cutout");
    atmosphere.style.setProperty("--hero-cutout-left", vars.left);
    atmosphere.style.setProperty("--hero-cutout-right", vars.right);
    atmosphere.style.setProperty("--hero-cutout-top", vars.top);
    atmosphere.style.setProperty("--hero-cutout-bottom", vars.bottom);
  };

  const scheduleSync = () => {
    window.cancelAnimationFrame(animationFrame);
    animationFrame = window.requestAnimationFrame(syncMask);
  };

  const resizeObserver = new ResizeObserver(scheduleSync);
  resizeObserver.observe(hero);
  window.addEventListener("resize", scheduleSync);

  syncMask();

  return () => {
    resizeObserver.disconnect();
    window.removeEventListener("resize", scheduleSync);
    window.cancelAnimationFrame(animationFrame);
    atmosphere.classList.remove("has-hero-cutout");
    atmosphere.style.removeProperty("--hero-cutout-left");
    atmosphere.style.removeProperty("--hero-cutout-right");
    atmosphere.style.removeProperty("--hero-cutout-top");
    atmosphere.style.removeProperty("--hero-cutout-bottom");
  };
}

function render(): void {
  document.body.dataset.theme = state.theme;
  document.documentElement.style.colorScheme = state.theme === "moon" ? "dark" : "light";

  root.innerHTML = `
    <canvas class="atmosphere-canvas" data-atmosphere aria-hidden="true"></canvas>
    <div class="noise-layer" aria-hidden="true"></div>
    <div class="beam-layer" aria-hidden="true"></div>
    <div class="theme-celestial-layer" aria-hidden="true">
      <span class="theme-celestial theme-celestial-halo"></span>
      <span class="theme-celestial theme-celestial-core"></span>
      <span class="theme-celestial theme-celestial-mask"></span>
      <span class="theme-celestial theme-celestial-glint"></span>
    </div>
    <div class="theme-atmosphere" aria-hidden="true">
      <span class="theme-particle theme-particle-1"></span>
      <span class="theme-particle theme-particle-2"></span>
      <span class="theme-particle theme-particle-3"></span>
      <span class="theme-particle theme-particle-4"></span>
      <span class="theme-particle theme-particle-5"></span>
      <span class="theme-particle theme-particle-6"></span>
      <span class="theme-particle theme-particle-7"></span>
      <span class="theme-particle theme-particle-8"></span>
      <span class="theme-particle theme-particle-9"></span>
      <span class="theme-particle theme-particle-10"></span>
      <span class="theme-particle theme-particle-11"></span>
      <span class="theme-particle theme-particle-12"></span>
    </div>
    ${renderApp(state)}
  `;

  cleanupAtmosphere?.();
  cleanupHeroMask?.();
  cleanupOutsideClick?.();
  
  cleanupAtmosphere = mountAtmosphere(state.theme);
  cleanupHeroMask = mountHeroAtmosphereMask();

  if (state.installDialogStage === "followup") {
    const handleOutsideClick = (e: MouseEvent) => {
      const panel = document.querySelector(".install-panel");
      // Allow clicking buttons that might transition states without triggering a reset mid-air
      const isInsidePanel = panel?.contains(e.target as Node);
      const isCopyButton = (e.target as Element).closest("[data-copy]");
      
      if (!isInsidePanel && !isCopyButton) {
        state = { ...state, installDialogStage: "prompt" };
        render();
      }
    };
    
    // Use timeout to prevent immediate trigger on the click that opened the followup panel
    window.setTimeout(() => {
      document.addEventListener("click", handleOutsideClick);
    }, 0);
    
    cleanupOutsideClick = () => {
      document.removeEventListener("click", handleOutsideClick);
    };
  } else {
    cleanupOutsideClick = undefined;
  }

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

  const highlightLinks = [...root.querySelectorAll<HTMLAnchorElement>("[data-highlight-link]")];
  highlightLinks.forEach((link) => {
    link.addEventListener("click", (event) => {
      event.preventDefault();
      const targetId = link.dataset.highlightLink as HighlightId | undefined;
      if (!targetId) {
        return;
      }

      state = selectHighlight(state, targetId);
      render();
    });
  });
}

render();
