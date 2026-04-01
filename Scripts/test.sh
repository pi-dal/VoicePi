#!/bin/sh
set -eu

if [ ! -f "Package.swift" ] || [ ! -f "Makefile" ]; then
  echo "error: run this script from the project root containing Package.swift and Makefile" >&2
  exit 1
fi

echo "==> Running Swift tests"
swift test

echo
echo "==> Running shell tests"
for script in Tests/*.sh; do
  echo "==> $script"
  sh "$script"
done

echo
echo "All repository tests passed."
