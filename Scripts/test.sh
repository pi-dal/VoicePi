#!/bin/sh
set -eu

if [ ! -f "Package.swift" ] || [ ! -f "Makefile" ]; then
  echo "error: run this script from the project root containing Package.swift and Makefile" >&2
  exit 1
fi

echo "==> Running Swift tests"
set -- test

SWIFT=./Scripts/swiftw
if [ ! -x "$SWIFT" ]; then
  SWIFT=swift
fi

"$SWIFT" "$@"

echo
echo "==> Running shell tests"
for script in Tests/*.sh; do
  echo "==> $script"
  sh "$script"
done

echo
echo "==> Checking site workspace"
if grep -q "^// test fixture$" Package.swift 2>/dev/null; then
  echo "note: test fixture detected — skipping site workspace verification"
elif [ ! -d "site" ]; then
  echo "error: site/ directory not found" >&2
  exit 1
elif [ ! -f "site/package.json" ]; then
  echo "error: site/package.json not found" >&2
  exit 1
elif [ ! -f "pnpm-lock.yaml" ]; then
  echo "error: pnpm-lock.yaml not found — run 'pnpm install' from the workspace root" >&2
  exit 1
elif ! grep -q "site" pnpm-workspace.yaml 2>/dev/null; then
  echo "error: site not listed in pnpm-workspace.yaml" >&2
  exit 1
else
  echo "==> Running site tests"
  cd site && pnpm test -- --run
  echo
  echo "==> Running site typecheck"
  pnpm typecheck
  echo
  echo "==> Running site build"
  pnpm build
  echo
  echo "==> Site verification passed"
fi

echo
echo "All repository tests passed."
