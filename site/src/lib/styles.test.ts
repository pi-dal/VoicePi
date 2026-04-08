import { describe, expect, test } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

describe("hero styles", () => {
  test("does not use a hero ::before background panel", () => {
    expect(styles).not.toContain(".hero::before");
  });

  test("does not include hero in the shared panel surface rule", () => {
    expect(styles).not.toContain('body[data-theme="sunny"] .hero');
    expect(styles).not.toContain('body[data-theme="moon"] .hero');
  });

  test("uses a dedicated theme-atmosphere mask class for the hero cutout", () => {
    expect(styles).toContain(".theme-atmosphere.has-hero-cutout");
    expect(styles).toContain("-webkit-mask:");
    expect(styles).toContain("mask:");
  });

  test("positions the celestial layer on the left side of the page", () => {
    expect(styles).toContain(".theme-celestial-layer");
    expect(styles).toContain("left: min(4vw, 48px);");
  });
});
