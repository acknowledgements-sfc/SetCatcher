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

- No new `PIONEER/REC` WAV was available on a Mac-mounted volume during this pass.
- Cursor takeover: `/Volumes/RED-YOSHI/PIONEER` contains only `MYSETTING*.DAT` / `DJMMYSETTING.DAT` — **no REC WAV**.
- The agent cannot operate the deck's MASTER REC control or perform the required human listening step.
- Result: **needs human action**. Record a known USB1 track to a second device in USB2, copy the resulting WAV to the Mac, switch Mac output to Studio Display Speakers, and provide the WAV for sample analysis and listening.

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

## Next action for a human with gear

1. On the XDJ-XZ, make the USB2 MASTER REC control file and copy its `PIONEER/REC` WAV to this Mac. Play it through Studio Display Speakers and provide the file for analysis.
2. Open XDJ-XZ Setting Utility if needed; start the same recognizable track and keep it playing while rerunning `bash scripts/map-xdj-input-channels.sh`.
3. If the channel map finds a pair (hypothesized or adjacent active), play its generated stereo extraction through Studio Display Speakers and record the listening result.
4. Open Serato DJ Pro, play a track, and run the Serato Process Audio Tap and forced ScreenCaptureKit scenarios. Then repeat Process Audio Tap with rekordbox.
5. Promote only a lane that has a nonzero archived signal, valid WAV, archive/Library reconciliation, and human listening confirmation.
