# Handoff for Codex — PR2.1: fix the App Audio capture OOM leak (direct Core Audio IOProc)

**Repo:** `/Users/robcmartin/Documents/Claude/Projects/SetCatcher` (DJMemory, Swift
package). **Branch:** `perf/dsp-vdsp-vectorization`. Background handoffs in `docs/`:
`handoff-cursor-pr2-serato-virtual-audio-2026-08-17.md` (PR2 = the code you're fixing),
`handoff-cursor-pr3-process-tap-clock-anchor-2026-08-17.md`.

## Current status — 2026-08-17 (read this first)

PR2.1 implementation is complete and pushed as focused commits after `ac0b7fe`:

- `5fe6b1b` — safety-gate virtual App Audio behind `DJMEMORY_ENABLE_VIRTUAL_APP_AUDIO=1`.
- `ac40d7b` — direct Core Audio IOProc extraction and Serato virtual-device backend rewrite.
- `4b88d45` — correct interleaved Float32 input by deinterleaving before the planar converter.
- `2139cb7` — restore the virtual backend safety gate while a separate reported OOM was diagnosed.

The short live Serato listen after `4b88d45` was clean. A real GUI capture stayed roughly
124–137 MB for more than six minutes; its staging WAV was intentionally retained because
that app instance lacked archive-folder bookmark access. Do not delete that source file.

The later multi-GB OOM was independently diagnosed as a dirty `MenuBarExtra` rendering
loop, not Core Audio: macOS reported repeated `NSStatusBarButton.setImage:` / `setTitle:`
updates and footprint growth from 26 MB to 7.6 GB. The uncommitted menu-bar fix removes
continuous label animation, caches status images by discrete state, and removes the
menu-bar `TimelineView`. `swift build` is warning-free and `swift test` passes (208 tests,
3 expected hardware skips). A packaged-app menu-bar run lasted about 5m51s and ended at
222 MB RSS with no new resource report; its complete watchdog trace was not retained.

### Remaining live acceptance — run now

Do **not** enable virtual App Audio by default yet. Run the packaged app with
`DJMEMORY_ENABLE_VIRTUAL_APP_AUDIO=1`, with Serato's “Make Audio Available to Other
Applications” enabled, and sample RSS every 0.5 seconds with a 4 GB kill threshold.
Let Serato play for a sustained take, then use **Stop & Save** (not process kill). Confirm:

1. RSS remains in the low hundreds of MB and does not trend upward.
2. The WAV archives successfully and appears in Library (repair/reselect archive-folder
   access first if needed).
3. `afinfo`, `ffmpeg astats`, and a spectrum image are valid.
4. The repo owner listens and confirms no distortion, warble, or stutter.

Only after all four pass may a focused follow-up flip the default to virtual enabled;
retain `DJMEMORY_ENABLE_VIRTUAL_APP_AUDIO=0` as the emergency override. PR3 remains
deferred unless Serato sounds bad again or there is a confirmed need for an app without a
verified virtual device.

### Long-run attempt result — not accepted

One packaged-app run was attempted for about 13 minutes with the virtual flag confirmed
in the process environment. RSS was 283–301 MB at the end, so it did not reproduce the
prior multi-GB growth. However, after **Stop & Save**, the menu-bar UI reported a failed
capture beginning `“virtual-input-92F2F77C-A489-…` and there was no new staging WAV or
archive. Treat this as a save/finalization failure (apparently the virtual-input staging
file was missing), not a successful acceptance run. The 0.5-second detached watchdog did
not survive the full run, so only direct RSS samples are available. Investigate the
`CoreAudioIOProcCapture.endRecordingFile` staging-file lifecycle before retrying, and do
not change the default gate.

## Staging-file-missing investigation — findings (2026-08-17, Claude)

Static trace of the "no staging WAV / failed capture `virtual-input-<UUID>`" symptom.
No code was changed and the gate default was not touched.

**1. This is not the memory bug.** The 13-min run stayed 283–301 MB — the direct-IOProc
virtual backend does not leak. This is a separate, narrow save-path failure.

**2. The exact error is `ArchiveServiceError.sourceFileMissing(stagingURL)`** thrown by
`ingestCaptureWithAccess` at `Sources/DJMemoryCore/ArchiveService.swift:143`
(`guard fileManager.fileExists(atPath: stagingURL.path) else { throw sourceFileMissing(stagingURL) }`).
That error embeds the staging path, which is why the menu-bar message "began with"
`virtual-input-92F2F77C…`. It is **not** `CoreAudioIOProcCapture.endRecordingFile`'s own
guard (`Sources/DJMemoryCore/CoreAudioIOProcCapture.swift:198`, fixed string "Capture
staging file is missing", no filename). So `endRecordingFile` returned a **valid result**
(its `fileExists` guard passed → file was present), and `ingestCapture` then found the
file **gone**.

**3. The contradiction that localizes the cause.** In the app-audio Stop & Save path,
`AppModel.finalizeAppAudioSession` (`Sources/DJMemoryApp/AppModel.swift:1993`) calls
`appAudioCaptureService.endRecordingFile(discard: false)` (line 1999) and then
`archiveService().ingestCapture(stagingURL: result.stagingURL, …)` (line 2001)
**synchronously on the MainActor, with no `await` between them**, and both pass the same
`result.stagingURL`. Single-threaded, the file cannot exist at line 1999's return and be
gone at line 2001's `fileExists`. The only staging-file removers in the codebase are the
`discard: true` branches (`CoreAudioIOProcCapture.swift:190` and `:194`) and
`ingestCapture`'s own post-copy cleanup (`ArchiveService.swift:159`) — there is **no
periodic staging-cleanup routine** (grep-confirmed). Therefore the removal came from
**another thread**, and there are exactly two candidates:

- **Candidate A — a concurrent `discard:true` teardown racing the save. CORRECTED
  2026-08-18 (Codex, verified in code): this cannot by itself be the cause.**
  `AppModel.haltAppAudioCapture` (`Sources/DJMemoryApp/AppModel.swift:2330`) spawns a
  detached `Task { if isWriting { try? endRecordingFile(discard: true) } ; await stopMonitoring() }`
  (lines 2339–2344), and `stop()` (`CoreAudioIOProcCapture.swift:124-126`) also calls
  `endRecordingFile(discard: true)`. BUT the removal is gated: `endRecordingFile` begins
  with `guard isWriting else { throw notWriting }` (`CoreAudioIOProcCapture.swift:176`),
  and a successful `discard:false` save clears **both** `isWriting` (line 179) and
  `stagingURL` (line 187) before returning. So once the save has returned a valid result,
  any later `discard:true` throws `notWriting` at line 176 and never reaches the
  `removeItem` at line 190 — it cannot delete the file. And if a `discard:true` ran
  *before* the save, the save's own `guard isWriting` would throw `notWriting`, producing a
  different error, not `ArchiveService.sourceFileMissing`. **Treat A as a real fragility to
  harden (see fix note), not as the proven mechanism.**
- **Candidate B: a sandbox staging-path/permission mismatch** in the packaged (sandboxed)
  app — staging written to one location, checked/copied from another — possibly
  interacting with `ingestCapture`'s `withSecurityScopedArchiveRoot { … }` wrapper
  (`ArchiveService.swift:63`). The doc already noted that app instance "lacked
  archive-folder bookmark access," so verify the staging path resolves identically at
  write, at `endRecordingFile`'s guard, and at ingest under the sandbox.

**4. Disambiguate with three logs, then one guarded re-run** (this is the "investigate
before retrying" the status section asked for):
- `CoreAudioIOProcCapture.beginRecordingFile` — log the created `stagingURL`.
- `CoreAudioIOProcCapture.endRecordingFile` immediately after the `fileExists` guard
  passes — log `stagingURL`, file size, `isWriting`, thread.
- The `ArchiveService` `sourceFileMissing(stagingURL)` throw — log the path; and add a log
  to **every** `endRecordingFile(discard: true)` / `CoreAudioIOProcCapture.stop()` entry
  with thread + timestamp.
Run the guarded test (`DJMEMORY_ENABLE_VIRTUAL_APP_AUDIO=1`, Serato playing, RSS watchdog,
Stop & Save). If a `discard:true`/`stop()` log lands between the begin and the ingest, it
is Candidate A. If the paths differ, it is Candidate B.

**5. Do NOT implement a hypothesized fix yet — instrument, reproduce once, then fix the
mechanism the trace actually shows** (Claude + Codex agree on this). The observed
sequence (valid `endRecordingFile(discard:false)` result → `ArchiveService` finds that
same file missing) is not explained by any single-threaded or `isWriting`-gated path in
the current code, which means the real cause is still unproven. Codex's structural read
is the most promising lead: `CoreAudioIOProcCapture` mutates capture state
(`audioFile`, `isWriting`, `stagingURL`, preroll) from **both** the IOProc
`sampleHandlerQueue` and asynchronous teardown (`stop()` at
`CoreAudioIOProcCapture.swift:122`) without a single serialization boundary, so
finalization is fragile. Likely direction once the trace confirms the deletion/visibility
point: give the capture-state lifecycle one serialization boundary (all of
begin/end/stop/reset and the file handle mutated under one queue/actor), and ensure Stop
& Save's `endRecordingFile(discard:false)` + `ingestCapture` fully complete before any
teardown runs — rather than the disproven "guard the discard race" fix. Keep the gate
default OFF until a guarded run archives a file and the repo owner confirms clean audio.

## Precondition: build on the safety-gated base

**Part A (the safety gate) has already been implemented** and must be committed/pushed
before you start (confirm `git log` on `origin/perf/dsp-vdsp-vectorization` includes a
"safety gate" commit after `ac0b7fe`; if not, ask the repo owner — do not build Part B
on `ac0b7fe` itself, which OOMs the machine). Part A adds
`AppAudioCaptureBackendSelector.virtualAppAudioEnabled` (env
`DJMEMORY_ENABLE_VIRTUAL_APP_AUDIO`, default **OFF**) and a `virtualEnabled` parameter
on `preferredSelection(...)`, so App Audio uses Process Audio Tap by default. Your job
(Part B) is to make the virtual backend safe, then it can be enabled by default.

## The bug you're fixing

PR2 (`ac0b7fe`) captures Serato Virtual Audio through **AVAudioEngine**
(`VirtualInputDeviceCaptureService` → `CaptureService`). On a real Serato take this
**leaked ~8 GB/s and OOM'd the machine to 194 GB in ~24s.**

Confirmed by investigation:
- **Idle is stable** (RSS ~119 MB flat). The leak is only while armed + monitoring the
  virtual device.
- The **write path is fine** — a valid 24s WAV was produced; the balloon is
  AVAudioEngine's internal buffering, not the recording.
- **Root cause:** `CaptureService.bindEngineInput` pins only the engine's *input* to
  Serato Virtual Audio; the *output* stays on the system speakers → two mismatched
  clocks, and the software virtual device's timing follows Serato's jittery app
  scheduling → AVAudioEngine buffers the drift unbounded. Physical devices (Pioneer
  USB) never leaked because they have a stable hardware clock.

**Key insight:** a direct Core Audio `AudioDeviceIOProc` on a *real* device (Serato
Virtual Audio has its own clock) has neither problem — no AVAudioEngine output side to
mismatch (kills the leak), and a real device clock (also kills the drift/distortion
that the tap-aggregate path suffers). `ProcessAudioTapCaptureService` **already
contains this exact IOProc→convert→write→preroll pipeline** and it's proven + unit-
tested (`CaptureDSP`). It only distorts because it runs on a *clockless aggregate*, not
because the pipeline is wrong. Point that same pipeline at a real device ID.

## Part B — implement

Replace the AVAudioEngine-based
`Sources/DJMemoryCore/VirtualInputDeviceCaptureService.swift` (delegates to
`CaptureService` = the leak) with a direct Core Audio IOProc capture of the virtual
device.

1. **Extract `CoreAudioIOProcCapture`** from `ProcessAudioTapCaptureService`
   (`Sources/DJMemoryCore/AppAudioCaptureService.swift`). It should operate on an
   arbitrary input `AudioDeviceID` + its `AudioStreamBasicDescription`, owning:
   `AudioDeviceCreateIOProcIDWithBlock` + `AudioDeviceStart`/`AudioDeviceStop` (see
   ~lines 412–422), `handleAudioBufferList` (deinterleave/convert/write/meter, ~line
   653 — already vDSP-optimized), the preroll ring, and begin/end recording. The tap
   backend then becomes: "resolve tap → build aggregate → hand its device ID + format
   to `CoreAudioIOProcCapture`." Keep the tap backend's external behavior identical.
2. **Rewrite the virtual backend** to: resolve Serato Virtual Audio's `AudioDeviceID`
   via the existing `AudioInputDeviceCatalog.audioDeviceID(forUID:)`
   (`Sources/DJMemoryCore/AudioInputDeviceCatalog.swift`); read the device's input
   stream format (`kAudioDevicePropertyStreamFormat`, input scope — mirror the tap's
   `readTapFormat`, which reads `kAudioTapPropertyFormat`); and run
   `CoreAudioIOProcCapture` **directly on that device ID**. No tap, no aggregate, no
   AVAudioEngine, no output side. Drop the `CaptureService` dependency from the virtual
   backend.
3. `CaptureService` (AVAudioEngine) **stays as-is** for Input Device Capture of physical
   hardware — it works. (Known, out-of-scope risk: the same AVAudioEngine I/O clock
   mismatch could in theory affect Input Device Capture of an unstable-clock device;
   never seen on real hardware.)
4. **Enable by default** once the leak is verified fixed: flip the Part A gate so
   `virtualAppAudioEnabled` defaults true (or remove the gate), keeping the env override
   for emergencies.

## Verify

Unit (no hardware): `swift build`, `swift test` — keep the suite green (currently ~205
pass / 3 skipped). The extracted `CoreAudioIOProcCapture` must keep the existing
`CaptureDSP` and `AppAudioCaptureBackendSelectorTests` passing. Add a test resolving the
virtual device's `AudioDeviceID`/format.

**Leak test — MANDATORY, and use an RSS watchdog so a regression can't OOM the machine
again.** Not unit-testable; needs a real Serato session. Procedure:
```bash
swift build
DJMEMORY_ENABLE_VIRTUAL_APP_AUDIO=1 .build/debug/DJMemoryApp &
# In another shell, watchdog: sample RSS every 0.5s; sample+kill if >4 GB
PID=$(pgrep -f .build/debug/DJMemoryApp)
while :; do RSS=$(ps -o rss= -p $PID); RSS=${RSS// /}
  echo "$(date +%T) RSS=$((RSS/1024))MB"
  [ $((RSS/1024)) -gt 4000 ] && { sample $PID 1 -file /tmp/leak.txt; kill -9 $PID; break; }
  sleep 0.5; done
```
- In Serato, enable **Settings → Audio → "Make Audio Available to Other Applications"**
  (this is what activates Serato Virtual Audio; without it the device delivers no audio).
- Arm App Audio with Serato playing. **RSS must stay bounded (low hundreds of MB), not
  climb.** If it climbs, the watchdog kills it and `sample`'s stack shows the allocator.
- Stop & Save (NOT process-kill) → valid archived WAV → check with
  `afinfo` / `ffmpeg -af astats -f null -` / `showspectrumpic`.
- **Final acceptance gate is the repo owner listening — it must sound clean** (no
  distortion/warble/stutter). You cannot judge audio quality; hand it to them.

## Files
- `Sources/DJMemoryCore/AppAudioCaptureService.swift` — extract `CoreAudioIOProcCapture`;
  flip the gate default when verified.
- `Sources/DJMemoryCore/VirtualInputDeviceCaptureService.swift` — rewrite on
  `CoreAudioIOProcCapture`; drop `CaptureService`.
- `Sources/DJMemoryCore/AudioInputDeviceCatalog.swift` — add input-scope stream-format
  reader if not exposed.
- `Tests/DJMemoryCoreTests/AppAudioCaptureBackendSelectorTests.swift` + a resolution test.

## Constraints
Archive/scan correctness must never regress (source files never moved/renamed/deleted).
The working tree on this branch is dirty with unrelated in-flight work (UI redesign,
16-bit format, menu-bar fix, PR1 mic-safety guards). Commit ONLY PR2.1 files; do NOT
`git checkout`/`reset`/`stash drop` without asking (6 stashes live on this branch). The
16-bit `CaptureAudioFormat` change is intentional; leave it.
