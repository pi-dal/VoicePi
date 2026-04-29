import { describe, expect, test } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const appControllerSource = readFileSync(resolve(process.cwd(), "src/lib/app-controller.ts"), "utf8");

describe("main template structure", () => {
  test("renders the celestial layer outside the masked atmosphere layer", () => {
    expect(appControllerSource).toContain('class="theme-celestial-layer"');
    expect(appControllerSource).toContain('class="theme-atmosphere"');
    expect(appControllerSource).toContain('class="theme-celestial theme-celestial-halo"');
  });
});
