# Handoff for Cursor — PR3: Process Audio Tap clock-anchor spike

Date: 2026-08-17. Repo: `/Users/robcmartin/Documents/Claude/Projects/SetCatcher`
(DJMemory macOS app, Swift package). Branch: `perf/dsp-vdsp-vectorization`.

This is the **third and last** PR in the "fix corrupted App Audio captures + never
record from the system mic" arc. Read the two prior handoffs in `docs/` first for
context:
- `handoff-cursor-pr2-serato-virtual-audio-2026-08-17.md` (PR2 — DONE)
- `handoff-cursor-2026-08-16.md`, `handoff-dsp-optimization-2026-08-16.md` (unrelated
  earlier work on the same dirty branch)

## ⚠️ Do PR3 ONLY IF this precondition is met

PR3 is a **spike**, not a sure thing, and it is only worth doing for a specific case.
**Before starting, confirm with the user:**

1. **PR2's Serato Virtual Audio path has been listened to and still needs work OR
   there's a confirmed need to capture an app that has NO virtual device** (rekordbox,
   Traktor, VirtualDJ, djay — none have a verified virtual loopback device today).
   - If the PR2 Serato listen came back **clean**, then Serato — DJMemory's primary
     tested app — is already fixed the better way, and PR3 only matters for those
     other apps. Confirm the user actually captures from one of them before investing.
   - If PR2's Serato take **still sounded bad**, that's important signal that the
     process-tap clock hypothesis may be wrong (or incomplete) — flag it to the user
     before building PR3, because PR3 is built on that exact hypothesis.

Do not start PR3 speculatively. It touches Core Audio aggregate-device construction —
higher blast radius than PR1/PR2 — and it is explicitly gated behind a feature flag
so it can't regress the default path.

## The hypothesis PR3 tests

App Audio corruption (distortion + warble + stutter + muffled) began exactly at commit
`d5e65bc "Add process audio tap capture backend"`. The format math is provably clean
(48kHz Float32, ratio 1.0, no clipping, valid WAV — verified via afinfo/astats/
spectrogram). The leading remaining explanation is **clock drift on a tap-only
aggregate device**: the aggregate is built from the tap alone, with no real hardware
device to anchor its sample clock. Core Audio aggregate devices are known to
glitch/warble when there is no clock master.

Current code —
`Sources/DJMemoryCore/AppAudioCaptureService.swift`, `createAggregateDevice(tapUID:displayName:)`
(around line 624):
```swift
let tapList: [[String: Any]] = [[
    kAudioSubTapUIDKey: tapUID,
    kAudioSubTapDriftCompensationKey: true
]]
let description: [String: Any] = [
    kAudioAggregateDeviceNameKey: "DJMemory \(displayName) Tap",
    kAudioAggregateDeviceUIDKey: uid,
    kAudioAggregateDeviceIsPrivateKey: true,
    kAudioAggregateDeviceTapAutoStartKey: true,
    kAudioAggregateDeviceTapListKey: tapList
]
```
No `kAudioAggregateDeviceSubDeviceListKey`, no `kAudioAggregateDeviceMainSubDeviceKey`
— i.e. no real sub-device, so `kAudioSubTapDriftCompensationKey: true` has nothing
stable to compensate against.

## The change

Add the **system default output device** into the aggregate as a real sub-device that
acts as the clock master, alongside the tap:

1. Read the current default output device UID:
   `kAudioHardwarePropertyDefaultOutputDevice` on the system object →
   `AudioDeviceID` → its `kAudioDevicePropertyDeviceUID`. (There's already a
   `cfStringProperty(_:_:)` helper pattern in `AudioInputDeviceCatalog.swift` you can
   mirror; the transport/UID reading idioms are all there.)
2. Add to the aggregate description:
   - `kAudioAggregateDeviceSubDeviceListKey`: `[[kAudioSubDeviceUIDKey: <outputUID>]]`
   - `kAudioAggregateDeviceMainSubDeviceKey`: `<outputUID>` (makes it the clock master)
   - keep the existing `kAudioAggregateDeviceTapListKey` with the tap.
   - keep `kAudioSubTapDriftCompensationKey: true` (now it has a real master to track).
3. Keep `kAudioAggregateDeviceIsPrivateKey: true` so it doesn't show up as a
   user-facing device.

The IOProc reads from the aggregate exactly as today; only the aggregate's clock
topology changes.

## Feature-flag it (required — do not make it the default on first landing)

There is an existing env-var flag convention in this file:
`AppAudioCaptureBackendSelector` reads
`ProcessInfo.processInfo.environment["DJMEMORY_FORCE_SCK_APP_AUDIO"] == "1"`. Follow
the same pattern:

- Gate the new clock-anchored aggregate behind e.g.
  `DJMEMORY_TAP_CLOCK_ANCHOR == "1"`. Default OFF → current tap-only behavior unchanged.
- This lets the user A/B two builds recording the same source and compare, without
  risking the default path.

Once the user confirms the anchored version sounds clean AND the risks below are
verified clear, a follow-up can flip the default.

## Risks to verify before flipping the default (the reason this is a spike)

Adding a real output sub-device to the aggregate can change capture behavior. Check
each, on a recorded take, before recommending default-on:

1. **Channel layout / count** — does the captured buffer still arrive as 2ch, or does
   the output device's channel count (e.g. a multi-out interface) leak in? Log the
   `AudioStreamBasicDescription` the IOProc receives before/after.
2. **Sample rate** — aggregate may adopt the output device's rate; confirm it's still
   48kHz or that the existing converter path handles it.
3. **Format** — confirm still Float32 to the IOProc (the `handleAudioBufferList` code
   assumes float and bails otherwise).
4. **MOST IMPORTANT — capture isolation.** The tap is a *process* tap (only the target
   app's audio). Adding an output sub-device must NOT cause the capture to include
   other apps' audio routed to that output. Verify: play audio from a second app while
   capturing the target app, and confirm the second app is NOT in the recording.
   (This is the one that could turn a fidelity fix into a privacy/correctness bug.)
5. **Default-output changes mid-session** — if the user switches output device
   (plugs in headphones) while armed, does the aggregate break or keep going? At
   minimum, don't crash; ideally document the behavior.

## Verify

```bash
cd /Users/robcmartin/Documents/Claude/Projects/SetCatcher
swift build
swift test        # keep the current 204 pass / 3 skipped / 0 fail green
```

Manual A/B (needs the user's ears — you cannot judge audio quality):
1. Pick an app WITHOUT a virtual device (rekordbox is the realistic case).
2. Record a take with `DJMEMORY_TAP_CLOCK_ANCHOR` unset (current behavior) → listen.
3. Record the same source with `DJMEMORY_TAP_CLOCK_ANCHOR=1` → listen.
4. Compare. Run the objective paper-trail on both newest WAVs:
   ```bash
   afinfo "<file>.wav"
   ffmpeg -i "<file>.wav" -af astats=metadata=1 -f null - 2>&1 | grep -A20 Overall
   ffmpeg -y -i "<file>.wav" -lavfi showspectrumpic=s=1920x1080:legend=1 -frames:v 1 /tmp/spec.png
   ```
5. Run risk check #4 (capture isolation) explicitly.

## Testing notes

Most of PR3 is Core Audio device topology that can't be unit-tested without hardware
(like the existing `testLive*` tests, which are gated by env vars and skipped in CI).
What you CAN unit-test:
- The default-output-UID reader (returns a non-empty UID on a machine with an output
  device; returns nil/empty gracefully when absent — mirror the nil-handling style of
  `AudioInputDeviceCatalog.audioDeviceID(forUID:)`).
- The aggregate-description builder as a pure function returning the `[String: Any]`
  dictionary, asserting it contains the sub-device list + main-sub-device keys when the
  flag is on, and does NOT when off. Extract the dictionary construction so it's
  testable without actually calling `AudioHardwareCreateAggregateDevice`.

## Working tree / git (unchanged from PR2 handoff)

Branch `perf/dsp-vdsp-vectorization`. DSP work is committed as `c10db40`; everything
else (PR1, PR2, the UI redesign, menu-bar fix, 16-bit change, alternate-source
feature) is uncommitted. Do NOT `git checkout`/`reset`/`stash drop` without asking —
6 older stashes live on this branch. The 16-bit `CaptureAudioFormat` change is
intentional; leave it.

## Hard constraints (unchanged)

Archive/capture/scan correctness must never regress — source files are never moved,
renamed, or deleted; folder protection keeps working. And for PR3 specifically: the
process tap must keep capturing ONLY the target app's audio (risk #4). If clock-
anchoring can't be made to preserve that isolation, PR3 should be abandoned in favor
of leaving Process Audio Tap as-is and steering users toward virtual-device apps —
document that outcome rather than shipping a leaky capture.
