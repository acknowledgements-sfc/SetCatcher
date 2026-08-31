# Cursor handoff — implementing the DJMemory designs

How to drive Cursor against this repo. The design source is a Figma Make prototype that is **not**
checked out here; the specs below are self-sufficient.

## M14 VirtualDJ plugin work

Artifact A now has its own visible Xcode build surface at
`docs/virtualdj-plugin-scaffold/DJMemoryVirtualDJPlugin.xcodeproj`. It is a
separate C++ `.bundle`; do not add it to `Package.swift` or `DJMemory.app`.
The target references the supplied VirtualDJ SDK at
`/Users/robcmartin/Downloads/VirtualDJ8_SDK_20211003`.

The bundle compiles for arm64 and x86_64 and exports `DllGetClassObject`.
`VDJSDKAdapter.cpp` intentionally centralizes the candidate VDJScript getter
strings. Do not mark M14 Supported or claim the deck/on-air behavior works until
a real VirtualDJ mix writes JSONL and DJMemory imports and matches it. Details:
`docs/m14-vdj-plugin-spec.md` and `docs/virtualdj-plugin-scaffold/README.md`.

Live probe on 2026-08-13 found the sandboxed app's real Apple Silicon plugin
tree under its container at `PluginsMacArm`. The ad-hoc signed startup bundle
was not loaded by the current license session; general/basic plugin loading may
require VirtualDJ Pro. Treat that as the next live-test prerequisite.

---

## What Cursor reads

| File | Role |
| --- | --- |
| `.cursor/rules/*.mdc` | Always-on project rules. Cursor auto-attaches these; you never paste them. |
| `HANDOFF.md` | The authoritative spec — tokens, type mapping, screens §4.1–§4.8, state matrix, non-negotiables. |
| `HANDOFF-2-HOME.md` | Addendum — Home dashboard (§4.9), sidebar sources (§4.10), gaps G7–G9, tasks T12–T13. |

`HANDOFF-2-HOME.md` exists because those two screens were designed after `HANDOFF.md` was written.
Both files are current; neither supersedes the other. **Read both.**

`AGENTS.md` is also here (Codex reads it). Cursor 1.x reads `AGENTS.md` too, but `.cursor/rules` is
the reliable channel, so the rules restate what matters and point at the specs.

---

## Setup

```bash
git clone https://github.com/acknowledgements-sfc/SetCatcher.git
cd DJMemory
swift build          # confirm the baseline is green before Cursor touches anything
open -a Cursor .
```

Then check **Cursor Settings → Rules** lists `djmemory-project`, `djmemory-app-ui`, and
`djmemory-core`. If it doesn't, nothing below will behave as described.

---

## Running a task

Tasks are `T1`–`T13`; T1–T11 are issues #2–#12, T12–T13 are in `HANDOFF-2-HOME.md`. Order and
dependencies are in `HANDOFF.md` §6. **One task per Cursor session, one PR per task.** These screens
are dense; a five-screen diff is not reviewable and you will end up accepting drift.

In Agent mode:

```
Read HANDOFF.md §2, §3, §7 and HANDOFF-2-HOME.md.

Implement T13 — sidebar sources + add-app picker, per §4.10.

Constraints:
- Use existing tokens and Core types only. Do not add a Color(hex:) helper — one exists.
- Do not rename or remove any existing accessibility identifier.
- Add a #Preview for every state in the §4.10 state matrix rows.
- Show me the plan before editing files.

Then run: swift build && swift test
```

`@`-mention the files you want in context rather than trusting retrieval to find them. Ask for the
plan first on anything larger than one view — that is where you catch an invented type name for the
cost of one sentence.

Suggested order for visible progress: **T13** (small, self-contained), then **T4** (folder
reachability — trust-critical, no real dependency on the cosmetic refactors), then **T12** (Home).

---

## Where Cursor will go wrong here

Not hypotheticals — these follow from how the repo and the spec are shaped.

1. **It will invent Core types.** The specs deliberately use the real names (`AppModel`,
   `ArchiveMetadata`, `SetContext`, `TrackPlay`, `ImportedTracklist`, `SessionLibrary`,
   `ProtectionState`). If a diff introduces a new model, check whether the field already exists —
   `durationSeconds` and `fileSize` on `ArchiveMetadata` are the likeliest to get re-invented.
2. **It will rewrite whole files.** `AppModel` is large. A full-file rewrite silently drops
   accessibility identifiers and `@Published private(set)` boundaries. Ask for surgical edits and
   read the diff hunk-by-hunk, not the summary.
3. **It cannot run the app.** `swift build` and `swift test` pass anywhere; launching the macOS UI
   does not. Verification is builds, tests, and `#Preview` coverage. Treat any claim that a screen
   "looks right" as unverified unless you looked at it yourself.
4. **It will drift on copy.** The strings are load-bearing — support labels, the "what is still safe"
   clause, the privacy footer. Paraphrasing them breaks §7. Copy them literally.
5. **It will reach for dependencies.** The package has none, on purpose.
6. **It will build the add-app picker as a custom overlay,** because that is what the prototype does.
   The prototype's menu is absolutely positioned inside the sidebar's scroll container — a limitation
   of the web version, not a design intent. On macOS use `Menu` or `.popover`.

---

## Pre-PR checklist

```bash
swift build 2>&1 | tail -20
swift test  2>&1 | tail -20
git diff --stat                              # unexpected files touched?
git diff | grep -i accessibilityIdentifier   # any identifier removed?
```

Then by eye: a `#Preview` per state on every new view; light and dark both checked; no hardcoded hex
outside the token file; every string verbatim from the spec.

---

## The non-negotiables, short form

Full versions in `HANDOFF.md` §7. Product commitments, not preferences — if a task appears to require
breaking one, the task is wrong.

1. Local-first. 2. Audio files are never uploaded by default. 3. Full tracklists are never uploaded
by default. 4. Admins cannot access user audio or full tracklists. 5. Diagnostics exports are
metadata only. 6. Source recordings are never moved, renamed, or deleted. 7. Support labels are
honest — "Partial" stays "Partial". 8. No dead ends: every failure state has an action.
