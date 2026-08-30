#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-debug}"
APP_NAME="SetCatcher"
BUNDLE_ID="app.setcatcher.SetCatcher"
BUNDLE_DIR="$ROOT_DIR/.build/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_PATH="$ROOT_DIR/.build/$CONFIGURATION/SetCatcherApp"
ENTITLEMENTS_PATH="$ROOT_DIR/packaging/SetCatcher.entitlements"
DISTRIBUTION="${SETCATCHER_DISTRIBUTION:-adhoc}"

detect_developer_id_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: .*\)".*/\1/p' \
    | head -n 1
}

resolve_sign_identity() {
  if [[ -n "${SETCATCHER_SIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$SETCATCHER_SIGN_IDENTITY"
    return
  fi
  if [[ "$DISTRIBUTION" == "developer-id" ]]; then
    local detected
    detected="$(detect_developer_id_identity)"
    if [[ -z "$detected" ]]; then
      echo "error: SETCATCHER_DISTRIBUTION=developer-id but no Developer ID Application identity was found." >&2
      echo "Install a Developer ID Application certificate, or set SETCATCHER_SIGN_IDENTITY." >&2
      echo "See docs/signing-and-notarization.md" >&2
      exit 1
    fi
    printf '%s\n' "$detected"
    return
  fi
  printf '%s\n' "-"
}

cd "$ROOT_DIR"
swift build --configuration "$CONFIGURATION" --product SetCatcherApp

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>SetCatcher</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>SetCatcher</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.music</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.2</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright (c) 2026 SetCatcher</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>SetCatcher Capture records the master mix from your DJM or other audio input into your local archive. Audio stays on this Mac.</string>
	<key>NSAudioCaptureUsageDescription</key>
	<string>SetCatcher App audio Capture records a running DJ app when Record/Save is off. Captured audio stays on this Mac and is never uploaded by default.</string>
	<key>NSScreenCaptureUsageDescription</key>
	<string>SetCatcher uses Screen &amp; System Audio Recording when Process Audio Tap is unavailable. Captured audio stays on this Mac and is never uploaded by default.</string>
	<key>NSSupportsAutomaticTermination</key>
	<true/>
	<key>NSSupportsSuddenTermination</key>
	<true/>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>$BUNDLE_ID.callback</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>$BUNDLE_ID</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
PLIST

SIGN_IDENTITY="$(resolve_sign_identity)"

# Ad-hoc sandbox launches fail with POSIX 163 when associated-domains is present without a profile.
ENTITLEMENTS_TO_SIGN="$ENTITLEMENTS_PATH"
ADHOC_ENTITLEMENTS=""
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  ADHOC_ENTITLEMENTS="$(mktemp)"
  cp "$ENTITLEMENTS_PATH" "$ADHOC_ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.associated-domains" "$ADHOC_ENTITLEMENTS" >/dev/null 2>&1 || true
  ENTITLEMENTS_TO_SIGN="$ADHOC_ENTITLEMENTS"
fi

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --sign - --entitlements "$ENTITLEMENTS_TO_SIGN" "$BUNDLE_DIR" >/dev/null
else
  # Hardened runtime required for notarization.
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$ENTITLEMENTS_PATH" \
    "$BUNDLE_DIR" >/dev/null
fi

if [[ -n "$ADHOC_ENTITLEMENTS" ]]; then
  rm -f "$ADHOC_ENTITLEMENTS"
fi

codesign --verify --deep --strict "$BUNDLE_DIR"

echo "$BUNDLE_DIR"
