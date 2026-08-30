# SetCatcher Signing and Notarization

Last updated: August 7, 2026.

Local and CI builds default to **ad-hoc** signing (`codesign --sign -`). That is enough for smoke tests and Macs that already trust the build. Broad direct-download distribution needs **Developer ID Application** signing and **notarization**.

## Current machine status

This development Mac may only have an **Apple Development** identity. That cannot be notarized. Install a **Developer ID Application** certificate from a paid Apple Developer team before running the external distribution path.

Check:

```sh
security find-identity -v -p codesigning
```

You need a line like `Developer ID Application: Your Name (TEAMID)`.

## Scripts

| Script | Default | External |
| --- | --- | --- |
| `scripts/build-app.sh` | Ad-hoc | `SETCATCHER_DISTRIBUTION=developer-id` (or `SETCATCHER_SIGN_IDENTITY="Developer ID Application: …"`) |
| `scripts/notarize-app.sh` | Fails loudly without Developer ID + credentials | Submits with `notarytool`, staples ticket |
| `scripts/package-beta.sh` | Ad-hoc zip + honest manifest | `SETCATCHER_DISTRIBUTION=developer-id` builds, notarizes, zips |

Ad-hoc remains zero-config:

```sh
bash scripts/build-app.sh release
bash scripts/package-beta.sh
```

External:

```sh
export SETCATCHER_DISTRIBUTION=developer-id
# Preferred App Store Connect API key auth:
export APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_XXXX.p8
export APP_STORE_CONNECT_KEY_ID=XXXX
export APP_STORE_CONNECT_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# Or: APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID

bash scripts/package-beta.sh
```

Without a Developer ID identity, `build-app.sh` / `notarize-app.sh` exit with a clear error. Do not claim external-download readiness until a notarized zip verifies on a clean Mac.

## Create the certificate

1. Join or open an Apple Developer Program team.
2. In Certificates, Identifiers & Profiles, create **Developer ID Application**.
3. Install the certificate in Keychain Access on the build Mac.
4. Create an App Store Connect API key (Developer role) for `notarytool`, or an app-specific password for your Apple ID.

## Verify after notarization

```sh
codesign --verify --deep --strict .build/SetCatcher.app
spctl --assess --type execute -vv .build/SetCatcher.app
xcrun stapler validate .build/SetCatcher.app
```

Then copy the zip to a clean Mac (Downloads), open it, and confirm Gatekeeper allows launch without confusing “unidentified developer” blocks.

## Manifest honesty

`package-beta.sh` writes `signing` and `notarization` fields. Ad-hoc packages must say `not notarized`. Never mark a build notarized unless `stapler validate` succeeded.

## Sandbox

Keep `packaging/SetCatcher.entitlements` sandbox posture enabled for beta and App Store later. Hardened runtime is added only on the Developer ID path (`--options runtime --timestamp`).

### Process Audio Tap entitlement (resolved 2026-08-13)

`com.apple.security.system-audio-capture` is **not** a documented Apple entitlement — it does not exist in Apple's Entitlement Key Reference or the Core Audio Process Tap (`AudioHardwareCreateProcessTap`) documentation. Do not add it to the entitlements file; no signing change is required for Process Audio Tap before Developer ID distribution.

The real risk to watch during Developer ID + notarized testing is that Core Audio Process Taps are reported elsewhere as fragile under `com.apple.security.app-sandbox`. We keep the sandbox entitlement enabled (required for Mac App Store later), so if live verification on a Developer ID–signed build shows Process Audio Tap failing where the ad-hoc build succeeded, suspect the sandbox rather than a missing entitlement — the ScreenCaptureKit backend is the confirmed working fallback either way.
