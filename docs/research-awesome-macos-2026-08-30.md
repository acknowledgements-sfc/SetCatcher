# awesome-macos vs SetCatcher

**Date:** 2026-08-30  
**Source:** [phmullins/awesome-macos](https://github.com/phmullins/awesome-macos) (`readme.md`, OSS marked with the open-source icon)  
**Scope:** Whether any listed open-source macOS app (or virtual-audio device) should become a SetCatcher dependency, onboarding step, or Capture backend.

## Verdict

**No listed open-source app should be added as a SetCatcher dependency or bundled driver.** The list is consumer macOS software, not a library catalog. SetCatcher already covers the jobs those audio tools exist for (app capture, input capture, folder copy, local library) with Apple APIs and Core code, under constraints the list items break: local-first, no extra packages, sandbox/App Store posture, no source-file mutation, no default audio upload, no extra setup ritual.

## Filter

A listed OSS app is only “of benefit” if it would improve a real SetCatcher surface without violating:

- No new SPM packages without a stated reason
- Audio never uploaded by default; archives stay local
- Source recordings never moved/renamed/deleted
- Capture must not rewrite DJ-app output or system default device
- Honest support labels; no driver install as a Capture prerequisite

## Audio / virtual devices (the only close matches)

| Item | What it is | Benefit to SetCatcher |
| --- | --- | --- |
| **BlackHole** | GPL-3.0 HAL loopback virtual device | **None as product.** Already rejected in `docs/research-invisible-capture-2026-08-26.md`: a loopback only hears audio routed to it; DJ apps often pin USB/controller output; the documented workflow is a manual Multi-Output Device. GPLv3 must not be vendored. `Sources/SetCatcherCore/SetCatcherAudioDriver.swift` already says do not copy BlackHole. |
| **Background Music** | OSS per-app volume + virtual device | Same HAL/routing class. Study-only if someone later audits Core Audio patterns. Do not ship or require it. |
| **eqMac2** | System-wide equalizer | Harmful: mutates what the DJ hears. Out. |
| **Kid3 / Flacon / XLD** | Tagging / encode / decode GUIs | SetCatcher already writes 24-bit/48 kHz WAV plus JSON sidecars. Embedding ID3/Vorbis in the archive file is optional polish, not a reason to wrap these apps. |
| **Cog / Aural / Museeks / IINA / mpv** | Players | Library already reveals the archive in Finder. In-app playback is not Beta 1. |
| **Kap** | Screen recorder | SetCatcher uses ScreenCaptureKit for **application audio**, not a user-facing screen recorder. |
| **ShazamScrobbler / SpotMenu** | Now-playing / scrobble | Wrong source of truth. Tracklists come from DJ history/XML/NML/JSONL, not Shazam/Spotify. Twitch “now playing” stays research-only. |

Paid neighbors on the same list (Audio Hijack, Loopback, Sound Source) are adjacent competitors, not integration targets.

SetCatcher **already** consumes a *vendor* virtual input when it exists and is verified (Serato Virtual Audio) via `VirtualInputDeviceCaptureService` and `AudioInputDeviceCatalog`. That is the allowed virtual-device path: opt-in, already-enabled, never “install BlackHole and re-route your DJ app.”

## Capture route (unchanged)

Leave architecture as-is:

1. Verified USB / hardware input when present
2. Process Audio Tap (macOS 14.2+)
3. ScreenCaptureKit fallback
4. Already-enabled vendor virtual input
5. Honest unavailability

Do **not** add BlackHole, Background Music, or any HAL driver as a Capture backend or onboarding step. Do not treat awesome-macos as a device/hardware catalog; it is apps.

## Other OSS that is adjacent, not load-bearing

Worth remembering later, not wiring in now:

| Item | Notes |
| --- | --- |
| **Sparkle** | Framework that could later power non-MAS auto-update. Not in the tree today. Revisit only when Developer ID + notarized updates are a real milestone. |
| **KeepingYouAwake** (Amphetamine is not OSS) | Idea only: SetCatcher has no `IOPMAssertion` / `ProcessInfo.beginActivity` while Capture is Armed/Recording. Laptop sleep during a gig is a real failure mode. If added, implement natively in the app; do not vendor those apps. |
| **Rclone / Syncthing / Cryptomator** | Match post-beta “remote archive backup after explicit opt-in” in `docs/product/release-boundaries.md`. User-side tools at most; never default, never silent upload. |
| **PlugNPlayMac** | See correction below — desk automation, not a DJ USB helper. Do **not** vendor. |
| **UTM / VirtualBuddy** | Useful as *test VMs* for signed/sandbox Capture, not product features. |
| **Sloth / Unexpectedly** | Operator debug, not user-facing. |
| **Yo** | Notification Center CLI. Already covered by `LocalNotificationService`. |
| **xbar / BitBar** | Menu-bar plugin hosts. SetCatcher already has a native `MenuBarExtra`. |
| **DiskWave** | Disk-usage UX inspiration only; disk-full is already a named Capture/Protection failure. |

Everything else in the list (launchers, editors, IRC, emulators, calendars, etc.) does not map onto Protection, Capture, Library, history ingest, or diagnostics.

## PlugNPlayMac (correction)

[Piero24/PlugNPlayMac](https://github.com/Piero24/PlugNPlayMac) is **not** a USB-audio or DJ-hardware helper. It is a LaunchAgent shell loop that:

- Detects **desk context** via known Wi‑Fi SSID + external display
- Runs **`caffeinate -u -i -d`** while “at desk”
- Opens/closes a configured app list
- Uses **sudo + a stored password** to run `bclm` battery-charge limits

That conflicts with SetCatcher commitments: App Store / sandbox posture, no privileged helpers, no stored admin passwords, no ambient scripts rewriting system power policy. Desk Wi‑Fi/display heuristics also do not match gig venues.

**Do not vendor PlugNPlayMac.** Steal ideas only:

| Pattern | Verdict for SetCatcher |
| --- | --- |
| Stay awake while “on duty” (`caffeinate`) | **Steal** — implement natively while Capture is Armed/Recording (`ProcessInfo.beginActivity` and/or `IOPMAssertion`) |
| Open apps when docked | **Skip** — Login Item / launch-at-login is enough; do not LaunchAgent-open SetCatcher on display attach |
| Wi‑Fi + display as Capture trigger | **Reject** |
| sudo `bclm` / stored password | **Reject** |
| React when DJ USB appears | **Already mostly owned** by `DualRoutePolicy` + Pioneer auto-switch in `AppModel`; optional hardening is a native Core Audio device-list listener if plug-in feels lagged — not this script |

## Invisibility follow-ups (priority)

SetCatcher’s invisibility bar: after onboarding, no routine DJ-app output/input ritual. Capture route stays USB → Process Tap → ScreenCaptureKit → already-enabled vendor VA → honest fail.

| Priority | Follow-up | Why | Where |
| --- | --- | --- | --- |
| **1** | Native sleep-prevention while Capture Armed/Recording | Highest reliability/invisibility ROI; same problem PlugNPlayMac solves with `caffeinate` | **Capture-owning chat** — soft-overlaps Codex takeover / SwiftUI hardening; do not land Capture code from this research chat without handoff |
| **2** | Native Core Audio device-arrival refresh | Tighten DualRoute reactivity if audit shows plug-in is polled/manual-only | Separate small hardening task after #1 |
| **3** | Sparkle for notarized updates | Distribution invisibility, not set-capture | After Developer ID + notarized distribution is real |
| **4** | Capture route / HAL / BlackHole | No change | Already decided; PlugNPlayMac does not revive HAL loopbacks |

### Sleep-prevention handoff (next Capture chat)

**Objective:** Hold a process activity / power assertion while Capture phase is watching or recording (and Armed if product treats armed-idle the same). Release on Disarm, save-complete idle, and app terminate.

**Sketch:**

- Map Capture phase → assertion held/not held in `AppModel` (or a tiny Core helper)
- Prefer `ProcessInfo.beginActivity(options:reason:)` / `IOPMAssertion`; do not shell out to `caffeinate` or vendor KeepingYouAwake
- Unit-test phase → assertion mapping
- Soft-overlap: coordinate with chats `9aa94b74-4362-40fa-b65d-f6bccd95dd02` (Codex project takeover) and `46618da5-7940-42a7-83f6-19abe3dc7703` (SwiftUI Hardening) before editing Capture paths

## Related docs

- `docs/research.md` — Process Tap is product; BlackHole remains out of scope
- `docs/research-invisible-capture-2026-08-26.md` — HAL loopback rejection
- `docs/handoff-cursor-fable-invisible-capture-research-2026-08-26.md` — invisibility product bar
- `docs/product/release-boundaries.md` — post-beta remote backup
- `docs/product/feature-catalog.md` — current Capture / Protection surfaces
