# Manual macOS accessibility notes

Automated proof does not cover full VoiceOver or keyboard focus. Record checks against `.build/DJMemory.app`.

Date: 2026-08-29  
App: `.build/DJMemory.app` (debug) via `scripts/build-app.sh` + `scripts/smoke-app.sh`
Evidence detail: `docs/swiftui-a11y-evidence-2026-08-29.md`

## Checklist

| Check | Status | Notes |
|-------|--------|-------|
| Keyboard navigation (sidebar → content) | Partial (agent) | Cmd+1–6 + Tab samples on Home/Protection/Capture/Library/Activity/Settings. **Home focus rings visible** (blue border) — `docs/a11y-focus-rings-2026-08-29/`. |
| Visible focus rings on search / pickers | Partial (agent) | Home clear blue rings. Library segment/Date + Settings scan/verify stills in `docs/a11y-focus-rings-2026-08-29/`. Native controls use selection fill as focus cue. |
| VoiceOver names and roles | Partial (agent) | Value-aware AX spoken proxy 14:05Z: sidebar nav/apps, capture summary, accountOffline ok. Containers only WEAK. Full VO rotor still human. |
| Labeled search fields and pickers | Partial (agent) | Live labels on library/capture/activity/settings pickers + search. |
| Recovery and error actions named + actionable | Partial (agent) | Live Recovery via container `folder-access` probe (restored). `recovery.chooseDifferent` / `clear` / `back` named; `protection.fix.serato` / `home.fix.serato` named. VO still human. |
| Menu bar | Partial (agent) | Status item click opens panel; actions named; capture/previous labeled; last-capture actions correctly disabled. |
| Disabled scanning / arm controls | Partial (agent) | `capture.arm`, `settings.archive.reset`, menu last-capture buttons AXEnabled=false. VO phrasing unverified. |

## Confirmed fixes this pass

- `protection.root` children contain → `protectionSource.*` exposed
- Sidebar Library / statusStrip duplicate IDs collapsed
- Capture level meter + Mode label; Library/Activity/Settings picker labels; listeningSummary / accountOffline labels
- Sidebar nav + app row combine labels (VO-proxy)
- Menu bar capture/previous status labels
- Earlier: duplicate `home.scanNow` removed; Home lane labels

Static automated coverage: `AccessibilityIdentifierAuditTests` asserts required identifier **families** remain present in `Sources/DJMemoryApp`. Existing identifiers must not be renamed or removed.
