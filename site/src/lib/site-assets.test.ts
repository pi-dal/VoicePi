import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, test } from "vitest";

const siteRoot = resolve(import.meta.dirname, "../..");
const publicRoot = resolve(siteRoot, "public");
const indexHtml = readFileSync(resolve(siteRoot, "index.html"), "utf8");

describe("site assets", () => {
  test("declares favicon assets and GitHub Pages redirect in index.html", () => {
    expect(indexHtml).toContain('rel="icon"');
    expect(indexHtml).toContain('rel="apple-touch-icon"');
    expect(indexHtml).toContain("voicepi.pi-dal.com");
    expect(indexHtml).toContain("github.io");
  });

  test("ships custom domain and icon files from public/", () => {
    expect(existsSync(resolve(publicRoot, "CNAME"))).toBe(true);
    expect(readFileSync(resolve(publicRoot, "CNAME"), "utf8").trim()).toBe("voicepi.pi-dal.com");
    expect(existsSync(resolve(publicRoot, "favicon-32.png"))).toBe(true);
    expect(existsSync(resolve(publicRoot, "favicon-192.png"))).toBe(true);
    expect(existsSync(resolve(publicRoot, "apple-touch-icon.png"))).toBe(true);
  });
});
