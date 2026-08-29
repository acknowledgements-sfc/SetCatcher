# Live capture evidence — 2026-08-29

**Not CI / not automated merge proof.** Operator/hardware-dependent.

| Field | Value |
|-------|-------|
| Date (UTC) | 2026-08-29T13:14:48Z (initial); re-probe 13:47:54Z; **re-probe 2026-08-29T13:58:15Z** |
| macOS | 26.6.2 (25G83) |
| Checkout | `main` @ `89eef91` (+ local App a11y edits) |
| Machine role | Agent Mac; no Serato session / no Pioneer USB feed asserted |

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

- Exit: **0** (skip path when hardware absent and `DJMEMORY_REQUIRE_LIVE_HARDWARE` unset) — initial and re-probes
- Live Pioneer test: `XCTUnwrap failed … No Pioneer-like Core Audio input is present`
- Message: `Live hardware route check skipped: no Pioneer/XDJ/DJM-like Core Audio input is connected.`
- **Stop reason:** no hardware USB master/REC feed; permissions not the blocker once device absent
- Re-probe stdout: `/tmp/djmemory-live-hw-reprobe-out.txt`, `/tmp/djmemory-live-hw-reprobe3.txt`

### `scripts/live-app-audio-check.sh`

- Not fully executed this pass (same preconditions as invisible-capture: open DJ app + play audio)

## Output paths

- Script stdout: `/tmp/djmemory-live-invisible-out.txt`, `/tmp/djmemory-live-hw-out.txt`
- JSONL (if created): `/tmp/djmemory-invisible-capture-results.jsonl` (may be absent after early fail)
- No audio artifacts committed

## Next action for a human with gear

1. Open Serato (or other matrix app), play through Mac system output, grant Screen & System Audio Recording if prompted.  
2. Rerun `bash scripts/live-invisible-capture-check.sh`.  
3. With XDJ/DJM USB feed connected and mic permission granted: `bash scripts/live-hardware-route-check.sh`.  
4. Append PASS lines + durations + archive paths (metadata only) to this file.
