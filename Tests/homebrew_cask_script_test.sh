#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

mkdir -p "$TMP_DIR/Scripts" "$TMP_DIR/Casks"

cp "$ROOT_DIR/Scripts/write_homebrew_cask.sh" "$TMP_DIR/Scripts/write_homebrew_cask.sh"
chmod +x "$TMP_DIR/Scripts/write_homebrew_cask.sh"

(
  cd "$TMP_DIR"
  VERSION="1.2.3" \
  SHA256="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" \
  RELEASE_URL="https://github.com/pi-dal/VoicePi/releases/download/v1.2.3/VoicePi-1.2.3.zip" \
  ./Scripts/write_homebrew_cask.sh
)

CASK_PATH="$TMP_DIR/Casks/voicepi.rb"
[ -f "$CASK_PATH" ]
grep -q 'cask "voicepi" do' "$CASK_PATH"
grep -q 'version "1.2.3"' "$CASK_PATH"
grep -q 'sha256 "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"' "$CASK_PATH"
grep -q 'url "https://github.com/pi-dal/VoicePi/releases/download/v1.2.3/VoicePi-1.2.3.zip"' "$CASK_PATH"
grep -q 'name "VoicePi"' "$CASK_PATH"
grep -q 'desc "macOS menu-bar voice input app built with SwiftPM"' "$CASK_PATH"
grep -q 'homepage "https://github.com/pi-dal/VoicePi"' "$CASK_PATH"
grep -q 'depends_on macos: ">= :sonoma"' "$CASK_PATH"
grep -q 'app "VoicePi.app"' "$CASK_PATH"
