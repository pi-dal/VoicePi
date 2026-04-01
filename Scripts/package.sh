#!/bin/sh
set -eu

if [ ! -f "Package.swift" ] || [ ! -f "Makefile" ]; then
  echo "error: run this script from the project root containing Package.swift and Makefile" >&2
  exit 1
fi

VERIFY_SCRIPT="Scripts/verify.sh"
INFO_PLIST="Sources/VoicePi/Info.plist"
SIGN_IDENTITY_VALUE="${CODESIGN_IDENTITY:-${SIGN_IDENTITY:-}}"
PACKAGE_VERSION_VALUE="${PACKAGE_VERSION:-$(date '+%Y.%m.%d')}"
PACKAGE_BUILD_VERSION_VALUE="${PACKAGE_BUILD_VERSION:-$(date '+%Y%m%d%H%M%S')}"

if [ ! -f "$INFO_PLIST" ]; then
  echo "error: missing Info.plist at $INFO_PLIST" >&2
  exit 1
fi

if [ ! -f "$VERIFY_SCRIPT" ]; then
  echo "error: missing verification script at $VERIFY_SCRIPT" >&2
  exit 1
fi

if [ ! -x "$VERIFY_SCRIPT" ]; then
  echo "error: verification script is not executable: $VERIFY_SCRIPT" >&2
  echo "hint: chmod +x $VERIFY_SCRIPT" >&2
  exit 1
fi

PLIST_BACKUP=$(mktemp)
cleanup() {
  if [ -f "$PLIST_BACKUP" ]; then
    cp "$PLIST_BACKUP" "$INFO_PLIST"
    rm -f "$PLIST_BACKUP"
  fi
}
trap cleanup EXIT INT TERM

cp "$INFO_PLIST" "$PLIST_BACKUP"

echo "==> Step 1/2: verification"
"./$VERIFY_SCRIPT"

echo
echo "==> Step 2/2: packaging"
echo "Stamping bundle version:"
echo "  CFBundleShortVersionString=$PACKAGE_VERSION_VALUE"
echo "  CFBundleVersion=$PACKAGE_BUILD_VERSION_VALUE"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $PACKAGE_VERSION_VALUE" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $PACKAGE_BUILD_VERSION_VALUE" "$INFO_PLIST"

if [ -n "$SIGN_IDENTITY_VALUE" ]; then
  make release SIGN_IDENTITY="$SIGN_IDENTITY_VALUE"
else
  make release
fi

echo
echo "Packaging complete."
echo "Release app bundle:"
echo "  dist/release/VoicePi.app"
