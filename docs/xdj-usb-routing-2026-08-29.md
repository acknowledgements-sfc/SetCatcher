# XDJ / Pioneer USB REC OUT routing — 2026-08-29

**Status:** hypotheses + conflict notes. Not measured product proof.
**Sources:** Codex three-path leave-off; operator QuickTime silence; Gemini/handover matrix at `~/Downloads/pioneer_pipeline_setup-setcatcher.sh` (do **not** vendor into this repo).

## Topology (adopt)

Standalone USB stick (or CDJs into a mixer) plays on the hardware. The Mac records the all-in-one/mixer USB **REC OUT** bus — not a CDJ USB port and not “whatever the system default input is.”

DJMemory already binds a specific Core Audio device UID in `CaptureService`. Global default-input switching (Homebrew `switchaudio-osx` / SwitchAudioSource) is **out of scope** and must not be added.

## Hypothesized REC OUT pairs (1-indexed)

Unverified until a live map shows the pair in-range **and** above the shared `0.02` linear peak (≈ −33.98 dB). Indexes in Core are 0-based (`leftIndex` / `rightIndex`).

| Device | Hypothesized REC OUT | 0-based indexes | Notes |
| --- | --- | --- | --- |
| XDJ-XZ | 9 / 10 | 8 / 9 | Needs ≥10 input channels; Setting Utility may change USB layout |
| XDJ-RX2 | 3 / 4 | 2 / 3 | |
| XDJ-RX3 | 5 / 6 | 4 / 5 | |
| DJM-V10 | 11 / 12 | 10 / 11 | |
| DJM-A9 | 9 / 10 | 8 / 9 | |
| DJM-900 / DJM-900NXS | 9 / 10 (or utility 7/8) | 8 / 9 | Utility-dependent |
| CDJ-2000* | n/a | — | Ignore CDJ USB; route into a mixer |

## Conflict with 2026-08-29 live map

`scripts/map-xdj-input-channels.sh` observed **XDJ-XZ as 8 channels @ 44.1 kHz**, all digital zero. Hypothesized pair **9/10 is out of range** on that stream.

Before treating the matrix as wrong:

1. Confirm USB-stick (or DJ-app) playback ran for the full capture window.
2. Open **XDJ-XZ Setting Utility** and check USB audio / rec-out channel assignment.
3. Re-probe actual `channelCount` (AVFoundation / Core Audio). If still 8, treat 9/10 as wrong **for this driver mode** and trust the live map.

Do not claim USB REC OUT capture is supported until a pair is in-range, above threshold, archived, Library-reconciled, and heard on a **non-XDJ** output (e.g. Studio Display Speakers).

## What the handover got wrong (reject)

- **Mixer downmix ≠ REC OUT selection.** The sample Swift tap bounds-checked indexes 8/9 then wrote a stereo mixer of the **full** hardware format. That does not extract channels 9/10.
- **Second `ObservableObject` recorder + SwiftUI console.** `AppModel` is the only view model; Capture UI already exists.
- **Required `pioneer_recording_config.json` file picker.** Production uses in-process matrix lookup; optional debug dump only.
- **24-bit / 256-buffer archive format.** Keep `CaptureAudioFormat` (16-bit 48 kHz stereo WAV) after extract.
- **QuickTime meters ≠ recorded file.** Operator M4As were exact digital silence. Always set QT **microphone = XDJ-XZ** (or the mixer), then listen on Studio Display Speakers.

## Outcome rules (unchanged from Codex)

1. MASTER REC passes but all Mac USB inputs stay silent → support recordings via MASTER REC + Folder Protection/import; **do not** promise standalone USB stick → Mac capture for that mode.
2. A Mac input pair carries audio → implement/retest explicit channel-pair extract in Core (this workstream).
3. DJ-app Process Tap / SCK passes with audible archive → promote only that verified lane.
4. Meters without archived samples, or audio audible only through live XDJ monitoring, remain **failures**.

## Related evidence

See [live-capture-evidence-2026-08-29.md](live-capture-evidence-2026-08-29.md).
