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
ICON_COMPOSER_SOURCE="$ROOT_DIR/packaging/assets/SetCatcher.icon"
ICON_PATH="$RESOURCES_DIR/SetCatcher.icns"
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

# SPM resource bundles (ClerkKitUI colors/images, PhoneNumberKit) live next to
# the swift build product. Without them, Settings → Sign in traps in Bundle.module.
BUILD_PRODUCTS_DIR="$ROOT_DIR/.build/$CONFIGURATION"
if [[ -d "$BUILD_PRODUCTS_DIR" ]]; then
  shopt -s nullglob
  for bundle in "$BUILD_PRODUCTS_DIR"/*.bundle; do
    cp -R "$bundle" "$RESOURCES_DIR/"
  done
  shopt -u nullglob
fi

if [[ ! -d "$ICON_COMPOSER_SOURCE" ]]; then
  echo "error: Icon Composer file missing: $ICON_COMPOSER_SOURCE" >&2
  exit 1
fi

ICON_WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$ICON_WORK_DIR"' EXIT
mkdir -p "$ICON_WORK_DIR/out"
# Compile the Icon Composer document: Assets.car (layered / glass) + .icns fallback.
xcrun actool "$ICON_COMPOSER_SOURCE" \
  --compile "$ICON_WORK_DIR/out" \
  --platform macosx \
  --minimum-deployment-target 15.0 \
  --target-device mac \
  --app-icon SetCatcher \
  --output-partial-info-plist "$ICON_WORK_DIR/out/icon-partial.plist" \
  --output-format human-readable-text \
  --notices --warnings
if [[ ! -f "$ICON_WORK_DIR/out/Assets.car" ]]; then
  echo "error: actool did not produce Assets.car from $ICON_COMPOSER_SOURCE" >&2
  exit 1
fi
cp "$ICON_WORK_DIR/out/Assets.car" "$RESOURCES_DIR/Assets.car"
# actool names the icns after the .icon document.
if [[ -f "$ICON_WORK_DIR/out/SetCatcher.icns" ]]; then
  cp "$ICON_WORK_DIR/out/SetCatcher.icns" "$ICON_PATH"
elif [[ -f "$ICON_WORK_DIR/out/SetCatcher-Beta-Intrnl-v1.icns" ]]; then
  cp "$ICON_WORK_DIR/out/SetCatcher-Beta-Intrnl-v1.icns" "$ICON_PATH"
else
  echo "error: actool did not produce an icns fallback" >&2
  exit 1
fi
# Keep the composer document in the bundle so Dock/Finder on macOS 26 can use glass layers.
cp -R "$ICON_COMPOSER_SOURCE" "$RESOURCES_DIR/SetCatcher.icon"

if [[ ! -f "$ICON_PATH" ]]; then
  echo "error: $ICON_PATH was not produced" >&2
  exit 1
fi

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
	<key>CFBundleIconFile</key>
	<string>SetCatcher</string>
	<key>CFBundleIconName</key>
	<string>SetCatcher</string>
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
	<string>15.0</string>
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

# Optional local Clerk key so Dock / Spotlight launches still show Sign in.
# Reads admin/.env.local only; never prints the key.
if [[ -f "$ROOT_DIR/admin/.env.local" ]]; then
  python3 - "$ROOT_DIR/admin/.env.local" "$CONTENTS_DIR/Info.plist" <<'PY'
import pathlib, subprocess, sys
env_path, plist = pathlib.Path(sys.argv[1]), sys.argv[2]
key = None
for line in env_path.read_text().splitlines():
    if line.startswith("NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="):
        key = line.split("=", 1)[1].strip().strip('"').strip("'")
        break
if key:
    subprocess.run(
        ["/usr/libexec/PlistBuddy", "-c", f"Add :SETCATCHER_CLERK_PUBLISHABLE_KEY string {key}", plist],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
PY
fi

SIGN_IDENTITY="$(resolve_sign_identity)"

# Ad-hoc sandbox launches fail with POSIX 163 when associated-domains is present without a profile.
ENTITLEMENTS_TO_SIGN="$ENTITLEMENTS_PATH"
ADHOC_ENTITLEMENTS=""
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  ADHOC_ENTITLEMENTS="$(mktemp)"
  cp "$ENTITLEMENTS_PATH" "$ADHOC_ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.associated-domains" "$ADHOC_ENTITLEMENTS" >/dev/null 2>&1 || true
  # clerk-ios Bundle.module falls back to .build/.../*.bundle. Sandbox blocks that path,
  # and putting the bundle at the .app root makes codesign report unsealed contents.
  /usr/libexec/PlistBuddy -c "Delete :com.apple.security.app-sandbox" "$ADHOC_ENTITLEMENTS" >/dev/null 2>&1 || true
  ENTITLEMENTS_TO_SIGN="$ADHOC_ENTITLEMENTS"
fi

# Sign only real bundles (Info.plist). PhoneNumberKit's folder is resources-only.
while IFS= read -r -d '' bundle; do
  if [[ ! -f "$bundle/Info.plist" ]]; then
    continue
  fi
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$bundle" >/dev/null
  else
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$bundle" >/dev/null
  fi
done < <(find "$BUNDLE_DIR" -name '*.bundle' -print0)

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

codesign --verify --strict "$BUNDLE_DIR"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$BUNDLE_DIR" >/dev/null 2>&1 || true

echo "$BUNDLE_DIR"
