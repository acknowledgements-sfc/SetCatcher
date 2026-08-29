# SwiftUI visual review checklist

Authoritative design context: `HANDOFF.md`, `CONTEXT.md`, `Sources/DJMemoryApp/Theme/Tokens.swift`.
No web `PRODUCT.md` / `DESIGN.md` in this repo.

Use with the live debug app (`bash scripts/build-app.sh debug` → `open .build/DJMemory.app`) and Xcode `#Preview` (light and dark). Headless agents cannot certify layout from previews alone.

## Screens

| Screen | Preview / live | Light | Dark | Notes |
|--------|----------------|-------|------|-------|
| Home | `HomePreviews.swift` + live | | | |
| Sidebar | `SidebarView.swift` | | | |
| Protection | `ProtectionDashboardView.swift` | | | |
| Capture | `CaptureView.swift` | | | |
| Library | `SessionLibraryView.swift` | | | |
| Activity | `ActivityLogView.swift` | | | |
| Settings | `SettingsView.swift` (root previews) + panels | | | |
| Onboarding | `OnboardingView.swift` | | | |
| Recovery | `RecoveryView.swift` | | | |

## Checklist (every screen)

- [ ] **Layout hierarchy** — primary action and status readable; no marketing heroes
- [ ] **Spacing rhythm** — dense, radii ≤ 8, 1px hairline dividers
- [ ] **Typography** — body ~12pt, monospaced digits/paths where specified
- [ ] **Colors / tokens** — only `DJToken` (no raw hex / system `.green` etc. in views)
- [ ] **Empty / loading / error** — cause named + at least one resolving action
- [ ] **Light / dark** — both appearances
- [ ] **Keyboard focus** — visible focus; search fields and pickers reachable
- [ ] **Accessibility labels** — controls named; existing `accessibilityIdentifier` families preserved

## Identifier families (must not rename/remove)

`sidebar.*`, `protection.*`, `protectionSource.<id>.*`, `setup.<id>.*`, `historyImport.<id>.*`, `library.*`, `setDetail.<id>.*`, `tracklistDetail.<id>.*`, `settings.*`, `activity.*`, `virtualdj.networkControl.check`, `header.openArchiveFolder`
