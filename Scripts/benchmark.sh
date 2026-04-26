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
  "$ROOT_DIR/Sources/VoicePi/Core/Processing/TextInjectionTiming.swift" \
  "$ROOT_DIR/Sources/VoicePi/Core/Shortcuts/SpeechRecorderStopPolicy.swift" \
  "$ROOT_DIR/Sources/VoicePi/Core/Processing/RealtimeOverlayUpdateGate.swift" \
  "$ROOT_DIR/Sources/VoicePi/Core/Processing/PostInjectionLearningLoopPolicy.swift" \
  "$ROOT_DIR/Sources/VoicePi/Core/Processing/RecordingLatencyTrace.swift" \
  "$ROOT_DIR/Sources/VoicePi/Core/Processing/RecordingLatencyHistory.swift" \
  "$ROOT_DIR/Sources/VoicePi/Core/Models/DictionaryModels.swift" \
  "$ROOT_DIR/Sources/VoicePi/Core/Processing/DictionarySuggestionExtractor.swift" \
  "$ROOT_DIR/Sources/VoicePi/Core/Processing/DictionaryTextNormalizer.swift" \
  "$ROOT_DIR/Sources/VoicePi/UI/Panels/FloatingPanelTranscriptPresentationState.swift" \
  "$ROOT_DIR/Sources/VoicePi/Core/Processing/PerformanceBenchmarkReport.swift" \
  "$ROOT_DIR/Scripts/benchmark_main.swift" \
  -o "$BINARY_PATH"

"$BINARY_PATH" "$@"
