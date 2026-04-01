#!/bin/sh
set -eu

if [ ! -f "Package.swift" ] || [ ! -f "Makefile" ]; then
  echo "error: run this script from the project root containing Package.swift and Makefile" >&2
  exit 1
fi

APP_NAME="VoicePi"
VERIFY_TARGET="${VERIFY_TARGET:-verify}"
DEBUG_APP_BUNDLE="dist/debug/${APP_NAME}.app"

echo "==> Starting verification workflow"
echo "==> Running repository tests and building development app"
make "$VERIFY_TARGET"

echo
echo "Verification succeeded."
echo "Development app bundle:"
echo "  $DEBUG_APP_BUNDLE"
echo
echo "Next step:"
echo "  If the verification build looks good, run ./Scripts/package.sh"
