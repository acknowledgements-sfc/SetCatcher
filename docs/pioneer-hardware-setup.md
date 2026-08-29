# Pioneer Hardware Setup (M11)

DJMemory does not install Pioneer drivers. Support labels stay capability-specific. Do not round
Manual Setup up to Supported until the matching checklist has an external (non-dev) pass.

## Laptop + XDJ-XZ / CDJs over USB (verified target)

A DJ runs DJMemory on the Mac, connected to an XDJ-XZ or CDJs over USB, playing through Serato or
rekordbox on that laptop. The Mac is in the audio loop the whole time.

1. Grant the Serato or rekordbox recordings folder (Folder Protection).
2. Connect the XZ (or mixer that presents a Pioneer Core Audio input) over USB.
3. Leave Pioneer rig safety nets on **Both** (Settings → Capture). Input Capture auto-selects the
   Pioneer device and records when audio is detected; idle silence saves the take.
4. If the DJ hits Record, Folder Protection archives that file. If they forget, Input Capture still
   archives the USB output. Overlapping files appear as **one set** in Library: DJ-software recording
   primary, Input Capture labeled Hardware backup. Sources are never moved, renamed, or deleted.

This path does **not** cover a booth where master output never reaches the Mac.

### USB HID/audio vs LINK Ethernet

USB-B on the XZ is “audio and control from a computer” (this bench). LINK Ethernet is rekordbox
library sharing, CDJs on channels 3/4, and lighting/video. Serato-on-laptop uses USB HID, not PRO DJ
LINK. If LINK lights are on during the test, that is a separate network — ignore it for this pass.

Do not expect live tracklists from player-status packets. Tracklists still come from Serato or
rekordbox history export / Folder Protection sidecar match. Do not run Prolink Tools, Now Playing,
beat-link, or any virtual CDJ on the same Mac as rekordbox during the test (they conflict; they also
resemble the [8 Aug 2026 advisory](https://alphatheta.com/en/information/important-notice-security-vulnerability-in-pro-dj-link/)
“third party on the network”). Unofficial PRO DJ LINK clients stay Research; see
`docs/research.md`.

## DJM-900 / DJM-V10 / DJM-V10LF
1. Connect USB and install the Pioneer driver.
2. Assign MIX (REC OUT) in Setting Utility.
3. Open Capture, select the DJM, Start/Stop — or use Both so unattended Input Capture runs when the
   DJM is the selected Pioneer input.
4. Import a tracklist from Set Detail when available.

## XDJ-RX2 / RX3 / XZ / AZ — USB MASTER REC (Manual Setup)
Use this when the Mac is **out** of the audio path (standalone hardware-to-house).

1. MASTER REC to USB → PIONEERREC / RECxxx.WAV.
2. Add Pioneer Hardware and choose the stick or PIONEERREC folder. The folder must be granted and
   the drive must be mounted.
3. DJMemory copies stable files; originals stay on the stick.
4. MASTER REC has no clock — archive uses file mtime.

## CDJ-2000 / 2000NXS / 3000
Players do not record the master. DJMemory can protect only what reaches the Mac. Route USB through
this laptop or a DJM, or grant a PIONEERREC folder. A separate standalone mixer whose master never
reaches the Mac is Manual Setup / Research.

## Phase 1 bench (XDJ-XZ as Core Audio input)

Confirmation, not new detection. Auto-select is a name/manufacturer substring (`xdj` / `cdj` /
`djm` / `pioneer`). Update XZ firmware and rekordbox first ([AlphaTheta
support](https://support.alphatheta.com/en-US) plus the 8 Aug 2026 PRO DJ LINK advisory). This bench
is USB Core Audio, not LINK Ethernet.

- [x] XZ firmware and rekordbox are current before the test.
- [x] Confirm the mix is USB Core Audio (Input Capture). If LINK lights are on, ignore that network.
- [x] XZ appears as a Core Audio input over USB. Record the exact device name here when verified.
      Dev-bench 15 Aug 2026: Core Audio `name` is `XDJ-XZ`, manufacturer `AlphaTheta Corporation`,
      UID `USBAudioDevice:AlphaTheta Corporation:XDJ-XZ (2):1110000` (8 input channels). `system_profiler`
      listed transport as virtual; the UID is still USBAudioDevice. Heuristic
      `isLikelyPioneerDJHardware` is true (`xdj` in the name).
- [x] Known-Pioneer auto-select picks it while Input mode is armed.
- [ ] Level metering moves with master output. Dev-bench take had meter peak 0.0 (no program on
      USB master). Binding the selected HAL device (not the system default input) is required;
      that bind shipped in this bench.
- [x] A 24-bit/48 kHz stereo WAV archives through `ingestCapture` and appears in Library.
      `2026-08-15 0548 - DJMemory Capture - Set.wav` is 2 ch / 48000 Hz / 24-bit LE, original
      filename `XDJ-XZ.wav`, `sourceAppID` `djmemory-capture`.
- [ ] Unplug mid-record and microphone permission denied were not run (operator required).
      Disk-full on a 800 KB FAT volume throws `CaptureServiceError.diskFull` (maps to
      `This Mac is out of disk space. Free space, then Capture again.`).

Exit: one input-capture set off the XZ archives cleanly. Keep Pioneer Input Capture labeled
**Manual Setup** until Phase 2 has an **external (non-dev)** pass. This 15 Aug 2026 run is
dev-bench only.

## Phase 2 combined-rig bench

Serato or rekordbox through the XZ on the same Mac, Folder Protection watching the app record
folder, Input Capture unattended on the XZ (Both posture).

- [x] Both paths archive independently; Library shows **one** row with primary + Hardware backup.
      Capture `C65CF2E3-575B-417F-80FE-D701DBEE9815` (`XDJ-XZ.wav`) then a Serato folder archive
      `2026-08-15 DJMemory-xz-bench.wav` within the 15-minute join window. Linker group id is the
      capture (earliest member); primary is `serato`; hardware backup is `djmemory-capture`.
- [x] Both files exist on disk; pre-existing Serato source SHA-256 hashes were unchanged. Folder
      Protection copied; sources were not moved, renamed, or deleted.
- [x] Forgot Record: before the folder file joined, the capture sidecar had no hardware backup
      (`testForgotRecordLeavesCaptureUnlabeledAsBackup`). After join, that same session id stayed
      the Library row id and the Serato file became primary.
- [x] No naming collision: `2026-08-15 0548 - DJMemory Capture - Set` vs
      `2026-08-15 0552 - Serato DJ Pro - Set`. One group, not two Library identities.
- [ ] Unplug / microphone denied still need an operator. Disk-full is mapped (see Phase 1).

15 Aug 2026 (same developer as the morning bench): XZ still enumerated as `XDJ-XZ`; `.build/DJMemory.app` rebuilt with HAL `setDeviceID` bind. Later the same day, App audio Capture (Process Audio Tap) archived Serato (`2026-08-15 0910 - Serato DJ Pro - Set.wav`, `originalFilename` `Serato DJ Pro process audio.wav`, `sourceAppID` `serato`) and rekordbox (`2026-08-15 0941 - rekordbox - Set.wav`, `originalFilename` `rekordbox process audio.wav`, `sourceAppID` `rekordbox`) while playing through the XZ — both 24-bit / 48 kHz stereo. That is the already-Supported app path, not USB Input Capture. No new `XDJ-XZ.wav` / `djmemory-capture` take this pass, so meter / unattended / unplug / mic-denied stay unchecked. **dev operator; Supported not flipped.**

External (non-dev) verification is the gate before Input Capture off the XZ USB master is labeled
Supported. This 15 Aug 2026 run is the **dev** combined-rig bench, not that gate.
