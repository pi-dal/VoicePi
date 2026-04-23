#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

if [ ! -f "$ROOT_DIR/Package.swift" ] || [ ! -d "$ROOT_DIR/Sources/VoicePi" ]; then
  echo "error: run this script from the project root containing Package.swift and Sources/VoicePi" >&2
  exit 1
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/voicepi-benchmark.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

BINARY_PATH="$TMP_DIR/voicepi-benchmark"

SWIFTC=${ROOT_DIR}/Scripts/swiftcw
if [ ! -x "$SWIFTC" ]; then
  SWIFTC=swiftc
fi

"$SWIFTC" \
  -parse-as-library \
  -O \
  -whole-module-optimization \
  "$ROOT_DIR/Sources/VoicePi/TextInjectionTiming.swift" \
  "$ROOT_DIR/Sources/VoicePi/SpeechRecorderStopPolicy.swift" \
  "$ROOT_DIR/Sources/VoicePi/RealtimeOverlayUpdateGate.swift" \
  "$ROOT_DIR/Sources/VoicePi/PostInjectionLearningLoopPolicy.swift" \
  "$ROOT_DIR/Sources/VoicePi/RecordingLatencyTrace.swift" \
  "$ROOT_DIR/Sources/VoicePi/RecordingLatencyHistory.swift" \
  "$ROOT_DIR/Sources/VoicePi/DictionaryModels.swift" \
  "$ROOT_DIR/Sources/VoicePi/DictionarySuggestionExtractor.swift" \
  "$ROOT_DIR/Sources/VoicePi/DictionaryTextNormalizer.swift" \
  "$ROOT_DIR/Sources/VoicePi/FloatingPanelTranscriptPresentationState.swift" \
  "$ROOT_DIR/Sources/VoicePi/PerformanceBenchmarkReport.swift" \
  "$ROOT_DIR/Scripts/benchmark_main.swift" \
  -o "$BINARY_PATH"

"$BINARY_PATH" "$@"
