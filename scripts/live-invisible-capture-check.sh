#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SECONDS_PER_PROBE="${SETCATCHER_LIVE_PROBE_SECONDS:-30}"
JSONL_PATH="${SETCATCHER_INVISIBLE_CAPTURE_JSONL:-/tmp/setcatcher-invisible-capture-results.jsonl}"
OUTPUT_MODE_LABEL="${SETCATCHER_OUTPUT_MODE_LABEL:-system-default}"

cd "$ROOT_DIR"

swift build --product setcatcher >/dev/null
CLI="$ROOT_DIR/.build/debug/setcatcher"

rm -f "$JSONL_PATH"
export SETCATCHER_INVISIBLE_CAPTURE_JSONL="$JSONL_PATH"
export SETCATCHER_OUTPUT_MODE_LABEL="$OUTPUT_MODE_LABEL"

APPS=(serato rekordbox traktor virtualdj djay)

run_scenario() {
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

    local last_line
    last_line="$(grep "\"softwareID\":\"$software_id\"" "$JSONL_PATH" | tail -1)"
    if [[ -z "$last_line" || "$last_line" != *"\"pass\":true"* ]]; then
        echo "Expected JSONL pass=true for $software_id in $JSONL_PATH." >&2
        exit 1
    fi
}

print_matrix() {
    echo "Invisible capture scenario matrix (one invocation each):"
    for app in "${APPS[@]}"; do
        echo "  - ${app} / processAudioTap / ${OUTPUT_MODE_LABEL} / ${SECONDS_PER_PROBE}s"
        echo "  - ${app} / screenCaptureKit / ${OUTPUT_MODE_LABEL} / ${SECONDS_PER_PROBE}s"
    done
    echo
}

if [[ "${1:-}" == "--print-matrix" ]]; then
    print_matrix
    exit 0
fi

print_matrix

for app in "${APPS[@]}"; do
    case "$app" in
        serato) name="Serato DJ Pro" ;;
        rekordbox) name="rekordbox" ;;
        traktor) name="Traktor Pro" ;;
        virtualdj) name="VirtualDJ" ;;
        djay) name="djay Pro" ;;
        *) name="$app" ;;
    esac
    run_scenario "${app} Process Audio Tap" "$app" "$name" env
    run_scenario "${app} ScreenCaptureKit fallback" "$app" "$name" env SETCATCHER_FORCE_SCK_APP_AUDIO=1
done

echo
echo "Invisible capture JSONL results:"
cat "$JSONL_PATH"
echo
echo "SetCatcher invisible capture check passed."
