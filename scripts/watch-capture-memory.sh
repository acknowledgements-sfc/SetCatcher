#!/usr/bin/env bash
set -euo pipefail

# Samples a running DJMemory's memory and open descriptors over a long session.
#
# This produces the evidence needed to decide whether the virtual app audio safety
# gate from 2139cb7 can be lifted. That gate exists because a post-enable run
# exhausted system memory; 1a47ede fixed an unbounded FS-watcher leak that is the
# most likely cause, but the fix has not been confirmed over a real long session.
#
#   RSS climbing without plateau      -> a leak is still present, keep the gate
#   FDs climbing monotonically        -> a watcher leak is still present
#   Both flat after warm-up           -> the gate can likely be lifted
#
# Usage:
#   bash scripts/watch-capture-memory.sh                 # sample every 30s until Ctrl-C
#   INTERVAL=10 bash scripts/watch-capture-memory.sh      # faster sampling
#   bash scripts/watch-capture-memory.sh | tee /tmp/run.log
#
# Run it alongside a real armed capture session -- ideally with
# DJMEMORY_ENABLE_VIRTUAL_APP_AUDIO=1 -- for at least the length of a normal set.

APP_NAME="${APP_NAME:-DJMemory}"
INTERVAL="${INTERVAL:-30}"

PID="$(pgrep -x "$APP_NAME" | head -1 || true)"
if [ -z "$PID" ]; then
  echo "error: no running process named '$APP_NAME'." >&2
  echo "Launch the app first (swift run DJMemoryApp, or open .build/$APP_NAME.app)." >&2
  exit 1
fi

echo "Sampling $APP_NAME (pid $PID) every ${INTERVAL}s. Ctrl-C to stop."
printf '%-9s  %12s  %8s  %10s  %10s\n' "elapsed" "rss" "fds" "rss_delta" "fd_delta"

START_EPOCH="$(date +%s)"
BASE_RSS=""
BASE_FD=""

while kill -0 "$PID" 2>/dev/null; do
  # ps reports RSS in KiB.
  RSS_KB="$(ps -o rss= -p "$PID" | tr -d ' ')"
  FD_COUNT="$(lsof -p "$PID" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
  [ -n "$RSS_KB" ] || break

  : "${BASE_RSS:=$RSS_KB}"
  : "${BASE_FD:=$FD_COUNT}"

  ELAPSED=$(( $(date +%s) - START_EPOCH ))
  printf '%-9s  %9s MiB  %8s  %+9s  %+10s\n' \
    "$(printf '%02d:%02d:%02d' $((ELAPSED/3600)) $((ELAPSED%3600/60)) $((ELAPSED%60)))" \
    "$(( RSS_KB / 1024 ))" \
    "$FD_COUNT" \
    "$(( (RSS_KB - BASE_RSS) / 1024 ))MiB" \
    "$(( FD_COUNT - BASE_FD ))"

  sleep "$INTERVAL"
done

echo "$APP_NAME (pid $PID) is no longer running."
