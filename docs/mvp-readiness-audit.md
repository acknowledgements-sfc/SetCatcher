# SetCatcher MVP Readiness Audit

Last updated: August 29, 2026.

This audit maps the v0.1 PRD acceptance criteria to current implementation evidence and the manual checks still needed before handing a beta to DJs.

## Current renamed-branch status (2026-08-29)

The Phase 1 library/playback fixes are committed at `f7e9bb9`. The technical SetCatcher rename and app-owned data migration are committed at `b6a1a5e` on `codex/setcatcher-rename`. The renamed branch passes the full test suite, release build, debug app packaging, strict signature verification, and app smoke. This section supersedes only the current-candidate statements below; dated historical results remain unchanged.

**Update (2026-09-02):** `main` = `origin/main` = `7b3b698` now already contains the rename plus later dual-lane-archive, iPad-companion, and archive-catalog-sync work; the `codex/setcatcher-rename` / `255a6b0` references in this document are historical baselines, not the current tip. See the Frozen review baseline under Automated Evidence.

External beta is still blocked by Developer ID signing, notarization, clean-Mac validation, and remaining human UI/listening checks. The available signing identity is Apple Development only.

## Automated Evidence

Frozen review baseline (2026-09-02, `main` at `7b3b698` = `origin/main`):

- `swift test`: **411 tests executed, 4 skipped, 0 failures**; `swift build` completed with **0 warnings**. This is the authoritative current-commit baseline. The 2026-08-29 figures below are retained as dated history at their stated commits.

Current local gate baseline (2026-08-29, base `main` at `255a6b0` before scoped readiness fixes):

- `swift test`: 284 tests executed, 3 skipped, 0 failures.
- `bash scripts/smoke-cli.sh`: CLI archive/scan/diagnostics smoke path passes.
- `swift build --product SetCatcherApp`: passes.
- `bash scripts/build-app.sh release`: `.build/SetCatcher.app` builds and signs with sandbox-oriented entitlements. After changing `livePeak` to an immutable constant, the release rebuild completed with zero warnings.
- Built app `Info.plist` includes `NSAudioCaptureUsageDescription` for system audio capture.
- `codesign --verify --deep --strict .build/SetCatcher.app`: passes.
- `bash scripts/smoke-app.sh`: packaged app launches, verifies code signature, performs best-effort window detection, and quits cleanly.
- Fresh app-audio probe on August 29 had Screen & System Audio Recording preflight `true` but no shareable running DJ target. Live Process Audio Tap and forced ScreenCaptureKit meter/WAV/archive/Library verification remain pending.
- Fresh hardware re-probe detected `XDJ-XZ`, created a valid 48 kHz stereo 16-bit WAV and archive sidecar, but measured `LIVE_METER_PEAK 0.0`. Signal and listening acceptance failed or lacked routed program audio; do not claim hardware Capture passed.
- Capture-start notification format verified by `LocalNotificationServiceTests`: body is `Recording started - HH:MM`.
- Menu-bar status view now exposes accessibility identifiers for headline/status, last scan, next scan, commands, and archive path (`menuBar.*`) for live-session smoke coverage.
- `bash scripts/package-beta.sh`: pre-commit verification produced a zip and JSON manifest with a matching SHA-256. That artifact identified base `255a6b0`; the final clean candidate must be repackaged after commit, with its manifest treated as the authoritative artifact SHA.
- The extracted zip passed strict signature verification and launched for the current user. This does not replace a clean-user or clean-Mac installation test.
- `swift run setcatcher diagnostics <path>`: writes metadata-only report (counts, paths, activity messages; no track titles/artists).
- Signing: ad-hoc sandboxed local beta. `spctl` rejects it for external distribution and no stapled ticket exists. This Mac has only an Apple Development identity, not Developer ID Application.

The results below from August 7–9 are retained as historical workflow evidence. They are not proof for the current candidate unless explicitly re-run above.

## Manual Beta Results (2026-08-07, Round 1 on this Mac)

| Check | Result | Notes |
| --- | --- | --- |
| Packaged `.app` launches | Pass | `bash scripts/smoke-app.sh`; window check passed; process starts and quits cleanly. |
| Landing route | Pass | Default `selectedRoute = .home` (`AppModel`). Checklist aligned to Home (was incorrectly Protection). |
| Menu-bar item present | Pass | `MenuBarExtra` in `SetCatcherApp.swift`; smoke launch includes menu-bar host. |
| Folder bookmark persistence | Pass | `~/Library/Application Support/SetCatcher/folder-access.json` retains 10 accesses with `bookmarkData` across relaunches on this machine. |
| Archive copies source; sidecar written | Pass | `setcatcher archive` of 1s WAV → `~/Music/SetCatcher/…wav` + `.json`; source SHA-256 unchanged. |
| Diagnostics metadata-only | Pass | CLI diagnostics top-level keys: archiveRootPath, archives, generatedAt, imports, recentActivity, software, totals. No title/artist/tracklist fields. Sidecar has no track titles. |
| Permission / unreachable recovery (unit) | Pass | `FolderAccessStoreTests`, `DiagnosticsReportTests.testProtectedSourceCountExcludesUnreachableRecordingFolders`, Protection attention UI. |
| Unreachable-folder recovery (GUI e2e move/revoke) | Blocked | Needs interactive Finder/revoke on tester Mac; Core + UI wired. |
| Folder-change “Soon” scan timing (GUI) | Partial | Round 2 (2026-08-09): automatic archives from granted Serato Recording while app open (activity `Archived N recordings`); dedicated Next Scan = `Soon` label not eye-confirmed in UI. |
| Library search / import UI | Partial | Round 2 imported real CSV/XML via Core store path; in-app NSOpenPanel click not driven. |
| Real Serato recording folder + history | Pass | Round 2 (see below). |
| Real rekordbox install + XML/history | Pass | Round 2 (see below). Live in-app Rec UI not used; granted `~/Music/rekordbox/Recorded`. |
| Menu-bar during live recording session | Pending | `menuBar.*` accessibility identifiers added 2026-08-13; needs live recording session to confirm watching/recording/saving/saved transitions. |
| Clean-user Gatekeeper / notarized open | Blocked | Ad-hoc only until Developer ID + notarization credentials exist. This Mac has Apple Development only — no Developer ID Application. |

## Round 2 results (2026-08-09)

Tester: Rob (internal). macOS 26.6 (25G72). SetCatcher `0.1.0` / commit `2d0d4f5`. Notarization **skipped** (no Developer ID on this Mac).

### Launch note

- `bash scripts/build-app.sh release` produced a codesigned `.build/SetCatcher.app`.
- `open .build/SetCatcher.app` failed with Launchd/RBS error 163 (sandboxed spawn). Round 2 interactive work used unsandboxed `swift run` / `.build/.../SetCatcherApp` instead. Ad-hoc sandboxed launch on this OS build remains an open packaging issue; archive Core path still proved.

### Session notes (user-testing-plan Round 2)

| Task | Result | Evidence |
| --- | --- | --- |
| Real Serato recording folder | Pass | Prefs `record_location` = `~/Music/_Serato_/Recording`. Serato DJ Pro running. Folder granted in `folder-access.json` for `serato` / `recordings`. |
| Live audio into Serato Recording | Pass | Round 2 used Virtual Audio into Recording path. **Follow-up 2026-08-09 17:09:** real Serato Rec button wrote `Serato Recording 1.aif` (~19s, AIFF, SHA-256 `a1a26366…`). |
| In-app Rec → wait → archive | Pass | Activity: `Recording detected … waiting for Serato Recording 1.aif` then `Archived 1 recording`. Archive `~/Music/SetCatcher/archive/2026-08-09 1710 - Serato DJ Pro - Set.aif` + sidecar; source hash unchanged. |
| Next Scan = Soon (UI eye-check) | Pending | Waiting confirmed in activity; confirm Home/Protection shows **Soon** verbally if not already. |
| NSOpenPanel history import | Pending | Core import Pass earlier; confirm one in-app Import click if not already. |
| Scan / archive copy + sidecar + unchanged source | Pass | CLI + app archive root: source hash unchanged before/after; sidecar JSON has paths/fingerprint/size only (no track titles). Example: `~/Music/SetCatcher/archive/2026-08-09 1606 - Serato DJ Pro - Set.json`. |
| Auto-watch while app open | Pass | Activity log: `Archived 3 recordings` / `Archived 1 recording` for `/Users/…/_Serato_/Recording` without CLI for those batches; later Round2-soon file landed in Library. Periodic scan interval 60s + folder monitor enabled. |
| Library with real volume | Pass | Multiple Serato + rekordbox archives under `~/Music/SetCatcher/` and `…/archive/`; set context attached. |
| Real Serato history export | Pass | Imported `~/Music/SetCatcher/CSV/9-5-25.csv` → **35** tracks, kind `setHistory`, matchable. Sample titles visible (e.g. RCA mixes). |
| Real rekordbox XML | Pass | Imported iCloud `RekordBox.xml` → **580** tracks, kind `collection`, **not** matchable. |
| Collection not mistaken for one set | Pass | `LibrarySessionMatcher`: rekordbox session with empty context → auto-match `nil`; collection `isMatchableToRecording=false`. |
| Manual attach tracklist | Pass | Attached Serato CSV id `B760C075-…` to Serato session `441C2EB0-…`; matched 35 tracks; detach + reattach OK. |
| rekordbox live recording folder | Pass (partial honesty) | rekordbox 7 installed + running (`setcatcher probe`). No in-app Rec path in prefs. Granted `~/Music/rekordbox/Recorded`, archived 8s WAV; source SHA-256 `3695b95d…` unchanged; sidecar `…1612 - rekordbox - Set.json`. |
| Traktor NML | Blocked | No `.nml` found quickly on this Mac. |
| Notarized / Gatekeeper clean open | Blocked | No Developer ID Application identity (`security find-identity` shows Apple Development only). |

### Ratings

- Trust (archive won’t touch sources): **5** (SHA-256 proofs).
- Setup confidence (grant → scan → Library): **4** (blocked sandboxed `.app` open on this Mac; Core/CLI and unsandboxed app OK).

## Round 2 packaging / accounts status (unchanged blockers)

| Item | Status |
| --- | --- |
| `scripts/build-app.sh` / `package-beta.sh` / `notarize-app.sh` | Ready (Developer ID gated). Round 2 used ad-hoc; do not wait on notarization for archive validation. |
| Account client APIs (`/api/devices`, `/api/license`, `/api/diagnostics`) | Implemented; needs deployed admin + service role |
| iPad companion scheme `SetCatcheriPad` | Builds via `xcodegen` + Xcode (iOS 17+) |
| Notarized direct-download | Still blocked — needs Developer ID + notary credentials (Round 4 / distribution gate, not Round 2) |

## Acceptance Criteria

| Requirement | Status | Evidence | Manual Beta Check |
| --- | --- | --- | --- |
| User can install/run SetCatcher on macOS. | Ready for known-Mac internal beta only | Current-user app smoke and extracted-zip launch pass; strict code-signature verification passes | Clean external Gatekeeper launch remains **Blocked** until Developer ID signing, notarization, and clean-Mac verification. |
| User can configure at least one watched recording folder. | Pass | Folder grants for Serato Recording + rekordbox Recorded in Round 2 | **Pass** on this DJ Mac. |
| SetCatcher archives a completed recording without changing the source file. | Pass | Round 2 SHA-256 match for Serato + rekordbox sources | **Pass**. |
| Archived recordings appear in the library. | Pass | Archives + sidecars under `~/Music/SetCatcher/archive/`; set context attach | **Pass** (Library data on disk; GUI click-path not separately scripted). |
| Each archived recording has a metadata JSON sidecar. | Pass | Sidecars beside Round 2 WAVs; fingerprint/size/paths only | **Pass**. |
| Manual rescan can recover recent recordings from watched folders. | Pass | File → Scan Now / CLI `scan` archived stable files | **Pass**. |
| Recording folders trigger automatic protection while the app is open. | Pass | Activity archived from Serato Recording while app open | **Pass** (Soon label not visually confirmed). |
| Serato defaults are detected when folders exist. | Pass | `setcatcher probe` lists `~/Music/_Serato_/Recording`; Serato running | **Pass**. |
| rekordbox installation is detected when available. | Pass | `setcatcher probe`: rekordbox 7 installed + running | **Pass**. |
| Default archive location is `~/Music/SetCatcher`, with Settings support for a custom archive folder. | Pass | Settings `archiveRootPath` → `~/Music/SetCatcher/archive` used in Round 2 | **Pass**. |
| Permission errors are visible and understandable. | Automated with manual follow-up | Scan error tests, Protection attention, diagnostics | GUI move/revoke recovery still **Blocked** e2e. |

## Should-Have Coverage

| Item | Status | Evidence |
| --- | --- | --- |
| Serato default folder detection | Implemented | `DJSoftware`, `SoftwareProbe`, `SupportedDJSoftwareTests`; Round 2 probe confirmed |
| rekordbox installed-app detection | Implemented | Round 2 probe confirmed rekordbox 7 |
| Default archive folder creation | Implemented | `ArchiveService.ensureArchiveRootExists`, app launch refresh path, `ArchiveServiceTests` |
| User-editable archive naming template | Implemented | `AppSettings`, settings UI, `ArchiveServiceTests.testArchiveUsesCustomNamingTemplate` |
| Failure state with plain-language next step | Implemented | `ScanCoordinator.scanErrorDescription`, UI attention states, scanner tests |
| Basic diagnostics export | Implemented | `DiagnosticsReportBuilder`, app export action, CLI `diagnostics` command, `DiagnosticsReportTests`, `scripts/smoke-cli.sh` |

## Known Manual Validation Still Required (Blocked)

- macOS folder picker behavior under a clean user account.
- Unreachable-folder recovery flow end-to-end (move/revoke → Attention → re-choose → clear) in the GUI.
- Next Scan **Soon** label eye-check in the live UI (activity wait path Pass; label not confirmed).
- In-app tracklist import via NSOpenPanel + library search click-path.
- Menu-bar behavior during a live recording session (`menuBar.*` identifiers now available for smoke coverage).
- Process Audio Tap live meter + archive verification with Serato and rekordbox.
- Traktor NML on a machine that has one.
- Notarized Developer ID build path before broad direct-download distribution (Round 4).
- Clean-user and clean-Mac launch of the final notarized candidate. The historical Round 2 RBS/Launchd 163 failure did not recur in the August 29 current-user app smoke or extracted-zip launch, but that is not clean-install proof.

## Local Beta Known-Issues Snapshot (`2d0d4f5` / Round 2)

- **Supported:** Serato DJ Pro, rekordbox, Traktor
- **Partial:** VirtualDJ
- **Manual Setup:** djay Pro, SetCatcher Capture, Pioneer Hardware
- **Unsupported formats:** anything outside watched recording extensions / documented history parsers
- **Parser limitations:** see `docs/integration-status.md` (VDJ plugin research; capture match window partial)
- **Signing / notarization:** ad-hoc sandboxed local beta; **not notarized** (Developer ID absent on this Mac; see `docs/signing-and-notarization.md`). Round 2 did **not** require notarization.
- **Accounts / admin:** optional web app in `admin/` (Clerk + Supabase + Vercel); macOS Settings deep-links via `settings.openAccount` — local protection never depends on it
- **Minimum macOS:** the Mac app is built from `Package.swift`, which sets **macOS 15.0** — the authoritative product minimum. `project.yml` defines only iOS targets (`SetCatcheriPad`, `SetCatcherShareExtension`, both `platform: iOS`); its global `deploymentTarget.macOS: 14.0` is an unused default with no Mac-app target behind it, not a competing minimum. The Process Audio Tap capture path separately requires **macOS 14.2+** as a capability floor. (The earlier "14.2" here conflated that capture-API floor with the product minimum.)
- **Landing route:** Home
- **Folder permission recovery:** Protection / Recovery UI — choose a different folder, or clear saved folder (sources are never deleted)
- **Current packaging caveat:** current-user ad-hoc launch passes, but external beta remains blocked until Developer ID signing, notarization, and clean-Mac launch succeed.
