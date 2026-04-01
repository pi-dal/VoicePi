#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PLIST="$ROOT_DIR/Sources/VoicePi/Info.plist"

[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$PLIST")" = "AppIcon" ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$PLIST")" = "AppIcon" ]
