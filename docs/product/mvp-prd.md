# PRD: SetCatcher Mac Private Beta

Status: current beta requirements  
Last updated: September 2, 2026.

## Summary

The first external beta must prove that a new Mac user can install SetCatcher, connect a real recording workflow, understand whether protection is active, preserve a completed set without changing its source, and find the result later without developer assistance.

The beta includes multiple protection paths already implemented, but **Folder Protection is the minimum dependable promise**. Capture and history attachment improve coverage without weakening that baseline.

## Problem statement

Active DJs create valuable recordings in workflows that depend on memory, application-specific folders, permissions, and inconsistent history exports. If SetCatcher cannot make protection legible and dependable during a real workflow, the user will not trust it to remain running for the next set.

## Goals

1. At least 60% of invited testers who install the app complete one protected-source setup.
2. At least 80% of activated testers create a first protected set without developer intervention.
3. At least 40% of activated testers protect a second real set within 30 days.
4. At least 80% of first-set respondents rate trust and setup confidence at 4/5 or higher.
5. Zero tested workflows modify or delete source recordings, expose audio by default, or replace a user's manually pinned tracklist.

## Non-goals for the private beta

- Charging users or enforcing paid licenses; pricing must be validated after repeated value.
- Automatic audio upload or remote archive backup. Remote archive backup is not available in this private beta.
- Public hosting, social discovery, or direct publishing.
- Windows support or Mac-to-iPad archive synchronization.
- Perfect automatic tracklist matching for every DJ app and hardware workflow.
- Claiming every installed DJ application is fully supported.
- Depending on experimental VirtualDJ plugins, Traktor injection, Serato private formats, or streaming-service capture.

## Primary users

- A club or event DJ using Serato or rekordbox on a Mac who records at least monthly.
- A radio, streaming, or multi-platform DJ who needs recordings and available history to remain connected.

## Core user journeys

### Journey A — Protect recordings written by a DJ app

1. User opens SetCatcher and sees current protection status.
2. SetCatcher detects supported applications and likely recording folders.
3. User grants access to a detected or manually selected recording folder.
4. SetCatcher watches the reachable folder while the app is running.
5. A new audio file appears and stops changing.
6. SetCatcher creates a uniquely named archive copy and JSON sidecar.
7. The source remains unchanged and the set appears in Library.
8. The user receives a quiet success notification and can open the archive location.

### Journey B — Capture app audio when Record/Save was not used

1. User selects a shareable running DJ application and arms App audio Capture.
2. SetCatcher uses Process Audio Tap on supported macOS versions and falls back to ScreenCaptureKit when necessary.
3. SetCatcher displays permission, target, meter, recording, saving, and failure states.
4. Audio activity starts a take; the configured silence policy ends and archives it.
5. The resulting 24-bit/48 kHz stereo WAV appears in the same Library and archive model as a protected folder recording.
6. If the mix does not reach Mac system audio, SetCatcher explains that the user should use Input device Capture or Folder Protection.

### Journey C — Capture a mixer or USB input

1. User selects or auto-detects an audio input device.
2. SetCatcher requests microphone/input permission and displays a level meter.
3. User starts and stops Capture, or uses supported silence behavior.
4. SetCatcher archives the WAV through the same copy, metadata, and Library path.
5. Missing device, denied permission, engine failure, and disk-full states produce actionable messages.

### Journey D — Find and enrich a protected set

1. User opens Library and searches or filters archived sessions.
2. User opens Set Detail and can add event, venue, city, tags, and private notes.
3. User imports or selects an available track history.
4. SetCatcher may attach the closest eligible history automatically.
5. User can attach or detach a tracklist manually; a manual choice is never overridden.
6. User may export a local publish pack. That export remains local and uploads nothing.
7. If the user opts into catalog sync, event, venue, city, and tags may sync; private notes and manual tracklist choices remain local to that device. On Mac, the user enables catalog sync after signing in. On Companion, signing in from the disclosed Settings surface starts catalog sync.

### Journey E — Recover from lost access

1. SetCatcher detects a moved, missing, file-backed, or unreadable saved folder.
2. Protection changes to Attention Needed without claiming the folder is protected.
3. User chooses the folder again, chooses a replacement, or clears the saved folder.
4. SetCatcher resumes scanning without deleting any source or archive data.

## P0 requirements

### P0.1 Install and launch

- The distributed app opens on a clean supported Mac without Terminal instructions.
- The build is correctly signed and notarized for its distribution channel.
- Local protection remains usable while signed out.

Acceptance:

- Given a supported clean Mac, when a tester downloads and opens SetCatcher, then Gatekeeper permits normal launch and the main window appears.
- Given no account configuration, when the app launches, then Protection, Capture, Library, and local Settings remain available.

### P0.2 Protection status and setup

- The Home and Protection surfaces answer “Am I protected right now?”
- Only reachable recording folders count as protected sources.
- First-run setup detects DJ apps, explains the archive location, and offers a clear next action.
- Folder access persists through security-scoped bookmarks.

Acceptance:

- Given no accessible recording folders and no armed capture source, then the app shows Needs Setup or Attention Needed rather than Protected.
- Given a valid saved folder, when the app relaunches, then access is restored or a recovery state appears.
- A first-time tester can complete one folder setup in under five minutes.

### P0.3 Completed-file protection

- SetCatcher detects supported audio files in granted recording folders.
- It waits for stability before copying.
- It never mutates the source, never overwrites an archive, and avoids duplicate archives through file identity and metadata.
- It writes a metadata sidecar and adds the session to Library.
- Manual scan can recover recent completed recordings.

Acceptance:

- Given a growing file, when scanning occurs, then the app reports active/waiting and does not archive it early.
- Given a stable recording, when protection runs, then an archive copy and sidecar are created and the source hash is unchanged.
- Given the same recording is scanned again, then SetCatcher does not create an unintended duplicate.
- Given a naming collision, then a unique archive name is created without overwriting an existing file.

### P0.4 Library and set detail

- Library lists archived sessions and supports search and date filtering.
- Set Detail displays source application, archive information, time, available duration/size, and context.
- Event, venue, city, tags, and private notes persist across relaunch.
- The archive can be revealed in Finder.

Acceptance:

- Given multiple real sessions, when the user searches by available set context, then matching sessions are shown.
- Given edited set context, when the app relaunches, then the edits remain attached to the same session.

### P0.5 Privacy and support

- No audio or full tracklist is uploaded by default.
- Catalog sync is off while signed out and discloses its data boundary on both Settings surfaces. On Mac, it also remains off until the signed-in user enables the catalog-sync control; on Companion, signing in from that disclosed surface starts catalog sync.
- Opt-in catalog sync may send a session identifier, originating platform, filename, source application, dates, duration and size, device name, technical catalog and capture details, and event, venue, city, and tags.
- Catalog sync never sends recording audio, full tracklist contents, local file paths, private notes, or manual tracklist selections.
- Applying remote catalog context preserves each device's private notes and manual tracklist selection.
- Remote archive backup is not available in this private beta.
- Diagnostics redact home paths and exclude track titles/artists and sensitive file content.
- Errors provide a next step in plain language.
- Optional account failure does not stop local protection.

Acceptance:

- Given the user is signed out, then no catalog metadata is sent; on Mac, signed-in catalog sync also remains off until enabled.
- Given the user opts into catalog sync through the applicable Settings flow, then the disclosure names the synced categories and the local-only categories before sync.
- Given remote context is applied to a set with local private notes or a manual tracklist selection, then those local-only values remain unchanged.
- Given a diagnostics export, then it contains operational metadata and counts without full track data or an unredacted home path.
- Given the account service is unavailable, then local scan, archive, capture, import, and Library behavior continue.

### P0.6 Honest compatibility

- The UI uses the current support matrix from `integration-status.md`.
- Support is capability-specific: recording folders, history, App audio Capture, and hardware setup may have different paths.
- Unsupported or unverified paths are labeled Manual Setup or Research.

Acceptance:

- No product or launch surface claims support beyond a verified workflow.
- Every setup requiring user-selected folders or hardware routing explains that requirement before Capture or protection begins.

## P1 requirements

### P1.1 App audio Capture

- Auto-arm may be offered for a verified shareable DJ app, while preserving an explicit user Disarmed state.
- Process Audio Tap is preferred; ScreenCaptureKit remains the fallback.
- Silence thresholds, pre-roll, minimum take length, and idle split behavior are configurable within safe bounds.
- Failed Capture never weakens an already configured Folder Protection path.

### P1.2 Input device Capture

- Display devices and levels, auto-select known Pioneer/DJM input when appropriate, and preserve manual selection.
- Archive successful takes using the shared session model.

### P1.3 History import and matching

- Import supported Serato, rekordbox, Traktor, and VirtualDJ history formats.
- Watch granted history folders and ingest late or appended exports idempotently.
- Match within the configured time window and prefer a closer automatic match.
- Never override a user's manual pin.

### P1.4 Menu-bar operation and notifications

- Show protection state, scan timing, recent archive result, and a path to the full app.
- Notify on successful archive and actionable failure without interrupting performance unnecessarily.

### P1.5 User-initiated local publish pack

- Export the selected recording and available tracklist/context into a user-chosen local folder.
- Do not upload, post, or share automatically.

## P2 considerations

- Dedicated remote archive backup after explicit opt-in and storage/cost design.
- Paid licensing and device management.
- Windows application.
- Mac/iPad archive interchange.
- Native VirtualDJ plugin after official SDK verification.
- Richer waveform, audio-quality, silence, and clipping analysis.
- Publishing integrations and hosted share pages.
- Team or artist-management workflows.

## Data and privacy boundaries

### Local product data

- source and archive URLs;
- file fingerprint, size, and timestamps;
- security-scoped bookmarks;
- set context and imported track histories;
- local settings, activity, and support status.

### Account/backend data

- optional user, device, license, invite, limited diagnostics metadata, and admin audit records;
- when the user opts into catalog sync through the applicable signed-in Settings flow: session identifier, originating platform, filename, source application, dates, duration and size, device name, technical catalog and capture details, and event, venue, city, and tags.

### Prohibited by default

- recording audio;
- full tracklists or track titles/artists in diagnostics;
- automatic publish content;
- hidden collection or use of local home paths.

### Local-only catalog fields

- source and archive paths;
- private notes;
- full tracklist contents;
- manual tracklist selections.

Legacy remote private-note fields are ignored. A remote catalog merge must not replace local private notes or a local manual tracklist selection.

## Dependencies and release gates

- Developer ID/App Store signing identity and notarization path.
- Clean-user install and launch validation outside the build directory.
- Folder-permission recovery test on a different user account or Mac.
- At least one external onboarding session with no developer guidance.
- A support response path for beta testers.
- Current privacy review of diagnostics, waitlist, and optional accounts.

## Measurement

Marketing funnel events cover page, demo, waitlist, research profile, invite, and activation. Product activation metrics must remain privacy-safe and should not contain audio, track titles, artists, or local paths.

Evaluate:

- invite acceptance and successful installation;
- protected-source setup completion;
- first and second protected sets;
- archive error and duplicate rate;
- trust and setup-confidence ratings;
- support events by workflow and DJ application.

## Open product decisions

These are non-blocking for the first invite cohort unless explicitly promoted into scope:

- Final post-beta price and packaging.
- Dedicated SetCatcher domain.
- Whether paid major upgrades or an optional compatibility-update plan best funds ongoing integration work.
- Whether remote backup should use SetCatcher storage or user-owned storage.
- The minimum validated demand required before Windows development.
