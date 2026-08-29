#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DJMemory"
VERSION="${DJMEMORY_VERSION:-0.1.0}"
DIST_DIR="$ROOT_DIR/.build/distribution"
DISTRIBUTION="${DJMEMORY_DISTRIBUTION:-adhoc}"

cd "$ROOT_DIR"

COMMIT_SHA="$(git rev-parse --short HEAD)"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
ARTIFACT_BASENAME="$APP_NAME-$VERSION-$COMMIT_SHA"
ZIP_PATH="$DIST_DIR/$ARTIFACT_BASENAME.zip"
MANIFEST_PATH="$DIST_DIR/$ARTIFACT_BASENAME.json"

mkdir -p "$DIST_DIR"

if [[ "$DISTRIBUTION" == "developer-id" ]]; then
  export DJMEMORY_DISTRIBUTION=developer-id
  bash scripts/build-app.sh release >/dev/null
  bash scripts/notarize-app.sh
  SIGNING_LABEL="Developer ID Application (hardened runtime)"
  NOTARIZATION_LABEL="notarized and stapled"
else
  bash scripts/build-app.sh release >/dev/null
  SIGNING_LABEL="ad-hoc sandboxed local beta"
  NOTARIZATION_LABEL="not notarized"
fi

PLIST="$ROOT_DIR/.build/$APP_NAME.app/Contents/Info.plist"
PLIST_MIN="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST" 2>/dev/null || true)"
if [[ "$PLIST_MIN" != "14.2" ]]; then
  echo "ERROR: LSMinimumSystemVersion is '$PLIST_MIN', expected 14.2" >&2
  exit 1
fi

rm -f "$ZIP_PATH" "$MANIFEST_PATH"
ditto -c -k --keepParent "$ROOT_DIR/.build/$APP_NAME.app" "$ZIP_PATH"

CHECKSUM="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
SIZE_BYTES="$(stat -f "%z" "$ZIP_PATH")"

printf '{\n' > "$MANIFEST_PATH"
printf '  "app_name": "%s",\n' "$APP_NAME" >> "$MANIFEST_PATH"
printf '  "version": "%s",\n' "$VERSION" >> "$MANIFEST_PATH"
printf '  "commit": "%s",\n' "$COMMIT_SHA" >> "$MANIFEST_PATH"
printf '  "build_date": "%s",\n' "$BUILD_DATE" >> "$MANIFEST_PATH"
printf '  "minimum_macos": "14.2",\n' >> "$MANIFEST_PATH"
printf '  "artifact": "%s",\n' "$(basename "$ZIP_PATH")" >> "$MANIFEST_PATH"
printf '  "sha256": "%s",\n' "$CHECKSUM" >> "$MANIFEST_PATH"
printf '  "size_bytes": %s,\n' "$SIZE_BYTES" >> "$MANIFEST_PATH"
printf '  "distribution": "%s",\n' "$DISTRIBUTION" >> "$MANIFEST_PATH"
printf '  "signing": "%s",\n' "$SIGNING_LABEL" >> "$MANIFEST_PATH"
printf '  "notarization": "%s"\n' "$NOTARIZATION_LABEL" >> "$MANIFEST_PATH"
printf '}\n' >> "$MANIFEST_PATH"

echo "$ZIP_PATH"
echo "$MANIFEST_PATH"
