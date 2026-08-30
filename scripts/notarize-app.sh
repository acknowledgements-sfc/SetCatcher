#!/usr/bin/env bash
# Submit .build/SetCatcher.app to Apple notary service and staple the ticket.
# Requires Developer ID signing (see docs/signing-and-notarization.md).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="SetCatcher"
BUNDLE_DIR="${SETCATCHER_APP_PATH:-$ROOT_DIR/.build/$APP_NAME.app}"
DIST_DIR="$ROOT_DIR/.build/distribution"
ZIP_FOR_NOTARY="$DIST_DIR/SetCatcher-notarize-upload.zip"

if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "error: app bundle not found at $BUNDLE_DIR" >&2
  echo "Run: SETCATCHER_DISTRIBUTION=developer-id bash scripts/build-app.sh release" >&2
  exit 1
fi

SIGNING_INFO="$(codesign -dv --verbose=4 "$BUNDLE_DIR" 2>&1 || true)"
if ! grep -q "Authority=Developer ID Application" <<<"$SIGNING_INFO"; then
  echo "error: $BUNDLE_DIR is not signed with Developer ID Application." >&2
  echo "Ad-hoc or Apple Development signatures cannot be notarized." >&2
  echo "Create a Developer ID Application certificate, then rebuild with SETCATCHER_DISTRIBUTION=developer-id." >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -f "$ZIP_FOR_NOTARY"
ditto -c -k --keepParent "$BUNDLE_DIR" "$ZIP_FOR_NOTARY"

AUTH_ARGS=()
if [[ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" && -n "${APP_STORE_CONNECT_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  AUTH_ARGS=(
    --key "$APP_STORE_CONNECT_API_KEY_PATH"
    --key-id "$APP_STORE_CONNECT_KEY_ID"
    --issuer "$APP_STORE_CONNECT_ISSUER_ID"
  )
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  AUTH_ARGS=(
    --apple-id "$APPLE_ID"
    --password "$APPLE_APP_SPECIFIC_PASSWORD"
    --team-id "$APPLE_TEAM_ID"
  )
else
  echo "error: set App Store Connect API key env vars (preferred) or APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID." >&2
  echo "See docs/signing-and-notarization.md" >&2
  exit 1
fi

echo "Submitting for notarization…"
xcrun notarytool submit "$ZIP_FOR_NOTARY" --wait "${AUTH_ARGS[@]}"
xcrun stapler staple "$BUNDLE_DIR"
xcrun stapler validate "$BUNDLE_DIR"

echo "Notarized and stapled: $BUNDLE_DIR"
