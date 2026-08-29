# Codex sequence — phase completion matrix (2026-08-29)

Authoritative against current tree (re-verified **2026-08-29T14:08Z**): `main` @ `e357e15`, **ahead 34** of `origin/main`, a11y+evidence+plan **committed**, briefs on disk + **local exclude**.

| # | Requirement | Evidence | Verdict |
|---|-------------|----------|---------|
| 1 | Verify branch/remote/range/dirty/worktrees; `origin/main..HEAD` intended-only; no push/delete | ahead 33; `briefs_in_range=0`; worktrees preserved; no push this session | **Done** |
| 2 | Manual a11y: launch app; screens; VO/keyboard/focus/ids; dated evidence; fix confirmed issues; retest | Evidence + focus-ring stills; Recovery live; sidebar/capture/settings VO-proxy labels fixed 14:05Z; smoke passed. **Residual:** human VO rotor | **Agent-complete / human residual** |
| 3 | Live capture evidence; stop if permissions/hardware block | `docs/live-capture-evidence-2026-08-29.md` — dated stop; third re-probe 13:58:15Z still exit 1 / hw skip | **Done (dated stop)** |
| 4 | Recommend brief commit/move/exclude; no delete/relocate without approval | `docs/briefs-decision-2026-08-29.md` prefers **A**; **fallback C applied locally** via `.git/info/exclude` (briefs still on disk, not deleted/moved) | **Done (recommend + local exclude)** |
| 5 | Inventory branch hygiene; preserve experimental lines | `docs/branch-hygiene-inventory-2026-08-29.md` | **Done** |
| 6 | Push gate + **wait for explicit push approval** | Commit `e357e15` landed a11y/evidence; gates green; **waiting for push OK only** | **Prepared — waiting** |

## Invariants preserved

- Untracked `docs/brief-*.md` not staged
- Experimental branches/worktrees not deleted
- No `git push`
- Container `folder-access.json` has no leftover `MissingDrive` probe

## Ready to commit (when you approve) — exclude briefs

```
Sources/DJMemoryApp/MenuBarStatusView.swift
Sources/DJMemoryApp/Views/ActivityLogView.swift
Sources/DJMemoryApp/Views/CaptureView.swift
Sources/DJMemoryApp/Views/Home/HomeIdentityBand.swift
Sources/DJMemoryApp/Views/HomeDashboardView.swift
Sources/DJMemoryApp/Views/ProtectionDashboardView.swift
Sources/DJMemoryApp/Views/RecoveryView.swift
Sources/DJMemoryApp/Views/SessionLibraryView.swift
Sources/DJMemoryApp/Views/SettingsAccountPanel.swift
Sources/DJMemoryApp/Views/SettingsProfilePanel.swift
Sources/DJMemoryApp/Views/SettingsView.swift
Sources/DJMemoryApp/Views/SidebarView.swift
docs/a11y-focus-rings-2026-08-29/
docs/swiftui-a11y-evidence-2026-08-29.md
docs/swiftui-manual-a11y-notes-2026-08-29.md
docs/live-capture-evidence-2026-08-29.md
docs/briefs-decision-2026-08-29.md
docs/branch-hygiene-inventory-2026-08-29.md
docs/plan-post-consolidation-2026-08-29.md
docs/push-gate-2026-08-29.md
docs/codex-sequence-matrix-2026-08-29.md
```

**Exclude:** `docs/brief-brand.md`, `brief-competition-market.md`, `brief-marketing.md`, `brief-product.md`

## Blocking full objective close-out

1. Explicit approval to **`git push origin main`** (a11y+evidence already in `e357e15`)
2. Optional human: VO rotor; live capture PASS with gear

## Agent completion audit (2026-08-29T14:08Z)

| Req | Proof inspected | Verdict |
|-----|-----------------|---------|
| 1 State | ahead 34 @ `e357e15`; no product briefs in range; worktrees kept; no push | **Met** |
| 2 A11y | Evidence + stills + App fixes committed; smoke-app; VO-proxy; human VO residual | **Met (agent)** |
| 3 Live | Dated stop + re-probes | **Met (stop)** |
| 4 Briefs | Decision doc committed; product briefs local-excluded | **Met** |
| 5 Hygiene | Inventory committed; experimental lines kept | **Met** |
| 6 Gate+wait | Gate docs; smoke after commit; **awaiting push OK** | **Waiting** |
