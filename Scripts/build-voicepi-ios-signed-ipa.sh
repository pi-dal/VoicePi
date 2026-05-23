#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: Scripts/build-voicepi-ios-signed-ipa.sh [--team-id <id>] [--project-dir <dir>] [--clean]

Produces a properly signed IPA suitable for real device installation.

Requirements:
  - Apple Developer account with valid signing certificate / provisioning profile
  - Xcode with the certificate installed in the keychain
  - Workspace includes App Group capability for both app and keyboard extension

Artifacts:
  - VoicePiApp.xcarchive          (properly signed archive)
  - VoicePiApp-signed.ipa         (xcodebuild -exportArchive, ready for device)
  - ExportOptions.plist           (generated in archive dir)

This script preserves entitlements (including App Group) for both the main app
and the keyboard extension via Xcode's official exportArchive path.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/ios/VoicePiKeyboard"
TEAM_ID=""
CLEAN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      TEAM_ID="${2:-}"; shift 2 ;;
    --project-dir)
      PROJECT_DIR="${2:-}"; shift 2 ;;
    --clean)
      CLEAN=1; shift ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Resolve team ID
# ---------------------------------------------------------------------------
if [[ -z "$TEAM_ID" ]]; then
  # Try to extract from the first available signing identity
  TEAM_ID=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -oE '\([A-Z0-9]{10}\)' \
    | head -1 \
    | tr -d '()' || true)

  if [[ -z "$TEAM_ID" ]]; then
    echo "ERROR: Could not determine Team ID. Pass --team-id <id> explicitly." >&2
    echo "Hint: find it in https://developer.apple.com/account under Membership." >&2
    exit 1
  fi

  echo "==> Auto-detected Team ID: $TEAM_ID"
fi

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT_FILE="$PROJECT_DIR/VoicePiKeyboard.xcodeproj"
BUILD_DIR="$PROJECT_DIR/build-artifacts"
ARCHIVE_PATH="$BUILD_DIR/VoicePiApp.xcarchive"
SIGNED_IPA_PATH="$BUILD_DIR/VoicePiApp-signed.ipa"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"
SCHEME="VoicePiApp"

if [[ ! -d "$PROJECT_FILE" ]]; then
  echo "Xcode project not found: $PROJECT_FILE" >&2
  echo "Run 'cd ios/VoicePiKeyboard && xcodegen generate' first." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"

if [[ "$CLEAN" -eq 1 ]]; then
  rm -rf "$ARCHIVE_PATH" "$SIGNED_IPA_PATH" "$EXPORT_OPTIONS_PLIST"
fi

# ---------------------------------------------------------------------------
# 0. Regenerate project from project.yml (critical: prevents stale xcodeproj)
# ---------------------------------------------------------------------------
echo "==> Running xcodegen generate"

if ! command -v xcodegen &>/dev/null; then
  echo "ERROR: xcodegen not found. Install via: brew install xcodegen" >&2
  exit 1
fi

cd "$PROJECT_DIR"
xcodegen generate
cd - >/dev/null

if [[ ! -d "$PROJECT_FILE" ]]; then
  echo "ERROR: xcodegen generate did not produce $PROJECT_FILE" >&2
  exit 1
fi

echo "==> Project regenerated from project.yml"

# ---------------------------------------------------------------------------
# 1. Generate ExportOptions.plist (development method for device testing)
# ---------------------------------------------------------------------------
echo "==> Writing ExportOptions.plist (development)"
cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadSymbols</key>
    <false/>
</dict>
</plist>
PLIST

# ---------------------------------------------------------------------------
# 2. Archive (with code signing allowed)
# ---------------------------------------------------------------------------
echo "==> Archiving VoicePiApp (signed, Release)"

xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  -allowProvisioningUpdates \
  archive

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "ERROR: Archive not produced at $ARCHIVE_PATH" >&2
  exit 1
fi

echo "==> Archive created: $ARCHIVE_PATH"

# ---------------------------------------------------------------------------
# 3. Export signed IPA
# ---------------------------------------------------------------------------
echo "==> Exporting signed IPA (development)"

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -exportPath "$BUILD_DIR" \
  -allowProvisioningUpdates

# xcodebuild -exportArchive names the IPA after the scheme
EXPORTED_IPA="$BUILD_DIR/$SCHEME.ipa"
if [[ -f "$EXPORTED_IPA" ]]; then
  mv "$EXPORTED_IPA" "$SIGNED_IPA_PATH"
  echo "==> Signed IPA: $SIGNED_IPA_PATH"
else
  # xcodebuild may output it differently; try to find it
  FOUND=$(find "$BUILD_DIR" -maxdepth 1 -name "*.ipa" -not -name "*-unsigned*" | head -1)
  if [[ -n "$FOUND" && "$FOUND" != "$SIGNED_IPA_PATH" ]]; then
    mv "$FOUND" "$SIGNED_IPA_PATH"
    echo "==> Signed IPA: $SIGNED_IPA_PATH"
  else
    echo "ERROR: Could not locate exported IPA in $BUILD_DIR" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 4. Entitlement verification
# ---------------------------------------------------------------------------
echo ""
echo "==> Verifying entitlements on exported IPA"

TMP_DIR="$BUILD_DIR/entitlement-check"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
unzip -qo "$SIGNED_IPA_PATH" -d "$TMP_DIR"

check_app_group() {
  local target="$1"
  local label="$2"
  echo ""
  echo "--- $label ---"
  if codesign -d --entitlements :- "$target" 2>/dev/null | grep -q "group.com.voicepi.shared"; then
    echo "  ✅ App Group entitlement present"
    codesign -d --entitlements :- "$target" 2>/dev/null | grep -A3 "application-groups"
  else
    echo "  ❌ App Group entitlement MISSING — keyboard extension will not read shared config"
  fi
}

check_app_group "$TMP_DIR/Payload/VoicePiApp.app" "VoicePiApp.app"
check_app_group "$TMP_DIR/Payload/VoicePiApp.app/PlugIns/VoicePiKeyboardExtension.appex" "VoicePiKeyboardExtension.appex"

rm -rf "$TMP_DIR"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo "Artifacts:"
echo "  Archive:    $ARCHIVE_PATH"
echo "  Signed IPA: $SIGNED_IPA_PATH"
echo "  Options:    $EXPORT_OPTIONS_PLIST"
echo "============================================"
echo ""
echo "Install on device via Xcode:"
echo "  xcrun devicectl device install app --device <UDID> $SIGNED_IPA_PATH"
echo ""
echo "Or drag $SIGNED_IPA_PATH onto the device in Xcode's Devices window."
