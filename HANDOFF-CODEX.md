# Codex / Claude leave-off — refreshed 2026-08-29

Repo: `/Users/robcmartin/Documents/Claude/Projects/SetCatcher`
Remote: `origin` → `https://github.com/acknowledgements-sfc/DJMemory.git`
Branch: **`main`**, consolidated locally through **`255a6b0`** before the scoped beta-gate fixes.

Read `AGENTS.md` first. This file is the fleet leave-off, not the UI spec
(`HANDOFF.md` / `CURSOR-HANDOFF.md`).

## Current local verification checkpoint (2026-08-29)

Phase 1 is committed at `f7e9bb9`. The technical SetCatcher rename and app-owned DJMemory-to-SetCatcher data migration are committed at `b6a1a5e` on `codex/setcatcher-rename`. Full tests, release build, debug packaging, strict signature verification, and app smoke pass. This branch has not been merged to `main` or pushed. External beta remains blocked by Developer ID signing, notarization, clean-Mac validation, and human UI/listening checks. Historical sections below are retained as dated evidence.

---

## Final beta-readiness gate (2026-08-29)

- Local `main` contains the invisible-capture product line, SwiftUI hardening, and the App accessibility fixes from `e357e15`; it was 35 commits ahead of `origin/main` at gate start.
- Fresh baseline before the scoped gate fixes: 284 tests executed, 3 skipped, 0 failures; CLI smoke, app smoke, release bundle, package checksum, strict code-signature verification, and current-user extracted-zip launch passed.
- Folder Protection and the local Library are suitable for limited internal beta on known Macs. App audio and hardware Capture remain additive and require live operator/hardware evidence.
- External beta remains blocked by Developer ID signing, notarization, and clean-Mac installation evidence.
- Full VoiceOver operation, clean-user permission recovery, live Serato/rekordbox capture, forced ScreenCaptureKit, Pioneer input/listening, and Traktor NML remain human gates.
- Do not push, distribute, rename the product, merge experimental branches, or delete worktrees without separate explicit approval.

See `docs/beta-release-checklist.md`, `docs/mvp-readiness-audit.md`, `docs/push-gate-2026-08-29.md`, and `docs/branch-hygiene-inventory-2026-08-29.md` for the current gate.

---

## Historical fleet leave-off (2026-08-12)

## Invisible capture v1 (2026-08-27)

Active branch: **`cursor/invisible-capture-v1`** (reviewed code anchor `419e5c8`; bookmark fix `5267a09`; not pushed).
Codex re-review handoff: [`docs/handoff-codex-invisible-capture-v1-2026-08-27.md`](docs/handoff-codex-invisible-capture-v1-2026-08-27.md).
HAL driver plan remains paused.

---

## Where we stopped

Four commits landed on `main` after a Claude Code fleet built them in one
working tree and hit a session limit mid-commit. Re-verified **144 tests, 0
failures** before committing. They are on `origin/main`. **Do not re-do these
commits.**

| Commit | Message |
|---|---|
| `ca4e57f` | Buffer app-audio pre-roll so Capture takes start at first signal. |
| `845fc47` | Watch history folders so late exports still match archived sets. |
| `99c0d63` | Ingest VirtualDJ plugin JSONL drop files as ImportedTracklists. |
| `17ae83c` | Specify the VirtualDJ plugin JSONL contract and record fleet leave-off. |

`AppModel.swift` was split across the first two commits on purpose: M11b got
only the `prerollSeconds: startHold + 0.5` hunk; M12 got the history-watcher
rest. Do not squash.

The fleet sequence through docs fix `654e68b` was pushed on 2026-08-12.

---

## What is done

**M11b pre-roll.** While watching, `AppAudioCaptureService` keeps a converted
PCM ring and flushes it when a take starts. `startMonitoring(..., prerollSeconds:)`
is wired from `AppModel` to `silenceSessionConfig.startHoldSeconds + 0.5`.
`CapturePCMWriter.convert` returns a `(buffer, error)` tuple — **not**
`Result<_, String>`.

**M12 history watcher.** `HistoryAutoIngest` sweeps granted + default history
folders. `AppModel` runs FSEvents, a 3s debounce, a periodic-scan backstop, and
a launch catch-up. `docs/integration-status.md` marks M12 Implemented.

**M14 Artifact B (Swift ingest).** Frozen `v:1` contract:
`docs/m14-vdj-plugin-spec.md`. Implementation:

- `JSONLTracklistParser` + `VirtualDJPluginEvent` in
  `Sources/DJMemoryCore/VirtualDJPluginEvent.swift`
- `.jsonl` routed from `VirtualDJHistoryParser`
- `"jsonl"` in `HistoryFolderIngest.allowedExtensions`
- drop folder `~/Documents/VirtualDJ/DJMemoryDrop` on VirtualDJ
  `defaultHistoryPaths`

Parser rules: only `type: "track_play"` → `TrackPlay`; source
`"virtualdj-plugin"`; confidence `0.95`; consecutive same `(deck, artist,
title)` de-dup; truncated final line skipped; unknown major `v` throws
`.unsupportedVersion`. **Do not rename** `JSONLTracklistParser`.

---

## What is not done (next work)

**M14 Artifact A — Xcode scaffold builds; live validation pending.** The SDK
headers are at `/Users/robcmartin/Downloads/VirtualDJ8_SDK_20211003`. Open
`docs/virtualdj-plugin-scaffold/DJMemoryVirtualDJPlugin.xcodeproj`. Its native
C++ bundle target derives from `IVdjPluginStartStop8`, exports
`DllGetClassObject`, polls deck metadata/state, and appends JSONL into
`~/Documents/VirtualDJ/DJMemoryDrop/set-<date>-<session>.jsonl`.

The SDK API surface and universal arm64/x86_64 build are verified. The exact
VDJScript getter strings, worker-thread query safety, and on-air semantics still
need a live VirtualDJ test. **No private APIs.** Separate signing/notarization;
not bundled into DJMemory.app.

Live probe on 2026-08-13: `/Applications/VirtualDJ.app` is the sandboxed arm64
build and keeps plugins under its container's `PluginsMacArm` tree. An ad-hoc
signed bundle was installed in `PluginsMacArm/AutoStart`, but the current
VirtualDJ license session did not load the general/basic plugin. VirtualDJ's
plugin guidance notes this category can require a Pro-capable license. Resume
with a Pro session before changing getter or output-path assumptions.

Do not flip M14 to Supported in `docs/integration-status.md` until a real mix
archives and matches.

Open (spec §9): on-air signal vs inferred play; recue window; `startTime` =
wall-clock `ts` vs `elapsed`; multi-session files.

Do not add SDK callbacks or getter strings from memory. Keep candidates isolated
in `VDJSDKAdapter.cpp` and validate them against VirtualDJ.

---

## Sibling tree — leave it alone

`/Users/robcmartin/Documents/Codex/2026-08-06/i-wan/DJMemory` is a different
clone (GitHub issue #15). Do not mix working trees.

---

## Paste this to start the next session

```
Read AGENTS.md, CONTEXT.md, and HANDOFF-CODEX.md in
/Users/robcmartin/Documents/Codex/2026-08-06/i-wan/SetCatcher.

Fleet work is already committed locally on main (ca4e57f, 845fc47, 99c0d63,
17ae83c). Do not re-implement or re-commit it. The sequence through 654e68b is
on origin/main.

Next: live-test M14 Artifact A in VirtualDJ — see
docs/m14-vdj-plugin-spec.md §3 and docs/virtualdj-plugin-scaffold/README.md.
Keep M14 Research until JSONL imports and matches a real played set.
```
