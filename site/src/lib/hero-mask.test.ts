import { describe, expect, test } from "vitest";

import { resolveHeroMaskVars } from "./hero-mask";

describe("resolveHeroMaskVars", () => {
  test("returns viewport-aligned css variables for the hero cutout", () => {
    expect(resolveHeroMaskVars({ left: 120, top: 80, right: 720, bottom: 520 }, 1440, 900)).toEqual({
      left: "120px",
      right: "720px",
      top: "80px",
      bottom: "520px"
    });
  });

  test("clamps bleed-expanded values to the viewport", () => {
    expect(resolveHeroMaskVars({ left: 18, top: 16, right: 980, bottom: 760 }, 1000, 768, 32)).toEqual({
      left: "0px",
      right: "1000px",
      top: "0px",
      bottom: "768px"
    });
  });
});
