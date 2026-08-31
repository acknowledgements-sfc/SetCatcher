# Research Notes

Last checked: August 30, 2026.

## Competitor: Serauto

Serauto appears to target the core Serato pain: DJs forget to save recordings or lose temporary recordings. The public site at `https://www.serauto.app/` currently presents itself as "Stereo Aura - DJ Platform"; search results and community mentions still associate Serauto with Serato auto-recording.

Working assumption: Serauto is a narrow Serato-focused utility, likely watching Serato recording/temp folders and helping preserve recent recordings. This needs hands-on verification by installing or inspecting the app if available.

## Adjacent Competitors

- Native recording in DJ apps: Serato, rekordbox, VirtualDJ, Traktor, and djay all have some recording workflow, but usually require manual start/save and do not create a cross-platform archive.
- DAWs/editors: Audacity, Ableton Live, Logic Pro, and GarageBand can record audio, but they do not know what DJ app/session produced the set.
- Playlist/history tools: DJCU, MIXO, Lexicon, rekordcloud, and similar tools handle library conversion/metadata, not automatic capture.
- Streaming/publishing workflows: Mixcloud, SoundCloud, Dropbox/Drive folders, and podcast tooling start after the recording exists.

## Official vs community / sandbox-safe vs research

DJMemory ships **App Store–sandbox-safe** paths only for Mac Capture/Protection:

| Path | Status |
| --- | --- |
| ScreenCaptureKit App audio Capture | Product (sandbox OK; Screen & System Audio Recording TCC) |
| Folder Protection (copy-only bookmarks) | Product |
| Input device Capture (Core Audio) | Product |
| Local history / XML / NML / CSV import + autopull | Product |
| Serato Twitch “Now Playing” / Live Playlists cloud | **Research only** — cloud + account; not a Capture dependency |
| SSL-API (Scratch Live binary reader) | **Research only** — not App Store–safe dependency |
| Traktor Kontrol D2 QML CSI replacement (ErikMinekus et al.) | **Research only** — patches Traktor.app; Pro-oriented; not sandbox-safe |
| PRO DJ LINK unofficial clients (`prolink-connect`, `alphatheta-connect`, beat-link) | **Research only** — reverse-engineered LAN join, pcap, NFS USB/SD; not sandbox-safe; AlphaTheta 8 Aug 2026 advisory is a hard stop on joining that network |
| VirtualDJ native plugin | **Research** (M14) — JSONL ingest (Artifact B) is in Core; the C++ `.bundle` (Artifact A) is not started. Network Control remains the Partial live-control path |
| Core Audio Process Tap | **Product** — preferred App audio Capture path; ScreenCaptureKit remains the verified fallback |
| BlackHole / Background Music / other HAL loopback drivers | **Out of scope** — routing ritual + (BlackHole) GPLv3; do not vendor or require. See `docs/research-awesome-macos-2026-08-30.md` and `docs/research-invisible-capture-2026-08-26.md` |

## Integration Depth By Platform

### Serato DJ Pro

Likely depth: medium for file-based recording recovery, low for official control.

Official / public surfaces:

- Default macOS recording path: `~/Music/_Serato_/Recording`.
- Serato history includes sessions, played tracks, export to txt/csv/m3u, and Serato Playlists.
- No public SDK for external deck control.
- Official “Now Playing” Twitch extension uses **Live Playlists + access token** (cloud), not a local API.

Community (research only):

- Local history-log parsers used by “What’s Now Playing”–style tools.
- [SSL-API](https://gitlab.com/eladmaz/SSL-API) — Scratch Live binary event feed.

MVP / product integration:

- Watch `~/Music/_Serato_/Recording`.
- Detect Serato running (`com.serato.seratodj`).
- Preserve new or changed recording files (copy-only).
- Read exported history files / autopull when available.
- **App audio Capture** — end-to-end verified (ScreenCaptureKit).
- Do **not** depend on Twitch / Live Playlist for archiving (local-first; audio/tracklists not uploaded by default).

### rekordbox

Likely depth: low to medium.

Official surfaces:

- [rekordbox for Developers](https://rekordbox.com/en/support/developer/) — **XML playlist Bridge** import under Preferences → Bridge → Imported Library (playlist/library oriented, not live deck events).
- Recording location is **user-configured**; manuals cover UI, not a live control API.

MVP / product integration:

- Watch user-selected recording folder.
- Read exported XML/history artifacts when available.
- Detect rekordbox running (`com.pioneerdj.rekordboxdj` / `com.pioneerdj.rekordbox`) and prompt for recording folder.
- App audio Capture: shareable + arm OK; raise to verified only after live meter + archive PASS.

### PRO DJ LINK (Pioneer/AlphaTheta hardware)

Research labeling only — not a capture or tracklist product path. The laptop + USB dual-route
(Folder Protection + Input Capture) already covers the XDJ-XZ bench.

Official surfaces:

- [AlphaTheta Certified](https://www.pioneerdj.com/en/landing/alphatheta-certified/) is HID
  (Serato/Traktor/djay controlling players), DVS, and licensed **PRO DJ LINK Bridge** for
  lighting/video. DJMemory is none of those. Honest line: we protect what reaches the Mac over USB
  and folders. Do not say “Pioneer certified” or “PRO DJ LINK compatible.”
- [AlphaTheta support](https://support.alphatheta.com/en-US) — XZ firmware, rekordbox 6/7, USB/HID,
  MASTER REC.

Community (research only):

- [prolink-connect](https://github.com/evanpurkhiser/prolink-connect) — virtual CDJ on the LAN;
  player status and metadata from rekordbox USB/SD. Fails if rekordbox is already running on the same
  Mac. Device IDs 1–6 steal a CDJ slot.
- [alphatheta-connect](https://github.com/chrisle/alphatheta-connect) — fork used by Now Playing.
  All-in-ones need **pcap passive mode** (no normal virtual CDJ). XZ USB1 maps as SD / USB2 as USB;
  no `mediaSlot` broadcasts; NFS fetch of `export.pdb`. Stagehand mode can remote-control decks. That
  is live-deck telemetry and control, not set protection.
- beat-link and similar virtual-CDJ / pcap stacks sit on the same reverse-engineered surface.

Hard stop: [8 Aug 2026 PRO DJ LINK advisory](https://alphatheta.com/en/information/important-notice-security-vulnerability-in-pro-dj-link/).
Unpatched, a third party on a PRO DJ LINK network may view data on the Mac **or** on USB/SD in a
CDJ/XDJ. Do not ship, prototype, or bench a PRO DJ LINK joiner until AlphaTheta’s fix is out and
reviewed.

Why this is not the USB dual-route: USB-B on the XZ is audio and HID to the computer; LINK Ethernet
is rekordbox library sharing, CDJs on channels 3/4, and lighting/video. Live now-playing from the
link would only help standalone USB-stick / CDJ booths where the Mac is out of the audio path
(already Manual Setup / Research). XZ all-in-one pcap/NFS quirks are why even a future official path
is not Route A/B. Tracklists stay on local history export + match; scraping USB/SD over the link is
the opposite of that default. `DJMemoryCore` stays platform-SDK-only (no Node/Java protocol stack).

### djay Pro

Likely depth: medium for recording files, low for live metadata (no public live-deck API).

Official surfaces:

- [djay Pro for Mac user manual](https://help.algoriddim.com/user-manual/djay-pro-mac) — product UI (library, hardware, recording).
- iOS/iPad manual informs companion limits (device-input Capture only; no Mac↔iPad Capture sync).

MVP / product integration:

- Detect djay Pro / djay Pro 2 (`com.algoriddim.direct.djay-pro-2-mac`, etc.).
- Watch documented current and legacy recording folders when present.
- Allow user-selected recording folder.
- App audio Capture against running shareable process; meter verify still required for status raise.

### VirtualDJ

Likely depth: high relative to the others for optional live control.

Official / community surfaces:

- [VDJPedia](https://virtualdj.com/wiki/) / [software manual](https://virtualdj.com/manuals/virtualdj.html).
- Developer SDK for skins, controllers, effects/plugins, database; Mac plugins are `.bundle`.
- Network Control — local HTTP-style control (Partial in product, M13).

MVP / product integration:

- File watch recording/history folders.
- Optional Network Control adapter when present.
- App audio Capture independent of Network Control.
- Later: native plugin for richer events (M14 Research) — do not block Capture verification on it.

### Traktor

Likely depth: medium for files/history, low for direct control in a sandboxed ship.

Official surfaces:

- Traktor root under `~/Documents/Native Instruments/Traktor <version>`.
- `History` playlists; recordings under `~/Music/Traktor/Recordings` (Pro-oriented paths).
- NI product manuals for Recordings / History / NML.

Community (research only while sandboxed):

- [ErikMinekus/traktor-api-client](https://github.com/ErikMinekus/traktor-api-client) — replace Kontrol **D2** QML CSI so deck events POST to `localhost` (`/deckLoaded`, `/updateDeck`, …). Requires modifying Traktor.app package contents and adding a fake D2 device.
- Related: [traktor-kontrol-screens](https://github.com/ErikMinekus/traktor-kontrol-screens), [traktor-kontrol-qml](https://github.com/lsmith77/traktor-kontrol-qml), [AwesomeTraktor](https://github.com/mktg/AwesomeTraktor).

Product notes:

- This Mac may run **Traktor DJ 2** (`com.native-instruments.tmnt`) rather than Traktor Pro 3 — QML CSI paths and recording layouts may differ; treat Pro QML hacks as **Pro-only research**.
- Ship Capture + folder/NML Protection; do not ship QML injection in the App Store build.

MVP / product integration:

- Discover newest Traktor root folder.
- Watch `History` and `~/Music/Traktor/Recordings` when present.
- Parse NML/XML for session metadata.
- App audio Capture against shareable process when running.

## Product Opportunity

The wedge is not "another recorder." It is "never lose a set again":

- automatic recovery and archiving (folder Protection + App audio Capture when Record/Save is off)
- session naming based on date, venue, DJ software, and setlist
- waveform/level sanity checks
- one place to find recordings and tracklists across DJ platforms
- post-set actions: normalize, trim silence, export tracklist, upload/share (opt-in only)

## Technical Risks

- Sandboxed macOS apps need explicit folder access (security-scoped bookmarks) for Music/Documents folders.
- App audio Capture uses **ScreenCaptureKit** (not a virtual cable). Exclusive hardware routing that never hits Mac system audio yields silence — fall back to Input device Capture or folder Protection.
- App Store review: stay off private APIs, UI automation of other apps, and patched DJ-app bundles.
- Streaming-service recording restrictions may create policy/legal constraints. Preserve user recordings but avoid bypassing DRM or app limitations.
- Live-metadata community hacks (Traktor QML, SSL binary, Twitch Live Playlist, PRO DJ LINK unofficial clients) conflict with sandbox / local-first defaults — keep as research until product explicitly drops sandbox or opts into cloud. Do not join a PRO DJ LINK network until AlphaTheta’s 8 Aug 2026 advisory is closed.
