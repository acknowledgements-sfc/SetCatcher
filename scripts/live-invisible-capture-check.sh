#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SECONDS_PER_PROBE="${DJMEMORY_LIVE_PROBE_SECONDS:-8}"
JSONL_PATH="${DJMEMORY_INVISIBLE_CAPTURE_JSONL:-/tmp/djmemory-invisible-capture-results.jsonl}"

cd "$ROOT_DIR"

swift build --product djmemory >/dev/null
CLI="$ROOT_DIR/.build/debug/djmemory"

rm -f "$JSONL_PATH"

run_probe() {
    local label="$1"
    local software_id="$2"
    local app_name="$3"
    shift 3

    echo "== $label =="
    local output
    if ! output="$("$@" "$CLI" app-audio-probe "$SECONDS_PER_PROBE" "$software_id" 2>&1)"; then
        echo "$output" >&2
        exit 1
    fi
    echo "$output"

    if [[ "$output" != *"PASS meter+archive $software_id"* ]]; then
        echo "Expected $label to report PASS meter+archive $software_id." >&2
        echo "Open $app_name, play audio through Mac system output, and rerun this script." >&2
        exit 1
    fi
}

export DJMEMORY_INVISIBLE_CAPTURE_JSONL="$JSONL_PATH"

run_probe "Serato Process Audio Tap" "serato" "Serato DJ Pro" env
run_probe "rekordbox Process Audio Tap" "rekordbox" "rekordbox" env
run_probe "Traktor Process Audio Tap" "traktor" "Traktor Pro" env
run_probe "VirtualDJ Process Audio Tap" "virtualdj" "VirtualDJ" env
run_probe "djay Process Audio Tap" "djay" "djay Pro" env
run_probe "Serato ScreenCaptureKit fallback" "serato" "Serato DJ Pro" env DJMEMORY_FORCE_SCK_APP_AUDIO=1

echo
echo "Invisible capture JSONL results:"
cat "$JSONL_PATH"
echo
echo "DJMemory invisible capture check passed."
