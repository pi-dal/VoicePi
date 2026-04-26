#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

mkdir -p \
  "$TMP_DIR/bin" \
  "$TMP_DIR/Sources/VoicePi" \
  "$TMP_DIR/fake-bin" \
  "$TMP_DIR/fake-bin/VoicePi_VoicePi.bundle"

cp "$ROOT_DIR/Makefile" "$TMP_DIR/Makefile"

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

cat > "$TMP_DIR/fake-bin/VoicePi" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$TMP_DIR/fake-bin/VoicePi"

cat > "$TMP_DIR/fake-bin/VoicePi_VoicePi.bundle/registry.json" <<'EOF'
{"profiles":[]}
EOF

cat > "$TMP_DIR/bin/swift" <<EOF
#!/bin/sh
set -eu
printf '%s\n' '$TMP_DIR/fake-bin'
EOF
chmod +x "$TMP_DIR/bin/swift"

cat > "$TMP_DIR/bin/codesign" <<'EOF'
#!/bin/sh
set -eu
exit 0
EOF
chmod +x "$TMP_DIR/bin/codesign"

(
  cd "$TMP_DIR"
  PATH="$TMP_DIR/bin:$PATH" \
  make bundle APP_DIR="$TMP_DIR/dist/VoicePi.app" EXEC="$TMP_DIR/fake-bin/VoicePi" \
    > "$TMP_DIR/.make-output" 2>&1
)

[ -f "$TMP_DIR/dist/VoicePi.app/Contents/Resources/VoicePi_VoicePi.bundle/registry.json" ]
if grep -q 'Command not found' "$TMP_DIR/.make-output"; then
  cat "$TMP_DIR/.make-output" >&2
  echo "unexpected command lookup failure during make bundle" >&2
  exit 1
fi
