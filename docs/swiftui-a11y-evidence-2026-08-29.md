# Manual accessibility evidence — Phase 1

**Date:** 2026-08-29  
**Product under review:** `.build/DJMemory.app` (built via `bash scripts/build-app.sh debug`)  
**Not used as proof:** bare `swift build` / package compile alone  
**macOS:** 26.6.2 (25G83)  
**HEAD context:** `main` @ `89eef91` (+ local App UI a11y edits, uncommitted)

## Method

1. Inspect `Sources/DJMemoryApp`
2. `bash scripts/build-app.sh debug`
3. `open .build/DJMemory.app`
4. Probe accessibility with ApplicationServices (`kAXIdentifierAttribute` / `kAXDescriptionAttribute` / `kAXEnabledAttribute`) against the running app process
5. Navigate screens via **Cmd+1–6** (AppCommands) and sidebar cell clicks where List selection responds
6. `bash scripts/smoke-app.sh`
7. System Events `description` was **not** trusted after it returned only `"button"` while AX Description was correct

## Navigation notes (agent)

| Mechanism | Result |
|-----------|--------|
| `AXPress` on `sidebar.*` static text | Returns success but does **not** change `List(selection:)` |
| CGEvent click on parent `AXCell` mid-point | Works for Home / Protection / Capture; Library / Activity / Settings often flaky from Capture |
| Keyboard **Cmd+1…6** | Reliable for Home, Protection, Library, Activity, Settings |
| Keyboard **Cmd+3** Capture | Intermittent in automation (likely focus timing); sidebar cell click reliable |
| MenuBarExtra status item | App `AXChildren` includes a narrow second `AXMenuBar` (~34×24); click opens panel window with `menuBar.*` IDs |
| System-wide `AXExtrasMenuBar` | Missing; use app-scoped extras menubar instead |
| Keyboard **Tab** (after AX focus on a control) | Focus moves; see Keyboard focus sample below |
| `AXFocusedUIElement` with no prior focus | Often empty on SwiftUI until a control is focused |

## Screen walk (live AX after fixes)

### Home (Cmd+1)

| AXIdentifier | Role | AX Description | Enabled |
|--------------|------|----------------|---------|
| `home.scanNow` | AXButton | Scan Now | true |
| `home.openLibrary` | AXButton | Open Library | true |
| `home.lane.serato` | AXButton | Serato DJ Pro, Watching | true |
| `home.lane.rekordbox` | AXButton | rekordbox, Watching | true |
| `home.lane.*` (others) | AXButton | `{displayName}, {setup state}` | true |
| `home.root` / `home.identity` | AXGroup | (container) | true |

`home.scanNow` count after duplicate removal: **1**.

### Protection (Cmd+2)

| AXIdentifier | Role | AX Description | Enabled |
|--------------|------|----------------|---------|
| `protection.root` | AXGroup | (container) | true |
| `protection.scanNow` | AXButton | Rescan Last 24 Hours | true |
| `protectionSource.serato.setup` | AXButton | Setup | true |
| `protectionSource.serato.scanNow` | AXButton | Scan Now | true |
| `protectionSource.serato.recordingFolder` | AXButton | Manage | true |
| `protectionSource.rekordbox.*` | AXButton | Setup / Scan Now / Manage | true |
| `protectionSource.{djay,traktor,virtualdj,djmemory-capture,pioneer-hardware}.chooseFolderPrimary` | AXButton | Choose Folder | true |

**Before fix:** `protection.root` was an `AXStaticText` with **no** `protectionSource.*` children exposed.  
**After fix:** `.accessibilityElement(children: .contain)` — sources and scan control visible to AX.

### Capture (sidebar cell click)

| AXIdentifier | Role | AX Description | Enabled |
|--------------|------|----------------|---------|
| `capture.mode` | AXRadioGroup | Mode | true |
| `capture.levelMeter` | AXUnknown | Input level | true |
| `capture.arm` | AXButton | Arm | **false** (disabled; AXEnabled=false) |
| `capture.refreshTargets` | AXButton | Refresh Targets | true |
| `capture.retryAppAudio` | AXButton | Retry | true |
| `capture.openScreenRecordingSettings` | AXButton | Open Screen Recording Settings | true |
| `capture.listeningSummary` | AXStaticText | ∅ (content is AX value/text) | true |

### Library (Cmd+4)

| AXIdentifier | Role | AX Description | Enabled |
|--------------|------|----------------|---------|
| `library.segment` | AXRadioGroup | Library | true |
| `library.dateFilter` | AXPopUpButton | Date | true |
| `library.archivedSets.search` | AXTextField | Search archived sets | true |

### Activity (Cmd+5)

| AXIdentifier | Role | AX Description | Enabled |
|--------------|------|----------------|---------|
| `activity.exportDiagnostics` | AXButton | Export Diagnostics | true |
| `activity.clear` | AXButton | Clear | true |
| `activity.filter` | AXRadioGroup | Filter | true |

### Settings (Cmd+6)

| AXIdentifier | Role | AX Description | Enabled |
|--------------|------|----------------|---------|
| `settings.dualRoutePosture` | AXPopUpButton | Pioneer rig safety nets | true |
| `settings.scanInterval` | AXRadioGroup | Scan interval | true |
| `settings.archive.choose` / `.open` | AXButton | Change / Open | true |
| `settings.archive.reset` | AXButton | Reset | **false** |
| Checkboxes (`automaticScanning`, `verifyCopies`, …) | AXCheckBox | Visible label text | varies |
| Profile text fields | AXTextField | Display name / Handle / City / Residency | true |
| `settings.archiveNamingTemplate` | AXTextField | Archive naming template | true |

### Keyboard focus samples (after AX-focusing a seed control)

#### Home (seed `home.scanNow`)

| Step | Focused AXIdentifier | AX Description |
|------|----------------------|----------------|
| 0 | `home.scanNow` | Scan Now |
| Tab 1 | `home.openLibrary` | Open Library |
| Tab 2–8 | `home.lane.*` | app + setup state |
| Tab 9–10 | ∅ | Choose Folder / Open Library (banner actions) |

#### Protection (seed `protection.scanNow`)

| Step | Focused | Description |
|------|---------|-------------|
| 0 | `protection.scanNow` | Rescan Last 24 Hours |
| Tab 1–3 | `protectionSource.serato.*` | Setup / Scan Now / Manage |
| Tab 4–6 | `protectionSource.rekordbox.*` | Setup / Scan Now / Manage |
| Tab 7+ | `protectionSource.*.chooseFolderPrimary` / `.recordingFolder` | Choose Folder |

#### Capture (seed imperfect — first focus landed in sidebar; Tab still reaches capture chrome)

Toolbar → `header.openArchiveFolder` → App audio radio → `capture.refreshTargets` → `capture.retryAppAudio`.

#### Library

Toolbar → Archived Sets radio → `library.dateFilter` (Date) → `library.archivedSets.search` (Search archived sets).

#### Activity (seed `activity.exportDiagnostics`)

Export Diagnostics → Clear → All filter radio → sidebar/toolbar.

#### Settings (seed `settings.automaticScanning`)

Automatic scanning → scan-interval radio → verify/notify/login/menu-bar/folder-details/auto-arm checkboxes → `settings.dualRoutePosture` → profile text fields (now labeled Display name / Handle / City / Residency; archive naming template labeled).

**Not verified:** VO “dimmed” phrasing for disabled controls.

**Focus rings (visual):** Home primary/ghost buttons show clear blue keyboard focus borders (`docs/a11y-focus-rings-2026-08-29/`). Library segment/Date and Settings automatic-scanning/verify stills captured in the same folder; native controls often use selection fill as the focus cue.

### Setup / Recovery sample

- `sidebar.app.serato` cell click → `setup.serato.historyFolder` / `setup.serato.recordingFolder` named **Change History Folder** / **Change Recording Folder**.
- **Recovery (live, reversible container probe):** Sandboxed app reads  
  `~/Library/Containers/app.djmemory.DJMemory/Data/Library/Application Support/DJMemory/folder-access.json`  
  (not the non-sandbox `~/Library/Application Support/DJMemory/` path). Temporarily pointed serato recordings at `/Volumes/MissingDrive-a11y-probe/Recordings/`, relaunched, then restored backup (no `MissingDrive` left).

| Observation | Result |
|-------------|--------|
| Status strip | Attention Needed. A saved folder is unavailable. |
| `home.lane.serato` | Serato DJ Pro, Attention Needed |
| `home.fix.serato` | Fix Folder |
| `protection.fix.serato` | Fix Serato DJ Pro |
| `protectionSource.serato.fixFolder` | Fix Folder |
| After Fix click (post `recovery.root` contain fix) | `recovery.root` AXGroup; `recovery.chooseDifferent` / `recovery.clear` / `recovery.back` named correctly |

**Before Recovery contain fix:** buttons incorrectly all carried `recovery.root` as AXIdentifier (same collapse class as pre-fix `protection.root`).

### Menu bar (MenuBarExtra panel)

Status item AX title observed: e.g. **Ready for capture** / **Armed** / **Starting up**.

| AXIdentifier | Role | AX Description | Enabled |
|--------------|------|----------------|---------|
| `menuBar.captureState` | AXUnknown | Capture status, {headline} | true |
| `menuBar.previousCapture` | AXUnknown | Previous capture, {summary} | true |
| `menuBar.openMainWindow` | AXButton | Open Main Window | true |
| `menuBar.viewLastCaptureInMainWindow` | AXButton | View Last Capture in Main Window | false (no prior capture) |
| `menuBar.viewLastCaptureInFinder` | AXButton | View Last Capture in Finder | false |
| `menuBar.appSettings` | AXButton | App Settings | true |
| `menuBar.quit` | AXButton | Quit DJMemory | true |

### Sidebar status strip

After combine: single `sidebar.statusStrip` with description **Status** and value **Protected. All sources watched. Nothing to do.**

### Duplicate AXIdentifiers

| Before | After |
|--------|-------|
| `sidebar.library` × 2, `sidebar.statusStrip` × 4, `home.scanNow` × 2 (earlier) | Only system `ListColumn` × 2 remains |

## Fixes kept (App only)

1. **Home** — lane `.accessibilityLabel("\(displayName), \(state)")`; `home.root` / `home.identity` `.accessibilityElement(children: .contain)`; removed accidental duplicate Scan Now.
2. **Protection** — `protection.root` `.accessibilityElement(children: .contain)` so source rows are exposed.
3. **Recovery** — `recovery.root` `.accessibilityElement(children: .contain)` so choose/clear/back keep their own identifiers.
4. **Sidebar** — Library row combine + label/value; preserve `sidebar.library.count` in source (hidden from AX); status strip combine + label/value; nav rows (Home/Protection/Capture/Activity/Settings) + configured app rows use `.accessibilityElement(children: .combine)` + labels (spoken via AXValue / Description).
5. **Capture / Library / Activity / Settings** — accessibility labels on segment/date/search/filter/scan interval/dual-route pickers; capture level meter label/value; profile field labels; `capture.listeningSummary` labeled with summary text; `settings.accountOffline` labeled with offline copy.
6. **Menu bar** — `menuBar.captureState` / `previousCapture` labeled with headline/summary (`children: .ignore`).

### VO-proxy recheck (2026-08-29T14:05Z)

Spoken proxy = AX Description → Title → **Value** → RoleDescription (Value required for SwiftUI `AXStaticText` List rows).

| Screen | Interactive WEAK (no desc/title/value) |
|--------|----------------------------------------|
| Home / Protection / Capture / Library / Activity / Settings | **none** (containers `home.root` / `home.identity` / `protection.root` only) |
| Sidebar nav + app rows | spoken Home / Protection / Capture / Activity / Settings / app names |
| `capture.listeningSummary` | spoken full summary string |
| `settings.accountOffline` | spoken offline account copy |

**Residual human:** full VoiceOver rotor + disabled “dimmed” phrasing.

## Smoke

`bash scripts/smoke-app.sh` → **DJMemory window check passed; DJMemory smoke check passed** (after rebuilding `.build/DJMemory.app` with these fixes).

## Non-actions

- No push
- No branch deletes
- Briefs remain untracked
- These App + evidence changes are **not committed** until you approve
