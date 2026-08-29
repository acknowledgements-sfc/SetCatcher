# Handoff for Cursor — PR2: Serato Virtual Audio as an App Audio Capture backend

Date: 2026-08-17. Repo: `/Users/robcmartin/Documents/Claude/Projects/SetCatcher`
(DJMemory macOS app, Swift package). Branch: `perf/dsp-vdsp-vectorization` (working
tree is dirty with lots of unrelated in-progress work — see "Working tree" below).

The full approved design lives in `~/.claude/plans/generic-weaving-boot.md` on this
machine (may not be readable from Cursor). This handoff reproduces the PR2 parts.

## Why PR2 exists (the two problems it solves)

1. **Distorted/garbled/stuttering App Audio captures.** Confirmed via `git log` that
   the corruption began exactly with commit `d5e65bc "Add process audio tap capture
   backend"` — the last good capture (2026-08-09) used ScreenCaptureKit; the first bad
   one (2026-08-13) used the new Process Audio Tap. Extensive analysis (afinfo/astats/
   spectrogram/ffmpeg) of a bad file showed the *format math* is clean (48kHz Float32,
   ratio 1.0, no clipping, correct WAV header) — so the corruption is NOT bit-depth,
   NOT the DSP vectorization, NOT truncation. The leading hypothesis is **clock drift
   on the tap-only aggregate device** (`createAggregateDevice` in
   `Sources/DJMemoryCore/AppAudioCaptureService.swift` builds an aggregate from the tap
   alone, with no real hardware device anchoring the clock). That symptom set —
   distortion + warble + stutter + muffled — is the classic signature.
2. **PR2 sidesteps that entirely for Serato.** Serato ships a real Core Audio device
   "Serato Virtual Audio" (confirmed on this machine via `system_profiler
   SPAudioDataType`: Manufacturer "Serato", 2ch, 48kHz, Transport: Virtual) that
   mirrors Serato's mix. Capturing it through DJMemory's existing, already-correct
   `CaptureService` AVAudioEngine path (a real device with a real clock) avoids the
   process-tap clock problem completely. (The actual process-tap clock-anchor fix is
   deferred to PR3 — a separate, feature-flagged spike, for apps like rekordbox that
   have no virtual device. Do NOT do PR3 here.)

## PR1 is already done (context you're building on)

The safety fix already landed in the working tree — read these to understand the new
primitives you'll reuse:

- `Sources/DJMemoryCore/AudioInputDeviceCatalog.swift` now has:
  - `AudioDeviceTransport` enum (from `kAudioDevicePropertyTransportType`) — note the
    `.virtual` case, which PR2 needs.
  - `AudioInputDeviceSafety` enum: `.trustedAutoSelectable` / `.manualOnly` /
    `.blocked`.
  - `AudioInputDevice.transportType`, `.safety`, `.isBlockedInput`,
    `.isTrustedAutoSelectable`.
  - `safety(for:)` — currently blocks built-in/Bluetooth/Continuity mics, trusts
    Pioneer hardware, everything else `.manualOnly`. **There's an explicit comment
    marking where PR2's virtual-device branch goes:** "PR2 adds: a verified
    DJ-software virtual device (transport == .virtual, name match) for the currently
    detected DJ app is also `.trustedAutoSelectable`."
  - `preferredDefault(from:)` returns trusted-only or nil (no `devices.first`
    fallback).
- `AppModel.refreshAudioInputs()` / `armInputCaptureWatching()` / `startCapture()`
  now guard against blocked devices.

PR1 tests: `Tests/DJMemoryCoreTests/AudioInputDeviceCatalogTests.swift` (14 tests,
all green). Full suite currently **191 pass / 3 skipped (hardware) / 0 fail**.

## What to build in PR2 (Serato only — do not add other apps)

### User decision already made (do not re-litigate)
**Prefer the virtual device over Process Audio Tap** when an app has one. From the
user's POV "App Audio Capture" still just works; under the hood it uses the virtual
device via `CaptureService`. Process Audio Tap stays the path for apps without a
recognized virtual device.

### 1. `DJSoftware` gains virtual-device hints
`Sources/DJMemoryCore/DJSoftware.swift` (struct at line ~30, `SupportedDJSoftware.all`
at line ~62). Add `virtualAudioDeviceNameHints: [String]`. **Serato only:**
`["Serato Virtual Audio"]`. Every other app gets `[]`.
**Do NOT add rekordbox/Traktor/VirtualDJ/djay hints** — none are verified (rekordbox
uses real Pioneer hardware; NI ships hardware drivers not a confirmed loopback;
VirtualDJ/djay unknown). Each future app needs a manual `system_profiler
SPAudioDataType` check (device name, manufacturer, transport, input channels, whether
it exists only while the app runs, whether it carries the master mix, sample
rate/layout, any required in-app setting) before a hint is added.

### 2. Virtual-device matching REQUIRES `.virtual` transport (not just name)
Add to `AudioInputDeviceCatalog`:
`matchesDJSoftwareVirtualAudioDevice(_ device: AudioInputDevice, for software: DJSoftware) -> Bool`
requiring **all** of:
- input-capable (already guaranteed by `listInputs()`),
- `device.transportType == .virtual`,
- name and/or manufacturer matches one of `software.virtualAudioDeviceNameHints`,
- prefer exact name contains `"Serato Virtual Audio"`.
`"Serato"` alone must NOT match (a Serato-branded controller/hardware device must not
be treated as the virtual backend).

### 3. App-context-aware trust (resolves the "virtual device always enumerated" trap)
Serato Virtual Audio stays in the device list even when Serato is closed. So a
matching virtual device is only `.trustedAutoSelectable` when **its** software is
currently detected/running (or is the explicitly selected target app). Otherwise it
is NOT auto-selected. This preserves PR1's "no app + no deck ⇒ nil" guarantee.

Implication: `safety(for:)` and/or `preferredDefault` need a DJ-app-context param
(e.g. `currentSoftwareID: String?` or the set of running software IDs). Thread it
through from `AppModel` (which already knows detected apps via `probeResults` /
`captureState.targetApps`). PR1 deliberately left `safety(for:)` context-free with a
comment marking this seam.

Auto-selection precedence:
| Situation | Auto-selection |
|---|---|
| Pioneer/DJM/XDJ/CDJ hardware present | hardware |
| Serato running + Serato Virtual Audio present | Serato Virtual Audio |
| Serato Virtual Audio installed but Serato NOT running | nothing |
| Built-in mic only | nothing (blocked) |
| Unknown USB interface only | nothing (manualOnly — user may pick manually) |

### 4. Model it as a first-class App Audio backend — NOT a mutation of the input route
This is the critical architectural seam. Do **not** let App Audio Capture overwrite
the user's normal `selectedDeviceID` / Input Device Capture state.

`Sources/DJMemoryCore/AppAudioCaptureService.swift` already has
`AppAudioCaptureBackendKind` (`.processAudioTap` / `.screenCaptureKit`) and
`AppAudioCaptureBackendSelector.preferredBackend(...)`. Add a third, highest-priority
tier. Suggested:
```swift
enum AppAudioCaptureBackend {
    case virtualInputDevice(deviceID: AudioDeviceID, softwareID: String)
    case processAudioTap
    case screenCaptureKit
}
```
Precedence: `virtualInputDevice` > `processAudioTap` > `screenCaptureKit`.
The `virtualInputDevice` backend should internally reuse `CaptureService`'s existing
AVAudioEngine input-device capture machinery, but remain **semantically App Audio** so:
- `.both` dual-route posture never confuses it with the user-selected input route,
- the singleton `CaptureService` isn't driven twice (App Audio + Input Device at once).

Put the seam at "app-audio backend selection," not at "mutate global selected input
device." `AppAudioCaptureService` conforms to a backend protocol
(`AppAudioCaptureBackend` protocol already exists with `listShareableDJApps`,
`startMonitoring`, `stopMonitoring`, `beginRecordingFile`, `endRecordingFile`,
`currentInputLevel`) — the cleanest path is a new backend type that satisfies that
same protocol by wrapping a `CaptureService` bound to the virtual device.

### 5. Surface the real source everywhere (transparent to workflow, explicit in data)
- Status/UI: `App Audio Capture: Serato Virtual Audio`.
- Logs: chosen backend + device UID/name/transport.
- Archive/session metadata: route (`appAudio`) + backend
  (`virtualInputDevice`/`processAudioTap`/`screenCaptureKit`) + device info. Metadata
  types are in `Sources/DJMemoryCore/` (ArchiveService / ArchiveMetadata — grep for
  `sourceAppID`, `originalFilename`). Add backend + device fields so no future
  recording is an unattributable mystery (this whole debugging saga happened partly
  because captures didn't record which backend produced them).

## Tests to add
- `AudioInputDeviceCatalogTests`:
  - Serato virtual present + Serato running ⇒ eligible/trusted
  - Serato virtual present + no detected app ⇒ NOT auto-selected
  - Serato-branded **non-virtual** device ⇒ not matched as virtual backend
  - Pioneer + Serato virtual ⇒ Pioneer still wins as input default
- `AppAudioCaptureBackendSelectorTests` (file already exists):
  - Serato running + Serato virtual present ⇒ `.virtualInputDevice`
  - Serato running + no virtual ⇒ `.processAudioTap`
  - rekordbox running + Serato virtual present ⇒ do NOT pick Serato virtual
  - no app detected + virtual devices present ⇒ no virtual app-audio backend
  - virtual backend bind failure ⇒ defined behavior (fail clearly or fall back) —
    test whichever you choose
- Recording-metadata tests: App Audio via Serato Virtual Audio records
  route=appAudio, backend=virtualInputDevice, device name/UID/transport.

## Verify
```bash
cd /Users/robcmartin/Documents/Claude/Projects/SetCatcher
swift build
swift test            # keep 191+ green; add the PR2 tests above
.build/debug/DJMemoryApp   # bare binary; prints to the launching Terminal
```
**Critical manual check (needs the user / real ears — you cannot verify audio
quality yourself):** with Serato open and playing, arm App Audio Capture, record a
short take, Stop & Save (do NOT just kill the process — that skips WAV finalization),
then have the user LISTEN. It should sound clean (the whole point). Also re-run the
objective checks from this session for a paper trail:
```bash
FILE="/Users/robcmartin/Music/DJMemory/archive/<newest>.wav"
afinfo "$FILE"
ffmpeg -i "$FILE" -af astats=metadata=1 -f null - 2>&1 | grep -A20 Overall
ffmpeg -y -i "$FILE" -lavfi showspectrumpic=s=1920x1080:legend=1 -frames:v 1 /tmp/spec.png
```
Also confirm PR1 still holds: no DJ app + no deck ⇒ input picker shows no built-in
mic and Start is blocked.

## Working tree / git notes
- Branch `perf/dsp-vdsp-vectorization`. The DSP-vectorization work is committed as
  `c10db40`; **everything else is uncommitted**, including PR1 (this session), a big
  "Bold Directions" UI redesign, the menu-bar CPU fix, the 16-bit format change, and
  the alternate-source-detection feature. Treat the working tree as a mix of several
  in-flight efforts.
- **Do not** `git checkout`/`reset`/`stash drop` without checking with the user —
  there are 6 older stashes on this branch too.
- The 16-bit change (`CaptureAudioFormat.bitDepth = 16`, was 24) is intentional and
  should stay — 24-bit int WAV writing was a suspected trouble spot; 16-bit is the
  well-exercised path. It was NOT the root cause of the corruption (PR2's clock issue
  is), but leave it as-is.
- Related handoffs in `docs/`: `handoff-cursor-2026-08-16.md` (menu-bar CPU fix +
  redesign review), `handoff-dsp-optimization-2026-08-16.md` (the vDSP work).

## Hard constraints (unchanged)
Archive/capture/scan correctness must never regress — source files are never moved,
renamed, or deleted; folder protection keeps working. PR2 only adds an App Audio
backend and device-selection intelligence; it must not touch the archive/scan write
paths.
