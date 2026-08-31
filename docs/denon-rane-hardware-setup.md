# Denon and Rane Hardware Setup

Both vendors reuse Folder Protection, USB Input Capture, and honest **Manual Setup**.
Do not round up to Supported until a non-dev bench passes. See also
[`analog-mixer-setup.md`](analog-mixer-setup.md) for vinyl-only / Session Out pin.

## Denon Engine OS (Prime, SC Live, SC6000, …)

Standalone units write recordings to a folder named **`Sessions`** at the root of the
selected USB/SD (official Prime / SC Live FAQ). That is the PIONEERREC analogue.

### Once

1. Enable / start recording on the unit when you want a set saved on the stick
   (forgetting Record is still possible — same honesty as Pioneer MASTER REC).
2. After the gig, mount the stick or SD on this Mac.
3. In SetCatcher, add **Denon Hardware** and choose the `Sessions` folder (or the stick root
   that contains it).
4. SetCatcher copies stable WAVs; originals stay on the stick. Archive time uses mtime when
   Engine files have no clock.

### Every gig

Mount the media so the granted folder is reachable, then Scan if the volume was late.

### Not automatic

- Engine never pressing Record on the unit
- Engine OS LAN “now playing” / library scrape (research only; same class as PRO DJ LINK)

Laptop + Denon USB: treat like Pioneer dual-route once Core Audio name/manufacturer is
measured. Until then, pick the device explicitly (`manualOnly`) or use the DJ app’s Supported
folder / App audio path.

## Rane (Seventy, Seventy-Two, Twelve, …)

Rane battle mixers are typically Serato DVS. **Serato remains the primary path** (folder +
App audio already Supported).

### Hardware extras (Manual Setup)

- **USB mix feed:** Input Capture only after a live bench records the exact Core Audio name,
  channel count, and which stereo pair is program/session — not the DVS control-tone pair.
- **Session Out RCA** into a second interface: use **Analog Mixer** Choose rec-out (same pin
  as vinyl-only).

### Once / every gig

If you already protect Serato: no extra analog onboarding. If you use Session Out into a
second box: follow [`analog-mixer-setup.md`](analog-mixer-setup.md).

Do not vendor BlackHole or other HAL loopbacks.

## Bench checklist (human)

Keep **Manual Setup** until a non-dev pass.

### Denon

- [ ] Grant `Sessions` on a stick with a real Engine WAV; archive copy; original unchanged
- [ ] Optional: USB Input Capture name + meter + listen when a Denon unit appears as Core Audio

### Rane

- [ ] Serato folder / App audio still works with the mixer connected
- [ ] USB program pair identified (not control vinyl)
- [ ] Session Out → Analog pin path meters and archives
