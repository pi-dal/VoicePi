#!/bin/sh
set -eu

echo "==> Testing site workspace verification contract"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -d "site" ]; then
  echo "site/ directory not found — skipping" >&2
  exit 0
fi

if [ ! -f "site/package.json" ]; then
  echo "site/package.json not found — skipping" >&2
  exit 0
fi

if [ -f "site/package-lock.json" ]; then
  echo "site/package-lock.json found — should not exist (pnpm-only workspace)" >&2
  exit 1
fi

if [ ! -f "pnpm-workspace.yaml" ]; then
  echo "pnpm-workspace.yaml not found at root — pnpm workspace not configured" >&2
  exit 1
fi

if ! grep -q "site" pnpm-workspace.yaml; then
  echo "site not listed in pnpm-workspace.yaml" >&2
  exit 1
fi

if [ ! -f "pnpm-lock.yaml" ]; then
  echo "pnpm-lock.yaml missing at root — run 'pnpm install' from the workspace root" >&2
  exit 1
fi

echo "==> site workspace contract OK"
echo "All site workspace tests passed."
