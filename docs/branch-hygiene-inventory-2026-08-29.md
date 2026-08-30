# Branch / worktree hygiene inventory — 2026-08-29

**Rule:** preserve experimental lines; do not force-delete.

## Primary

Current local verification branch: `codex/setcatcher-rename` at `b6a1a5e`, with Phase 1 at `f7e9bb9`. It contains the technical rename and app-owned migration. Keep `.cursor/settings.json` and `docs/phase2-new-chat-seed.md` untracked; keep product briefs excluded.

| Ref | Tip (approx) | Role | Action |
|-----|--------------|------|--------|
| `main` | Scoped beta-readiness tip descended from `255a6b0` | Consolidated capture + hardening locally; **ahead 37** of `origin/main` after the two scoped gate commits | Push only after separate explicit approval |
| `cursor/invisible-capture-v1` | `ab50dee` | Source product line (merged into local main) | Keep until origin has tip; optional archive tag later |
| `integration/swiftui-hardening-capture` | `a52a5a7` | Integration merge commit | Keep for recoverability |

## Experimental / parked (do not auto-merge)

| Ref | Worktree | Action |
|-----|----------|--------|
| `feature/mobile-companion` | — | Parked iOS companion; separate review |
| `review-audio-driver-proto` | `…/workable-level` | Live driver grading; keep |
| `fix-memory-leaks` | `…/colorful-snowflake` | Long-session sampler; keep |
| `superset-config-setup` | `…/admitted-stretch` | Tooling only |
| `superset-setup-scripts` | `…/checkered-pickup` | Tooling only |
| `review-markdown-plan` | `…/eager-spandex` | Docs/review park |
| `codex/invisible-capture-v1-corrections` | — | Diff vs main before any cherry-pick |
| `perf/dsp-vdsp-vectorization` | — | Likely already in main lineage; verify before cherry-pick |
| `Ui-Design-v1` | — | Older UI; leave |

## Worktrees (current)

```
SetCatcher → main
…/admitted-stretch → superset-config-setup
…/checkered-pickup → superset-setup-scripts
…/colorful-snowflake → fix-memory-leaks
…/eager-spandex → review-markdown-plan
…/workable-level → review-audio-driver-proto
```

## Merged vs unresolved

- **On local main:** invisible-capture product + SwiftUI hardening (`3bf2785` / `ab50dee` ancestry).
- **Unresolved evidence:** live capture (see `docs/live-capture-evidence-2026-08-29.md`); human VO remainder.
- **Untracked:** `.cursor/settings.json` (`{}`) only; unrelated editor state, do not stage.
