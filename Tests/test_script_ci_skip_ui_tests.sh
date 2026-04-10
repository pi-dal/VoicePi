#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

mkdir -p "$TMP_DIR/Scripts" "$TMP_DIR/Tests" "$TMP_DIR/bin"

cp "$ROOT_DIR/Scripts/test.sh" "$TMP_DIR/Scripts/test.sh"
chmod +x "$TMP_DIR/Scripts/test.sh"

cat > "$TMP_DIR/Package.swift" <<'EOF'
// test fixture
EOF

cat > "$TMP_DIR/Makefile" <<'EOF'
test:
	@true
EOF

cat > "$TMP_DIR/Tests/noop_test.sh" <<'EOF'
#!/bin/sh
set -eu
exit 0
EOF
chmod +x "$TMP_DIR/Tests/noop_test.sh"

cat > "$TMP_DIR/bin/swift" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" > .swift-test-args
exit 0
EOF
chmod +x "$TMP_DIR/bin/swift"

(
  cd "$TMP_DIR"
  PATH="$TMP_DIR/bin:$PATH" \
  CI=true \
  ./Scripts/test.sh >/dev/null
)

grep -q -- '--skip ResultReviewPanelControllerTests' "$TMP_DIR/.swift-test-args"
grep -q -- '--skip SettingsWindowLayoutTests' "$TMP_DIR/.swift-test-args"
