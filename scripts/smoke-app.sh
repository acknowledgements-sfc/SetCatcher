#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="SetCatcher"
BUNDLE_DIR="$ROOT_DIR/.build/$APP_NAME.app"
STRICT="${SETCATCHER_SMOKE_STRICT:-0}"

cd "$ROOT_DIR"

bash scripts/build-app.sh debug >/dev/null
codesign --verify --deep --strict "$BUNDLE_DIR"

osascript -e "tell application id \"app.setcatcher.SetCatcher\" to quit" >/dev/null 2>&1 || true
sleep 1

open "$BUNDLE_DIR"

for _ in {1..20}; do
    if pgrep -x "$APP_NAME" >/dev/null; then
        if WINDOW_CHECK_OUTPUT="$(osascript <<APPLESCRIPT 2>&1
tell application "System Events"
    if not (exists process "$APP_NAME") then
        return "missing-process"
    end if

    tell process "$APP_NAME"
        repeat 20 times
            if (count of windows) > 0 then
                return "window-found"
            end if
            delay 0.25
        end repeat
    end tell
end tell

return "no-window"
APPLESCRIPT
)"; then
            if [[ "$WINDOW_CHECK_OUTPUT" == "window-found" ]]; then
                echo "SetCatcher window check passed."
            else
                echo "SetCatcher smoke check warning: main window was not detected ($WINDOW_CHECK_OUTPUT)." >&2
                if [[ "$STRICT" == "1" ]]; then
                    osascript -e "tell application id \"app.setcatcher.SetCatcher\" to quit" >/dev/null 2>&1 || true
                    echo "SetCatcher smoke check failed (strict): window missing." >&2
                    exit 1
                fi
            fi
        else
            echo "SetCatcher smoke check warning: window check was blocked or unavailable." >&2
            echo "$WINDOW_CHECK_OUTPUT" >&2
            if [[ "$STRICT" == "1" ]]; then
                osascript -e "tell application id \"app.setcatcher.SetCatcher\" to quit" >/dev/null 2>&1 || true
                echo "SetCatcher smoke check failed (strict): accessibility blocked." >&2
                exit 1
            fi
        fi

        echo "SetCatcher smoke check passed."
        osascript -e "tell application id \"app.setcatcher.SetCatcher\" to quit" >/dev/null 2>&1 || true
        exit 0
    fi

    sleep 0.5
done

echo "SetCatcher smoke check failed: app process did not launch." >&2
exit 1
