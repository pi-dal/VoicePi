#!/bin/sh
set -eu

if [ ! -f "Package.swift" ] || [ ! -f "Makefile" ]; then
  echo "error: run this script from the project root containing Package.swift and Makefile" >&2
  exit 1
fi

APP_BUNDLE="dist/release/VoicePi.app"
ZIP_PATH="dist/release/VoicePi-macOS.zip"

"./Scripts/package.sh"

if [ ! -d "$APP_BUNDLE" ]; then
  echo "error: expected packaged app bundle at $APP_BUNDLE" >&2
  exit 1
fi

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Zip package complete."
echo "Archive:"
echo "  $ZIP_PATH"
