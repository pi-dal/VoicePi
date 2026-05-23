#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: Scripts/verify-voicepi-entitlements.sh --ipa <path>

Verify that an IPA (e.g. Impactor-signed) preserves App Group entitlements
for both the main app and the keyboard extension.

This script does NOT resign anything — it only reports what entitlements
are actually present in the IPA. Use it to decide whether your current
installation method (Impactor, sideload, etc.) is compatible with the
host app + keyboard extension shared-config architecture.

Exit code:
  0 — both app and extension have group.com.voicepi.shared
  1 — one or both are missing the App Group
  2 — usage / file-not-found error

EOF
}

IPA_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ipa)
      IPA_PATH="${2:-}"; shift 2 ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$IPA_PATH" ]]; then
  echo "ERROR: --ipa <path> is required." >&2
  usage >&2
  exit 2
fi

if [[ ! -f "$IPA_PATH" ]]; then
  echo "ERROR: IPA not found: $IPA_PATH" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="$(mktemp -d /tmp/voicepi-entitlement-check.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# ---------------------------------------------------------------------------
# Unpack
# ---------------------------------------------------------------------------
echo "==> Unpacking $IPA_PATH"
unzip -qo "$IPA_PATH" -d "$WORK_DIR"

APP_PATH="$WORK_DIR/Payload/VoicePiApp.app"
APPEX_PATH="$APP_PATH/PlugIns/VoicePiKeyboardExtension.appex"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: VoicePiApp.app not found in IPA Payload" >&2
  exit 2
fi

if [[ ! -d "$APPEX_PATH" ]]; then
  echo "ERROR: VoicePiKeyboardExtension.appex not found in IPA" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
APP_GROUP="group.com.voicepi.shared"

check_entitlement() {
  local target="$1"
  local label="$2"

  echo ""
  echo "=== $label ==="
  echo "  Path: $target"

  if ! ENTITLEMENTS=$(codesign -d --entitlements :- "$target" 2>/dev/null); then
    echo "  FAILED to read entitlements (binary may not be signed)"
    return 1
  fi

  if echo "$ENTITLEMENTS" | grep -q "$APP_GROUP"; then
    echo "  App Group present: $APP_GROUP"
    echo ""
    echo "$ENTITLEMENTS" | grep -A3 "application-groups" | sed 's/^/  /'
    return 0
  else
    echo "  App Group MISSING: $APP_GROUP"
    echo ""
    echo "  Full entitlements:"
    echo "$ENTITLEMENTS" | sed 's/^/  /'
    return 1
  fi
}

APP_OK=true
APPEX_OK=true

check_entitlement "$APP_PATH" "VoicePiApp.app" || APP_OK=false
check_entitlement "$APPEX_PATH" "VoicePiKeyboardExtension.appex" || APPEX_OK=false

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo "VERDICT"
echo "============================================"
echo ""

if $APP_OK && $APPEX_OK; then
  echo "BOTH app and keyboard extension have $APP_GROUP"
  echo ""
  echo "Impactor preserved App Group entitlements. This installation"
  echo "method IS compatible with the shared-config architecture."
  echo ""
  echo "Next step: the keyboard extension should be able to read API keys"
  echo "configured in the Host App. Test on device to confirm."
  exit 0
else
  echo "ONE OR BOTH targets are missing $APP_GROUP"
  echo ""
  if ! $APPEX_OK; then
    echo "  - Keyboard extension lacks App Group -- it CANNOT read shared config."
  fi
  if ! $APP_OK; then
    echo "  - Main app lacks App Group -- it CANNOT write shared config."
  fi
  echo ""
  echo "This distribution path cannot support shared-config keyboard runtime."
  echo ""
  echo "The host app + keyboard extension architecture requires App Group"
  echo "entitlements to share API keys and configuration. Use a signing or"
  echo "installation method that preserves App Group entitlements for both"
  echo "the main app and the keyboard extension."
  echo ""
  echo "App Groups depend on program membership and must be registered in"
  echo "Certificates, Identifiers & Profiles:"
  echo "  https://developer.apple.com/help/account/reference/supported-capabilities-ios"
  echo "  https://developer.apple.com/help/account/manage-identifiers/enable-app-capabilities"
  echo ""
  echo "If you try an Xcode-managed development install, verify again with"
  echo "this script or inspect with codesign -d --entitlements :- to confirm"
  echo "the App Group entitlement is actually present before relying on it."
  exit 1
fi
