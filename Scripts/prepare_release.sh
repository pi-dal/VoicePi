#!/bin/sh
set -eu

if [ ! -f "Package.swift" ] || [ ! -f "Makefile" ]; then
  echo "error: run this script from the project root containing Package.swift and Makefile" >&2
  exit 1
fi

TAG_NAME_VALUE="${1:-${TAG_NAME:-}}"
if [ -z "$TAG_NAME_VALUE" ]; then
  echo "error: TAG_NAME is required (example: v1.2.3)" >&2
  exit 1
fi

case "$TAG_NAME_VALUE" in
  v*)
    VERSION_VALUE=${TAG_NAME_VALUE#v}
    ;;
  *)
    echo "error: tag must start with 'v' (example: v1.2.3)" >&2
    exit 1
    ;;
esac

APP_NAME_VALUE="${APP_NAME:-VoicePi}"
ASSET_PATH_VALUE="${ASSET_PATH:-dist/release/${APP_NAME_VALUE}-${VERSION_VALUE}.zip}"
ASSET_NAME_VALUE="${ASSET_NAME:-$(basename "$ASSET_PATH_VALUE")}"
BUILD_VERSION_VALUE="${PACKAGE_BUILD_VERSION:-${GITHUB_RUN_NUMBER:-$(date '+%Y%m%d%H%M%S')}}"
REPOSITORY_VALUE="${GITHUB_REPOSITORY:-pi-dal/VoicePi}"
RELEASE_URL_VALUE="${RELEASE_URL:-https://github.com/${REPOSITORY_VALUE}/releases/download/${TAG_NAME_VALUE}/${ASSET_NAME_VALUE}}"
OUTPUT_CASK_PATH_VALUE="${OUTPUT_CASK_PATH:-Casks/voicepi.rb}"

PACKAGE_VERSION="$VERSION_VALUE" PACKAGE_BUILD_VERSION="$BUILD_VERSION_VALUE" ./Scripts/package_zip.sh

if [ ! -f "$ASSET_PATH_VALUE" ]; then
  echo "error: expected release asset at $ASSET_PATH_VALUE" >&2
  exit 1
fi

SHA256_VALUE=$(shasum -a 256 "$ASSET_PATH_VALUE" | awk '{print $1}')

VERSION="$VERSION_VALUE" \
SHA256="$SHA256_VALUE" \
RELEASE_URL="$RELEASE_URL_VALUE" \
OUTPUT_PATH="$OUTPUT_CASK_PATH_VALUE" \
./Scripts/write_homebrew_cask.sh >/dev/null

write_output() {
  key="$1"
  value="$2"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$key" "$value" >> "$GITHUB_OUTPUT"
  else
    printf '%s=%s\n' "$key" "$value"
  fi
}

write_output tag_name "$TAG_NAME_VALUE"
write_output version "$VERSION_VALUE"
write_output asset_path "$ASSET_PATH_VALUE"
write_output asset_name "$ASSET_NAME_VALUE"
write_output sha256 "$SHA256_VALUE"
write_output release_url "$RELEASE_URL_VALUE"
write_output package_build_version "$BUILD_VERSION_VALUE"
write_output cask_path "$OUTPUT_CASK_PATH_VALUE"

echo "Prepared release asset: $ASSET_PATH_VALUE"
