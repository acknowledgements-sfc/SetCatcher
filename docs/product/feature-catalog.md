# SetCatcher Feature and Workflow Catalog

Last updated: August 14, 2026. Dual-route Pioneer linking and unattended Input Capture added August 15, 2026; Pioneer Input Capture remains Manual Setup until external XDJ-XZ verification.

This catalog describes user-visible product behavior. Status reflects the repository and verification documents on the date above.

## Product surfaces

| Surface | Purpose | Current behavior |
| --- | --- | --- |
| Home | At-a-glance readiness | Summarizes protection, sources, archive activity, and next action |
| Protection | Folder-based safety net | Configures recording/history folders, scans, statuses, recovery, and timing |
| Capture | Direct recording safety nets | App audio and input-device modes with permissions, levels, arm/record/save states |
| Library | Durable history of sets | Lists, searches, filters, and opens archived sessions and imported histories |
| Activity | Operational evidence | Shows scans, archives, imports, errors, and recovery-relevant events |
| Settings | Product control | Archive location/naming, scanning, launch behavior, Capture settings, optional account/cloud flags, diagnostics |
| Menu bar | Passive confidence | Shows current protection status, scan timing, recent activity, and quick actions |

## Folder Protection

### What it does

- Stores user-granted recording and history folders with security-scoped bookmarks.
- Monitors reachable recording folders for file-system changes, with a periodic scan as a backstop.
- Detects active/growing recordings separately from completed files.
- Waits for file stability before archive.
- Copies completed audio into the SetCatcher archive.
- Writes a JSON sidecar and session-library record.
- Deduplicates previously archived inputs and resolves naming collisions.
- Supports manual scan/recovery for recent recordings.

### What it never does

- Move, rename, delete, truncate, or rewrite the source.
- Claim an inaccessible saved folder is protected.
- Treat a file itself as a valid recording folder.

### User-visible states

`Needs Setup` → `Protected` → `Recording Detected` → `Saving` → `Saved`, with `Attention Needed` for permission, path, disk, or copy problems.

## Archive

- Default root: `~/Music/SetCatcher` with a protected archive subfolder used by current implementation.
- Custom root supported through a security-scoped bookmark.
- Default naming includes date/time, source software, and set label.
- Naming template is user-editable.
- Archive entries retain source application, detected/completed time, paths, fingerprint, file size, and metadata URL.
- The archive is local storage, not automatically a separate-device disaster-recovery backup.

## App audio Capture

### Purpose

Protect a set even when the DJ forgot or could not use the DJ application's Record/Save action, provided the mix reaches Mac system audio.

### Behavior

- Discovers shareable running DJ applications.
- Prefers Process Audio Tap (macOS 15+).
- Uses ScreenCaptureKit as the verified fallback.
- Displays permission, target, backend, level, monitoring, recording, saving, completed, and failure states.
- Supports armed monitoring, pre-roll, audio-triggered take start, and silence-based session split.
- Saves 24-bit/48 kHz stereo WAV through the shared archive and Library pipeline.
- Respects an explicit Disarmed state.

### Limits

- Cannot capture a mix routed exclusively to hardware without reaching Mac system audio.
- ScreenCaptureKit requires Screen & System Audio Recording permission.
- Process Audio Tap behavior under a fully signed sandboxed distribution must remain part of clean-build verification; the fallback remains available.
- Streaming-service and DRM restrictions still apply.

## Input device Capture

- Lists available Core Audio input devices.
- Requests input/microphone permission.
- Supports manual device selection and known Pioneer/DJM preference where detected.
- On a recognized Pioneer USB input with Both (default) or Input only posture, auto-switches to Input device mode and records on audio / saves on idle silence. Folder Protection still watches granted folders.
- Overlapping folder and input archives of the same performance are one Library row (DJ-software file primary; Input Capture labeled Hardware backup). Neither source nor archive audio is mutated.
- Displays input levels and recording state.
- Records 24-bit/48 kHz stereo WAV.
- Handles missing device, denied permission, disk-full, engine, and double-start/stop conditions.
- Uses the same archive, metadata, Library, notification, and context workflows as other recordings.

## Library and Set Detail

- Lists protected and captured sessions. Overlapping Folder Protection and Input Capture files of one performance appear as a single row.
- Searches available session context and filters by date.
- Shows recording source, time, file information, archive location, matched history, and activity context.
- Persists event, venue, city, tags, and private notes.
- Supports manual tracklist attach and detach.
- Reveals the local archive in Finder.
- Exports a user-initiated local publish pack when requested.

## Track history

- Imports supported history/export formats for Serato, rekordbox, Traktor, and VirtualDJ.
- Distinguishes matchable set history from broader collection exports.
- Stamps undated plays with the set date when appropriate.
- Matches nearby history to a recording within a configurable time window.
- Watches granted history folders for late-written or appended exports.
- Ingest is idempotent; a closer automatic match may replace a weaker automatic match.
- Manual user attachment is authoritative and is never overwritten by automation.
- Missing history never invalidates the recording archive.

## Software compatibility

| Software/source | Folder protection | History/context | App audio Capture | Notes |
| --- | --- | --- | --- | --- |
| Serato DJ Pro | Supported | Serato history import and automatic matching | Supported and live-verified | Primary beta workflow |
| rekordbox 6/7 | Supported with selected recording folder | XML Bridge/history import and matching | Supported and live-verified | Primary beta workflow |
| Traktor | Supported | NML import and matching | Supported and live-verified | App and folder paths vary by version |
| VirtualDJ | Supported | File/Network Control paths; JSONL ingest implemented | Supported and live-verified | Native plugin remains research |
| djay Pro | Supported documented/manual folders | Limited compared with other apps | Supported and live-verified | Manual setup may be required |
| Pioneer/DJM hardware | Manual Setup | May match the nearest eligible app history | Laptop + USB Input Capture (implemented; device verification pending) or `PIONEERREC` folder | Device-specific verification remains required. Dual-route overlap is one Library row. CDJs into a mixer that never reaches the Mac stay Manual Setup. |
| Analog Mixer + turntables | Manual Setup | None unless the DJ imports one (or uses DVS + Serato/Traktor) | Pinned rec-out Input Capture (unattended after one-time pin) or dump-folder Protection | Not invisible Capture — see [`../analog-mixer-setup.md`](../analog-mixer-setup.md). Unknown USB stays manual-only until pinned. |
| Denon Engine OS hardware | Manual Setup | No Engine LAN scrape | Grant USB/SD `Sessions` folder; optional USB Input Capture when measured | See [`../denon-rane-hardware-setup.md`](../denon-rane-hardware-setup.md). |
| Rane hardware | Manual Setup | Prefer Serato history when using Serato | Serato folder + App audio (Supported); USB / Session Out extras Manual Setup | Session Out reuses Analog Mixer pin. |

For engineering-level detail and the latest verification, use [`../integration-status.md`](../integration-status.md).

## Onboarding and recovery

- First launch summarizes detected applications, archive location, protected-source count, and the next setup action.
- Setup can be reopened from Settings.
- The product asks for folder access only when needed.
- Unreachable saved folders stop counting as protected and show recovery actions.
- Users can choose a replacement folder or clear saved access without deleting source content.
- Permission and capture failures link to the relevant macOS System Settings when possible.

## Activity, notifications, and diagnostics

- Activity records scans, active recordings, successful archives, imports, warnings, and errors.
- Notifications announce successful archive and actionable failures without requiring the main window.
- Diagnostics export operational counts, support states, settings metadata, and recent activity needed for support.
- Diagnostics redact the home-folder prefix and exclude full track titles/artists.

## Accounts, licensing, and admin

- Accounts are optional for the local product.
- When configured, Clerk sign-in can register a device and refresh a license snapshot.
- Local Protection, Capture, Library, import, and diagnostics export continue while signed out or when the account service is unavailable.
- Diagnostic upload is a separate explicit user action and is metadata-only.
- The backend includes users, devices, licenses, beta invites, diagnostics metadata, admin roles, and audit events.
- Beta waitlist research and marketing events are limited to approved fields and must not include audio or track content.

## Cloud and publishing boundaries

- Cloud sync and archive-backup settings exist as opt-in flags; automatic audio upload is not a current default product promise.
- Archive backup cannot be enabled before cloud sync is explicitly enabled.
- Publish-pack export writes locally to a user-selected folder.
- Nothing is automatically posted or made public.

## iPad product boundary

SetCatcher for iPad is a standalone product surface. It does not connect to, mirror, or sync the Mac archive. Mac and iPad may share optional account identity only. iPad Capture uses device input because iPadOS cannot tap another application's audio.

## Known beta limitations

- Clean external installation, Developer ID signing, and notarization remain release gates.
- Some recording and history locations require manual folder selection.
- Hardware routing can prevent app-audio capture; Input device Capture or Folder Protection is the fallback.
- A local archive on the same disk is not sufficient protection from disk failure or theft.
- Automatic history matching is best-effort and may require a manual correction.
- Windows is not supported.
