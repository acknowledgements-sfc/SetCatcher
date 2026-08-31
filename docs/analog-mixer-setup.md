# Analog Mixer + Turntables Setup

SetCatcher does **not** claim invisible Capture for vinyl-only rigs. There is no DJ app
process to tap. Support stays **Manual Setup** until a non-dev bench passes.

Product bar: **one honest setup, then unattended on the pin**. Every gig after that should
not reopen Capture unless the cable or interface is missing.

## Once (booth — Mac stays in the loop)

1. Run a cable from the mixer **REC OUT / SESSION OUT / RECORD** (not booth, not headphones,
   not a microphone) into this Mac’s interface, or use the mixer’s USB audio if it has one.
2. In SetCatcher, open **Analog Mixer** and **Choose rec-out**. That pins the Core Audio input.
3. Grant microphone / input permission when macOS asks.
4. Leave Analog Mixer armed (default after pin). Recording starts when the mix is heard; idle
   silence saves the take.

## Once (dump — Mac is out of the booth)

1. Record the set on a handheld / mixer USB stick.
2. After the gig, mount that drive and **Choose dump folder** on Analog Mixer. SetCatcher
   copies stable files; originals stay put. Archive time uses file modification date.

## Every gig

- **Booth:** plug in the same interface and play. If the pinned device is missing: plug it in
  or Choose rec-out again. You do not press Record in a DJ app.
- **Dump:** mount the recorder or stick so the granted folder is reachable, then Scan if the
  volume was late.

## Never automatic

- Analog tracklists (import later if you have one)
- Guessing which USB box is rec-out (Focusrite / Tascam / Zoom stay manual-only until pinned)
- Capturing house PA from a room mic (built-in / Bluetooth / Continuity stay blocked)

## Load-bearing copy

Use these strings in onboarding, Adapter, Capture, and Home:

- `Analog Mixer is Manual Setup. There is no DJ app folder to watch.`
- `Once: connect mixer REC OUT or SESSION OUT to this Mac, then Choose rec-out. After that, SetCatcher records when audio is detected and saves on idle silence.`
- `This records the mixer rec-out, not a microphone. No tracklist is attached unless you import one.`
- `Do not use booth, headphones, or a built-in mic. Those are not the set.`
- `The pinned rec-out is missing. Plug in {device name}, then Refresh. Everything already in your archive is safe.`
- `The Mac is out of the mix. After the set, grant the folder on your recorder or USB stick. SetCatcher copies files and leaves the originals unchanged.`
- `Listening to {device name}. Recording starts when audio is detected; idle silence saves the take automatically.`
- `Analog Mixer needs a rec-out or a dump folder before SetCatcher can protect vinyl sets.`

## DVS on the same mixer

If turntables run Serato or Traktor DVS, keep that DJ app as the software source. Analog Mixer
is the vinyl-only or rec-out backup path — not a second auto-route over Pioneer DualRoute.

## Bench checklist (human)

Keep **Manual Setup** until a non-dev pass.

- [ ] Rec-out → interface → pin → meter moves with program
- [ ] Operator listens and confirms the take is the mix (not phono/control tone)
- [ ] 24-bit / 48 kHz stereo WAV archives into Library as the set (not a hardware backup)
- [ ] Unplug mid-record: missing-device copy + Refresh / Choose rec-out
- [ ] Microphone permission denied offers System Settings
- [ ] Dump folder: copy a WAV in, scan, original unchanged
