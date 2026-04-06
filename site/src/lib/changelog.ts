import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

import type { ChangelogEntry, ChangelogSection } from "../types";

function parseVersionParts(version: string): number[] {
  return version.split(".").map((part) => Number.parseInt(part, 10));
}

export function compareVersionsDescending(left: string, right: string): number {
  const leftParts = parseVersionParts(left);
  const rightParts = parseVersionParts(right);
  const length = Math.max(leftParts.length, rightParts.length);

  for (let index = 0; index < length; index += 1) {
    const leftPart = leftParts[index] ?? 0;
    const rightPart = rightParts[index] ?? 0;

    if (leftPart !== rightPart) {
      return rightPart - leftPart;
    }
  }

  return 0;
}

function normalizeBody(lines: string[]): string {
  return lines.join("\n").trim();
}

export function parseChangelogMarkdown(markdown: string, filename: string): ChangelogEntry {
  const lines = markdown.replace(/\r\n/g, "\n").split("\n");
  const titleLine = lines.find((line) => line.startsWith("# "));

  if (!titleLine) {
    throw new Error(`Expected markdown title in ${filename}.`);
  }

  const title = titleLine.replace(/^#\s+/, "").trim();
  const versionMatch = title.match(/v(\d+\.\d+\.\d+)/);

  if (!versionMatch) {
    throw new Error(`Expected semantic version in ${filename}.`);
  }

  const sections: ChangelogSection[] = [];
  let currentTitle: string | null = null;
  let currentBody: string[] = [];

  for (const line of lines.slice(1)) {
    if (line.startsWith("## ")) {
      if (currentTitle) {
        sections.push({
          title: currentTitle,
          body: normalizeBody(currentBody)
        });
      }

      currentTitle = line.replace(/^##\s+/, "").trim();
      currentBody = [];
      continue;
    }

    if (currentTitle) {
      currentBody.push(line);
    }
  }

  if (currentTitle) {
    sections.push({
      title: currentTitle,
      body: normalizeBody(currentBody)
    });
  }

  return {
    slug: filename.replace(/\.md$/, ""),
    version: versionMatch[1],
    title,
    sections
  };
}

export async function loadChangelogEntries(changelogDir: string): Promise<ChangelogEntry[]> {
  const directory = path.resolve(process.cwd(), changelogDir);
  const filenames = await readdir(directory);
  const markdownFiles = filenames.filter((filename: string) => /^v\d+\.\d+\.\d+\.md$/.test(filename));
  const entries = await Promise.all(
    markdownFiles.map(async (filename: string) => {
      const markdown = await readFile(path.join(directory, filename), "utf8");
      return parseChangelogMarkdown(markdown, filename);
    })
  );

  return entries.sort((left: ChangelogEntry, right: ChangelogEntry) =>
    compareVersionsDescending(left.version, right.version)
  );
}
