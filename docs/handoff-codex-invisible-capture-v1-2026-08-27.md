# Handoff for Codex — Invisible Capture v1 re-review

**Date:** 2026-08-27
**Repo:** `/Users/robcmartin/Documents/Claude/Projects/SetCatcher` (DJMemory)
**Branch:** `cursor/invisible-capture-v1`
**Reviewed code anchor:** `419e5c8` (Codex blocker corrections: probe WAV peak, interrupt salvage removal, permission injection, onboarding step rail)
**Bookmark fix:** `5267a09`
**Prior corrections:** `8600975` on blocker fixes ending at `9300629`

Read `AGENTS.md` first. Research context: `docs/research-invisible-capture-2026-08-26.md`.
**HAL driver (Plan 2):** paused — do not start.

Not pushed to `origin` unless the owner asks.

---

## Current status — 2026-08-27

Invisible Capture v1 on `cursor/invisible-capture-v1` through:

1. Plan 1 implementation + Codex blocker fixes (`9300629`)
2. Correction pass (`8600975`) — interrupted capture delivery, probe evidence, onboarding tokens
3. Bookmark bench fix (`5267a09`) — shared `ArchiveRootResolver`
4. **Codex re-review corrections (`419e5c8`)** — archived-WAV probe PASS, no post-teardown salvage, E2E interrupt metadata, injectable mic permission, UNKNOWN scenario cannot PASS, compact onboarding step rail

Automated gate on `419e5c8`: **274 tests, 3 skipped, 0 failures**; `swift build` clean; `bash scripts/build-app.sh`; `codesign --verify --deep --strict .build/DJMemory.app`; `bash scripts/smoke-app.sh` passed.

---

## What landed (by theme)

| Theme | Key commits | Notes |
|-------|-------------|-------|
| Routing | `1a44258`, `eea6349`, `5f15bea`, `f8d51a9` | Hardware vs app-audio meters; Process Tap → SCK → vendor |
| Interrupted capture | `9923886`, `8600975`, `419e5c8` | Backend-finalized `CaptureResult` only; post-teardown `endRecordingFile` salvage **removed**; SCK finalize failure is explicit |
| Probe / PASS gate | `420be8e`, `9300629`, `419e5c8` | PASS requires **chunked archived WAV peak**, library reconcile, and **explicit** `DJMEMORY_OUTPUT_MODE_LABEL` (UNKNOWN cannot PASS) |
| UI / tokens | `3547723`, `8600975`, `419e5c8` | Compact step rail replaces waveform; light/dark previews for all six onboarding states |
| Packaging | `1e193a5`, `92b3143` | macOS **14.2** minimum |
| Bookmark bench fix | `5267a09` | `ArchiveRootResolver` for CLI/`swift test` |

---

## Automated verification (`419e5c8`)

```text
git diff --check 9300629...HEAD  → clean after this handoff commit
swift test                       → 274 tests, 3 skipped, 0 failures
swift build                      → complete
build-app.sh                     → .build/DJMemory.app signed
codesign --verify --deep --strict .build/DJMemory.app → ok
smoke-app.sh                     → window check + smoke check passed
```

---

## Live verification (honest scope)

- [x] **Five-app laptop-output app-audio:** Serato / rekordbox / Traktor / VirtualDJ / djay — Process Tap + forced SCK reported PASS (prior Cursor bench, 2026-08-27)
- [x] **XDJ app-audio:** Serato + rekordbox only (Process Tap + SCK PASS). Traktor / VirtualDJ / djay were **not** re-benched on XDJ in that session
- [ ] **Hardware USB master capture:** unresolved — XDJ-XZ detected; prior `LIVE_METER_PEAK ~0.0002` (silence). Bookmark ingest path fixed in `5267a09`; signal/routing still open
- [ ] **Listening / WAV quality:** unresolved — Serato + XDJ-as-Mac-output takes deferred (owner reported poor quality / peak 1.0 clipping suspicion)

Do not conflate bookmark ingest failures with USB master silence. Do not claim five-app coverage on XDJ.

---

## Codex re-review checklist

- [ ] SCK interrupt delivers finalized partial `CaptureResult` via `onInterruptedCapture` before teardown; AppModel never calls `endRecordingFile` after backend teardown
- [ ] Probe PASS uses archived WAV sample peak (chunked reads); silent structurally valid WAV fails; UNKNOWN scenario cannot PASS
- [ ] Interrupt E2E: backend-finalized `CaptureResult` → ingest → sidecar `captureInterrupted` + `captureInterruptionReason`
- [ ] Permission lifecycle uses injectable microphone closure; vendor stays explicit opt-in; Apple-first order preserved
- [ ] Onboarding: compact step rail (no waveform); light/dark previews for all six states
- [ ] Bookmark resolver still intact; `SecurityScopedAccess` still throws when callers pass bad bookmarks
- [ ] 274 unit tests green; smoke-app green; `git diff --check 9300629...HEAD` clean

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
git merge-base --is-ancestor 419e5c8 HEAD && echo "reviewed code anchor present"

git diff --check 9300629...HEAD
swift test
bash scripts/build-app.sh
codesign --verify --deep --strict .build/DJMemory.app
bash scripts/smoke-app.sh

# Owner live benches only if Rob prepares hardware/audio:
# bash scripts/live-invisible-capture-check.sh
# bash scripts/live-hardware-route-check.sh
```

Related Antigravity task brief (already executed earlier):
`docs/handoff-antigravity-bookmark-fix-merge-2026-08-27.md`

---

## Binding product rules (do not regress)

- Interrupted partial = successfully archived session with `captureInterrupted` metadata — **not** a new session status
- Local-first; audio / full tracklists never uploaded by default
- Source recordings never moved/renamed/deleted — copy only
- Honest support labels; no dead-end failure states
