# SetCatcher Integration Status

Last updated: September 2, 2026.

## Status Labels
- Supported / Partial / Manual Setup / Research — honest labels; never round Partial up to Supported.
- **Single source of truth:** each app's user-visible support label is defined in code at `Sources/SetCatcherCore/DJSoftware.swift` (`IntegrationSupportStatus`). This table must mirror that source and the current release gate in `docs/beta-release-checklist.md`. Never present `partial`, `manualSetup`, or `research` as `supported` here or on any launch/support surface.

## Current App Matrix

| App | Status | Current Support |
| --- | --- | --- |
| Serato DJ Pro | Supported | Recording-folder watch + history import (verified). App audio Capture passed prior live probes on both backends (Process Audio Tap + ScreenCaptureKit, 2026-08-14); operator listening acceptance still required per `beta-release-checklist.md` |
| rekordbox | Supported | Manual recording-folder + XML Bridge / history import (verified). App audio Capture passed prior live probes on rekordbox 6/7 via Process Audio Tap and ScreenCaptureKit (2026-08-14); operator listening acceptance still required |
| Traktor | Supported | Recordings + NML history import. **App audio Capture is not yet verified — Traktor is skipped in the current release gate.** Pro QML CSI live API = Research only |
| VirtualDJ | Partial | File watch + Network Control (M13, Partial). App audio Capture route passed a prior probe; native plugin (M14) = Research |
| djay Pro | Manual Setup | Documented recording folders; history/session metadata still needs verification. App audio Capture via ScreenCaptureKit only; XDJ hardware path unclaimed in the current gate |
| SetCatcher Capture | Implemented | Backend selector prefers Process Audio Tap, falls back to ScreenCaptureKit. ScreenCaptureKit verified end-to-end on Serato, rekordbox, and VirtualDJ; Traktor and djay routes not verified. Process Audio Tap live meter + archive remains an operator acceptance gate. Input device (Core Audio) + silence session split implemented |
| Pioneer Hardware | Manual Setup | USB PIONEERREC / RECxxx.WAV watch. Laptop + XDJ-XZ USB Input Capture: **dev-bench 15 Aug 2026** saw Core Audio `name` `XDJ-XZ` (manufacturer `AlphaTheta Corporation`, UID `USBAudioDevice:AlphaTheta Corporation:XDJ-XZ (2):1110000`), archived a 24-bit/48 kHz stereo WAV via `ingestCapture`, and grouped overlapping Serato + Capture as one Library session. Later the same day HAL bind (`setDeviceID`) is in the rebuilt app; operator also archived Serato and rekordbox via App audio Capture (Process Audio Tap) while playing through the XZ. That is the already-Supported app path, not USB Input Capture. **dev operator; Supported not flipped.** Meter-with-master, unplug, and mic-denied still need an operator, then a non-dev pass. See `docs/pioneer-hardware-setup.md`. |
| Analog Mixer | Manual Setup | Vinyl / analog mixer: pin rec-out once, then unattended Input Capture on that UID only; or grant a dump folder. No invented tracklists. Unknown USB stays manual-only (webcam rule). See `docs/analog-mixer-setup.md`. **Supported not claimed.** |
| Denon Engine DJ | Manual Setup | Desktop app detection + pref/default path discovery (fixture-tested; no bench hardware yet). See `docs/dj-app-path-discovery.md`. |
| Denon Hardware | Manual Setup | Engine OS `Sessions` stick/SD folder watch (PIONEERREC analogue). USB Input Capture only after measured Core Audio identity. No Engine LAN. See `docs/denon-rane-hardware-setup.md`. |
| Rane Hardware | Manual Setup | Serato remains primary for Seventy-class + DVS. USB program pair and Session Out (Analog pin) are extras. Channel map nil until live bench. See `docs/denon-rane-hardware-setup.md`. |

## Source map (official vs community / sandbox-safe vs research)

Locked Mac product paths stay **sandbox-safe**. Community live-deck hacks stay **research** until sandbox policy changes.

| Source | Kind | Use in SetCatcher |
| --- | --- | --- |
| Process Audio Tap | Platform SDK | Preferred App audio Capture backend; live-verified end-to-end (Serato, rekordbox 6, rekordbox 7) |
| ScreenCaptureKit App audio | Platform SDK | Product Capture |
| Invisible DJ app capture research | Product research | Current design target: after initial onboarding, no supported DJ app may require routine manual output/input changes. Research must verify the exact macOS API/driver/helper path, permissions, entitlements, process targeting, minimum OS, real-audio bench, and automatic restore behavior before implementation. See `docs/handoff-cursor-fable-invisible-capture-research-2026-08-26.md`. |
| Folder Protection + bookmarks | Product | Copy-only archive |
| Local history CSV / XML / NML | Official exports + documented folders | Import + autopull |
| Input device Capture | Core Audio | Product fallback |
| rekordbox XML Bridge | Official developer | Library/playlist import — not live deck audio |
| VirtualDJ Network Control | Community / product Partial | Optional control (M13); Capture independent |
| Serato Twitch Now Playing / Live Playlists | Official cloud | **Do not** use as Capture or default tracklist path |
| SSL-API (Scratch Live binary) | Community | Research only |
| Traktor Kontrol D2 QML CSI replacement | Community (patches Traktor.app) | Research only; Pro-oriented; not App Store–safe |
| VirtualDJ native plugin | SDK | Research (M14) — ingest implemented; `.bundle` scaffold compiles against public SDK, but did not load in VirtualDJ 2026 under tester's current license tier (2026-08-13 live probe) — Pro-tier license retest needed |
| PRO DJ LINK unofficial clients (`prolink-connect` / `alphatheta-connect` / beat-link) | Community reverse-engineering | **Research only.** Official Certified Bridge = lighting/video, not applicable. 8 Aug 2026 advisory: do not join that network until AlphaTheta’s fix is reviewed |

See `docs/research.md` for per-app depth and links.

## App Audio Capture (Mac)

Direction update (2026-08-26): invisible capture is now the product bar for all supported DJ apps,
not only Serato. After onboarding, SetCatcher must not require manual output/input changes inside
Serato, rekordbox, Traktor, VirtualDJ, or djay Pro/2. Driver/helper research is tracked in
`docs/handoff-cursor-fable-invisible-capture-research-2026-08-26.md`; the research must prove
automatic activation, deactivation, restore-to-previous/default audio device behavior, and
real-audio capture before any final driver claim.

Primary Mac feature: when a shareable DJ app is found, **auto-arm** Capture (unless the user Disarmed)
→ Process Audio Tap captures the running DJ app → ScreenCaptureKit is the fallback
backend → silence policy starts/stops/archives takes → stays watching. Writes **24-bit / 48 kHz**
stereo WAV. Requires `NSAudioCaptureUsageDescription`; ScreenCaptureKit fallback also requires Screen
& System Audio Recording. Does **not** work when the mix never hits Mac system audio (exclusive
interface) — use Input device Capture (also 24-bit / 48 kHz; auto-selects Pioneer/DJM while armed) or
folder Protection.

After each archive (Capture or folder scan), SetCatcher **autopulls** a nearby local history export from
known history folders when available, stamps track dates from the set, and matches. Because many DJ
apps only flush their history export when the set ends — often *after* the recording archives — SetCatcher
also runs a **continuous history watcher** (M12): FSEvents on the granted history folders, a backstop
poll on the scan interval, and a launch catch-up sweep. Any late-written or mid-set-appended export
within the match window of a recent archive is auto-ingested (idempotently) and attached by the live
matcher; a closer export upgrades an earlier auto-match, while a user's manual pin is never overridden.
Soft-fail leaves manual Import as the recovery path.

Local verify (2026-08-10):

- **Serato DJ Pro** — App audio Capture verified end-to-end (Arm → level meter → Stop & Save / archive) with Screen & System Audio Recording granted.

Local verify (2026-08-12) — write-path bug found and fixed:

- The `AppAudioCaptureService` / `CaptureService` write path converted buffers to a standalone 24-bit `CaptureAudioFormat.writeFormat()` before calling `AVAudioFile.write(from:)`, but `AVAudioFile(forWriting:settings:)` always expects Float32 deinterleaved buffers matching its own `processingFormat` (it packs to the on-disk bit depth internally). Mismatch threw `com.apple.coreaudio.avfaudio error -50` on every write, deterministically, regardless of source app. Fixed in `AppAudioCaptureService.swift` / `CaptureService.swift` by converting to the file's actual `processingFormat` instead of a separately-computed 24-bit target.
- **Serato DJ Pro / rekordbox / djay Pro 2 / VirtualDJ / Traktor DJ 2 (`com.native-instruments.tmnt`)** — re-probed with decks playing live audio to Mac system output after the fix: all five now report `PASS meter+write <id>` (peaks 0.26–0.42, staged WAVs written and verified). Probe: `.build/SetCatcher.app/Contents/MacOS/SetCatcher --app-audio-probe <seconds> <softwareID>`.

Implementation update (2026-08-13):

- `AppAudioCaptureService` now selects a backend: Process Audio Tap first unless `SETCATCHER_FORCE_SCK_APP_AUDIO=1`, then ScreenCaptureKit fallback. The Process Audio Tap service creates a private Core Audio tap with `CATapDescription`, attaches it to a private aggregate device, meters/writes PCM through the shared 24-bit / 48 kHz WAV path, and destroys the tap/device on stop or failed arm.
- Packaging check: `scripts/build-app.sh` already writes `NSAudioCaptureUsageDescription`. **Resolved (2026-08-13):** `com.apple.security.system-audio-capture` is not a real/documented Apple entitlement — it does not appear in Apple's Entitlement Key Reference, the CoreAudio/`AudioHardwareCreateProcessTap` docs, or App Sandbox docs, and no header/SDK search or public developer report confirms it exists. Do not add it to `packaging/SetCatcher.entitlements`. The actual known risk for Process Audio Tap under Developer ID/App Store is different: independent reports (e.g. community writeups building CATap-based capture tools in 2026) describe CATap behavior as **fragile under App Sandbox** and disable `com.apple.security.app-sandbox` entirely for their sandboxed-unsafe builds, relying instead on `NSAudioCaptureUsageDescription` + a properly signed (not ad-hoc) binary to trigger the TCC prompt. Our entitlements file currently keeps `com.apple.security.app-sandbox = true` (required for Mac App Store distribution later) — this is the item to watch: if Process Audio Tap misbehaves under Developer ID + sandbox in live testing or on a clean Mac, the fallback is confirmed working (ScreenCaptureKit backend), not a missing entitlement. No entitlement change is needed before Developer ID signing.
- Local probe: VirtualDJ was the only running target. Default backend reported `backend: Process Audio Tap` and forced fallback reported `backend: ScreenCaptureKit`; both armed and cleaned up. Meter was silent, so live meter + archive verification remains pending.
- Probe update (2026-08-13): `swift run setcatcher app-audio-probe <seconds> <softwareID>` and `.build/SetCatcher.app/Contents/MacOS/SetCatcher --app-audio-probe <seconds> <softwareID>` now archive successful metered captures through `ArchiveService.ingestCapture`, print archive + metadata paths, and confirm the new session appears in `SessionLibrary`.
- `scripts/live-app-audio-check.sh` runs the required Serato Process Audio Tap, rekordbox Process Audio Tap, and forced Serato ScreenCaptureKit probes; it exits nonzero unless each reports `PASS meter+archive`.
- Local attempt (2026-08-13 08:24): Serato and rekordbox probe attempts reported Screen & System Audio Recording preflight `true`, then `targets: (none)` because no shareable DJ app target was running. Forced `SETCATCHER_FORCE_SCK_APP_AUDIO=1` produced the same target-discovery result.
- Live verification still required: open Serato and rekordbox, play real audio through Mac system output, then run `.build/SetCatcher.app/Contents/MacOS/SetCatcher --app-audio-probe <seconds> serato` and `rekordbox` without `SETCATCHER_FORCE_SCK_APP_AUDIO=1`; confirm backend `Process Audio Tap`, meter, staging WAV, archive write, and Library visibility. Repeat one forced `SETCATCHER_FORCE_SCK_APP_AUDIO=1` fallback check and confirm backend `ScreenCaptureKit`.
- **Live verification complete (2026-08-14):** ran `swift run setcatcher app-audio-probe 8 <id>` with real playback in each app.
  - Serato DJ Pro — Process Audio Tap: `PASS meter+archive serato`, peak 1.0, archive + Library entry confirmed.
  - rekordbox 6 — Process Audio Tap: `PASS meter+archive rekordbox`, peak 0.096, archive + Library entry confirmed. (rekordbox 6 and 7 share bundle ID `com.pioneerdj.rekordboxdj`, so only one instance was run at a time.)
  - rekordbox 7 — Process Audio Tap: `PASS meter+archive rekordbox`, peak 0.076, archive + Library entry confirmed, with rekordbox 6 fully quit beforehand.
  - Serato DJ Pro — forced `SETCATCHER_FORCE_SCK_APP_AUDIO=1` ScreenCaptureKit fallback: `PASS meter+archive serato`, backend confirmed `ScreenCaptureKit`, peak 1.0, archive + Library entry confirmed.
  - M17 Process Audio Tap live verification is now done; no further live-audio verification blocking beta.

Do **not** start Traktor QML injection, SSL-API, or Twitch Live Playlist integration in the sandboxed Mac app.

iPad is a **separate** app: no Mac connection; accounts only are shared. On iPad, Capture is device-input only (iPadOS cannot tap another app’s audio).

| Milestone | Scope | Status |
| --- | --- | --- |
| M11 | Capture + Pioneer hybrid | Implemented (Manual Setup until device-verified) |
| M11b | App audio Capture + silence sessions | Implemented (Serato, rekordbox, djay Pro 2, VirtualDJ, Traktor DJ 2 all verified end-to-end; meter + archive write confirmed for all five 2026-08-12) |
| M12 | Deeper history + capture match window | Implemented (post-archive autopull + configurable 6h match window + continuous history watcher: FSEvents on history folders, backstop poll, and launch catch-up sweep; late/appended exports auto-ingest and match. Hardware Capture/Pioneer sets match the nearest matchable export from any DJ app within the window; auto-matches upgrade to a closer export while user pins stay sacred) |
| M13 | VDJ Network Control commands | Partial |
| M14 | VDJ native plugin | Research (Artifact B JSONL ingest implemented and unit-tested; Artifact A C++ `.bundle` scaffold exists in `docs/virtualdj-plugin-scaffold/` and compiles against the public VDJ8 SDK — no download/registration blocker. Live probe 2026-08-13: plugin did not load under tester's current VirtualDJ license tier; VirtualDJ's own guidance suggests Pro licensing may be required. Next step: retest plugin load with a Pro-tier license, then live-verify getter strings and on-air signal) |
| M15 | Opt-in cloud sync settings | Settings flags; off by default |
| M16 | User-initiated publish pack | Local export only |
| M17 | Process Audio Tap Capture | Implemented and live-verified (Serato, rekordbox 6, rekordbox 7, plus ScreenCaptureKit fallback) |
