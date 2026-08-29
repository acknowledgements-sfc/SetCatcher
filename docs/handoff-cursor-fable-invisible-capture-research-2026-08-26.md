# Cursor / Fable 5 Handoff — Invisible DJ App Capture Research

Date: 2026-08-26

Repo:

`/Users/robcmartin/Documents/Claude/Projects/SetCatcher`

Use Fable 5 for research/planning. Do not implement yet unless explicitly asked after the research report.

## Context

DJMemory must become invisible after initial onboarding. A DJ should not have to manually change output/input settings inside Serato, rekordbox, Traktor, VirtualDJ, or djay Pro/2 after setup.

## Current product rule

- Onboarding may request permissions and install DJMemory-owned capture components.
- Runtime must automatically identify the active DJ app and/or connected hardware.
- If verified USB hardware audio is actually heard from XDJ/DJM/all-in-one hardware, capture that.
- If no verified hardware feed is heard and a DJ app is producing audio on the Mac, capture the app automatically.
- If a vendor virtual input is available, DJMemory may use it internally, but the user must not be asked to route the DJ app manually.
- If no audio reaches the Mac, say DJMemory cannot hear the set yet.

## Important correction

Do not treat Serato as special. The same no-manual-routing rule applies to all supported DJ software: Serato, rekordbox, Traktor, VirtualDJ, and djay Pro/2.

## Research task

Investigate MJAudioRecorder, MJRecorderDevice.driver, Record It Audio Device, NoteBurner-style audio drivers, and similar macOS apps that appear to activate a virtual audio device automatically when their app is opened/enabled, deactivate that virtual audio device automatically when their app is closed/disabled, and return the Mac to the previously enabled audio device or the system default.

## Research goals

1. Identify the likely macOS architecture patterns:
   - Core Audio HAL plugin / Audio Server plugin
   - virtual audio input/output device
   - privileged helper or launch daemon/agent
   - app-level routing helper
   - Process Audio Tap
   - ScreenCaptureKit audio
   - aggregate/multi-output device management
2. Determine which pattern can satisfy DJMemory's requirement: invisible runtime capture after initial onboarding.
3. Determine whether a DJMemory-owned driver/helper can capture app audio without requiring DJ software output changes.
4. Compare feasibility across:
   - Serato
   - rekordbox
   - Traktor
   - VirtualDJ
   - djay Pro/2
5. Identify macOS permission/install requirements:
   - Screen Recording
   - microphone/audio capture permissions if relevant
   - helper tool install
   - HAL plugin install location
   - notarization/signing implications
6. Identify legal/licensing constraints:
   - Do not copy proprietary MJAudioRecorder, NoteBurner, Record It, or similar driver code.
   - Do not vendor GPL driver code such as BlackHole unless the license impact is explicitly accepted.
   - libASPL/MIT may be used only with preserved notices if vendored.
7. Produce a recommendation:
   - best architecture for v1 invisible capture
   - backup architecture if app-level capture fails
   - what must be bench-tested with real DJ software
   - what must be built next in the repo

## Critical review bar

Be critical. Do not optimize for legacy macOS. If the only defensible invisible-capture path requires the latest macOS release, recommend that and state the minimum OS clearly.

For every architecture you propose, return evidence sufficient for Codex review:

1. exact macOS API / framework / driver mechanism;
2. exact install location or helper model if applicable;
3. required entitlements, permissions, signing, notarization, and user approval steps;
4. whether capture can target one specific running DJ app/process;
5. whether the DJ must change any setting after onboarding;
6. how DJMemory verifies real audio is being heard;
7. smallest bench test required with real Serato, rekordbox, Traktor, VirtualDJ, and djay Pro/2;
8. known failure modes and how DJMemory should recover invisibly.

Reject any path that requires routine manual DJ-app output/input changes after onboarding.

## Files to read first

- `docs/automation-testing-plan.md`
- `Sources/DJMemoryCore/LiveCaptureRoute.swift`
- `Sources/DJMemoryCore/LiveCaptureRouteResolver.swift`
- `Sources/DJMemoryCore/DJMemoryAudioDriver.swift`
- `Sources/DJMemoryCore/DJAppOutputRouting.swift`

## Deliverable

Write a concise research report and recommendation. Include sources/links. Clearly separate confirmed facts from inferences. Do not claim final driver feasibility until tested with real DJ software.
