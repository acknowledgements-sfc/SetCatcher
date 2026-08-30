# SetCatcher — Design Handoff (prototype → SwiftUI)

This document hands the SetCatcher UI prototype to an agent working in this repo.

**Target:** `Sources/SetCatcherApp` — SwiftUI, macOS 14+, SwiftPM, no external dependencies.
**Not the target:** porting React code. The prototype is a *visual and behavioural reference*.
Every screen is built in SwiftUI against the existing `SetCatcherCore` types.

Verified against `main` commit `d11d0c8`.

**The prototype repo is not checked out alongside this one.** Prototype filenames below are
provenance notes, not files you can open. **§2–§5 of this document are the authoritative spec.** If
something is genuinely ambiguous, say so in the PR rather than inventing a layout.

---

## 1. Current state of the Swift app

The SwiftUI app is now split across dedicated views under `Sources/SetCatcherApp/Views/` and theme
primitives under `Sources/SetCatcherApp/Theme/`; `ContentView` is the app shell.
Most panes already exist in rough form:

| Pane | Swift view (line) | Status vs prototype |
| --- | --- | --- |
| App shell | `ContentView` | Present. `NavigationSplitView` with the `Route` enum |
| Sidebar | `Sidebar` (159) | Present. Missing per-app status dots and accent swatches |
| Onboarding | `OnboardingView` (51) | **Single sheet** vs prototype's 6-step flow |
| Protection | `ProtectionDashboardView` (556) | Present. Only 2 of 4 headline states |
| Per-app setup | `AdapterDetailView` (764) | Present and fairly complete |
| Library | `SessionLibraryView` (1308) | Present. Two `Table`s, no search |
| Set detail | `SetDetailView` (1618) | Present |
| Tracklist detail | `TracklistDetailView` (1525) | Present |
| Activity | `ActivityLogView` (226) | Present. No `diagnostics` kind |
| Settings | `SettingsView` (329) | Present. 4 of 7 prototype settings |
| Folder recovery | — | **Missing entirely** |
| Design tokens | `Theme/Tokens.swift` | Present and used by the current SwiftUI views |

So this remains a **refinement and extraction** job, not a greenfield build. The remaining work is
primarily feature-state completion and visual refinement:

1. Complete the remaining protection, recovery, settings, and activity-state gaps below.
2. Continue keeping domain logic in `SetCatcherCore` and app composition in dedicated SwiftUI views.

**Out of scope for this repo:** the prototype's Flow Map, Sign In, Account, and Admin Console
screens. Those are design concepts only — do not build them in the app.

---

## 2. Design tokens

Port to `Sources/SetCatcherApp/Theme/Tokens.swift`. Dark is the default appearance; both must work.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `background` | `#F2F2F4` | `#17171A` | Window + sidebar ground |
| `content` | `#FBFBFD` | `#0C0C0E` | Main pane ground |
| `chrome` | `#F6F6F8` @ 72% | `#18181B` @ 66% | Title bar, inspector header (blurred) |
| `foreground` | `#1D1D1F` | `#F2F2F4` | Default text |
| `card` | `#FFFFFF` | `#17181B` | Panel background |
| `elevated` | `#FFFFFF` | `#202024` | Controls, inputs, buttons |
| `secondary` | `#E8E8ED` | `#2A2A2E` | Segmented control track, hover fill |
| `muted` | `#F2F2F7` | `#1E1E21` | Table headers, path chips |
| `mutedForeground` | `#6E6E73` | `#9A9AA1` | Labels, captions, secondary text |
| `primary` | `#0071E3` | `#0A84FF` | Accent, selection, primary buttons |
| `border` | `#D8D8DD` | `#2E2E33` | Panel and control borders |
| `hairline` | black @ 8% | white @ 7% | Row dividers |
| `ok` | `#1D8A4B` | `#32D74B` | Protected, Supported, Matched |
| `warn` | `#A86800` | `#FFD60A` | Needs Setup, Partial, Unmatched |
| `danger` | `#C8362C` | `#FF453A` | Attention Needed, errors |

Light-mode `ok`/`warn`/`danger` are deliberately darkened from the macOS system greens/yellows to
hold 4.5:1 on white. Do not substitute `.green` / `.yellow` / `.red`.

**Geometry and type**
- Corner radius: `5` for controls and panels, `3` for badges and inner chips, `8` maximum anywhere.
- Dividers: 1px hairline, never a full-strength `Divider()` between table rows.
- Body text `12pt`; secondary `11pt`; micro labels `10pt`; page titles `17pt semibold`;
  metric numerals `22pt semibold`.
- Micro label style (used for every panel header and table column header):
  10pt, semibold, uppercase, `+0.09em` tracking, `mutedForeground`.
- Numerals in tables and metrics: monospaced digits (`.monospacedDigit()`).
- Paths and filenames: monospaced (SF Mono), `11pt`, `mutedForeground`, truncated head-first.

**Per-app accent colors** — these do not exist in `DJSoftware` and should live in the theme layer
keyed by `software.id`, used for the sidebar swatch and the waveform tint:

| `id` | Hex |
| --- | --- |
| `serato` | `#4BD07A` |
| `rekordbox` | `#5B8CFF` |
| `traktor` | `#FFB02E` |
| `virtualdj` | `#C88CFF` |
| `djay` | `#FF6F5E` |

---

## 3. Type mapping

The prototype's models were written to mirror `SetCatcherCore`. Use the **Swift** types; do not
introduce parallel models.

| Prototype | Existing Swift type | Notes |
| --- | --- | --- |
| `DjApp` | `DJSoftware` + `SoftwareProbeResult` | `support` → `IntegrationSupportStatus.displayName` |
| `DjApp.recordingFolder` | `AppModel.recordingFolders(for:)` | Prototype shows one; Swift supports many |
| `ArchivedSet` | `LibrarySessionSummary` + `ArchiveMetadata` | |
| `ArchivedSet.event/venue/city/tags/notes` | `SetContext` | Already wired via `saveSetContext(_:)` |
| `ArchivedSet.tracklist` | `LibrarySessionSummary.matchedTracklist` | |
| `ArchivedSet.tracks` | `LibrarySessionSummary.trackCount` | Show `—` when unmatched; Swift returns `0`, so branch on `matchedTracklist == nil` |
| `Tracklist` | `ImportedTracklist` | `kind` → `ImportedTracklistKind` |
| `Track` | `TrackPlay` | `played` → `startTime` (optional) |
| `ActivityRow` | `ActivityEvent` | See gap G1 |
| Settings | `AppSettings` | See gap G4 |

### Gaps that require `SetCatcherCore` changes

Each of these is a real API gap, not a UI detail. Handle them in T4.

- **G1 — `ActivityEventKind` has no `diagnostics` case.** The design logs diagnostics exports as
  their own kind. Add `case diagnostics`. `ActivityEvent` is `Codable`, so decode must tolerate
  older logs; the enum is `String`-backed, so add a fallback in `init(from:)` like
  `ImportedTracklist` already does for `kind`.
- **G2 — No protection-state enum.** `AppModel.headlineStatus` returns only `"Protected"` /
  `"Needs setup"`. The design needs four states. Add
  `enum ProtectionState { case protected, needsSetup, scanning, attentionNeeded }` and derive it:
  `scanning` when `isScanning`; `attentionNeeded` when any `FolderAccess` URL fails to resolve;
  `needsSetup` when any probed app has no recordings folder; else `protected`.
- **G3 — No folder reachability check.** `FolderAccess` records a URL and bookmark but nothing
  reports "the volume is gone". This is what makes the whole Attention Needed / recovery path
  possible, and it is the single highest-value gap in the list. Add a reachability probe
  (resolve the security-scoped bookmark, then `FileManager.fileExists`) exposed per `FolderAccess`.
- **G4 — `AppSettings` is missing three toggles** the design specifies: `verifyCopies`,
  `notifyAfterArchiving`, `launchAtLogin`. All properties are `let`; adding fields needs
  `Codable` defaults so existing `settings.json` still decodes.
- **G5 — `setupState(for:)` returns raw strings** (`"Watching"`, `"Needs folder access"`, …).
  Convert to an enum so status tiles can pick a tone without string comparison.
- **G6 — `IntegrationSupportStatus.research`** has no prototype equivalent. Style it like
  `manualSetup` (neutral badge) and label it "Research".

---

## 4. Screen specs

Only the deltas from the current Swift implementation are listed. Anything not mentioned here keeps
its current behaviour.

### 4.1 App shell
- Replace raw `String` route tags with a `Route` enum (`protection`, `library`, `activity`,
  `settings`, `app(String)`, `recovery(String)`).
- Sidebar rows: 3px accent swatch for DJ apps, trailing status dot (ok/warn/danger/info,
  pulsing while scanning), and a count badge on Library.
- Sidebar sections: `SetCatcher` → Protection, Library, Activity; `DJ Apps` → one row per probe
  result; footer → a status strip (state + one-line detail) above Settings.
- Sidebar uses `.background(.ultraThinMaterial)`; main pane uses the opaque `content` token.
- Keep every existing `.accessibilityIdentifier` — the smoke tests in `scripts/` depend on them.

### 4.2 Protection dashboard
- Headline block: 40pt icon tile, state name, one-sentence explanation, and inline fix buttons.
  All four states of G2, each with its own icon and tone. Copy:
  - *Protected* — "Your sets are being backed up automatically."
  - *Needs Setup* — "Choose a recordings folder so SetCatcher can protect your sets."
  - *Scanning* — "Checking watched folders for new recordings."
  - *Attention Needed* — "A saved folder is unavailable, so new sets are not being archived."
- `Attention Needed` renders a `Fix <App>` button per unreachable folder → recovery route.
- Three metric tiles: Protected Sources, Archived Sets, Imported Histories.
- Source rows: accent bar, name, support badge, state dot + `state · scanned <when> · N sets`,
  path chip (tinted `danger` when unreachable, `warn` when unset), then
  `Setup` / `Fix Folder` / `Scan Now` + `Choose Folder` + `Manage`.
- Empty state when no folder is configured anywhere: `ContentUnavailableView` is fine, but it must
  carry both actions (`Choose Folder`, `Browse DJ apps`).
- Footer line: "Audio files and full tracklists stay on this Mac. Nothing is uploaded."

### 4.3 Per-app setup
Closest to done already. Deltas:
- Four status tiles in one row: **State**, **Application**, **Recordings**, **History** (uses G5).
- Danger banner above the tiles when the folder is unreachable, with `Start Recovery`.
- Folder rows keep choose/reveal/clear but gain an inline reason line when broken
  ("volume GIG-SSD is not mounted").
- Track History section needs a real empty state, not an empty list.
- Privacy panel (3 checked lines) in the right column under Latest Scan Result.
- Setup steps are numbered, and Partial / Manual Setup / Research apps state the caveat inline.

### 4.4 Library
- Two `Table`s become a **segmented switch** (Archived Sets / Imported Tracklists) rather than
  stacked tables, with the detail pane as a fixed 352pt right-hand inspector.
- Add a search field filtering recording name, event, venue, city, tags, and app.
- Add a **date filter** (All / Today / This week / This month) on `ArchiveMetadata.detectedAt`
  for sets, and on import/match/`playedOn` dates for tracklists.
- Archived Sets columns: Recording (waveform + name + `event · venue, city`), Date, App (swatch +
  name), Tracks, Duration, Size, Matched Tracklist (badge).
- Distinct empty states for "no archived sets yet" vs "nothing matches <query>".
- Set inspector: waveform strip, facts panel, source/archive paths with both Reveal buttons,
  editable Event/Venue/City/Tags/Notes + Save, matched-tracklist preview with Detach, manual picker
  with Apply Match, and a related-activity list.
- Tracklist inspector: metadata, source file + reveal, track search, track table (show set date on
  tracks when `playedOn` is stamped from a matched archive).
- **Waveform:** the prototype draws a deterministic seeded bar chart, *not* real audio analysis.
  Reproduce that — hash the filename, draw 18–80 bars. Do not add `AVFoundation` sample reading.

### 4.4b Capture (product behavior)
- **Auto-arm:** when App audio mode finds a shareable DJ app, arm automatically (`autoArmOnDJAppFound`,
  default on). Explicit Disarm suppresses re-arm until Arm or mode change.
- **Auto-input:** in Input device mode while armed (not recording), auto-select Pioneer/DJM when it
  appears. Do not force-switch away from Input device when a DJ app is found.
- **Format:** Capture writes **24-bit / 48 kHz** stereo WAV (app audio and input device).
- **History autopull:** after each successful archive (Capture or folder scan), look in that app’s
  known history folder(s) for a nearby export and import + match locally. Soft-fail if none found;
  manual Import remains available.

### 4.4c Dual-route Pioneer (laptop + USB)

Target rig: SetCatcher on the Mac, Serato or rekordbox on that Mac, XDJ-XZ or CDJs over USB. The Mac
stays in the audio loop. Pure hardware-to-mixer rigs where no audio reaches the Mac stay labeled.

- **Both (default):** Folder Protection watches the DJ-app record folder. When Pioneer USB input is
  present, Input Capture auto-selects it and records on audio / saves on idle silence. Forgetting
  Record still produces an archive.
- Overlapping folder and input archives are **one Library row**. DJ-software file is primary; Input
  Capture is **Hardware backup**. Capture-only (forgot Record) is the set, not a backup. Identity is
  the earliest member `sessionID`.
- Copy: `Watching the XDJ-XZ input. Recording starts when audio is detected; idle silence saves the
  take automatically. Folder Protection still watches recording folders.`
- Hardware backup body: `Caught from the XDJ-XZ USB input. The source recording was not moved,
  renamed, or deleted.` (device name from the capture filename).
- Join notifications: `Hardware backup attached to this set.` / `{App} recording attached as the
  primary file.`
- Changing dual-route posture never deletes archives. Folder Protection of granted folders is never
  turned off.
- USB `PIONEERREC` and CDJs into a mixer that never reaches the Mac stay **Manual Setup**.

### 4.5 Activity
- Filter segmented control: All / Scans / Archives / Imports / Errors / Diagnostics (needs G1).
- Error rows get a `danger`-tinted row background and a next-action button routing to recovery.
- Footer: "Exported diagnostics contain paths, timings, and error messages only — no audio and no
  tracklist contents."

### 4.6 Settings
- Rows in a Scanning panel: automatic scanning, scan interval, verify each copy, notify after
  archiving, launch at login (needs G4) — each with a one-line explanation under the title.
- Capture panel: auto-arm when a DJ app is running (maps to `autoArmOnDJAppFound`); Pioneer rig
  safety nets picker (`dualRoutePosture`: Both / Folder primary, Input on-demand / Folder only /
  Input only) with the selected explanation; note that Capture writes 24-bit / 48 kHz and stays
  local. Changing posture never deletes archives.
- Scan interval description text changes per selection.
- Archive panel: folder field + Change, naming template + Reset, and a **live** example filename.
- Current State panel: archive folder, protected sources, archived sets, imported tracklists,
  archive size on disk, version.
- Account panel: placeholder copy + the three privacy guarantees. No sign-in implementation.

### 4.7 Onboarding
Replace the single sheet with a 6-step flow: Welcome → DJ Apps → Folder Access → Archive → History
→ Ready. Step rail at top with completed checks, Back / Skip setup / Continue footer. `Continue` is
disabled until each step's requirement is met (≥1 app; ≥1 recordings folder granted). Finishing
calls the existing `completeOnboarding(destinationAppID:)` and kicks a scan.

### 4.8 Folder recovery (new)
Four phases in one view: **problem** (what broke, what is still safe, details panel, three exits) →
**choosing** (folder list with mounted/not-mounted badges) → **recovered** (catch-up scan result) or
**cleared** (folder unset, warn state). Reachable from Protection, per-app setup, Activity error
rows, and the sidebar. Depends on G3.

---

## 5. State matrix

Every state below must be representable. Add a `#Preview` per state.

| Group | States |
| --- | --- |
| Protection headline | Protected · Needs Setup · Scanning · Attention Needed |
| Support badge | Supported · Partial · Manual Setup · Research |
| Folder | Set & reachable · Set & unreachable · Not set · Optional-not-set |
| Tracklist match | Matched · Unmatched |
| Tracklist kind | Set History · Collection |
| Empty | No sources · No archived sets · No search results · No tracklists · No activity |
| Activity kind | scan · archive · importTracklist · error · diagnostics |

---

## 6. Ordered task list

One PR per task. Each task assumes the previous one merged. Every task must keep
`swift build`, `swift test`, and `bash scripts/smoke-app.sh` green, and must not break existing
`.accessibilityIdentifier` values.

**T1 — Theme layer.** Add `Sources/SetCatcherApp/Theme/Tokens.swift` with the §2 color set (light +
dark via `NSColor(name:dynamicProvider:)`), radius/spacing/type constants, the micro-label
`ViewModifier`, and the per-app accent map. No view changes yet. *Done when:* tokens compile and a
preview renders both appearances.

**T2 — Split `ContentView.swift`.** Move each of the 24 views into
`Sources/SetCatcherApp/Views/<Name>.swift`, `internal` instead of `private`, no behaviour change.
Introduce the `Route` enum from §4.1. *Done when:* no file over ~250 lines, behaviour identical.

**T3 — Primitives.** `Panel`, `Badge(tone:)`, `StatusDot`, `PathChip`, `MetricTile`, `KeyValueRow`,
`EmptyStateView`, `Waveform`, plus button styles for primary/secondary/ghost/danger. Replace the
ad-hoc `RoundedRectangle`/`.quaternary` call sites. *Done when:* no raw hex or `cornerRadius:`
literal outside `Theme/`.

**T4 — Core gaps.** Implement G1–G5 in `SetCatcherCore` with unit tests: `diagnostics` activity kind
with legacy-decode fallback, `ProtectionState`, folder reachability probe, three new `AppSettings`
fields with `Codable` defaults, `setupState` as an enum. *Done when:* `swift test` covers old
`settings.json` and old activity-log JSON still decoding.

**T5 — Protection dashboard.** All four headline states, metric tiles, source rows, empty state.

**T6 — Per-app setup.** Status tiles, unreachable banner, folder-row reasons, history empty state,
privacy panel.

**T7 — Library.** Segmented switch, search, inspector layout, waveform, both empty states.

**T8 — Activity + Settings.** Filters, error-row treatment, the three new toggles, live filename
example, Current State panel.

**T9 — Onboarding flow.** Six steps, gated Continue, wired to `completeOnboarding`.

**T10 — Recovery flow.** All four phases, reachable from all four entry points.

**T11 — Previews and polish.** A `#Preview` per state in §5, both appearances, hover and focus
states, keyboard focus order.

### Prompt template

> Read `HANDOFF.md` §2, §3, §4.<n>, and §7. Implement **T<n>** in
> `Sources/SetCatcherApp`. Use the existing `SetCatcherCore` types listed in §3 — do not create
> parallel models. Use only tokens from `Theme/Tokens.swift`; no raw hex, no `cornerRadius:`
> literals, no `.green`/`.red`/`.yellow`. Preserve every existing `.accessibilityIdentifier`.
> Add a `#Preview` for each state listed in §5 that this screen owns. Run `swift build`,
> `swift test`, and `bash scripts/smoke-app.sh` before you finish.

---

## 7. Non-negotiables

Product rules that must survive implementation. They are the reason the app exists.

1. **Local-first.** No network calls for archiving, scanning, or tracklist parsing.
2. **No audio upload, ever, by default.** Say so in Settings, per-app setup, and onboarding.
3. **Full tracklists stay on the Mac** unless the user explicitly exports them.
4. **Source files are never moved, renamed, or deleted** — only copied.
5. **Honest support labels.** Never present Partial, Manual Setup, or Research as Supported.
6. **No dead ends.** Every error state names what happened in plain language and offers at least
   one button that resolves it.
7. **Diagnostics are metadata only** — paths, timings, counts, error codes. No audio, no track
   titles.
8. **Native, quiet, dense.** No marketing hero sections, no gradients, no decorative
   illustrations, radii ≤ 8.
