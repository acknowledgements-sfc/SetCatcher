# SetCatcher Beta Release Checklist

Last updated: August 29, 2026.

## Current Candidate Gate

The current verification candidate is `codex/setcatcher-rename` at `b6a1a5e`, descended from the Phase 1 checkpoint `f7e9bb9`. The artifact manifest is the authority for the exact packaged commit. Regenerate the package after every candidate commit; earlier packages are verification artifacts only and must not be distributed.

**Update (2026-09-02):** `main` = `origin/main` = `7b3b698` now already carries the rename plus later dual-lane-archive / companion / catalog-sync work. Re-baseline any distribution candidate from `7b3b698` rather than the `b6a1a5e` rename branch; the frozen-review automated baseline is **411 tests executed, 4 skipped, 0 failures, 0 build warnings** (see `docs/mvp-readiness-audit.md`).

| Gate | Current status |
| --- | --- |
| Automated tests, CLI smoke, app build/smoke | Frozen-review baseline (2026-09-02, `main`@`7b3b698`): 411 tests executed, 4 skipped, 0 failures. Historical renamed-branch run: 325 tests, 4 skipped, 0 failures; CLI and app smoke passed |
| Release build warnings | Passed: release rebuild completed with zero warnings after the `livePeak` fix |
| Ad-hoc package and checksum | Verification package passed with matching SHA-256; regenerate from the final clean candidate so the manifest identifies the exact commit |
| Current-user extracted-zip launch | Passed after scoped fixes; not clean-install proof |
| Manual accessibility | Partial agent evidence; full VoiceOver rotor and disabled-state phrasing need a human |
| Live Capture | Current evidence verifies XDJ, Serato, rekordbox, VirtualDJ, and ScreenCaptureKit routes; Traktor remains skipped and djay’s XDJ hardware path remains unclaimed. Operator listening and route-specific human checks remain required |
| External signing and notarization | Blocked: no Developer ID Application identity or stapled ticket |
| Clean external Mac | Blocked until a notarized candidate is installed and exercised on a clean supported Mac |

Do not push or distribute from this checklist. Those actions require separate explicit approval.

For the no-paid-account private beta workflow, use [`docs/external-beta-ad-hoc-guide.md`](external-beta-ad-hoc-guide.md). It covers checksum verification, Gatekeeper approval, permissions, migration, rollback, and known limitations.

## Build

- Run `swift test`.
- Run `bash scripts/smoke-cli.sh`.
- Run `swift build --product SetCatcherApp`.
- Run `bash scripts/build-app.sh release`.
- Run `bash scripts/package-beta.sh`.
- Confirm `.build/SetCatcher.app` exists.
- Confirm `codesign --verify --deep --strict .build/SetCatcher.app` passes.
- Confirm `.build/distribution/` contains a zip and JSON manifest with a SHA-256 checksum.
- Review `docs/mvp-readiness-audit.md` for automated evidence and remaining manual checks.

## Signing and Distribution

- Debug/local beta builds may use ad hoc signing (default `scripts/build-app.sh` / `scripts/package-beta.sh`).
- External beta builds: set `SETCATCHER_DISTRIBUTION=developer-id` (see [`docs/signing-and-notarization.md`](signing-and-notarization.md)).
- `scripts/notarize-app.sh` submits with `notarytool` and staples; fails loudly without Developer ID + credentials.
- Developer ID signing + notarization are required before broad direct-download distribution.
- App Store distribution remains later, but sandbox posture should stay enabled.

## Manual Smoke Test

- Launch the packaged `.app`.
- Confirm the app opens to Home.
- Confirm the menu-bar item appears.
- Set a recording folder for at least one DJ app.
- Quit and relaunch.
- Confirm the folder still appears.
- Run Scan Now against a folder with no new files.
- Confirm the Protection dashboard and menu-bar status show last-scan and next-scan timing.
- Add or update an audio file in a watched folder and confirm SetCatcher schedules a scan soon.
- Arm App audio Capture with Serato on macOS 15+ and confirm Process Audio Tap records meter + WAV + archive. Probe command: `swift run setcatcher app-audio-probe 8 serato`.
- Arm App audio Capture with rekordbox on macOS 15+ and confirm Process Audio Tap records meter + WAV + archive. Probe command: `swift run setcatcher app-audio-probe 8 rekordbox`.
- Run fallback verification with `SETCATCHER_FORCE_SCK_APP_AUDIO=1` and confirm ScreenCaptureKit still records meter + WAV + archive. Probe command: `SETCATCHER_FORCE_SCK_APP_AUDIO=1 swift run setcatcher app-audio-probe 8 serato`.
- Or run `bash scripts/live-app-audio-check.sh` with Serato and rekordbox open and playing through Mac system output; it fails unless Serato Process Audio Tap, rekordbox Process Audio Tap, and forced Serato ScreenCaptureKit each report `PASS meter+archive`.
- Confirm the capture-start notification says `Recording started - HH:MM`.
- Import one supported tracklist file.
- Search archived sets by filename, app, venue, or matched track text.
- Export diagnostics and confirm the report avoids track titles by default.
- Run `swift run setcatcher diagnostics ./SetCatcher-Diagnostics.json` and confirm it writes a redacted support report.

## Permission Recovery

- Move or revoke access to a saved folder.
- Confirm the folder row shows an attention state.
- Confirm the protected-source count does not include the inaccessible folder.
- Choose the folder again.
- Confirm the warning clears and scanning can run.

## Privacy Review

- Confirm no audio files are uploaded.
- Confirm no tracklists are uploaded by default.
- Confirm diagnostics are saved only when the user chooses Export Diagnostics.
- Confirm diagnostics include counts and redacted paths, not full track contents.

## Known Issues Template

Before each beta build, document:

- supported DJ apps
- partial DJ apps
- unsupported formats
- known parser limitations
- signing/notarization status
- minimum macOS version
- recovery steps for folder permission issues
