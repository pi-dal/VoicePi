#!/bin/sh
set -eu

if [ ! -f "Package.swift" ] || [ ! -d "Sources/VoicePi" ]; then
  echo "error: run this script from the project root containing Package.swift and Sources/VoicePi" >&2
  exit 1
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/voicepi-benchmark.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

BINARY_PATH="$TMP_DIR/voicepi-benchmark"

swiftc \
  -parse-as-library \
  Sources/VoicePi/TextInjectionTiming.swift \
  Sources/VoicePi/SpeechRecorderStopPolicy.swift \
  Sources/VoicePi/RealtimeOverlayUpdateGate.swift \
  Sources/VoicePi/PostInjectionLearningLoopPolicy.swift \
  Sources/VoicePi/RecordingLatencyTrace.swift \
  Sources/VoicePi/RecordingLatencyHistory.swift \
  Sources/VoicePi/FloatingPanelTranscriptPresentationState.swift \
  Sources/VoicePi/PerformanceBenchmarkReport.swift \
  Scripts/benchmark_main.swift \
  -o "$BINARY_PATH"

"$BINARY_PATH" "$@"
