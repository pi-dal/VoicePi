#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

mkdir -p "$TMP_DIR/Scripts"
cp "$ROOT_DIR/Scripts/check_source_structure.sh" "$TMP_DIR/Scripts/check_source_structure.sh"
chmod +x "$TMP_DIR/Scripts/check_source_structure.sh"

cat > "$TMP_DIR/Package.swift" <<'EOF'
// test fixture
EOF

mkdir -p \
  "$TMP_DIR/Sources/VoicePi/App" \
  "$TMP_DIR/Sources/VoicePi/Core/Models" \
  "$TMP_DIR/Sources/VoicePi/Adapters/System" \
  "$TMP_DIR/Sources/VoicePi/UI/Panels" \
  "$TMP_DIR/Sources/VoicePi/Support" \
  "$TMP_DIR/Sources/VoicePi/AppIcon.appiconset" \
  "$TMP_DIR/Sources/VoicePi/PromptLibrary"

touch "$TMP_DIR/Sources/VoicePi/Info.plist"
touch "$TMP_DIR/Sources/VoicePi/App/main.swift"
touch "$TMP_DIR/Sources/VoicePi/Core/Models/AppModel.swift"
touch "$TMP_DIR/Sources/VoicePi/Adapters/System/TextInjector.swift"
touch "$TMP_DIR/Sources/VoicePi/UI/Panels/FloatingPanelController.swift"
touch "$TMP_DIR/Sources/VoicePi/Support/RuntimeEnvironment.swift"

(
  cd "$TMP_DIR"
  ./Scripts/check_source_structure.sh > .pass-output
)

grep -q -- '^Source structure check passed\.$' "$TMP_DIR/.pass-output"

touch "$TMP_DIR/Sources/VoicePi/LooseFile.swift"
if (
  cd "$TMP_DIR"
  ./Scripts/check_source_structure.sh > .root-fail-output 2>&1
); then
  echo "expected root-level Swift file structure check to fail" >&2
  exit 1
fi
grep -q -- 'root-level Swift files are not allowed' "$TMP_DIR/.root-fail-output"

rm -f "$TMP_DIR/Sources/VoicePi/LooseFile.swift"
mkdir -p "$TMP_DIR/Sources/VoicePi/Misc"
touch "$TMP_DIR/Sources/VoicePi/Misc/Unexpected.swift"
if (
  cd "$TMP_DIR"
  ./Scripts/check_source_structure.sh > .layer-fail-output 2>&1
); then
  echo "expected unsupported top-level source directory check to fail" >&2
  exit 1
fi
grep -q -- 'unsupported source layer' "$TMP_DIR/.layer-fail-output"

rm -rf "$TMP_DIR/Sources/VoicePi/Misc"
awk 'BEGIN { for (i = 1; i <= 801; i++) print "let value" i " = " i }' \
  > "$TMP_DIR/Sources/VoicePi/UI/Panels/TooLong.swift"
if (
  cd "$TMP_DIR"
  ./Scripts/check_source_structure.sh > .length-fail-output 2>&1
); then
  echo "expected oversized Swift file check to fail" >&2
  exit 1
fi
grep -q -- 'exceeds 800 lines' "$TMP_DIR/.length-fail-output"
