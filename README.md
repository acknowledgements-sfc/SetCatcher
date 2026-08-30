# SetCatcher

SetCatcher is a planned macOS app for DJs that automatically captures set recordings and attaches usable session metadata from Serato DJ Pro, rekordbox, djay Pro, VirtualDJ, and Traktor.

The first scaffold is intentionally small:

- a Swift core package for software detection and adapter modeling
- a CLI probe for local discovery
- current product strategy and beta PRD in `docs/product/`, with research and historical milestone documentation in `docs/`

## Run  

```bash
swift run setcatcher probe
swift run setcatcher archive /path/to/set.wav serato
swift run setcatcher scan ~/Music/_Serato_/Recording serato
swift run setcatcher watch ~/Music/_Serato_/Recording serato
swift run setcatcher diagnostics ./SetCatcher-Diagnostics.json
swift run setcatcher virtualdj-network
swift run SetCatcherApp
swift test
bash scripts/smoke-cli.sh
bash scripts/smoke-app.sh
```

Set `SETCATCHER_ARCHIVE_ROOT=/path/to/archive` when testing CLI archive, scan, or watch commands against a temporary archive folder.
Use `swift run setcatcher diagnostics [output.json|-]` to write a privacy-redacted support report from local SetCatcher state.

Archived recordings are copied to `~/Music/SetCatcher` by default with a JSON metadata sidecar. The default archive folder is created on launch. A custom archive folder can be set in Settings. Source files are never moved, renamed, or deleted.

`SetCatcherApp` launches the first SwiftUI app shell with setup status, menu-bar status, and an archived-session library view.
First launch shows a setup sheet that summarizes detected DJ apps, the archive location, and the next setup action.

For a clickable local macOS app bundle:

```bash
bash scripts/build-app.sh
open .build/SetCatcher.app
```

For a zipped local beta handoff with a checksum manifest:

```bash
bash scripts/package-beta.sh
```

The local bundle is signed ad hoc with sandbox-oriented entitlements in `packaging/SetCatcher.entitlements`. Xcode is still needed later for Developer ID/App Store signing, icons, notarization, and archived release export.

Beta handoff checks live in `docs/beta-release-checklist.md`.
MVP acceptance evidence lives in `docs/mvp-readiness-audit.md`.
Current DJ app support levels live in `docs/integration-status.md`.
Local smoke-test coverage lives in `scripts/smoke-app.sh`.

The app can save recording/history folder selections using macOS security-scoped bookmarks, which keeps the setup path compatible with sandboxed distribution. Custom archive folders use the same bookmark approach.

Configured recording folders can be scanned from the app with **Rescan Last 24 Hours**. While the app is open, reachable recording folders also trigger a short debounced scan when macOS reports folder activity, with a one-minute scheduled scan as a backup.

To open the package in Xcode:

```bash
bash scripts/open-xcode.sh
```

Xcode is not required for day-to-day preview, but it will be needed for production signing, sandbox entitlement inspection, icons, notarization, and packaged app export.

### Cursor / SweetPad (iPad scheme)

This repo recommends the SweetPad, Swift, and CodeLLDB extensions (see `.vscode/extensions.json`). Use the SweetPad sidebar to build and run the **SetCatcheriPad** scheme on an iPad simulator or device; regenerate the Xcode project with SweetPad’s XcodeGen command or `xcodegen generate --spec project.yml`. Press **F5** to build, launch, and attach via `.vscode/launch.json`.

Mac day-to-day work stays on SPM (`swift run SetCatcherApp`). Do not commit `buildServer.json` — a root build-server config overrides SourceKit-LSP’s native `Package.swift` support.

## Product Direction

The practical integration strategy is file-first:

1. Watch each DJ app's recording and history locations.
2. Detect active sessions by app process plus audio/file activity.
3. Save/rename/archive the recording automatically when possible.
4. Attach setlists from history exports or app-local history files.
5. Add deeper integrations only where supported, especially VirtualDJ.
