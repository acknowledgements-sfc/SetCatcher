# Live capture evidence — 2026-08-29

**Not CI / not automated merge proof.** Operator/hardware-dependent.

| Field | Value |
|-------|-------|
| Date (UTC) | 2026-08-29T13:14:48Z (initial); re-probes through 13:58:15Z; **beta-gate re-probe 2026-08-29T19:34:19Z** |
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

### `scripts/live-app-audio-check.sh`

- Not fully executed this pass (same preconditions as invisible-capture: open DJ app + play audio)

## Output paths

- Script stdout: `/tmp/djmemory-live-invisible-out.txt`, `/tmp/djmemory-live-hw-out.txt`
- JSONL (if created): `/tmp/djmemory-invisible-capture-results.jsonl` (may be absent after early fail)
- No audio artifacts committed

## Next action for a human with gear

1. Open Serato (or other matrix app), play through Mac system output, grant Screen & System Audio Recording if prompted.
2. Rerun `bash scripts/live-invisible-capture-check.sh`.
3. Route known program audio to the XDJ-XZ USB master/REC input, rerun `bash scripts/live-hardware-route-check.sh`, and confirm a non-zero meter.
4. Listen to the resulting WAV, then append PASS lines, duration, and archive path metadata to this file.
