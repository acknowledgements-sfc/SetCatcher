# SetCatcher Product Documentation

Last updated: August 14, 2026.

This folder is the current product source of truth for SetCatcher. It separates the enduring strategy from the beta requirements and the implemented feature inventory.

## Read in this order

1. [`product-strategy.md`](product-strategy.md) — why SetCatcher exists, who it serves, where it competes, and the product principles that guide decisions.
2. [`mvp-prd.md`](mvp-prd.md) — the requirements and acceptance criteria for the first external Mac beta.
3. [`feature-catalog.md`](feature-catalog.md) — what the product currently does, how each workflow behaves, and what is deliberately limited.
4. [`release-boundaries.md`](release-boundaries.md) — what belongs in Beta 1, what follows after validation, and what remains research.

## Supporting documents

- [`../integration-status.md`](../integration-status.md) — engineering truth for each DJ-software integration.
- [`../mvp-readiness-audit.md`](../mvp-readiness-audit.md) — verification evidence and current release blockers.
- [`../user-testing-plan.md`](../user-testing-plan.md) — hands-on testing protocol.
- [`../brand-launch/`](../brand-launch/) — positioning, brand, market, pricing hypothesis, and launch communications.
- [`../prd.md`](../prd.md) — historical master PRD and milestone record. It remains useful context, but this folder governs current beta scope.

## Document ownership

| Document | Governs | Update when |
| --- | --- | --- |
| Product strategy | Audience, problem, category, principles, strategic bets | Research or positioning changes |
| MVP PRD | Beta requirements and success criteria | Beta scope or acceptance changes |
| Feature catalog | Current user-visible behavior | A feature ships or materially changes |
| Release boundaries | Sequencing and non-goals | A feature moves between releases |
| Integration status | Technical support truth | An integration is verified or regresses |
| Readiness audit | Release evidence | A release check is performed |

When documents disagree, use this priority: verified application behavior and tests → `integration-status.md` → current product files in this folder → historical `prd.md`.
