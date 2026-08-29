# Handoff — DSP vectorization exploration (2026-08-16)

For: an agent exploring/implementing this specific optimization. **Report back to Rob
directly when done or when you hit a decision point** — this doc is scoped to one
task, not the whole app. For broader context on today's other fixes (menu bar
CPU/RSS runaway, alternate-source detection, adaptive polling), see
`docs/handoff-cursor-2026-08-16.md` in this same `docs/` folder — skim it, don't
re-derive it.

## The task

Investigate and, if it checks out, implement vectorizing the hand-written scalar
deinterleave + RMS-level loops in DJMemory's live audio capture path using
Accelerate/vDSP. This is **not a rubber-stamped "just do it"** — Rob asked for
exploration and a report back, specifically because this code produces the actual
recorded audio content, and there's no existing test coverage for it. Use your own
judgment on whether the payoff justifies the risk, and say so plainly in your report.

## Why this, why now

Today's session profiled DJMemory live with macOS `sample` while an App Audio
Process Tap was actively armed and watching a running Serato DJ Pro session (this is
the app's normal/intended behavior — a DJ app is open, so DJMemory keeps a live tap
open on it, continuously converting and RMS-metering every audio buffer in
real time). Sustained CPU was ~85%, held steady (confirmed via an 8-minute
monitoring run — RSS plateaued at ~239MB the whole time, so this isn't a leak, it's
real ongoing work). The hot threads in the profile were CoreAudio's own sample-handler
queues, not SwiftUI or the app's poll loops (those were already ruled out/fixed
earlier today). The remaining lever is the per-buffer DSP work itself.

## Exactly where the scalar loops live (three near-duplicates)

1. **`Sources/DJMemoryCore/AppAudioCaptureService.swift:503-577`** —
   `ProcessAudioTapCaptureService.handleAudioBufferList(_:)`. Two branches:
   - Interleaved path (`AppAudioCaptureService.swift:530-540`): nested `for frame in
     0..<frameLength { for channel in 0..<channelCount { ... } }`, deinterleaves into
     `floatChannels[channel][frame]` AND accumulates `sumSquares`/`sampleCount` in
     the same loop.
   - Non-interleaved path (`AppAudioCaptureService.swift:542-553`): same idea, per
     channel.
   - RMS finalized at `AppAudioCaptureService.swift:555-556`:
     `sqrt(sumSquares / Float(sampleCount)) * 4`, clamped to `[0, 1]`.

2. **`Sources/DJMemoryCore/AppAudioCaptureService.swift:883-1020`** —
   `ScreenCaptureKitAppAudioCaptureService.handleAudioSampleBuffer(_:)` (the
   ScreenCaptureKit fallback backend). RMS loop at
   `AppAudioCaptureService.swift:922-937` (float-only, single accumulation loop over
   `ablPointer`). Deinterleave loop separately at
   `AppAudioCaptureService.swift:983-997`.

3. **`Sources/DJMemoryCore/CaptureService.swift:95-105`** — the input-device
   (`AVAudioEngine` tap) path's level meter: `for i in 0..<frameLength { let s =
   channelData[i]; sum += s * s }`. Single-channel already (tap installed on bus 0),
   simpler than the above two, but same pattern.

This session's earlier work already made `CaptureService.engine` lazy
(`CaptureService.swift:37`) and fixed unrelated poll-loop/menu-bar issues — none of
that touches these three loops. They're untouched, original code.

## What "vectorize with vDSP" means concretely

- **RMS**: replace the manual `sumSquares += sample * sample` accumulation with
  `vDSP_measqv` (mean of squares directly) or `vDSP_svesq` (sum of squares, then
  divide by count yourself) from `Accelerate`. One call replaces the whole
  accumulation loop.
- **Deinterleave**: for interleaved→planar, `cblas_scopy(count, srcPtr + channel,
  sourceStride, dstPtr, 1)` per channel (stride-based copy, SIMD internally) replaces
  the inner per-sample copy loop. Non-interleaved→planar is already closer to a
  straight `memcpy` per channel; may not need vDSP at all, just confirm it's already
  using `memcpy`/`copyMemory` rather than a manual loop (line 992-997 currently *is*
  a manual loop — check if it can just become `memcpy`).

## Required before wiring anything into the live paths

Write a **synthetic-buffer equivalence test** — no live hardware needed. Pick one
canonical helper (recommend extracting the deinterleave+RMS logic out of all three
call sites into one shared, testable function in `DJMemoryCore`, since it's
duplicated three times with minor variations — that's a legitimate simplification
independent of the vDSP question). Then:

1. Generate a synthetic interleaved `Float` buffer (e.g. deterministic sine tones or
   seeded random values — see `Waveform.seededAmplitudes` in
   `Sources/DJMemoryApp/Theme/Waveform.swift` for the existing FNV-1a/xorshift seeding
   pattern already used elsewhere in this codebase, reusable for deterministic test
   fixtures).
2. Run it through the **current** scalar implementation, capture the deinterleaved
   output + RMS value.
3. Run it through the **new** vDSP implementation on the identical input.
4. Assert the two outputs match within float precision (`1e-6` or so — vDSP may
   differ in summation order from the naive loop, so expect *tiny* floating-point
   differences, not bit-exact equality).
5. Only wire the new implementation into the three live call sites once that test is
   green.

Put this in `Tests/DJMemoryCoreTests/` following the existing naming/structure (see
`Tests/DJMemoryCoreTests/CaptureServiceTests.swift` for conventions — note its tests
are prefixed `testLive*` where they need real hardware/permissions; this new test
should NOT need that prefix since it's pure math on synthetic data, no hardware).

## What you cannot verify yourself, and should say so in your report

There is no way to verify from this environment that the *audio content* DJMemory
records is unaffected — that requires an actual DJ app playing real audio through a
real (or virtual) audio path, which needs a human. Say clearly in your report
whether you got as far as the synthetic equivalence test (and what it showed), and
that real-audio verification is still Rob's to do before he trusts this in a real
session — don't imply more confidence than the synthetic test actually gives you.

## Hard constraints (carried over from the original task, still apply)

Archive/capture/scan correctness must never regress — source files must never be
moved, renamed, or deleted, and folder protection must keep working. This task is
scoped to CPU efficiency of the *metering/deinterleave* math specifically, not the
write-to-disk path (`CapturePCMWriter`, `AVAudioFile` writes) — leave those alone
unless you find a *specific, tested* reason to touch them.

## Build / verify

```bash
cd /Users/robcmartin/Documents/Claude/Projects/SetCatcher
swift test --filter DJMemoryCoreTests   # your new synthetic test + existing suite
swift build
.build/debug/DJMemoryApp                # smoke test — launches, no crash
```

Profiling method used today, if you want to re-confirm the CPU improvement while a
real tap is active (needs a real DJ app open, e.g. Serato):
```bash
sample <PID> 5 -file /tmp/out.txt
grep -E "^\s+[0-9]+ Thread_" /tmp/out.txt | sort -t' ' -k2 -rn | head -15
```
Compare against today's baseline: ~85% sustained CPU, dominant threads were
CoreAudio sample-handler queues (`caulk.messenger.shared`, `app.djmemory.ProcessAudioTap.sample`,
`com.apple.audio.toolbox.AUScheduledParameterRefresher`).
