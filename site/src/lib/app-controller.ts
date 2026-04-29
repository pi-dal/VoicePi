import { renderApp } from "./render";
import { resolveHeroMaskVars } from "./hero-mask";
import { selectHighlight, selectInstallTab, selectTheme, selectVersion } from "./site-state";
import type { HighlightId, InstallTab, SiteTheme, SiteState } from "../types";

export interface AppController {
  root: HTMLElement;
  contentLayer: HTMLDivElement;
  state: SiteState;
  cleanupAtmosphere: (() => void) | undefined;
  cleanupHeroMask: (() => void) | undefined;
  cleanupOutsideClick: (() => void) | undefined;
  pendingOutsideClickTimeout: ReturnType<typeof setTimeout> | undefined;
}

export function startApp(root: HTMLElement, initialState: SiteState): AppController {
  // Stable background container — inserted once, never replaced
  const backgroundLayer = document.createElement("div");
  backgroundLayer.setAttribute("aria-hidden", "true");
  backgroundLayer.style.cssText = "position:fixed;inset:0;pointer-events:none;z-index:0;overflow:hidden;";
  backgroundLayer.innerHTML =
    `<canvas class="atmosphere-canvas" data-atmosphere></canvas>
    <div class="noise-layer"></div>
    <div class="beam-layer"></div>
    <div class="theme-celestial-layer">
      <span class="theme-celestial theme-celestial-halo"></span>
      <span class="theme-celestial theme-celestial-core"></span>
      <span class="theme-celestial theme-celestial-mask"></span>
      <span class="theme-celestial theme-celestial-glint"></span>
    </div>
    <div class="theme-atmosphere">
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
    </div>`;

  // Content layer — replaced on each render, never touches background
  const contentLayer = document.createElement("div");
  contentLayer.style.cssText = "position:relative;z-index:1;";

  root.appendChild(backgroundLayer);
  root.appendChild(contentLayer);

  const controller: AppController = {
    root,
    contentLayer,
    state: initialState,
    cleanupAtmosphere: undefined,
    cleanupHeroMask: undefined,
    cleanupOutsideClick: undefined,
    pendingOutsideClickTimeout: undefined,
  };

  render(controller);
  controller.cleanupAtmosphere = mountAtmosphere(controller.state.theme);
  attachEventDelegation(controller);
  return controller;
}

function updateTheme(controller: AppController, theme: SiteTheme): void {
  document.body.dataset.theme = theme;
  document.documentElement.style.colorScheme = theme === "moon" ? "dark" : "light";
  controller.cleanupAtmosphere?.();
  controller.cleanupAtmosphere = mountAtmosphere(theme);
}

function render(controller: AppController): void {
  document.body.dataset.theme = controller.state.theme;
  document.documentElement.style.colorScheme = controller.state.theme === "moon" ? "dark" : "light";

  // Only replace content layer — backgroundLayer is never touched
  controller.contentLayer.innerHTML = renderApp(controller.state);

  controller.cleanupOutsideClick?.();
  if (controller.pendingOutsideClickTimeout !== undefined) {
    clearTimeout(controller.pendingOutsideClickTimeout);
    controller.pendingOutsideClickTimeout = undefined;
  }

  attachInstallDialogOutsideClick(controller);

  // Re-bind hero mask after every content render — .hero is in contentLayer
  controller.cleanupHeroMask?.();
  controller.cleanupHeroMask = mountHeroAtmosphereMask();
}

function handleVersionSelect(controller: AppController, version: string): void {
  controller.state = selectVersion(controller.state, version);
  render(controller);
}

function handleHighlightSelect(controller: AppController, highlightId: HighlightId | undefined): void {
  if (!highlightId) { return }
  controller.state = selectHighlight(controller.state, highlightId);
  render(controller);
}

function attachEventDelegation(controller: AppController): void {
  controller.root.addEventListener("click", (event) => {
    const target = event.target as HTMLElement;

    const themeButton = target.closest<HTMLButtonElement>("[data-theme]");
    if (themeButton) {
      const newTheme = themeButton.dataset.theme as SiteTheme;
      controller.state = selectTheme(controller.state, newTheme);
      updateTheme(controller, newTheme);
      render(controller);
      return;
    }

    const installTabButton = target.closest<HTMLButtonElement>("[data-install-tab]");
    if (installTabButton) {
      controller.state = selectInstallTab(controller.state, installTabButton.dataset.installTab as InstallTab);
      render(controller);
      return;
    }

    const versionButton = target.closest<HTMLButtonElement>("[data-version]");
    if (versionButton) {
      handleVersionSelect(controller, versionButton.dataset.version ?? "");
      return;
    }

    const copyButton = target.closest<HTMLButtonElement>("[data-copy]");
    if (copyButton) {
      handleCopyButton(copyButton);
      return;
    }

    const highlightLink = target.closest<HTMLAnchorElement>("[data-highlight-link]");
    if (highlightLink) {
      event.preventDefault();
      handleHighlightSelect(controller, highlightLink.dataset.highlightLink as HighlightId | undefined);
      return;
    }
  });
}

function attachInstallDialogOutsideClick(controller: AppController): void {
  if (controller.state.installDialogStage !== "followup") {
    controller.cleanupOutsideClick = undefined;
    return;
  }

  controller.pendingOutsideClickTimeout = setTimeout(() => {
    controller.pendingOutsideClickTimeout = undefined;
    const handleOutsideClick = (e: MouseEvent) => {
      const panel = controller.root.querySelector(".install-panel");
      const isInsidePanel = panel?.contains(e.target as Node);
      const isCopyButton = (e.target as Element)?.closest("[data-copy]");

      if (!isInsidePanel && !isCopyButton) {
        controller.state = { ...controller.state, installDialogStage: "prompt" };
        render(controller);
      }
    };

    document.addEventListener("click", handleOutsideClick);

    controller.cleanupOutsideClick = () => {
      document.removeEventListener("click", handleOutsideClick);
    };
  }, 0);
}

async function handleCopyButton(button: HTMLButtonElement): Promise<void> {
  const text = button.dataset.copy ?? "";
  await navigator.clipboard.writeText(text);
  const original = button.textContent;
  button.textContent = "Copied";
  setTimeout(() => {
    button.textContent = original;
  }, 1400);
}

// ─── Atmosphere and hero mask ─────────────────────────────────────────────

export function mountAtmosphere(theme: SiteTheme): () => void {
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

export function mountHeroAtmosphereMask(): () => void {
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
