# Handoff: Native Capture sleep-prevention

**Date:** 2026-08-30  
**From:** Open source devices for SetCatcher (`0cfb3aea-ec38-48d1-bd72-594f0cf53824`)  
**Status:** Ready for a Capture-owning chat — **not started in-tree**

## Why

While Capture is Armed/Recording, laptop sleep kills the take and can drop FSEvents/history ingest. awesome-macos listed KeepingYouAwake / Amphetamine and PlugNPlayMac’s `caffeinate` pattern; SetCatcher must implement stay-awake **natively**, not vendor those tools.

Full priority context: `docs/research-awesome-macos-2026-08-30.md` (§ PlugNPlayMac correction, § Invisibility follow-ups).

## Do

1. Hold `ProcessInfo.beginActivity` and/or `IOPMAssertion` while Capture phase is `.watching` / `.recording` (include Armed-idle only if product treats Armed as “on duty”).
2. Release on Disarm, save-complete idle, and app terminate.
3. Unit-test phase → assertion held/not held.
4. Do **not** shell out to `caffeinate`, vendor KeepingYouAwake, or install PlugNPlayMac.

## Soft overlaps — coordinate before editing Capture

- Codex project takeover plan (`9aa94b74-4362-40fa-b65d-f6bccd95dd02`)
- SwiftUI Hardening Codex Sequence (`46618da5-7940-42a7-83f6-19abe3dc7703`)

Likely touch points: `Sources/SetCatcherApp/AppModel.swift` Capture phase transitions; optional tiny helper under `Sources/SetCatcherCore/` if the mapping is unit-tested without AppKit UI.

## Out of scope for this handoff

- Sparkle
- HAL / BlackHole / Background Music
- Wi‑Fi/display dock heuristics
- Changing Capture route priority
