# Handoff for Codex — Invisible Capture v1 re-review

**Date:** 2026-08-27  
**Repo:** `/Users/robcmartin/Documents/Claude/Projects/SetCatcher` (DJMemory)  
**Branch:** `cursor/invisible-capture-v1`  
**HEAD:** `5267a09`  
**Bookmark fix commit:** `5267a09`  
**Corrections base:** `8600975` (on top of blocker fixes ending at `9300629`)

Read `AGENTS.md` first. Research context: `docs/research-invisible-capture-2026-08-26.md`.  
**HAL driver (Plan 2):** paused — do not start.

Not pushed to `origin` unless the owner asks.

---

## Current status — 2026-08-27

Invisible Capture v1 is merged onto `cursor/invisible-capture-v1` through:

1. Plan 1 implementation + Codex blocker fixes (`9300629`)
2. Correction pass (`8600975`) — interrupted capture delivery, probe evidence, onboarding tokens
3. Bookmark bench fix (`5267a09`) — shared `ArchiveRootResolver` so CLI/`swift test` omit unresolvable GUI bookmarks

Automated gate on merged HEAD: **265 tests, 3 skipped, 0 failures**; `swift build` clean; `bash scripts/build-app.sh` + `bash scripts/smoke-app.sh` passed.

---

## What landed (by theme)

| Theme | Key commits | Files |
|-------|-------------|-------|
| Routing | `1a44258`, `eea6349`, `5f15bea`, `f8d51a9` | `LiveCaptureRouteResolver`, `LiveCaptureRouteFactsBuilder`, hardware vs app-audio meters |
| Interrupted capture | `9923886`, `7f66991`, `8600975` | `AppAudioCaptureService` `onInterruptedCapture`; SCK partial finalize; `captureInterrupted` metadata |
| Probe / PASS gate | `420be8e`, `9300629`, `8600975` | `AppAudioProbeRunner`, lifecycle policy tests, recording-during-meter window |
| UI / tokens | `3547723`, `8600975` | `OnboardingTopBar`, `OnboardingAppChip`; hero rollback |
| Packaging | `1e193a5`, `92b3143` | macOS **14.2** minimum; package-beta assert |
| Bookmark bench fix | `5267a09` | `ArchiveRootResolver`, CLI + live `CaptureServiceTests`, Antigravity handoff doc |

Research / hygiene: `0eaa2df`, `a8c9fd6`.

---

## Automated verification (2026-08-27, this session)

```text
swift test     → 265 tests, 3 skipped, 0 failures
swift build    → complete
build-app.sh   → .build/DJMemory.app signed
smoke-app.sh   → window check + smoke check passed
```

---

## Live verification (owner/Cursor)

Fill or confirm before treating as accepted:

- [x] **App-audio matrix (laptop + XDJ scenarios):** Serato / rekordbox / Traktor / VirtualDJ / djay — Process Tap + forced SCK reported PASS (prior Cursor bench, 2026-08-27)
- [ ] **Hardware USB feed (`live-hardware-route-check.sh`):** XDJ-XZ detected; prior `LIVE_METER_PEAK ~0.0002` (silence — **signal/routing open**); prior ingest failed with `SecurityScopedAccess.resolveFailed` — **bookmark path fixed in `5267a09`**; re-run to confirm result file writes even if peak stays near zero
- [ ] **Serato + XDJ-as-Mac-output WAV quality:** deferred (owner called archived takes “trash” / peak 1.0 clipping suspicion)

Do not conflate bookmark ingest failures with USB master silence.

---

## Codex re-review checklist

- [ ] SCK interrupt path archives partial WAV **before** teardown (`onInterruptedCapture` / salvage)
- [ ] Probe meters **during** recording window; PASS requires archive + signal evidence
- [ ] No hero UI / raw color regressions in onboarding (token-backed panels only)
- [ ] Bookmark resolver: bench/CLI ingest works without GUI scoped access; `SecurityScopedAccess` still throws on stale/unresolvable bookmarks when callers pass them
- [ ] 265 unit tests green; smoke-app green

---

## Human gates (not Codex)

- Owner listening pass on archived sets
- Developer ID signing / notarization
- XDJ USB master feed routing (why peak ~0)
- Serato + XDJ audio quality investigation
- Push / PR (only when owner asks)

---

## Commands for next session

```bash
cd /Users/robcmartin/Documents/Claude/Projects/SetCatcher
git checkout cursor/invisible-capture-v1
git log -1 --oneline   # expect 5267a09

swift test
bash scripts/build-app.sh && bash scripts/smoke-app.sh

# Owner live benches (optional):
bash scripts/live-invisible-capture-check.sh
bash scripts/live-hardware-route-check.sh
DJMEMORY_ARCHIVE_ROOT=~/Music/DJMemory bash scripts/live-hardware-route-check.sh
```

Related Antigravity task brief (already executed in Cursor):  
`docs/handoff-antigravity-bookmark-fix-merge-2026-08-27.md`

---

## Binding product rules (do not regress)

- Salvaged partial = successfully archived session with `captureInterrupted` metadata — **not** a new session status
- Local-first; audio / full tracklists never uploaded by default
- Source recordings never moved/renamed/deleted — copy only
- Honest support labels; no dead-end failure states
