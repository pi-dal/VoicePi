#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SOURCE_FILE="$ROOT_DIR/Sources/VoicePi/AppleTranslateService.swift"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

cat > "$TMP_DIR/repro.swift" <<'EOF'
import SwiftUI
import Translation
EOF

if grep -q '^import _Translation_SwiftUI$' "$SOURCE_FILE"; then
  cat >> "$TMP_DIR/repro.swift" <<'EOF'
import _Translation_SwiftUI
EOF
fi

cat >> "$TMP_DIR/repro.swift" <<'EOF'

@available(macOS 15.0, *)
struct TranslationTaskImportRepro: View {
    let configuration: TranslationSession.Configuration? = nil

    var body: some View {
        Color.clear.translationTask(configuration) { _ in }
    }
}
EOF

"$ROOT_DIR/Scripts/swiftcw" -typecheck -sdk "$SDK_PATH" "$TMP_DIR/repro.swift" >/dev/null
