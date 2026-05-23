#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: Scripts/resign-voicepi-ipa.sh [--unsigned-ipa <path>] [--output-ipa <path>]

Resigns an unsigned VoicePi IPA, explicitly preserving App Group entitlements
for both the main app and the keyboard extension.

This script does NOT require a paid Apple Developer account — it can work with
a free Apple ID for development (7-day provisioning). However, the provisioning
profile MUST include the App Group capability for the keyboard extension to
read shared config.

Prerequisites:
  - Valid signing identity in keychain (Xcode-managed or manual)
  - Provisioning profiles that include com.apple.security.application-groups
    for both com.voicepi.VoicePiApp and com.voicepi.VoicePiApp.VoicePiKeyboardExtension
  - If using a free account, deploy via Xcode (not Impactor) for App Group support

EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/ios/VoicePiKeyboard"
BUILD_DIR="$PROJECT_DIR/build-artifacts"

UNSIGNED_IPA="${UNSIGNED_IPA:-$BUILD_DIR/VoicePiApp-unsigned.ipa}"
SIGNED_IPA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --unsigned-ipa)
      UNSIGNED_IPA="${2:-}"; shift 2 ;;
    --output-ipa)
      SIGNED_IPA="${2:-}"; shift 2 ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$SIGNED_IPA" ]]; then
  SIGNED_IPA="$BUILD_DIR/VoicePiApp-resigned.ipa"
fi

if [[ ! -f "$UNSIGNED_IPA" ]]; then
  echo "ERROR: Unsigned IPA not found: $UNSIGNED_IPA" >&2
  echo "Run Scripts/build-voicepi-ios-artifacts.sh first." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Resolve signing identity
# ---------------------------------------------------------------------------
SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -oE '[A-F0-9]{40} ".*"' \
  | head -1 \
  | grep -oE '"(.*)"' \
  | tr -d '"' || true)

if [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "ERROR: No valid code signing identity found in keychain." >&2
  echo "Open Xcode → Settings → Accounts → verify your Apple ID is signed in." >&2
  exit 1
fi

echo "==> Using signing identity: $SIGNING_IDENTITY"

# ---------------------------------------------------------------------------
# Entitlement files (from project source)
# ---------------------------------------------------------------------------
APP_ENTITLEMENTS="$PROJECT_DIR/VoicePiApp/VoicePiApp.entitlements"
APPEX_ENTITLEMENTS="$PROJECT_DIR/VoicePiKeyboardExtension/VoicePiKeyboardExtension.entitlements"

if [[ ! -f "$APPEX_ENTITLEMENTS" ]]; then
  echo "ERROR: Extension entitlements file not found: $APPEX_ENTITLEMENTS" >&2
  exit 1
fi

if [[ ! -f "$APP_ENTITLEMENTS" ]]; then
  echo "ERROR: App entitlements file not found: $APP_ENTITLEMENTS" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Unpack unsigned IPA
# ---------------------------------------------------------------------------
WORK_DIR="$BUILD_DIR/resign-work"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "==> Unpacking unsigned IPA"
unzip -qo "$UNSIGNED_IPA" -d "$WORK_DIR"

APPEX_PATH="$WORK_DIR/Payload/VoicePiApp.app/PlugIns/VoicePiKeyboardExtension.appex"
APP_PATH="$WORK_DIR/Payload/VoicePiApp.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: App bundle not found in IPA: $APP_PATH" >&2
  exit 1
fi

if [[ ! -d "$APPEX_PATH" ]]; then
  echo "ERROR: Extension not found in IPA: $APPEX_PATH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Verify entitlements are present in unsigned IPA (pre-sign check)
# ---------------------------------------------------------------------------
echo ""
echo "=== Pre-sign entitlement check ==="
echo ""

check_entitlement() {
  local target="$1" label="$2"
  echo "$label:"
  if codesign -d --entitlements :- "$target" 2>/dev/null | grep -q "group.com.voicepi.shared"; then
    echo "  ✅ App Group already present (embedded in binary)"
  else
    echo "  ⚠️  App Group not embedded in binary — will be added from .entitlements file"
  fi
}

check_entitlement "$APP_PATH" "VoicePiApp.app"
check_entitlement "$APPEX_PATH" "VoicePiKeyboardExtension.appex"

# ---------------------------------------------------------------------------
# Step 1: Sign the keyboard extension FIRST (with its entitlements)
# ---------------------------------------------------------------------------
echo ""
echo "=== Step 1: Signing keyboard extension ==="

codesign -f -s "$SIGNING_IDENTITY" \
  --entitlements "$APPEX_ENTITLEMENTS" \
  --timestamp=none \
  "$APPEX_PATH"

echo "  ✅ Extension signed"

# ---------------------------------------------------------------------------
# Step 2: Sign frameworks/dylibs in the app bundle (if any)
# ---------------------------------------------------------------------------
# VoicePiApp uses Swift Package Manager dependencies; these are statically
# linked, so there are typically no embedded frameworks to sign.
# If that changes, add framework signing here.

# ---------------------------------------------------------------------------
# Step 3: Sign the main app (with its entitlements)
# ---------------------------------------------------------------------------
echo ""
echo "=== Step 2: Signing main app ==="

codesign -f -s "$SIGNING_IDENTITY" \
  --entitlements "$APP_ENTITLEMENTS" \
  --timestamp=none \
  "$APP_PATH"

echo "  ✅ App signed"

# ---------------------------------------------------------------------------
# Step 4: Post-sign verification
# ---------------------------------------------------------------------------
echo ""
echo "=== Post-sign entitlement verification ==="
echo ""

verify_entitlement() {
  local target="$1" label="$2"
  echo "$label:"
  if codesign -d --entitlements :- "$target" 2>/dev/null | grep -q "group.com.voicepi.shared"; then
    echo "  ✅ App Group confirmed"
    codesign -d --entitlements :- "$target" 2>/dev/null | grep -A3 "application-groups" | sed 's/^/  /'
  else
    echo "  ❌ App Group MISSING"
    echo ""
    echo "  This means the provisioning profile for this app does not include"
    echo "  the App Group capability. Common causes:"
    echo "    - Free Apple ID used with Impactor (free accounts lack App Groups in IPA flow)"
    echo "    - Provisioning profile was generated without App Group capability"
    echo ""
    echo "  Suggested fix: use Xcode direct deploy (Product → Run) instead of IPA sideload."
    echo "  Xcode's automatic signing for development builds DOES include App Groups."
    return 1
  fi
}

APP_OK=true
APPEX_OK=true

verify_entitlement "$APPEX_PATH" "VoicePiKeyboardExtension.appex" || APPEX_OK=false
verify_entitlement "$APP_PATH" "VoicePiApp.app" || APP_OK=false

# ---------------------------------------------------------------------------
# Step 5: Repack signed IPA
# ---------------------------------------------------------------------------
echo ""
echo "=== Step 3: Repacking signed IPA ==="

rm -f "$SIGNED_IPA"
(
  cd "$WORK_DIR"
  zip -qry "$SIGNED_IPA" Payload
)

echo "  ✅ Signed IPA: $SIGNED_IPA"

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -rf "$WORK_DIR"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo "Signed IPA: $SIGNED_IPA"
echo "============================================"

if $APPEX_OK && $APP_OK; then
  echo ""
  echo "✅ All entitlements verified. IPA is ready for device."
  echo ""
  echo "Install options:"
  echo "  1. Xcode: drag $SIGNED_IPA onto your device in Devices window"
  echo "  2. xcrun devicectl device install app --device <UDID> $SIGNED_IPA"
  echo "  3. Apple Configurator: drag $SIGNED_IPA onto your device"
else
  echo ""
  echo "⚠️  WARNING: App Group entitlement verification failed."
  echo ""
  echo "If you are using a free Apple ID with Cydia Impactor:"
  echo "  Impactor regenerates the provisioning profile without App Group support."
  echo "  This is a limitation of free accounts in the IPA distribution flow."
  echo ""
  echo "WORKAROUND: Deploy directly from Xcode instead of using Impactor:"
  echo "  1. Open ios/VoicePiKeyboard/VoicePiKeyboard.xcodeproj in Xcode"
  echo "  2. Select your device as the run target"
  echo "  3. Product → Run (⌘R)"
  echo "  4. After first launch, go to Settings → General → VPN & Device Management"
  echo "     → Trust the developer certificate"
  echo "  5. The keyboard extension will appear in Settings → Keyboard → Keyboards"
  echo ""
  echo "  Xcode's automatic signing for development builds includes App Group"
  echo "  support even with a free Apple ID."
fi
