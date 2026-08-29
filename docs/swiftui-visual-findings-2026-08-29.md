# SwiftUI visual findings (Phase 5)

Findings-only audit. No styling commits unless a token/hierarchy bug blocks shipping.

Date: 2026-08-29
Branch: `cursor/invisible-capture-v1`
Sources: live `.build/DJMemory.app`, `#Preview` coverage, `HANDOFF.md` / `Tokens.swift`, Codex trial review.

## Confirmed (no visual redesign)

1. **Home top tracks** — uses stable `TrackPlayCount.id`; local `let tracks` avoids repeated aggregation. No layout change required.
2. **Settings root** — previously lacked `#Preview`; empty light/dark previews added for review only (not a redesign).
3. **AdapterDetail setup steps** — index-based `ForEach` remains appropriate for static numbered display text.
4. **Token usage** — Home / Library / Settings panels reviewed use `DJToken`; no Liquid Glass / gradients / heroes introduced by this pass.

## Judgement calls (documented, not changed)

1. **Library segment change** — no `onChange(of: segment)` clearing selection. Inspector is segment-gated, so a session selection does not surface while viewing tracklists (and vice versa). Not a hidden-row correctness bug; leave as-is.
2. **Broad AppModel `@Published` invalidation** — optional Instruments follow-up if hitch evidence appears; no cache without measurement.
3. **Spacing / hierarchy micro-polish** — none blocked shipping; defer any visual tweaks to a separate approval (priority: hierarchy → spacing → focus → empty/error → type).

## Blockers for styling

None identified that alter product behavior or require token fixes before merge.
