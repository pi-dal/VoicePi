#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: Scripts/build-voicepi-ios-artifacts.sh [--project-dir <dir>] [--clean]

Builds the current iOS VoicePi app into reusable unsigned artifacts:
  - VoicePiApp.xcarchive
  - VoicePiApp.xcarchive.zip
  - VoicePiApp-unsigned.ipa

This does not produce an installable signed IPA.
EOF
}

PROJECT_DIR=""
CLEAN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="${2:-}"
      shift 2
      ;;
    --clean)
      CLEAN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_DIR" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  PROJECT_DIR="$REPO_ROOT/ios/VoicePiKeyboard"
fi

PROJECT_FILE="$PROJECT_DIR/VoicePiKeyboard.xcodeproj"
ARCHIVE_DIR="$PROJECT_DIR/build-artifacts"
ARCHIVE_PATH="$ARCHIVE_DIR/VoicePiApp.xcarchive"
ARCHIVE_ZIP_PATH="$ARCHIVE_DIR/VoicePiApp.xcarchive.zip"
UNSIGNED_IPA_PATH="$ARCHIVE_DIR/VoicePiApp-unsigned.ipa"
UNSIGNED_WORK_DIR="$ARCHIVE_DIR/unsigned-ipa"
APP_PATH="$ARCHIVE_PATH/Products/Applications/VoicePiApp.app"

if [[ ! -d "$PROJECT_FILE" ]]; then
  echo "Xcode project not found: $PROJECT_FILE" >&2
  exit 1
fi

mkdir -p "$ARCHIVE_DIR"

if [[ "$CLEAN" -eq 1 ]]; then
  rm -rf "$ARCHIVE_PATH" "$ARCHIVE_ZIP_PATH" "$UNSIGNED_IPA_PATH" "$UNSIGNED_WORK_DIR"
fi

echo "==> Archiving VoicePiApp without code signing"
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme VoicePiApp \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  archive

if [[ ! -d "$APP_PATH" ]]; then
  echo "Archived app not found: $APP_PATH" >&2
  exit 1
fi

echo "==> Compressing xcarchive"
rm -f "$ARCHIVE_ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$ARCHIVE_PATH" "$ARCHIVE_ZIP_PATH"

echo "==> Packaging unsigned IPA shell"
rm -rf "$UNSIGNED_WORK_DIR"
mkdir -p "$UNSIGNED_WORK_DIR/Payload"
cp -R "$APP_PATH" "$UNSIGNED_WORK_DIR/Payload/"

(
  cd "$UNSIGNED_WORK_DIR"
  zip -qry "$UNSIGNED_IPA_PATH" Payload
)

echo
echo "Artifacts created:"
echo "  xcarchive:      $ARCHIVE_PATH"
echo "  xcarchive zip:  $ARCHIVE_ZIP_PATH"
echo "  unsigned ipa:   $UNSIGNED_IPA_PATH"
echo
echo "Note: the IPA is unsigned and is not expected to be installable."
