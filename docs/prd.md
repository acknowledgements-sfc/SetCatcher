# PRD: DJMemory macOS App

> **Historical master PRD and milestone record.** For the current product strategy, private-beta requirements, feature inventory, and release boundaries, start with [`docs/product/README.md`](product/README.md). This file is preserved for implementation history and earlier decisions.

Last updated: August 9, 2026.

## One-Line Pitch

DJMemory is a macOS safety net for DJs: it automatically preserves set recordings, remembers where they came from, and attaches track-history metadata when the DJ software makes that available.

## Product Thesis

DJMemory’s primary Mac safety net is **App audio Capture**: when armed, it records a running DJ app via Process Audio Tap with ScreenCaptureKit fallback, even if that app is **not** in Record/Save. After configurable idle silence, it saves the take and waits for the next set.

Folder Protection remains the co-equal safety net for recordings the DJ app *does* write: DJMemory watches the right places, detects when a file has finished, copies it into a durable library, and never mutates or deletes the DJ software’s original files.

Input device Capture (DJM USB / mixer) covers cases where the mix never reaches Mac system audio (exclusive hardware routing).

DJMemory wins by being quiet, reliable, and honest about limits:

- App audio Capture when Record/Save was forgotten
- folder Protection when the DJ app did record
- readable names and metadata sidecars
- never mutates or deletes the DJ software's original files
- never uploads audio by default

## Target Users

### Primary User

Working or semi-working DJs who play live sets and want a dependable archive for review, posting, client delivery, or radio/podcast prep.

Typical context:

- uses a Mac laptop at gigs or home sessions
- records sets inside DJ software when possible
- may use different DJ software depending on venue, controller, or format
- does not want another technical setup ritual before playing

### Secondary Users

- DJ teachers and students who review practice sessions
- radio DJs and livestreamers who need tracklists after recording
- event/mobile DJs who need client-deliverable set archives
- content-focused DJs who post mixes regularly

## Problem

DJ software makes recording possible, but the workflow is fragile during a real set:

- the DJ must remember to start recording
- the DJ must remember to stop and save
- recordings may live in different folders per app
- temporary or unnamed recordings can be overwritten
- the audio file and played-track history are separate
- naming conventions are inconsistent
- post-set organization happens when the DJ is tired or packing up

The emotional pain is simple: "I played a great set and now I cannot find, save, name, or reconstruct it."

## Product Goals

- Protect recordings from being lost after a set.
- Give the DJ one reliable library across supported DJ apps.
- Preserve context: app, date, time, original path, archive path, and track history when available.
- Make setup understandable in under five minutes.
- Avoid brittle/private integration paths in the MVP.
- Keep the architecture App Store-safe from day one, even if v0.1 is distributed outside the Mac App Store.

## Product Decisions

- Distribution posture: App Store-safe architecture and permissions from day one; initial distribution does not need to be through the Mac App Store.
- UI shape: full macOS app window for setup/library, plus menu-bar status for passive protection state.
- Default archive location: `~/Music/DJMemory`.
- First compatibility targets: Serato DJ Pro and rekordbox.
- First metadata parser target: Serato history export, followed by rekordbox XML/history exports once local formats are verified.

## Non-Goals

- Do not bypass DRM or streaming-service recording restrictions.
- Do not use private APIs or patch DJ software internals.
- Do not automate UI clicking inside DJ apps in v0.1.
- Do not claim a Mac↔iPad connection for Capture, archives, or folder Protection. Mac and iPad share **accounts only**; each device listens only to DJ apps / audio on that device.
- Do not upload or publish recordings automatically in v0.1.
- Do not delete, move, rename, or mutate original source recordings.

## Competitive Positioning

### Main Competitor: Serauto

Serauto appears focused on Serato auto-recording/recovery. DJMemory should treat Serauto as validation of the most painful wedge: DJs forget to preserve Serato recordings.

Differentiation:

- multi-app, not Serato-only
- library and metadata layer, not just recovery
- track-history attachment where available
- future deeper VirtualDJ/Traktor integration
- post-set workflow foundation

### Adjacent Alternatives

- Native DJ app recording: works, but is app-specific and manual.
- Audacity/Logic/Ableton: can record audio, but lacks DJ-app context and set history.
- MIXO/Lexicon/DJCU-style library tools: strong for playlists/libraries, not automatic set recording preservation.
- Cloud folders: useful after the file exists, not helpful for detection, naming, or track history.

## Integration Strategy

Use three integration levels. This keeps the roadmap honest and prevents overpromising.

### Level 1: File Watcher

DJMemory watches recording/history folders and archives completed files.

Used for:

- all MVP platforms
- least brittle path
- safest App Store posture

### Level 2: Export/History Parser

DJMemory imports session metadata from known export/history formats.

Used for:

- Serato history exports
- Traktor NML history files
- rekordbox XML/history exports if user-provided
- VirtualDJ history/database files if verified

### Level 3: Local Control or Plugin

DJMemory communicates with DJ software through supported local interfaces.

Used later for:

- VirtualDJ Network Control
- VirtualDJ native plugin
- any official API that becomes available

## Platform Plan

### Serato DJ Pro

MVP confidence: high.

Why first:

- clear default recording folder: `~/Music/_Serato_/Recording`
- clear history/export concepts
- competitor validation around recording loss

v0.1:

- detect Serato installation and running state
- request access to `~/Music/_Serato_`
- watch `Recording`
- archive completed recordings
- optionally ingest files from `History Export`

Later:

- investigate `.session` files for live history, but treat as unstable
- add "recover unsaved recent Serato recording" flow if temp file behavior is verified

### rekordbox

MVP confidence: medium without local verification.

Why first:

- major market platform
- XML bridge/export story exists
- Serato plus rekordbox covers a large share of working DJ workflows

v0.1:

- detect rekordbox installation
- require user-selected recording folder
- preserve recordings from that folder
- support manual import of rekordbox XML/history exports when available

v0.2:

- deepen rekordbox metadata support after verifying local history/export formats

### Traktor

MVP confidence: high for folders/history.

Why later:

- recordings default to `~/Music/Traktor/Recordings`
- history playlists live under `~/Documents/Native Instruments/Traktor <version>/History`
- NML/XML-style parsing is a tractable technical path

v0.2:

- discover newest Traktor root directory
- request access to Documents and Music folders as needed
- watch recordings and history
- archive completed recordings

Later:

- parse Traktor history playlist files into tracklists

### VirtualDJ

MVP confidence: medium for files, high for future deep integration.

Why important:

- strongest public customization/plugin story
- likely best path to richer event data without brittle hacks

v0.2:

- detect VirtualDJ installation
- watch likely VirtualDJ user folder
- allow manual folder selection if defaults are wrong
- probe Network Control if installed/enabled
- document supported local commands

Later:

- native VirtualDJ plugin for set start/end and track events

### djay Pro

MVP confidence: medium for recording preservation, low for history metadata.

Why included:

- popular Mac DJ app
- important for consumer/prosumer DJs

v0.1:

- detect app installation/running state
- watch documented current and legacy recording folders when present
- allow user-selected recording folder when defaults are missing or customized
- preserve recordings from watched folders

Later:

- research AppleScript, Shortcuts, or supported automation surfaces

## MVP Scope: v0.1

### Must Have

- Native macOS app shell with a full app window and menu-bar presence.
- First-run setup that scans for supported DJ apps.
- Supported-app scanning includes installed apps, likely folders, and running app processes when macOS exposes the bundle identifier.
- Per-app setup state:
  - App Found
  - App Not Found
  - Needs Folder Access
  - Watching
  - Recording Detected
  - Archived
  - Error
- Folder permission flow for Music/Documents/custom folders.
- Recording watcher that detects new audio files.
- File stability detection before archive copy.
- Archive copy into DJMemory library.
- Metadata JSON sidecar next to archived recording.
- Manual "Rescan Last 24 Hours" action.
- Basic library screen showing archived sessions.
- Never modify source files.

Implementation note: scans now report active recordings separately from archived recordings so the app can show "Recording Detected" while DJMemory waits for a file to finish.

Implementation note: the Protection dashboard and menu-bar status now show last-scan and next-scan timing so automatic protection is visible while the app is open.

Implementation note: while automatic scanning is enabled, reachable recording folders are monitored for macOS file-system activity and schedule a short debounced scan; the periodic scan remains a backup.

### Should Have

- Serato default folder detection.
- rekordbox installed-app detection.
- Default archive folder creation at `~/Music/DJMemory`.
- User-editable archive naming template.
- Failure state with plain-language next step.
- Basic diagnostics export for support/debugging.

Implementation note: scan failures now map missing, moved, file-backed, and unreadable recording folders into recovery-oriented messages instead of raw system errors.

Implementation note: software probing now marks an adapter as `running` when a supported app process is active, and diagnostics include that boolean state.

### Could Have

- Tracklist import for Serato CSV/TXT.
- rekordbox XML/history import after format verification.
- Traktor root/history discovery.
- VirtualDJ installed-app detection.
- Traktor NML parser.
- Waveform thumbnail or duration check.
- Silence/low-level warning.
- Auto-copy to a user-selected cloud folder.

## User Experience

### Main Product Question

The app should answer one question first:

"Am I protected right now?"

### Primary States

- Protected: at least one app/folder is being watched.
- Needs Setup: no recording folders are accessible.
- Recording: a growing recording file is detected.
- Saving: recording stopped changing and is being archived.
- Saved: archived copy and metadata were created.
- Attention Needed: folder permission, disk space, or copy error.

### First-Run Flow

1. Welcome: "DJMemory keeps a backup of your recorded sets."
2. Scan: detect installed DJ apps and likely folders.
3. Permissions: ask for folder access only where needed.
4. Library: confirm default archive location at `~/Music/DJMemory` or choose a different folder in Settings.
5. Ready screen: show protected apps, watched folders, and next scan time.

Implementation note: the current app shows a first-run setup sheet with detected apps, archive location, protected-source count, and actions to start folder setup or review archive settings. The flow can be reopened from Settings.

Implementation note: protected-source counts only include reachable recording folders. Saved folders that moved or became inaccessible show an attention state until the user chooses the folder again.

### Post-Set Flow

1. DJ stops or saves recording in DJ software.
2. DJMemory detects file stability.
3. DJMemory copies file to archive.
4. DJMemory creates metadata sidecar.
5. DJMemory shows a quiet notification: "Set saved."
6. User can rename with event/venue notes later.

## Data Model

### DJAppAdapter

- `id`
- `displayName`
- `bundleIdentifiers`
- `defaultRecordingLocations`
- `defaultHistoryLocations`
- `integrationLevel`
- `capabilities`
- `setupInstructions`

### RecordingSession

- `id`
- `sourceAppID`
- `detectedAt`
- `completedAt`
- `sourceURL`
- `archiveURL`
- `duration`
- `fileSize`
- `status`
- `metadataURL`
- `errorMessage`

### TrackPlay

- `id`
- `sessionID`
- `title`
- `artist`
- `startTime`
- `endTime`
- `deck`
- `source`
- `confidence`

### AppFolderPermission

- `id`
- `adapterID`
- `folderURL`
- `permissionType`
- `bookmarkData`
- `status`

## Technical Architecture

- `DJMemoryCore`: adapters, file discovery, watchers, session model, archive service.
- `DJMemoryApp`: SwiftUI app window, menu-bar item, setup, library UI.
- `DJMemoryCLI`: diagnostics and local probes.
- `DJMemoryParsers`: later module for Serato/Traktor/VirtualDJ metadata parsers if complexity grows.

### Archive Behavior

- Copy only after file has stopped changing for a configurable stability window.
- Default stability window: 30 seconds.
- Never delete source files.
- Never overwrite existing archive files.
- Preserve original extension.
- Generate sidecar metadata JSON.

Default archive naming:

`YYYY-MM-DD HHmm - {DJ Software} - Set.{ext}`

Default archive folder:

`~/Music/DJMemory`

Users can choose a custom archive folder in Settings. Custom archive folders use security-scoped bookmarks for sandbox-safe access.

Future naming variables:

- date
- time
- app
- venue
- event
- city
- first track
- detected duration

## Privacy, Security, and Policy

- DJMemory processes files locally by default.
- No cloud account is required for v0.1.
- No audio or library metadata leaves the Mac without explicit user action.
- Diagnostics exports redact the user's home-folder prefix and exclude full imported track titles/artists by default.
- Streaming-service restrictions must be respected.
- The app should avoid language suggesting it can bypass disabled recording features.

## Success Metrics

### Product Metrics

- percentage of users with at least one protected app/folder
- number of recordings archived per active user
- archive success rate
- permission/setup completion rate
- support events per archived recording

### Quality Metrics

- false archive rate: files copied before complete
- missed recording rate from known watched folders
- duplicate archive rate
- parser success rate for supported history files

## Milestones

### Milestone 0: Foundation

- Swift package and repo scaffold.
- Adapter model.
- Local probe CLI.
- Initial research and PRD.

Status: complete.

### Milestone 1: Archive Engine

- File watcher service.
- Stability detector.
- Archive copy service.
- Metadata sidecar writer.
- CLI command to watch a folder and archive test recordings.

### Milestone 2: macOS App Shell

- SwiftUI app.
- Menu-bar status.
- First-run setup.
- Folder permission/bookmark storage.
- Basic session library.

### Milestone 3: Serato + rekordbox MVP

- Serato folder watcher.
- rekordbox installed-app detection.
- rekordbox recording folder setup.
- Serato history export importer.
- rekordbox XML/history import probe.
- Manual rescan.
- App-specific setup states.

### Milestone 4: Traktor + Beta Metadata

- Traktor folder/root discovery.
- Traktor NML history parser.
- Session-to-tracklist matching.

### Milestone 5: VirtualDJ Deep Probe

- VirtualDJ folder verification.
- Network Control probe.
- Decision memo on plugin vs local-control path.

### Milestone 6: Core Set Experience

- Archived set detail view.
- Editable event, venue, city, tags, and private notes.
- Manual tracklist attach/detach for incorrect automatic matches.
- Related recording metadata and activity context.

### Milestone 7: App UI + Visual Product Pass

- Protection-first dashboard.
- Clear top-level navigation for Protection, Library, Activity, and Settings.
- Strong empty states and clearer folder setup paths.
- Visual hierarchy and product-language cleanup.

### Milestone 8: Onboarding, Accounts, Backend Admin + Security Design

- New-user onboarding flow.
- Optional account model.
- Backend entity scope.
- Admin roles, permissions, and audit requirements.
- Security requirements and local-first data boundaries.

Status: documented in `docs/onboarding-accounts-security.md`.

### Milestone 9: Beta Readiness

- Reproducible packaged app build.
- Signing/notarization path.
- Permission recovery.
- Diagnostics privacy review.
- Release checklist.

### Milestone 10: Integration Expansion

- Finish Traktor recording setup and history support.
- Add VirtualDJ file-based support.
- Add djay documented recording-folder support with manual fallback.
- Add honest per-app integration status labels.

## Acceptance Criteria For v0.1

- User can install/run DJMemory on macOS.
- User can configure at least one watched recording folder.
- DJMemory archives a completed recording without changing the source file.
- Archived recordings appear in the library.
- Each archived recording has a metadata JSON sidecar.
- Manual rescan can recover recent recordings from watched folders.
- Serato defaults are detected when folders exist.
- rekordbox installation is detected when available.
- Default archive location is `~/Music/DJMemory`, with Settings support for a custom archive folder.
- Permission errors are visible and understandable.

## Resolved Decisions

- App Store-safe architecture from day one; initial distribution outside the Mac App Store is acceptable.
- Full app window plus menu-bar status.
- Default archive location: `~/Music/DJMemory`.
- First compatibility targets: Serato DJ Pro and rekordbox.
- First metadata parser: Serato history export, followed by rekordbox XML/history imports.
- Direct audio capture is an **in-app Capture mode** (not a separate product). **App audio** prefers Process Audio Tap and falls back to ScreenCaptureKit; **Input device** (Core Audio) remains for mixer/USB. Both are additive to folder Protection.

## Open Decisions

- Should v0.1 include Traktor as a visible "coming next" adapter, or hide it until support is implemented?
- Should the default `~/Music/DJMemory` library mirror files into subfolders by app, year, or event?

## Milestones 11–16
See `docs/integration-status.md`. M11 Capture/Pioneer hybrid; M12 history; M13 VDJ commands; M14 plugin research; M15 opt-in sync; M16 publish packs.
