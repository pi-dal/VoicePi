import { describe, expect, test } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const mainSource = readFileSync(resolve(process.cwd(), "src/main.ts"), "utf8");

describe("main template structure", () => {
  test("renders the celestial layer outside the masked atmosphere layer", () => {
    expect(mainSource).toContain('class="theme-celestial-layer"');
    expect(mainSource).toContain('class="theme-atmosphere"');
    expect(mainSource).toContain('class="theme-celestial theme-celestial-halo"');
  });
});
