#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

mkdir -p "$TMP_DIR/Scripts" "$TMP_DIR/dist/release" "$TMP_DIR/Casks" "$TMP_DIR/bin"

cp "$ROOT_DIR/Scripts/prepare_release.sh" "$TMP_DIR/Scripts/prepare_release.sh"
chmod +x "$TMP_DIR/Scripts/prepare_release.sh"

cat > "$TMP_DIR/Package.swift" <<'EOF'
// test fixture
EOF

cat > "$TMP_DIR/Makefile" <<'EOF'
package:
	@true
EOF

cat > "$TMP_DIR/Scripts/package_zip.sh" <<'EOF'
#!/bin/sh
set -eu
mkdir -p dist/release
printf 'zip-contents' > dist/release/VoicePi-1.2.3.zip
EOF
chmod +x "$TMP_DIR/Scripts/package_zip.sh"

cat > "$TMP_DIR/Scripts/write_homebrew_cask.sh" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$VERSION" > .observed-version
printf '%s\n' "$SHA256" > .observed-sha
printf '%s\n' "$RELEASE_URL" > .observed-url
printf '%s\n' "$OUTPUT_PATH" > .observed-output-path
mkdir -p "$(dirname "$OUTPUT_PATH")"
printf 'generated-cask' > "$OUTPUT_PATH"
EOF
chmod +x "$TMP_DIR/Scripts/write_homebrew_cask.sh"

OUTPUT_FILE="$TMP_DIR/release.outputs"
(
  cd "$TMP_DIR"
  unset TAG_NAME OUTPUT_CASK_PATH RELEASE_URL VERSION SHA256 ASSET_PATH ASSET_NAME APP_NAME
  GITHUB_REPOSITORY="pi-dal/VoicePi" \
  GITHUB_OUTPUT="$OUTPUT_FILE" \
  PACKAGE_BUILD_VERSION="42" \
  ./Scripts/prepare_release.sh v1.2.3 >/dev/null
)

EXPECTED_SHA=$(printf 'zip-contents' | shasum -a 256 | awk '{print $1}')

grep -q '^tag_name=v1.2.3$' "$OUTPUT_FILE"
grep -q '^version=1.2.3$' "$OUTPUT_FILE"
grep -q '^asset_path=dist/release/VoicePi-1.2.3.zip$' "$OUTPUT_FILE"
grep -q '^asset_name=VoicePi-1.2.3.zip$' "$OUTPUT_FILE"
grep -q "^sha256=$EXPECTED_SHA\$" "$OUTPUT_FILE"
grep -q '^release_url=https://github.com/pi-dal/VoicePi/releases/download/v1.2.3/VoicePi-1.2.3.zip$' "$OUTPUT_FILE"
grep -q '^package_build_version=42$' "$OUTPUT_FILE"
grep -q '^cask_path=Casks/voicepi.rb$' "$OUTPUT_FILE"

[ "$(cat "$TMP_DIR/.observed-version")" = "1.2.3" ]
[ "$(cat "$TMP_DIR/.observed-sha")" = "$EXPECTED_SHA" ]
[ "$(cat "$TMP_DIR/.observed-url")" = "https://github.com/pi-dal/VoicePi/releases/download/v1.2.3/VoicePi-1.2.3.zip" ]
[ "$(cat "$TMP_DIR/.observed-output-path")" = "Casks/voicepi.rb" ]
[ -f "$TMP_DIR/Casks/voicepi.rb" ]
