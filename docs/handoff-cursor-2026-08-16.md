# Handoff — 2026-08-16

For: continuing this work in Cursor.
Repo: SetCatcher (DJMemory macOS app, Swift package). Branch: `main`. No commits made
this session — everything below is either an uncommitted fix on top of `HEAD`, or
pre-existing uncommitted work already on the tree.

## 1. What's uncommitted right now

`git status` shows two independent groups of changes on top of `main`:

1. **A launch-time performance fix I just made** (see §2) — small, isolated diff in
   `AppModel.swift`, `DJMemoryApp.swift`, `MenuBarIconView.swift`.
2. **A pre-existing, in-progress "Bold Directions" dark UI redesign** — the rest of
   the modified/untracked files (`AppSettings.swift`, `MenuBarState.swift`,
   `MenuBarStatusView.swift`, `Theme/*`, several `Views/*`, plus new files
   `Theme/HeroHeader.swift` and `Views/Home/HomeHeroBand.swift`). This was already on
   the tree before this session started; I reviewed it (§3) but did not modify it,
   except where fixing #1 required touching a file it also touches (`MenuBarIconView.swift`,
   see conflict note below).

**Don't `git checkout .` or stash-drop anything without reading it first** — there
are 6 older stashes on this branch (`git stash list`) from prior work sessions;
leave those alone unless you know what they are.

**Overlap to watch**: my fix and the UI redesign both touch `MenuBarIconView.swift`.
The redesign's copy already attempted its own fix for a *related but different*
symptom (see §2) — my change supersedes that attempt. If you're diffing/reconciling
against an earlier version of the redesign branch, don't reintroduce the
`TimelineView(.animation(...))` pattern into that file.

## 2. Launch-time CPU/RSS runaway — fixed and verified

**Symptom (pre-existing, confirmed on clean `HEAD` before any redesign work):** on
every launch, one CPU core pegs near 100% and RSS climbs unbounded (40MB → 1GB+
within ~9s), nothing printed to console.

**Root cause (confirmed via live `sample` profiling, not just reading code):**
`MenuBarIconView`'s `TimelineView(.animation(...))`, used to animate the flashing
(launch) / pulsing (recording) menu bar icon, is hosted inside the `MenuBarExtra`
label — an `NSStatusBarButton`, not a real window. `sample` showed 100% of sampled
main-thread time inside one call chain:
`MenuBarExtraController.updateConfiguration` → `Update.dispatchActions()` →
`MenuBarExtraController.updateButton(_:)` → `-[NSStatusBarButton setImage:]` → AppKit
SF-Symbol image-resolution/cell-layout — called continuously, without returning.
`TimelineView(.animation)` is built for a window's real display-link-paced render
loop; in a `MenuBarExtra` label it does not appear to respect `minimumInterval` and
instead spins.

Important: the redesign's own (uncommitted) version of `MenuBarIconView.swift` had
already tried to fix a *symptom* of this — its doc comment says recreating the
`NSImage` inside the animation closure "caused unbounded memory growth," and it
hoists the image out + drops to 10fps. **I tested that fix in isolation (clean HEAD
+ only that file swapped in) and it did not resolve the CPU spin.** The bug isn't
about per-frame allocation cost, it's `TimelineView` itself misbehaving as a
`MenuBarExtra` host, regardless of frame rate or per-tick cost.

**The actual fix:** stopped using `TimelineView` entirely for the menu bar icon.
Replaced it with the same bounded, explicitly-cancelled
`Task { while !Task.isCancelled { try? await Task.sleep(...) } }` polling pattern
already used everywhere else in `AppModel` (e.g. `startAppAudioPolling()`). A new
`@Published private(set) var menuBarIconOpacity: Double` on `AppModel` is ticked at
~10Hz by `updateMenuBarPulseTask()` only while `menuBarState.isFlashing ||
.isPulsing`, and cancelled the instant neither is true. `MenuBarIconView` now takes
`opacity: Double` as a plain parameter instead of sampling `context.date` inside a
`TimelineView` closure.

**Files touched:**
- `Sources/DJMemoryApp/AppModel.swift` — added `menuBarIconOpacity`, `menuBarPulseTask`, `updateMenuBarPulseTask()`; hooked into `isLaunchingForMenuBar`'s `didSet` and `handleCaptureStateChange`; cancelled in `deinit`.
- `Sources/DJMemoryApp/MenuBarIconView.swift` — removed `TimelineView`, takes `opacity: Double` directly.
- `Sources/DJMemoryApp/DJMemoryApp.swift` — call site now passes `opacity: model.menuBarIconOpacity`.

No changes to `FolderChangeMonitor`, `ScanCoordinator`, `RecordingFolderScanner`,
`ArchiveService`, capture services, or any archive/scan/protection logic. Source
files are never touched by this change — purely menu-bar-icon presentation.

**Verification (reproducible):**
```bash
swift build
.build/debug/DJMemoryApp &
APP_PID=$!
sleep 1;  ps -p $APP_PID -o %cpu,rss,etime
sleep 3;  ps -p $APP_PID -o %cpu,rss,etime
sleep 5;  ps -p $APP_PID -o %cpu,rss,etime
kill -9 $APP_PID
```
Before fix: CPU climbs to ~98%, RSS climbs past 1GB and keeps rising past 9s.
After fix: CPU settles to single digits after the initial launch burst, RSS
plateaus around ~137MB. Confirmed with a follow-up `sample $PID 3 -file out.txt` —
`updateButton`/`dispatchActions` no longer appear anywhere in the profile; the main
thread sits in kernel wait traps (idle) as expected.

**Not yet done:** I haven't done a live/visual check that the icon still visibly
flashes at launch and pulses while recording (only confirmed the perf fix + that the
opacity math is unchanged, just relocated). Worth a 30-second manual look before
calling this fully closed.

## 3. UI redesign review ("Bold Directions" — dark, waveform-as-hero)

Reviewed by reading code (live screenshot access was declined this session — worth
doing a real visual pass with Xcode's canvas/previews or a live run). Everything
below is code-level "this is wired up correctly," not "I looked at it and it's
good":

- **Home hero** (`Views/Home/HomeHeroBand.swift`) — "Protected."-style headline via
  shared `HeroHeader`, status waveform that recolors/breathes by protection state,
  EQ glyph mark, per-app source lanes (`HomeSourceLanes`) — all correctly reading
  live `AppModel` state (`protectionState`, `captureState`, `probeResults`).
- **Capture hero** (`Views/CaptureView.swift`) — pulsing dot (`PulsingDot`, respects
  Reduce Motion), big mono timecode via a 1s `TimelineView` (fine — real window,
  1s cadence, not the menu bar pattern), live input-reactive waveform
  (`LiveWaveform`), Stop & Save / Disarm. Idle state correctly falls back to the
  dense `captureConfig` layout (`isHeroActive` gate).
- **Onboarding** (`Views/OnboardingView.swift`) — warm-ink ground
  (`DJToken.Ground.onboarding`), serif-italic accent tail via `HeroHeader`
  (`accentTail`/Georgia italic), waveform + app chips that light gold
  (`DJToken.warmGold`) as folders are granted.
- **Theme system** (`Theme/Tokens.swift`, `Theme/ButtonStyles.swift`,
  `Theme/Panel.swift`) — consistent, deliberate dark palette; app is pinned dark via
  `.preferredColorScheme(.dark)` at the `ContentView` root. No stray hardcoded
  colors found that would fight the dark ground (`grep`'d for raw `Color.black`/
  `Color.white` backgrounds outside the theme files — none in `Views/`).

**Flagged, not fixed:** `LiveWaveform` (`Theme/Waveform.swift:128`) uses uncapped
`TimelineView(.animation)` — no `minimumInterval`. This is a *real* window (not a
`MenuBarExtra` label), so it doesn't have the same failure mode as §2, and it's only
active while actively recording — but it's driving 96 bars' `sin()` per frame at
full display refresh rate. Cheap fix if you want it: add
`minimumInterval: 1.0/30.0` — visually indistinguishable, less CPU during long
capture sessions.

**Not yet reviewed:** Protection, Library, Activity, Settings, and per-app setup
routes for legibility/contrast — the original ask included these but I ran out of
scope this session focusing on Home/Capture/Onboarding + the perf fix. Worth a pass.

## 4. Further optimization punch list (not started)

In rough priority order:

1. **`LiveWaveform` uncapped animation** — see §3 above. Small, safe, do first.
2. **`SoftwareProbe.probeAll()`** (`Sources/DJMemoryCore/SoftwareProbe.swift:75`) —
   synchronous on the main thread, called from every `AppModel.refresh()` (init,
   post-scan, manual refresh button). Enumerates installed apps + filesystem paths
   for every entry in `SupportedDJSoftware.all`. Not currently a measured problem,
   but it's on the main thread and scales linearly with the supported-app list —
   worth moving to a background task if that list grows much more.
3. **`refresh()` cost** (`Sources/DJMemoryApp/AppModel.swift:430`) — reloads every
   on-disk store (folder access, tracklists, sessions, activity log, profile) on
   every call, including after every scan (`scanNow()` calls it in its completion).
   Fine at current data volumes (a DJ's personal archive); would need attention if
   users accumulate thousands of archived sets — profile before optimizing.
4. **Sliding debounce in `FolderChangeMonitor`** —
   `AppModel.scheduleFolderChangeScan()` (`AppModel.swift:1185`) restarts a 5s timer
   on every FS event rather than coalescing to a fixed window. A folder under
   sustained write pressure (e.g. a DJ app writing continuously) could defer
   scanning indefinitely. Low priority — real but narrow edge case; needs a design
   decision (fixed window vs. sliding cap) before implementing.
5. **Poll-loop lifecycle while menu-bar-only** —
   `captureTargetPollTask`/`captureInputPollTask` (`AppModel.swift:1566`) poll every
   15s unconditionally while capture mode is active-but-idle. Confirm these fully
   stop (not just no-op cheaply) when the app is backgrounded to menu-bar-only —
   haven't verified either way this session.

## 5. Build / run / verify

```bash
cd /Users/robcmartin/Documents/Claude/Projects/SetCatcher
swift build                        # or open Package.swift in Xcode
.build/debug/DJMemoryApp           # launch directly; kill after a few seconds if testing perf —
                                    # historically this app could peg a CPU core, see §2
```
Xcode: `Package.swift` is the project entry point (SPM), already reopened this
session via `open -a Xcode Package.swift`.

**Hard constraints for any future changes** (carried over from the original task):
archive/capture/scan correctness must never regress — source files must never be
moved, renamed, or deleted, and folder protection must keep working. None of the
work in §2–§4 touches that path; keep it that way unless the task explicitly calls
for it.
