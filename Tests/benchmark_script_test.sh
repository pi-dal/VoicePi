#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

mkdir -p "$TMP_DIR/Scripts" "$TMP_DIR/Sources/VoicePi" "$TMP_DIR/bin"

cp "$ROOT_DIR/Scripts/benchmark.sh" "$TMP_DIR/Scripts/benchmark.sh"
chmod +x "$TMP_DIR/Scripts/benchmark.sh"

cat > "$TMP_DIR/Package.swift" <<'EOF'
// test fixture
EOF

touch "$TMP_DIR/Sources/VoicePi/TextInjectionTiming.swift"
touch "$TMP_DIR/Sources/VoicePi/SpeechRecorderStopPolicy.swift"
touch "$TMP_DIR/Sources/VoicePi/RealtimeOverlayUpdateGate.swift"
touch "$TMP_DIR/Sources/VoicePi/PostInjectionLearningLoopPolicy.swift"
touch "$TMP_DIR/Sources/VoicePi/RecordingLatencyTrace.swift"
touch "$TMP_DIR/Sources/VoicePi/RecordingLatencyHistory.swift"
touch "$TMP_DIR/Sources/VoicePi/DictionaryModels.swift"
touch "$TMP_DIR/Sources/VoicePi/DictionarySuggestionExtractor.swift"
touch "$TMP_DIR/Sources/VoicePi/DictionaryTextNormalizer.swift"
touch "$TMP_DIR/Sources/VoicePi/FloatingPanelTranscriptPresentationState.swift"
touch "$TMP_DIR/Sources/VoicePi/PerformanceBenchmarkReport.swift"
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

(
  cd "$TMP_DIR"
  PATH="$TMP_DIR/bin:$PATH" \
  ./Scripts/benchmark.sh > .benchmark-output
)

grep -q -- 'Sources/VoicePi/TextInjectionTiming.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Sources/VoicePi/SpeechRecorderStopPolicy.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Sources/VoicePi/RealtimeOverlayUpdateGate.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Sources/VoicePi/PostInjectionLearningLoopPolicy.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Sources/VoicePi/RecordingLatencyTrace.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Sources/VoicePi/RecordingLatencyHistory.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Sources/VoicePi/DictionaryModels.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Sources/VoicePi/DictionarySuggestionExtractor.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Sources/VoicePi/DictionaryTextNormalizer.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Sources/VoicePi/FloatingPanelTranscriptPresentationState.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Sources/VoicePi/PerformanceBenchmarkReport.swift' "$TMP_DIR/.swiftc-args"
grep -q -- 'Scripts/benchmark_main.swift' "$TMP_DIR/.swiftc-args"
grep -q -- '^-O$' "$TMP_DIR/.swiftc-args"
grep -q -- '^-whole-module-optimization$' "$TMP_DIR/.swiftc-args"
grep -q -- '^VoicePi performance benchmarks$' "$TMP_DIR/.benchmark-output"
grep -q -- '^- text_injection_clipboard_restore_deficit_ms current=0ms legacy=120ms improvement=100.0%$' "$TMP_DIR/.benchmark-output"
