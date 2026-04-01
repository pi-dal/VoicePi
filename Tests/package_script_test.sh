#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

mkdir -p "$TMP_DIR/Scripts" "$TMP_DIR/Sources/VoicePi" "$TMP_DIR/bin"

cp "$ROOT_DIR/Scripts/package.sh" "$TMP_DIR/Scripts/package.sh"
chmod +x "$TMP_DIR/Scripts/package.sh"

cat > "$TMP_DIR/Package.swift" <<'EOF'
// test fixture
EOF

cat > "$TMP_DIR/Makefile" <<'EOF'
release:
	@true
EOF

cat > "$TMP_DIR/Scripts/verify.sh" <<'EOF'
#!/bin/sh
set -eu
exit 0
EOF
chmod +x "$TMP_DIR/Scripts/verify.sh"

cat > "$TMP_DIR/Sources/VoicePi/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
</dict>
</plist>
EOF

cat > "$TMP_DIR/bin/make" <<'EOF'
#!/bin/sh
set -eu

if [ "${1:-}" = "release" ]; then
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/VoicePi/Info.plist > .observed-short-version
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Sources/VoicePi/Info.plist > .observed-build-version
  exit 0
fi

echo "unexpected make target: $*" >&2
exit 1
EOF
chmod +x "$TMP_DIR/bin/make"

(
  cd "$TMP_DIR"
  PATH="$TMP_DIR/bin:$PATH" \
  PACKAGE_VERSION="2026.03.31" \
  PACKAGE_BUILD_VERSION="20260331213045" \
  ./Scripts/package.sh >/dev/null
)

observed_short_version=$(cat "$TMP_DIR/.observed-short-version")
observed_build_version=$(cat "$TMP_DIR/.observed-build-version")
restored_short_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$TMP_DIR/Sources/VoicePi/Info.plist")
restored_build_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$TMP_DIR/Sources/VoicePi/Info.plist")

[ "$observed_short_version" = "2026.03.31" ]
[ "$observed_build_version" = "20260331213045" ]
[ "$restored_short_version" = "1.0" ]
[ "$restored_build_version" = "1" ]
