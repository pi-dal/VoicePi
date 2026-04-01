#!/bin/sh
set -eu

VERSION_VALUE="${VERSION:-${1:-}}"
SHA256_VALUE="${SHA256:-${2:-}}"
RELEASE_URL_VALUE="${RELEASE_URL:-${3:-}}"

if [ -z "$VERSION_VALUE" ] || [ -z "$SHA256_VALUE" ] || [ -z "$RELEASE_URL_VALUE" ]; then
  echo "error: VERSION, SHA256, and RELEASE_URL are required" >&2
  echo "usage: VERSION=1.2.3 SHA256=<sha256|:no_check> RELEASE_URL=https://... ./Scripts/write_homebrew_cask.sh" >&2
  exit 1
fi

OUTPUT_PATH="${OUTPUT_PATH:-Casks/voicepi.rb}"
APP_NAME_VALUE="${APP_NAME:-VoicePi}"
DESC_VALUE="${APP_DESC:-macOS menu-bar voice input app built with SwiftPM}"
HOMEPAGE_VALUE="${HOMEPAGE:-https://github.com/pi-dal/VoicePi}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

if [ "$SHA256_VALUE" = ":no_check" ]; then
  SHA256_LINE='  sha256 :no_check'
else
  SHA256_LINE="  sha256 \"$SHA256_VALUE\""
fi

cat > "$OUTPUT_PATH" <<EOF
cask "voicepi" do
  version "$VERSION_VALUE"
$SHA256_LINE

  url "$RELEASE_URL_VALUE"
  name "$APP_NAME_VALUE"
  desc "$DESC_VALUE"
  homepage "$HOMEPAGE_VALUE"

  depends_on macos: ">= :sonoma"

  app "$APP_NAME_VALUE.app"
end
EOF

echo "Wrote Homebrew cask to $OUTPUT_PATH"
