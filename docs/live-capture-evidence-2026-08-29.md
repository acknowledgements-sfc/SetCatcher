# Live capture evidence — 2026-08-29

**Not CI / not automated merge proof.** Operator/hardware-dependent.

| Field | Value |
|-------|-------|
| Date (UTC) | 2026-08-29T13:14:48Z (initial); re-probes through 13:58:15Z; beta-gate re-probe 19:34:19Z; **XDJ three-path pass 2026-08-29T19:59:47Z** |
| macOS | 26.6.2 (25G83) |
| Checkout | local `main` based on `255a6b0` plus scoped beta-readiness fixes |
| Machine role | Agent Mac; no shareable Serato target. XDJ-XZ became visible during the beta-gate re-probe |

## Scripts run

### `scripts/live-invisible-capture-check.sh`

- Probe window: `DJMEMORY_LIVE_PROBE_SECONDS=5`
- Exit: **1** (initial and both re-probes)
- First scenario: `serato Process Audio Tap`
- Result: `targets: (none) — open a DJ app, or grant Screen & System Audio Recording.`
- Expected `PASS meter+archive serato` **not** met
- **Stop reason:** no DJ app delivering Mac system audio / Screen & System Audio Recording not providing targets (probe shows apps installed; none running as capture targets; only `SeratoVirtualAudio.driver` process)
- Re-probe stdout: `/tmp/djmemory-live-reprobe2.txt`, `/tmp/djmemory-live-reprobe3.txt`

### `scripts/live-hardware-route-check.sh`

- Earlier probes: skip path when no Pioneer/XDJ/DJM-like input was connected.
- Beta-gate re-probe: exit **1** after detecting `XDJ-XZ` (`AlphaTheta Corporation`).
- File result: valid 2-channel, 48 kHz, Int16 interleaved WAVE, approximately 5.99 seconds, with archive sidecar.
- Signal result: `LIVE_METER_PEAK 0.0`; the signal assertion failed. This does not prove whether program audio was routed to the tested USB input.
- Archive artifact: `~/Music/DJMemory/archive/2026-08-29 1234 - DJMemory Capture - Set.wav`; SHA-256 `7422a11888c97f1a6a8afd4c03e9457460c352bd724e7211a74a1a3923460256`.
- **Stop reason:** hardware and file/archive path succeeded, but non-silent signal and human listening were not proven.

The test was hardened during the three-path pass so format-only output can no longer pass. It now requires the live meter and archived samples to reach the shared `0.02` signal threshold, validates the WAV through `CaptureAudioFormat`, and verifies the archive sidecar appears in `SessionLibrary`. The result file is written before signal assertions so a failed bench remains inspectable.

- Hardened re-probe: **failed as intended** at both signal assertions.
- Device: `XDJ-XZ`, AlphaTheta Corporation, UID `USBAudioDevice:AlphaTheta Corporation:XDJ-XZ (2):110000`.
- File/archive/Library: **passed** — 292,491 frames, 48 kHz, stereo, 16-bit; Library reconciliation `true`.
- Live peak: `0.0`; archived peak: `0.0`; required threshold: `0.02`.
- Archive artifact: `~/Music/DJMemory/archive/2026-08-29 1259 - DJMemory Capture - Set.wav`.
- Result metadata: `/tmp/djmemory-live-xz-result-hardened.txt`.

### `scripts/map-xdj-input-channels.sh`

- Added a native eight-channel AVFoundation bench with per-channel peak/RMS analysis and automatic extraction of the first adjacent stereo pair that reaches `-33.98 dB` (linear peak `0.02`).
- Device: `XDJ-XZ`, AVFoundation audio input `0`; input observed as 8 channels at 44.1 kHz.
- Capture window: 15 seconds.
- Channels 1–8: exact digital zero (`peakDB=-inf`, `rmsDB=-inf`) on every channel.
- Result: **no active channels; no stereo extraction**.
- Capture/report: `/tmp/djmemory-xdj-channel-map-20260829T195836Z/`.
- Interpretation: this observation does not establish that standalone USB playback is unavailable because continuous deck playback during this exact capture window was not independently confirmed.

### `scripts/live-app-audio-check.sh`

- The three individual scenarios were re-probed: Serato Process Audio Tap, rekordbox Process Audio Tap, and forced Serato ScreenCaptureKit.
- Screen & System Audio Recording preflight: `true`.
- All three reported `targets: (none)` because neither DJ application was running as a shareable target.
- Result: **pending precondition**, not a capture failure and not a pass.
- Outputs: `/tmp/djmemory-serato-tap-20260829.txt`, `/tmp/djmemory-rekordbox-tap-20260829.txt`, `/tmp/djmemory-serato-sck-20260829.txt`.
- Cursor takeover re-probe (2026-08-29T20:46Z): still exit **1** — Serato Process Audio Tap `targets: (none)`. Output: `/tmp/djmemory-live-app-audio-takeover-20260829.txt`.

## QuickTime recordings supplied by the operator

- `/Users/robcmartin/Desktop/Untitled.m4a`: every decoded sample is zero; peak and RMS are `-inf`.
- `/Users/robcmartin/Desktop/Untitled-v23.m4a`: every decoded sample is zero; peak and RMS are `-inf`.
- These are exact digital silence, not merely quiet recordings. Hearing music while playback output was set to the XDJ-XZ is therefore evidence of the deck's live monitoring/output path, not audio stored in either M4A.

## XDJ-XZ MASTER REC control

- Cursor takeover earlier: `/Volumes/RED-YOSHI/PIONEER` had settings DAT only.
- Operator supplied `/Users/robcmartin/Desktop/REC001.WAV` (2026-08-29).
- Analysis: Pioneer metadata (`artist=PIONEER DJ REC`, `genre=XDJ-XZ`); **73.19 s**; **44.1 kHz** stereo pcm_s16le; peak linear **1.0** (0 dBFS); RMS ≈ **−13.4 dB**; above shared `0.02` threshold.
- Result: **file PASS** (nonzero program audio on disk). **Human listen PASS** (2026-08-29): operator confirmed clean playback on Studio Display Speakers.

## Output paths

- Script stdout: `/tmp/djmemory-live-invisible-out.txt`, `/tmp/djmemory-live-hw-out.txt`
- JSONL (if created): `/tmp/djmemory-invisible-capture-results.jsonl` (may be absent after early fail)
- No audio artifacts committed

## REC OUT matrix (hypotheses)

Unverified channel pairs and the 8ch-vs-9/10 conflict are documented in [`docs/xdj-usb-routing-2026-08-29.md`](xdj-usb-routing-2026-08-29.md). Do not treat Gemini/handover tables as measured truth. Do not add Homebrew SwitchAudioSource or a second Capture view model.

For XDJ-XZ the hypothesized REC OUT pair is **channels 9/10** (0-based 8/9). The 2026-08-29 map saw only **8** channels, so that pair was **out of range**. Re-run `scripts/map-xdj-input-channels.sh` after Setting Utility / confirmed playback; the script now prints hypothesized vs actual and fails clearly when the pair exceeds `channelCount`.

### Cursor takeover pass (2026-08-29T20:45Z)

- `scripts/map-xdj-input-channels.sh` (5s): hypothesized 9/10 **out_of_range**; `actualChannels=8` @ 44.1 kHz; channels 1–8 still digital zero (`peakDB=-inf`). Exit fail as designed. Report: `/tmp/djmemory-xdj-channel-map-20260829T204531Z/`.
- `scripts/live-hardware-route-check.sh`: XDJ-XZ detected; `CaptureService.startMonitoring` now fails with: hypothesized REC OUT pair 9/10 needs 10 channels, device exposes 8. Honest stop (no silent stereo archive).
- Core: `PioneerRecOutChannelMatrix` + `CaptureChannelPairExtractor` wired into `CaptureService`; unit tests green (291 executed / 3 skipped / 0 failures).
- `/Volumes/RED-YOSHI/PIONEER` has setting DAT files only — **no** `REC` WAV for MASTER REC control.
- Operator listening on Studio Display Speakers and Setting Utility / 10-channel USB mode remain human gates.

### Measured signal pass (2026-08-29T21:35–21:39Z)

- XDJ-XZ present again; playback active.
- Map: 8ch @ 44.1 kHz; ffmpeg first adjacent pair **3/4** (ch 3–8 looked hot). Gemini 9/10 still out of range.
- Core Audio channel dump: **ch 5/6 peak ≈ 0.997** (CaptureService authority). ffmpeg channel order ≠ Core Audio.
- Matrix updated to XDJ-XZ **5/6**. `bash scripts/live-hardware-route-check.sh` **PASSED**: livePeak ≈ 0.968, archivedPeak 1.0, 48 kHz/16-bit stereo, Library reconciled.
- Archive: `~/Music/DJMemory/archive/2026-08-29 1439 - DJMemory Capture - Set.wav`
- Desktop listen copies: `XDJ-XZ-channels-3-4.wav`, `XDJ-XZ-coreaudio-channels-5-6.wav`, etc.
- Hardware Input Capture archive listen remains operator-confirmed separately from MASTER REC.
- **rekordbox Process Audio Tap** (controller-usb label): **PASS** meter+archive — livePeak 0.0501, archivedPeak 0.0335, Library reconciled. Archive: `~/Music/DJMemory/2026-08-29 1440 - rekordbox - Set.wav`.
- **Serato Process Audio Tap** (controller-usb, 2026-08-29T21:52Z): **PASS** — livePeak 1.0, archivedPeak 0.6304. Archive: `~/Music/DJMemory/2026-08-29 1452 - Serato DJ Pro - Set.wav`.
- **Serato forced ScreenCaptureKit** (controller-usb): **PASS** — livePeak 1.0, archivedPeak 0.5989. Archive: `~/Music/DJMemory/2026-08-29 1452 - Serato DJ Pro - Set 2.wav`.
- **Traktor:** marked **unavailable for this gear pass**. XDJ-XZ is not on NI Advanced HID list (MIDI/community maps only for Traktor Pro). This Mac has **Traktor DJ 2** only (`com.native-instruments.tmnt`), not Traktor Pro. Best-effort Process Tap found the app but **silent** (peak 0.0) — no program audio to archive. Skip; do not claim Traktor+XDJ supported.
- **VirtualDJ Process Audio Tap** (controller-usb, 2026-08-29T21:58Z): **PASS** — livePeak 0.3208, archivedPeak 0.1247. Archive: `~/Music/DJMemory/2026-08-29 1458 - VirtualDJ - Set.wav`.
- **djay Pro 2 Process Audio Tap** (2026-08-29T22:05Z): **PASS** on **`system-default`** only — operator has no djay Pro license for XDJ hardware; audio was **not** routed through the XDJ. livePeak 0.4410, archivedPeak 0.2516. Archive: `~/Music/DJMemory/2026-08-29 1505 - djay Pro - Set.wav`. Do **not** claim XDJ/controller-usb for djay until a Pro hardware session is re-benched.
- Multi-app Process Tap matrix for this gear pass: rekordbox + Serato (+ SCK) + VirtualDJ + djay(system-default) PASS; Traktor skipped; djay XDJ path pending Pro account.

## Planned multi-app Process Tap matrix (next)

Order after MASTER REC file analysis:

1. **Serato** Process Audio Tap + forced ScreenCaptureKit (`DJMEMORY_OUTPUT_MODE_LABEL=controller-usb` while XDJ is the interface). **DONE PASS**
2. **Traktor** Process Audio Tap — **SKIPPED** this pass (no Traktor Pro; XDJ not native HID; DJ 2 tap silent).
3. **VirtualDJ** Process Audio Tap. **DONE PASS**
4. **djay Pro** Process Audio Tap — **PASS on system-default** (no XDJ; Pro hardware license missing). XDJ re-bench later.

rekordbox Process Tap already **PASS**ed on this Mac (controller-usb). Full `scripts/live-app-audio-check.sh` only covers Serato + rekordbox + Serato SCK — remaining apps will be probed individually via `djmemory app-audio-probe`.

Operator: open one app at a time, play audible audio, say **ready** (name the app if not Serato). Listen archives on Studio Display Speakers.
