# Handoff for Antigravity — Bookmark fix, merge prep, Codex handoff draft

**Date:** 2026-08-27
**Repo:** `/Users/robcmartin/Documents/Claude/Projects/SetCatcher` (DJMemory)
**Read first:** `AGENTS.md`, `.cursor/rules/djmemory-project.mdc`

## Your mission

Implement the archive-root bookmark fix, land **one commit** on `codex/invisible-capture-v1-corrections`, fast-forward merge into `cursor/invisible-capture-v1`, run the automated verification gate, and **draft** the Codex re-review handoff doc. **Do not push.**

## Context

Live hardware bench test `CaptureServiceTests/testLivePioneerInputRecords16Bit48kCapture` captures audio successfully but **fails at archive ingest** with `SecurityScopedAccessError.resolveFailed` because it passes a GUI-created security-scoped bookmark into `ArchiveService` from a `swift test` context where the bookmark cannot resolve.

The CLI already handles this correctly in `Sources/DJMemoryCLI/main.swift` (`resolvedArchiveRoot`). `AppAudioProbeRunner` uses `ArchiveService()` with no bookmark. Extract shared resolution into Core.

## Binding constraints

1. **Local-first; no network** for archiving or scanning.
2. **Do not** change `SecurityScopedAccess.withScopedArchiveRootAccess` to silently fall back on bad bookmarks.
3. Fix by resolving at call site: pass `bookmarkData: nil` when bookmark is unusable; use resolved URL for `archiveRoot`.
4. **Surgical scope:** Core + CLI + tests + one script comment. **No** AppModel scoped-access changes, **no** UI edits, **no** capture routing changes, **no** HAL driver work.
5. **One commit** for the bookmark fix (after tests pass).
6. **Do not push** to `origin`.
7. **Do not** reset, stash, or clean the working tree.

## Implementation spec

### 1. New file: `Sources/DJMemoryCore/ArchiveRootResolver.swift`

```swift
public struct ArchiveRootResolution: Equatable, Sendable {
    public let url: URL
    public let bookmarkData: Data?  // non-nil only when bookmark resolves and !isStale
}

public enum ArchiveRootResolver {
    public static func resolve(settings: AppSettings) -> ArchiveRootResolution
}
```

Resolution order (mirror CLI `resolvedArchiveRoot` exactly):

1. `ProcessInfo.processInfo.environment["DJMEMORY_ARCHIVE_ROOT"]` — tilde-expand, directory URL
2. `settings.archiveRootBookmarkData` — resolve with `[.withSecurityScope]`, return URL + bookmark if `!isStale`
3. `settings.archiveRootPath` — tilde-expand
4. `ArchiveService.defaultArchiveRoot()`

When using steps 3–4, or when step 2 fails, set `bookmarkData: nil`.

### 2. Wire callers

- **`Sources/DJMemoryCLI/main.swift`:** Delete private `resolvedArchiveRoot(settings:)`. Use `ArchiveRootResolver.resolve(settings:)`. Pass `resolution.url` and `resolution.bookmarkData` into `ArchiveService`.
- **`Tests/DJMemoryCoreTests/CaptureServiceTests.swift`:** In `testLivePioneerInputRecords16Bit48kCapture` and `testLiveUserArchiveLinkerGroupsCaptureWithFolder`, replace manual path + raw bookmark with resolver output.

### 3. New tests: `Tests/DJMemoryCoreTests/ArchiveRootResolverTests.swift`

- Env `DJMEMORY_ARCHIVE_ROOT` wins over path/bookmark
- Garbage bookmark + valid `archiveRootPath` → path URL, `bookmarkData == nil`
- Empty/minimal settings → `ArchiveService.defaultArchiveRoot()`

Use temp dirs and env cleanup; no checked-in real bookmarks.

### 4. Script comment

In `scripts/live-hardware-route-check.sh`, add a comment near the top that `DJMEMORY_ARCHIVE_ROOT=~/Music/DJMemory` is an optional escape hatch. Do not require it in the script.

## Git workflow

```bash
git checkout codex/invisible-capture-v1-corrections
# implement, verify
git add Sources/DJMemoryCore/ArchiveRootResolver.swift \
        Sources/DJMemoryCLI/main.swift \
        Tests/DJMemoryCoreTests/ArchiveRootResolverTests.swift \
        Tests/DJMemoryCoreTests/CaptureServiceTests.swift \
        scripts/live-hardware-route-check.sh
git commit -m "$(cat <<'EOF'
Resolve archive root for bench contexts when GUI bookmark is unusable.

Share CLI-style archive root resolution in DJMemoryCore so swift test and
CLI ingest omit unresolvable GUI bookmarks instead of failing scoped access.
EOF
)"
git checkout cursor/invisible-capture-v1
git merge --ff-only codex/invisible-capture-v1-corrections
```

If FF merge fails, **stop** and report — do not force-merge.

## Verification gate (run twice: before merge commit check, after FF merge)

```bash
cd /Users/robcmartin/Documents/Claude/Projects/SetCatcher
swift test
swift build
bash scripts/build-app.sh
bash scripts/smoke-app.sh
```

**Pass criteria:**

- All tests green (expect 262+ including new resolver tests)
- Build warning-free for touched code
- `smoke-app.sh` exits 0

**Do not run** (owner/Cursor handles):

- `bash scripts/live-hardware-route-check.sh`
- `bash scripts/live-invisible-capture-check.sh`

## Codex handoff draft (your second deliverable)

Create `docs/handoff-codex-invisible-capture-v1-2026-08-27.md` using tone of `docs/handoff-codex-pr2-1-virtual-ioproc-2026-08-17.md`.

Include:

- Branch `cursor/invisible-capture-v1`, merged HEAD SHA, bookmark fix commit SHA
- Commit table from `0eaa2df` through `8600975` + your bookmark commit (group by theme: routing, interrupted capture, probe, UI, packaging, bookmark)
- Automated verification results you observed (test count, build, smoke)
- **Placeholder section** `### Live verification (owner/Cursor)` — leave bullets for owner to fill:
  - App-audio matrix PASS (Serato/rekordbox/Traktor/VDJ/djay, Tap + SCK)
  - XDJ hardware: device detected, peak ~0.0002 (signal open), bookmark ingest fixed
  - Serato+XDJ WAV quality deferred
- Codex re-review checklist (from parent plan Phase 5)
- Human gates (listening, signing, XDJ routing, Serato quality)
- Commands block for next session

Add one line to `HANDOFF-CODEX.md` linking the new doc under "Invisible capture v1".

## Out of scope

- Push / PR
- AppModel changes
- Onboarding / UI
- Capture backend / probe logic changes
- HAL driver (Plan 2)
- Live bench re-runs

## Report back

When done, reply with:

1. Bookmark fix commit SHA
2. Merged `cursor/invisible-capture-v1` HEAD SHA
3. `swift test` summary line (N tests, 0 failures)
4. Paths to both handoff docs created
5. Any blockers (FF merge failure, test failures, unexpected dirty files)
