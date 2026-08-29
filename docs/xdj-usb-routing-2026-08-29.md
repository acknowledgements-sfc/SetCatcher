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
| XDJ-XZ | **5 / 6 (measured Core Audio)** | 4 / 5 | Live 2026-08-29: 8ch @ 44.1 kHz; Core Audio peaks on ch 5/6 (~1.0). ffmpeg first-adjacent was 3/4 — do not trust ffmpeg index order for CaptureService. Gemini 9/10 out of range |
| XDJ-RX2 | 3 / 4 | 2 / 3 | |
| XDJ-RX3 | 5 / 6 | 4 / 5 | |
| DJM-V10 | 11 / 12 | 10 / 11 | |
| DJM-A9 | 9 / 10 | 8 / 9 | |
| DJM-900 / DJM-900NXS | 9 / 10 (or utility 7/8) | 8 / 9 | Utility-dependent |
| CDJ-2000* | n/a | — | Ignore CDJ USB; route into a mixer |

## Conflict with 2026-08-29 live map

Earlier probes saw **XDJ-XZ as 8 channels @ 44.1 kHz** with all digital zero (no confirmed playback).

**Measured pass (2026-08-29T21:35–21:38Z)** with playback active:

- `actualChannels=8` @ 44.1 kHz
- Gemini **9/10** still **out of range**
- **ffmpeg** first adjacent active pair: **3/4** (ch 3–8 looked hot; channel order not trustworthy for Core Audio)
- **Core Audio / AVAudioEngine** dump: ch **5/6** peak ≈ 0.997; ch 1–4 noise floor; ch 7–8 zero
- Core matrix uses **5/6** for XDJ-XZ CaptureService extract
- Listen files on Desktop: `XDJ-XZ-channels-3-4.wav` (and 5-6 / 7-8 copies) — confirm on Studio Display Speakers

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
