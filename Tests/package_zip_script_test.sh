#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

mkdir -p "$TMP_DIR/Scripts" "$TMP_DIR/dist/release/VoicePi.app" "$TMP_DIR/bin"

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

cat > "$TMP_DIR/Sources.plist" <<'EOF'
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
mkdir -p "$TMP_DIR/Sources/VoicePi"
cp "$TMP_DIR/Sources.plist" "$TMP_DIR/Sources/VoicePi/Info.plist"

cat > "$TMP_DIR/bin/ditto" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" > .ditto-args
touch dist/release/VoicePi-1.2.3.zip
EOF
chmod +x "$TMP_DIR/bin/ditto"

cat > "$TMP_DIR/bin/make" <<'EOF'
#!/bin/sh
set -eu
exit 0
EOF
chmod +x "$TMP_DIR/bin/make"

cp "$ROOT_DIR/Scripts/package_zip.sh" "$TMP_DIR/Scripts/package_zip.sh" 2>/dev/null || true
[ -x "$TMP_DIR/Scripts/package_zip.sh" ]

(
  cd "$TMP_DIR"
  PATH="$TMP_DIR/bin:$PATH" \
  PACKAGE_VERSION="1.2.3" \
  ./Scripts/package_zip.sh >/dev/null
)

[ -f "$TMP_DIR/dist/release/VoicePi-1.2.3.zip" ]
grep -q -- '--keepParent dist/release/VoicePi.app dist/release/VoicePi-1.2.3.zip' "$TMP_DIR/.ditto-args"
