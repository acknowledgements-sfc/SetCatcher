# SetCatcher — next chat handoff (2026-09-01)

Paste the **New chat seed** block below as the first message in the next Cursor Agent chat with this repo selected.

---

## New chat seed

```
Continue SetCatcher on main (origin synced through 8f0d911).

## Done (do not redo)
- **Protection UX (Layout B):** Live cockpit + dashboard, 8-state LiveProtection, capture arm/strip, recovery panels, toast queue. Commits: d091e02, 49f148e, 81fe6c0.
- **Presentation modes:** AppPresentationMode (menu bar + main / menu bar only / main only) in Settings + onboarding Ready.
- **Onboarding list (partial):** DJ app detection list + analog in-sheet setup. Commit: ca82e50.
- **Phase 0 HTML mockups:** admin/prototypes/ (index opens all layouts). Commit: 8f0d911.

## Active WIP on disk (uncommitted — pick up here)
**DJ app path discovery + richer onboarding probe rows**

Core (new module):
- Sources/SetCatcherCore/DJAppPaths/ — DJPathDiscovery, per-app readers, variant catalog, bundle metadata
- Tests/SetCatcherCoreTests/DJAppPathDiscoveryTests.swift
- Tests/Fixtures/ — pref/XML fixtures for readers
- docs/dj-app-path-discovery.md

Touched:
- SoftwareProbe.swift — wires DJPathDiscovery into probe/installation rows
- DJSoftware.swift — denon-engine / variant metadata
- AppModel.swift, OnboardingDJAppsList.swift, OnboardingView.swift — show discovered paths + sources in onboarding
- SetCatcherCLI/main.swift — probe output shows path sources
- SupportedDJSoftwareTests.swift, docs/integration-status.md

## Task for this chat
1. Run `swift build` and `swift test` — fix any failures in DJAppPathDiscoveryTests.
2. Finish wiring: onboarding list shows edition labels + discovered recording paths with honest support labels.
3. Verify CLI: `swift run setcatcher probe` prints `[userPreference|catalogDefault|…]` sources.
4. Commit as one focused PR-sized commit (Core + tests + docs + app/CLI wiring). Do not commit admin/prototypes/setcatcher-generated-light.html (duplicate of admin/public/) or docs/phase2-new-chat-seed.md (stale).

## Specs & rules
- Read AGENTS.md, HANDOFF.md, HANDOFF-2-HOME.md before UI work.
- AppModel is the only view model. SetCatcherCore stays UI-agnostic.
- Product non-negotiables: local-first, copy never mutate, honest Partial/Manual Setup labels, no dead ends.
- Preserve accessibility identifiers (smoke-app.sh depends on them).

## Human gates (not blocking commit)
- Visual QA: Live 8-state matrix + three presentation modes on a main build.
- Bench: Engine DJ desktop paths (fixture-tested only so far).

## Collisions
- Avoid overlapping AppModel edits with handoff-sleep-prevention-capture chat if still open.
- Marketing landing owns admin/public/generated-light.html.
```

---

## Context for the agent

| Item | Detail |
| --- | --- |
| Repo | `/Users/robcmartin/Documents/Claude/Projects/SetCatcher` |
| Branch | `main` @ `8f0d911` (synced with origin) |
| Prior chat | X - Protection UX Layout B (`95f61a95-4ff4-4b75-808f-17ed2eb9de91`) — closed |
| Prototype entry | Open `admin/prototypes/home-layout-index.html` in browser for Phase 0 reference |

## Intentionally untracked

- `admin/prototypes/setcatcher-generated-light.html` — near-duplicate of `admin/public/generated-light.html`
- `docs/phase2-new-chat-seed.md` — obsolete Cowork seed; superseded by this file
