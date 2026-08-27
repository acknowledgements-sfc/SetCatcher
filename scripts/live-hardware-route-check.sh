#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_PATH="${DJMEMORY_LIVE_HARDWARE_RESULT_PATH:-/tmp/djmemory-live-xz-result.txt}"
REQUIRE_LIVE_HARDWARE="${DJMEMORY_REQUIRE_LIVE_HARDWARE:-0}"
# Optional escape hatch if GUI archive bookmark is exotic:
#   DJMEMORY_ARCHIVE_ROOT=~/Music/DJMemory bash scripts/live-hardware-route-check.sh

cd "$ROOT_DIR"

cat <<'MSG'
DJMemory live hardware route check

Before running:
- Connect an XDJ/DJM/all-in-one that exposes a USB master or REC OUT feed to this Mac.
- Play real program audio through that hardware.
- Make sure DJMemory has microphone/input permission in macOS.

This does not install or test DJMemoryAudio.driver. It verifies the hardware USB feed path.
MSG

TMP_OUTPUT="$(mktemp)"
cleanup() {
    rm -f "$TMP_OUTPUT"
}
trap cleanup EXIT

rm -f "$RESULT_PATH"

if ! DJMEMORY_LIVE_XZ=1 swift test --filter CaptureServiceTests/testLivePioneerInputRecords16Bit48kCapture 2>&1 | tee "$TMP_OUTPUT"; then
    if [[ "$REQUIRE_LIVE_HARDWARE" != "1" ]] && grep -q "No Pioneer-like Core Audio input is present" "$TMP_OUTPUT"; then
        echo
        echo "Live hardware route check skipped: no Pioneer/XDJ/DJM-like Core Audio input is connected."
        echo "Set DJMEMORY_REQUIRE_LIVE_HARDWARE=1 to make this condition fail."
        exit 0
    fi
    exit 1
fi

if [[ ! -s "$RESULT_PATH" ]]; then
    if [[ "$REQUIRE_LIVE_HARDWARE" != "1" ]] && grep -q "Test skipped" "$TMP_OUTPUT"; then
        echo
        echo "Live hardware route check skipped by XCTest. Set DJMEMORY_REQUIRE_LIVE_HARDWARE=1 to require a bench pass."
        exit 0
    fi
    echo "Expected live hardware result file at $RESULT_PATH" >&2
    exit 1
fi

echo
echo "Live hardware result:"
cat "$RESULT_PATH"
echo
echo "DJMemory live hardware route check passed."
