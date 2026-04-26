#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SOURCE_ROOT="$ROOT_DIR/Sources/VoicePi"
MAX_SWIFT_LINES=800

if [ ! -f "$ROOT_DIR/Package.swift" ] || [ ! -d "$SOURCE_ROOT" ]; then
  echo "error: run this script from the project root containing Package.swift and Sources/VoicePi" >&2
  exit 1
fi

for resource_path in \
  "$SOURCE_ROOT/Info.plist" \
  "$SOURCE_ROOT/AppIcon.appiconset" \
  "$SOURCE_ROOT/PromptLibrary"
do
  if [ ! -e "$resource_path" ]; then
    echo "error: required root resource is missing: $resource_path" >&2
    exit 1
  fi
done

root_level_swift_files=$(find "$SOURCE_ROOT" -maxdepth 1 -type f -name '*.swift' -print)
if [ -n "$root_level_swift_files" ]; then
  echo "error: root-level Swift files are not allowed under Sources/VoicePi:" >&2
  printf '%s\n' "$root_level_swift_files" >&2
  exit 1
fi

find "$SOURCE_ROOT" -type f -name '*.swift' -print | while IFS= read -r swift_file; do
  relative_path=${swift_file#"$SOURCE_ROOT"/}
  top_level_layer=${relative_path%%/*}

  case "$top_level_layer" in
    App|Core|Adapters|UI|Support)
      ;;
    *)
      echo "error: unsupported source layer for $relative_path; expected App, Core, Adapters, UI, or Support" >&2
      exit 1
      ;;
  esac

  line_count=$(wc -l < "$swift_file")
  if [ "$line_count" -gt "$MAX_SWIFT_LINES" ]; then
    echo "error: $relative_path exceeds $MAX_SWIFT_LINES lines ($line_count)" >&2
    exit 1
  fi
done

echo "Source structure check passed."
