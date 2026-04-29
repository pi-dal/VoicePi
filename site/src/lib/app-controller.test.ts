/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, expect, test, vi, beforeEach, afterEach } from "vitest";
import type { ChangelogEntry } from "../types";
import { createSiteState } from "./site-state";

const entries: ChangelogEntry[] = [
  {
    slug: "v1.3.2",
    version: "1.3.2",
    title: "VoicePi v1.3.2",
    sections: [{ title: "Highlights", body: "Test release." }]
  }
];

// ─── Mock globals ──────────────────────────────────────────────────────────

const eventListeners = new WeakMap<object, Map<string, Function[]>>();
const mockSetAttribute = vi.fn();
const mockAppendChild = vi.fn();
const mockQuerySelectorAll = vi.fn(() => []);
const mockRemoveEventListener = vi.fn();
const mockClearTimeout = vi.fn();
const mockCancelAnimationFrame = vi.fn();
const mockRequestAnimationFrame = vi.fn((fn: () => void) => { fn(); return 1 });
const resizeObserverInstances: Array<{ observe: ReturnType<typeof vi.fn>; disconnect: ReturnType<typeof vi.fn>; unobserve: ReturnType<typeof vi.fn> }> = [];

function addListener(el: object, event: string, handler: Function) {
  if (!eventListeners.has(el)) eventListeners.set(el, new Map());
  const map = eventListeners.get(el)!;
  if (!map.has(event)) map.set(event, []);
  map.get(event)!.push(handler);
}

function callListeners(el: object, event: string, ev: object) {
  const map = eventListeners.get(el);
  if (map && map.has(event)) {
    for (const handler of map.get(event)!) {
      handler.call(el, ev);
    }
  }
}

// Per-element mock storage
const elementData: Map<object, Record<string, string>> = new Map();

function makeEl(tag: string): any {
  const data: Record<string, string> = {};
  elementData.set(data, data);
  const style = {
    cssText: "",
    setProperty: vi.fn(),
    removeProperty: vi.fn(),
  };
  const el = {
    tagName: tag.toUpperCase(),
    style,
    setAttribute: mockSetAttribute,
    appendChild: mockAppendChild,
    insertBefore: vi.fn(),
    querySelector: vi.fn(),
    querySelectorAll: mockQuerySelectorAll,
    getContext: vi.fn(() => null),
    getBoundingClientRect: vi.fn(() => ({ left: 0, right: 100, top: 0, bottom: 100 })),
    classList: { add: vi.fn(), remove: vi.fn() },
    removeEventListener: mockRemoveEventListener,
    addEventListener: (event: string, handler: Function) => addListener(el, event, handler),
    textContent: "",
    innerHTML: "",
    children: [],
    firstChild: null,
    dataset: data,
    getElementsByTagName: vi.fn(() => []),
    contains: vi.fn(() => false),
    dispatchEvent: vi.fn(function(this: object, ev: any) {
      if (ev && ev.type === "click") {
        callListeners(this, "click", ev);
      }
      return true;
    }),
    parentElement: null,
    closest: (sel: string) => {
      const ds = elementData.get(data) ?? data;
      // CSS attribute selector [data-theme] means "has data-theme attribute set"
      if (sel.startsWith("[data-theme]")) {
        return ds.theme !== undefined ? el : null;
      }
      if (sel.startsWith("[data-install-tab]")) {
        return ds.installTab !== undefined ? el : null;
      }
      if (sel.startsWith("[data-version]")) {
        return ds.version !== undefined ? el : null;
      }
      if (sel.startsWith("[data-highlight-link]")) {
        return ds.highlightLink !== undefined ? el : null;
      }
      if (sel.startsWith("[data-copy]")) {
        return ds.copy !== undefined ? el : null;
      }
      return null;
    },
  };
  return el;
}

vi.stubGlobal("document", {
  body: {
    dataset: {} as Record<string, string>,
    style: {} as CSSStyleDeclaration,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    appendChild: vi.fn(),
    removeChild: vi.fn(),
    innerHTML: "",
  },
  documentElement: { style: {} as CSSStyleDeclaration, addEventListener: vi.fn() },
  querySelector: vi.fn(),
  querySelectorAll: mockQuerySelectorAll,
  createElement: (tag: string) => makeEl(tag),
  getElementsByTagName: vi.fn(() => []),
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
});

vi.stubGlobal("ResizeObserver", vi.fn(function (_callback: ResizeObserverCallback) {
  const observer = {
    observe: vi.fn(),
    disconnect: vi.fn(),
    unobserve: vi.fn(),
  };
  resizeObserverInstances.push(observer);
  return observer;
}));

vi.stubGlobal("setTimeout", ((fn: () => void) => { fn(); return 1 }) as unknown as typeof setTimeout);
vi.stubGlobal("clearTimeout", mockClearTimeout);
vi.stubGlobal("cancelAnimationFrame", mockCancelAnimationFrame);
vi.stubGlobal("requestAnimationFrame", mockRequestAnimationFrame);
vi.stubGlobal("window", {
  matchMedia: vi.fn(() => ({ matches: false })),
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
  requestAnimationFrame: mockRequestAnimationFrame,
  cancelAnimationFrame: mockCancelAnimationFrame,
  devicePixelRatio: 1,
  innerWidth: 1280,
  innerHeight: 800,
  MouseEvent: class MouseEvent {
    constructor(public type: string, public init?: EventInit & { bubbles?: boolean }) {}
    get bubbles() { return this.init?.bubbles ?? false; }
    get target() { return (this as any)._target; }
    preventDefault = vi.fn();
    stopPropagation = vi.fn();
  },
});

// ─── Test helpers ──────────────────────────────────────────────────────────

// Store event target so event.target resolves correctly
const eventTargetMap = new WeakMap<object, HTMLElement>();

function click(target: HTMLElement): any {
  const ev = new (window as any).MouseEvent("click", { bubbles: true });
  ev.preventDefault = vi.fn();
  ev.stopPropagation = vi.fn();
  eventTargetMap.set(ev, target);
  Object.defineProperty(ev, "target", {
    get() { return eventTargetMap.get(ev); },
    configurable: true,
    enumerable: true,
  });
  return ev;
}

// ─── Tests ─────────────────────────────────────────────────────────────────

describe("AppController interactions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resizeObserverInstances.length = 0;
    elementData.clear();
    (document.body as any).dataset = {};
    document.body.style.cssText = "";
    document.body.innerHTML = "";
    (document.querySelector as any).mockReturnValue(null);
  });

  afterEach(() => {
    document.body.innerHTML = "";
  });

  // ── Theme toggle (1 path to prove the delegation chain works) ────────────

  test("clicking theme button updates controller.state.theme and document.body.dataset.theme", async () => {
    const { startApp } = await import("./app-controller");

    // Create root element
    const root = makeEl("div");
    root.id = "app";
    (document.body as any).appendChild(root);

    const state = createSiteState(entries, "sunny");
    const controller = startApp(root, state);

    // Create theme button — its dataset.theme matches what closest will check
    const themeButton = makeEl("button");
    themeButton.dataset.theme = "moon";

    // Dispatch a click event on root
    // The event's target is themeButton; closest("[data-theme='moon']") should find themeButton
    root.dispatchEvent(click(themeButton));

    expect(controller.state.theme).toBe("moon");
    expect(document.body.dataset.theme).toBe("moon");
  });

  test("theme toggle does not affect installTab or activeHighlight", async () => {
    const { startApp } = await import("./app-controller");

    const root = makeEl("div");
    root.id = "app";
    (document.body as any).appendChild(root);

    const state = createSiteState(entries, "sunny");
    const controller = startApp(root, state);
    const originalInstallTab = controller.state.installTab;
    const originalActiveHighlight = controller.state.activeHighlight;

    const themeButton = makeEl("button");
    themeButton.dataset.theme = "moon";
    root.dispatchEvent(click(themeButton));

    expect(controller.state.installTab).toBe(originalInstallTab);
    expect(controller.state.activeHighlight).toBe(originalActiveHighlight);
  });

  test("startup mounts one hero mask observer when hero and atmosphere exist", async () => {
    const { startApp } = await import("./app-controller");

    const root = makeEl("div");
    root.id = "app";
    const hero = makeEl("section");
    const atmosphere = makeEl("div");
    (document.querySelector as any).mockImplementation((selector: string) => {
      if (selector === ".hero") return hero;
      if (selector === ".theme-atmosphere") return atmosphere;
      return null;
    });

    startApp(root, createSiteState(entries, "sunny"));

    expect(resizeObserverInstances).toHaveLength(1);
    expect(resizeObserverInstances[0].observe).toHaveBeenCalledWith(hero);
  });

  // ── Install tab ────────────────────────────────────────────────────────

  test("clicking install tab button enters followup stage", async () => {
    const { startApp } = await import("./app-controller");

    const root = makeEl("div");
    root.id = "app";
    (document.body as any).appendChild(root);

    const state = createSiteState(entries, "sunny");
    const controller = startApp(root, state);

    const installTabButton = makeEl("button");
    installTabButton.dataset.installTab = "download";
    root.dispatchEvent(click(installTabButton));

    expect(controller.state.installTab).toBe("download");
    expect(controller.state.installDialogStage).toBe("followup");
  });

  test("clicking install tab from download keeps followup stage", async () => {
    const { startApp } = await import("./app-controller");

    const root = makeEl("div");
    root.id = "app";
    (document.body as any).appendChild(root);

    const state = { ...createSiteState(entries, "sunny"), installTab: "download" as const, installDialogStage: "followup" as const };
    const controller = startApp(root, state);

    const homebrewButton = makeEl("button");
    homebrewButton.dataset.installTab = "homebrew";
    root.dispatchEvent(click(homebrewButton));

    expect(controller.state.installTab).toBe("homebrew");
    expect(controller.state.installDialogStage).toBe("followup");
  });

  // ── Highlight selection ─────────────────────────────────────────────────

  test("clicking highlight link updates controller.state.activeHighlight", async () => {
    const { startApp } = await import("./app-controller");

    const root = makeEl("div");
    root.id = "app";
    (document.body as any).appendChild(root);

    const state = createSiteState(entries, "sunny");
    const controller = startApp(root, state);

    const highlightLink = makeEl("a");
    highlightLink.dataset.highlightLink = "settings-home";
    root.dispatchEvent(click(highlightLink));

    expect(controller.state.activeHighlight).toBe("settings-home");
  });

  test("highlight selection does not affect other state", async () => {
    const { startApp } = await import("./app-controller");

    const root = makeEl("div");
    root.id = "app";
    (document.body as any).appendChild(root);

    const state = createSiteState(entries, "sunny");
    const controller = startApp(root, state);

    const highlightLink = makeEl("a");
    highlightLink.dataset.highlightLink = "recording-overlay";
    root.dispatchEvent(click(highlightLink));

    expect(controller.state.theme).toBe("sunny");
    expect(controller.state.installTab).toBe("homebrew");
    expect(controller.state.activeVersion).toBe("1.3.2");
  });

  // ── Version selection ─────────────────────────────────────────────────

  test("clicking version button updates controller.state.activeVersion", async () => {
    const { startApp } = await import("./app-controller");

    const root = makeEl("div");
    root.id = "app";
    (document.body as any).appendChild(root);

    const state = createSiteState(entries, "sunny");
    const controller = startApp(root, state);

    const versionButton = makeEl("button");
    versionButton.dataset.version = "1.3.1";
    root.dispatchEvent(click(versionButton));

    expect(controller.state.activeVersion).toBe("1.3.1");
  });

  test("version selection does not affect other state", async () => {
    const { startApp } = await import("./app-controller");

    const root = makeEl("div");
    root.id = "app";
    (document.body as any).appendChild(root);

    const state = createSiteState(entries, "sunny");
    const controller = startApp(root, state);

    const versionButton = makeEl("button");
    versionButton.dataset.version = "1.3.1";
    root.dispatchEvent(click(versionButton));

    expect(controller.state.theme).toBe("sunny");
    expect(controller.state.installTab).toBe("homebrew");
    expect(controller.state.activeHighlight).toBe("mode-cycle");
  });

  // ── Sequence tests ─────────────────────────────────────────────────────

  test("theme then tab changes are independent", async () => {
    const { startApp } = await import("./app-controller");

    const root = makeEl("div");
    root.id = "app";
    (document.body as any).appendChild(root);

    const state = createSiteState(entries, "sunny");
    const controller = startApp(root, state);

    const themeButton = makeEl("button");
    themeButton.dataset.theme = "moon";
    root.dispatchEvent(click(themeButton));
    expect(controller.state.theme).toBe("moon");

    const installTabButton = makeEl("button");
    installTabButton.dataset.installTab = "download";
    root.dispatchEvent(click(installTabButton));
    expect(controller.state.installTab).toBe("download");
    expect(controller.state.installDialogStage).toBe("followup");
    expect(controller.state.theme).toBe("moon");
  });

  test("highlight then version changes are independent", async () => {
    const { startApp } = await import("./app-controller");

    const root = makeEl("div");
    root.id = "app";
    (document.body as any).appendChild(root);

    const state = createSiteState(entries, "sunny");
    const controller = startApp(root, state);

    const highlightLink = makeEl("a");
    highlightLink.dataset.highlightLink = "settings-home";
    root.dispatchEvent(click(highlightLink));
    expect(controller.state.activeHighlight).toBe("settings-home");

    const versionButton = makeEl("button");
    versionButton.dataset.version = "1.3.1";
    root.dispatchEvent(click(versionButton));
    expect(controller.state.activeVersion).toBe("1.3.1");
    expect(controller.state.activeHighlight).toBe("settings-home");
    expect(controller.state.theme).toBe("sunny");
  });
});
