#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

mkdir -p \
  "$TMP_DIR/Scripts" \
  "$TMP_DIR/Sources/VoicePi/Core/Models" \
  "$TMP_DIR/Sources/VoicePi/Core/Processing" \
  "$TMP_DIR/Sources/VoicePi/Core/Shortcuts" \
  "$TMP_DIR/Sources/VoicePi/UI/Panels" \
  "$TMP_DIR/bin"

cp "$ROOT_DIR/Scripts/benchmark.sh" "$TMP_DIR/Scripts/benchmark.sh"
chmod +x "$TMP_DIR/Scripts/benchmark.sh"

cat > "$TMP_DIR/Package.swift" <<'EOF'
// test fixture
EOF

touch "$TMP_DIR/Sources/VoicePi/Core/Processing/TextInjectionTiming.swift"
touch "$TMP_DIR/Sources/VoicePi/Core/Shortcuts/SpeechRecorderStopPolicy.swift"
touch "$TMP_DIR/Sources/VoicePi/Core/Processing/RealtimeOverlayUpdateGate.swift"
touch "$TMP_DIR/Sources/VoicePi/Core/Processing/PostInjectionLearningLoopPolicy.swift"
touch "$TMP_DIR/Sources/VoicePi/Core/Processing/RecordingLatencyTrace.swift"
touch "$TMP_DIR/Sources/VoicePi/Core/Processing/RecordingLatencyHistory.swift"
touch "$TMP_DIR/Sources/VoicePi/Core/Models/DictionaryModels.swift"
touch "$TMP_DIR/Sources/VoicePi/Core/Processing/DictionarySuggestionExtractor.swift"
touch "$TMP_DIR/Sources/VoicePi/Core/Processing/DictionaryTextNormalizer.swift"
touch "$TMP_DIR/Sources/VoicePi/UI/Panels/FloatingPanelTranscriptPresentationState.swift"
touch "$TMP_DIR/Sources/VoicePi/Core/Processing/PerformanceBenchmarkReport.swift"
touch "$TMP_DIR/Scripts/benchmark_main.swift"

cat > "$TMP_DIR/bin/swiftc" <<'EOF'
#!/bin/sh
set -eu

printf '%s\n' "$@" > .swiftc-args

OUTPUT_PATH=""
PREVIOUS=""
for ARG in "$@"; do
  if [ "$PREVIOUS" = "-o" ]; then
    OUTPUT_PATH="$ARG"
    break
  fi
  PREVIOUS="$ARG"
done

if [ -z "$OUTPUT_PATH" ]; then
  echo "missing -o output path" >&2
  exit 1
fi

cat > "$OUTPUT_PATH" <<'INNER'
#!/bin/sh
set -eu
printf '%s\n' "VoicePi performance benchmarks"
printf '%s\n' "Budgets:"
printf '%s\n' "- text_injection_clipboard_restore_deficit_ms current=0ms legacy=120ms improvement=100.0%"
printf '%s\n' "Microbenchmarks:"
INNER
chmod +x "$OUTPUT_PATH"
EOF
chmod +x "$TMP_DIR/bin/swiftc"

cat > "$TMP_DIR/bin/xcrun" <<'EOF'
#!/bin/sh
set -eu

if [ "${1:-}" = "--sdk" ] && [ "${2:-}" = "macosx" ] && [ "${3:-}" = "--show-sdk-path" ]; then
  printf '%s\n' "/tmp/VoicePiBenchmarkTest.sdk"
  exit 0
fi

echo "unexpected xcrun invocation: $*" >&2
exit 1
EOF
chmod +x "$TMP_DIR/bin/xcrun"

(
  cd "$TMP_DIR"
  PATH="$TMP_DIR/bin:$PATH" \
  ./Scripts/benchmark.sh > .benchmark-output
)

grep -q -- 'TextInjectionTiming.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'SpeechRecorderStopPolicy.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'RealtimeOverlayUpdateGate.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'PostInjectionLearningLoopPolicy.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'RecordingLatencyTrace.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'RecordingLatencyHistory.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'DictionaryModels.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'DictionarySuggestionExtractor.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'DictionaryTextNormalizer.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'FloatingPanelTranscriptPresentationState.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'PerformanceBenchmarkReport.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- 'benchmark_main.swift$' "$TMP_DIR/.swiftc-args"
grep -q -- '^-O$' "$TMP_DIR/.swiftc-args"
grep -q -- '^-whole-module-optimization$' "$TMP_DIR/.swiftc-args"
grep -q -- '^-sdk$' "$TMP_DIR/.swiftc-args"
grep -q -- '^/tmp/VoicePiBenchmarkTest.sdk$' "$TMP_DIR/.swiftc-args"
grep -q -- '^VoicePi performance benchmarks$' "$TMP_DIR/.benchmark-output"
grep -q -- '^- text_injection_clipboard_restore_deficit_ms current=0ms legacy=120ms improvement=100.0%$' "$TMP_DIR/.benchmark-output"
