import { defineConfig } from "vite";

import { loadChangelogEntries } from "./src/lib/changelog";

export default defineConfig(async () => ({
  define: {
    __VOICEPI_CHANGELOGS__: JSON.stringify(
      await loadChangelogEntries("../docs/changelogs")
    )
  },
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"]
  }
}));
