# Reference apps: virtual audio device install and lifecycle

**Access date:** 2026-08-26
**Worker:** 1 (reference-apps evidence)
**Scope:** MJAudioRecorder / `MJRecorderDevice.driver`, Record It Audio Device, NoteBurner-style Mingjie drivers, and comparable macOS recorders with public source or vendor documentation.
**Out of scope:** Final DJMemory architecture recommendation; DJ-app-specific routing claims beyond what each source supports.

---

## 1. Scope and method

### Questions addressed

How do MJAudioRecorder, `MJRecorderDevice.driver`, Record It Audio Device, NoteBurner-style tools, and comparable macOS recorders **appear** to install and manage virtual audio devices automatically—and which behaviors are **documented** versus **inferred**?

### Method

- Prefer **Apple Developer Documentation**, **vendor FAQ/support pages**, and **public source repositories** with direct URLs.
- Use **community threads** (Apple Community, MacRumors) only for file paths and lifecycle observations tied to a specific product; label those **INFERRED** unless corroborated by a vendor page.
- Do **not** treat bundle inspection, EtreCheck dumps, or secondary blogs as confirmed proprietary internals.
- Separate **documented capability** from behavior that still needs a **clean-Mac bench test**.
- Record **license** constraints for any pattern DJMemory might later adopt (BlackHole GPLv3 not vendorable; libASPL MIT with preserved notices).

### Evidence labels

| Label | Meaning |
|-------|---------|
| **CONFIRMED** | Stated on an official vendor page, Apple documentation, or public repo README/source the repo links to. |
| **INFERRED** | Reasonable from multiple independent user reports, naming conventions, or analogous public implementations—not stated by the proprietary vendor. |
| **UNKNOWN** | No primary public source; requires local inspection or bench test. |

---

## 2. Claim table

| Product | Label | Claim | Primary URL | Evidence location | DJMemory relevance |
|---------|-------|-------|-------------|-------------------|-------------------|
| MJRecorder / NoteBurner / Sidify | **CONFIRMED** | Recording driver installs as HAL plugin at `/Library/Audio/Plug-Ins/HAL/MJRecorderDevice.driver`. | [NoteBurner sound FAQ](https://www.noteburner.com/faq-tips/solution-to-make-mac-sound-work-again.html) | “Method Two” Terminal step: `sudo rm -rf /Library/Audio/Plug-Ins/HAL/MJRecorderDevice.driver` | HAL plug-in path is the standard install location for user-space virtual devices. |
| MJRecorder / NoteBurner / Sidify | **CONFIRMED** | User-visible device name in Sound settings is **MJAudioRecorder** (community name for the same driver). | [Apple Community removal thread](https://discussions.apple.com/thread/251316359) | Accepted answer: delete `MJRecorderDevice.driver` from HAL; thread title/question refer to “MJAudioRecorder”. | DJMemory must not assume vendor virtual device names map 1:1 to bundle folder names. |
| MJRecorder | **CONFIRMED** | Associated LaunchDaemon plist: `/Library/LaunchDaemons/com.mingjie.mjrecorder.agent.plist`. | [Apple Community removal thread](https://discussions.apple.com/thread/251316359) | Accepted answer edit: also delete `com.mingjie.mjrecorder.agent.plist`. | Shows some Mingjie deployments use a **LaunchDaemon** helper, not only the `.driver` bundle. |
| MJRecorder agent | **CONFIRMED** | Daemon executable path reported as `…/MJRecorderDevice.driver/Contents/MacOS/MJRecorder-agent`. | [Apple Community EtreCheck thread](https://discussions.apple.com/thread/255387801) | Quote of EtreCheck LaunchDaemon entry with `Executable:` path. | Helper may live **inside** the driver bundle; uninstall docs often omit it. |
| MJRecorder | **CONFIRMED** | Sidify documents the same driver path for playback recovery after use. | [Sidify Mac sound FAQ](https://www.sidify.com/faq-fix-mac-no-playback-sound-after-installing-sidify.html) | Step 2 Terminal command targets `MJRecorderDevice.driver`. | Same third-party driver stack reused across “converter/recorder” vendors. |
| MJRecorder | **CONFIRMED** | NoteBurner documents in-app “Reinstall Record Driver” and manual uninstall via Terminal, then **restart NoteBurner** (implying reinstall on next launch). | [NoteBurner sound FAQ](https://www.noteburner.com/faq-tips/solution-to-make-mac-sound-work-again.html) | “Method One: Directly Reinstall Record Driver”; “restart NoteBurner program”. | Driver lifecycle is **app-managed at install time**; public docs do not describe invisible per-session routing. |
| MJRecorder | **CONFIRMED** | NoteBurner Failed **1201** troubleshooting: uninstall recording driver, restart app. | [NoteBurner Spotify FAQ](https://www.noteburner.com/faq-sp-audio-converter.html) | Q11 note under Failed 1201. | Confirms driver is on the critical path for “Record Mode” capture. |
| MJRecorder | **INFERRED** | Developer/manufacturer appears as **Guilian Xiao** / **Mingjie** in system reports; bundle id `com.mingjie.mjrecorder.device` cited on third-party catalog. | [MacRumors Ventura background thread](https://forums.macrumors.com/threads/what-is-the-guilian-xiao-application-that-just-appeared-in-allow-in-background-after-update-to-ventura-13-0-1.2370180/) | `sfltool` output shows `com.mingjie.mjrecorder.agent`. | Signing identity and bundle IDs matter for Gatekeeper and Background Items UI. |
| MJRecorder | **INFERRED** | Driver can leave Mac **without speaker playback** until driver removed + reboot; suggests default-output or routing side effects. | [NoteBurner sound FAQ](https://www.noteburner.com/faq-tips/solution-to-make-mac-sound-work-again.html) | FAQ premise: “sound stopped working … after using NoteBurner”. | Any DJMemory-owned routing must **restore output**; this vendor stack is a negative reference for silent recovery. |
| MJRecorder | **UNKNOWN** | Whether enable/disable/quit automatically switches system default output, creates aggregate/multi-output, or restores previous device. | — | No Mingjie/NoteBurner primary doc found for routing automation. | Core “invisible capture” question—needs bench test (§6). |
| MJRecorder | **UNKNOWN** | Whether capture is **process-targeted** or requires the music app to play to a specific output device. | — | NoteBurner Q21 only says an **audio-output device must exist** for Spotify to play—not how audio reaches the driver. | Cannot infer DJ-app routing for Serato/rekordbox/Traktor/VDJ/djay from this driver alone. |
| Record It | **CONFIRMED** | App Store listing: system audio recording requires separate download/install of **`RecordItAudioDevice`** driver. | [Record It on Mac App Store](https://apps.apple.com/us/app/record-it-screen-recorder/id1339001002) | App description: “to record system audio please download the audio driver RecordItAudioDevice first”. | Confirms **two-step** onboarding (app + driver pkg), not driver-free capture. |
| Record It | **CONFIRMED** | Public distribution name of extension: **Record It Audio Device**; separate installer **`RecordItAudioDevice.pkg`**. | [Michele Pasin blog (2021)](https://www.michelepasin.org/blog/2021/08/30/recordit-plugin/index.html) | Steps 1–2: pkg name; “virtual audio input device”. | Secondary source only—vendor product page (`buildtoconnect.com`) returned 404 on access date. |
| Record It | **INFERRED** | HAL bundle likely `RecordItAudioDevice.driver` under `/Library/Audio/Plug-Ins/HAL/` (by pkg naming convention; same pattern as `FilmageAudioDevice.driver`). | [Filmage uninstall help](https://www.filmagepro.com/help/uninstall-filmage-audio-device-from-Mac) | Filmage (same developer ecosystem per App Store responses) documents `FilmageAudioDevice.driver` in HAL. | Exact Record It bundle filename needs local install verification. |
| Record It | **INFERRED** | Workflow documented by third party requires **manual** aggregate device, **DAW/app output → Record It**, and **system output → aggregate**—not automatic invisible routing. | [Michele Pasin blog (2021)](https://www.michelepasin.org/blog/2021/08/30/recordit-plugin/index.html) | Steps 3–7 (Audio MIDI Setup aggregate; Ableton output to Record It). | Strong evidence Record It path is **explicit routing**, not “open app and forget”. |
| Record It | **UNKNOWN** | LaunchDaemons/LaunchAgents, privileged helper labels, quit/crash/reboot restoration, `coreaudiod` reload behavior. | — | No Build to Connect primary install guide retrieved. | Needs clean-Mac install inventory (§6). |
| NoteBurner-style (general) | **CONFIRMED** | “Record Mode” / virtual sound-card recording is a documented product pattern; macOS FAQ ties it to **`MJRecorderDevice.driver`**. | [NoteBurner sound FAQ](https://www.noteburner.com/faq-tips/solution-to-make-mac-sound-work-again.html) | Methods One/Two for Recording Driver. | Category behavior: install HAL once, capture while converter runs—**not** documented as per-DJ-app tap. |
| NoteBurner-style | **INFERRED** | Routine DJ-app output changes **likely still required** unless the DJ app already plays to system default and the driver intercepts default output—**not documented**. | [NoteBurner Spotify FAQ](https://www.noteburner.com/faq-sp-audio-converter.html) | Q21: user must ensure **audio-output device** works for Spotify playback before conversion. | Supports treating converter-style HAL as **fragile** for post-onboarding invisibility across five DJ apps. |
| BlackHole (comparable, GPL) | **CONFIRMED** | HAL install: `/Library/Audio/Plug-Ins/HAL/BlackHoleXch.driver`; uninstall + `sudo killall -9 coreaudiod`. | [BlackHole README](https://github.com/ExistentialAudio/BlackHole/blob/master/README.md) | “Uninstallation Instructions”; “Manually Uninstall”. | Pattern for HAL reload; **GPLv3—cannot propose vendoring** into DJMemory. |
| BlackHole | **CONFIRMED** | Hear-while-record requires user-created **Multi-Output Device** and setting it as system output—manual. | [BlackHole README](https://github.com/ExistentialAudio/BlackHole/blob/master/README.md) | “Record System Audio” section + FAQ on multi-output. | Baseline: HAL loopback alone does **not** satisfy invisible capture. |
| libASPL (comparable, MIT) | **CONFIRMED** | Reference install script copies `*.driver` to `/Library/Audio/Plug-Ins/HAL/` then restarts audio server via `launchctl kickstart -k system/com.apple.audio.coreaudiod` with **`killall -9 coreaudiod` fallback**. | [libASPL `examples/install.sh`](https://github.com/gavv/libASPL/blob/main/examples/install.sh) | `install` case: copy to HAL; restart block. | Transferable packaging pattern; MIT license requires preserved notices if vendored. |
| libASPL | **CONFIRMED** | Library license: **MIT**; Apple sample fragments under separate Apple MIT notices. | [libASPL README](https://github.com/gavv/libASPL/blob/main/README.md) | “License” section. | Only MIT libASPL path is license-compatible for DJMemory driver research. |
| LitLink (comparable, public product docs) | **CONFIRMED** | Companion app toggling **System Audio Passthrough** auto-creates multi-output device, **sets system default**, restores on uninstall. | [LitLink product page](https://litpads.app/litlink) | “System Audio Passthrough” / uninstall sections. | Documents **automation layer above HAL**—what proprietary recorders may also do but rarely document. |
| Omi Recorder (comparable vendor doc) | **CONFIRMED** | Driver: `OmiRecorderAudioDriver.driver` in HAL; uninstall may use `sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod` **or reboot**; separate **Omi Recorder Aggregate Device** in Audio MIDI Setup. | [Oka Apps install/uninstall guide](https://okaapps.com/blog/6234484ebbd93f236a277dd1) | Uninstall + “Remove the Omi Recorder Aggregate Device” sections. | Shows split between **driver file** and **user-visible aggregate** lifecycle. |
| Apple Core Audio Tap (comparable, Apple) | **CONFIRMED** | `AudioHardwareCreateProcessTap` + aggregate device; minimum **macOS 14.2** in sample doc body; requires **`NSAudioCaptureUsageDescription`**. | [Capturing system audio with Core Audio taps (Apple doc JSON)](https://developer.apple.com/tutorials/data/documentation/coreaudio/capturing-system-audio-with-core-audio-taps.json) | Overview + “Configure the sample code project”. | Driver-free **per-process** capture path; no HAL install for tap-only designs. |
| Apple Core Audio Tap | **CONFIRMED** | Taps can target **specific processes**, be public/private, and optionally **mute process output** to speaker (`CATapDescription` fields in sample). | [Capturing system audio with Core Audio taps (Apple doc JSON)](https://developer.apple.com/tutorials/data/documentation/coreaudio/capturing-system-audio-with-core-audio-taps.json) | Overview paragraph on processes, private taps, mute behavior. | The only Apple-documented API in this set for **single-app** capture without DJ output menus. |
| coreaudiod reload | **CONFIRMED** | `sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod` **failed** on Sonoma 14.4+ with SIP enabled; forum reporter says `sudo killall coreaudiod` succeeded. | [Apple Developer Forums thread 748228](https://developer.apple.com/forums/thread/748228) | Original post + reply “killall worked”. | Install scripts must plan for **reboot fallback** on recent macOS. |
| coreaudiod reload | **CONFIRMED** | BlackHole documents **`sudo killall -9 coreaudiod`** after HAL file delete. | [BlackHole README](https://github.com/ExistentialAudio/BlackHole/blob/master/README.md) | Manual uninstall step 2. | Common HAL reload approach; still needs validation on target macOS build. |

---

## 3. Per-product lifecycle

### 3.1 MJAudioRecorder / `MJRecorderDevice.driver` (Mingjie stack: NoteBurner, Sidify, others)

| Phase | Documented / observed behavior | Label |
|-------|----------------------------------|-------|
| **Install** | Parent app installer or first-run flow places `MJRecorderDevice.driver` in `/Library/Audio/Plug-Ins/HAL/`. NoteBurner documents reinstall from app UI or manual delete + relaunch app. | **CONFIRMED** (path + reinstall flow); **INFERRED** (exact installer UI). |
| **Privileged helpers** | `com.mingjie.mjrecorder.agent.plist` in `/Library/LaunchDaemons/` launching `MJRecorder-agent` inside driver bundle. | **CONFIRMED** (community EtreCheck + removal threads). |
| **Activation** | Appears as **MJAudioRecorder** in Sound/Audio MIDI Setup after install + audio stack reload (typically reboot). | **CONFIRMED** (user-facing name); **INFERRED** (reload mechanism). |
| **During use** | NoteBurner “Record Mode” and Failed 1201 docs imply driver must be present while converter runs. | **CONFIRMED** |
| **Default device / routing** | No primary doc states automatic default switching, aggregate creation, or per-process routing. User reports of silent speakers after use suggest routing changes. | **UNKNOWN** (automation); **INFERRED** (side effects). |
| **Deactivation / quit** | Not documented. | **UNKNOWN** |
| **Restoration** | Recovery docs focus on **removing driver** and **rebooting**—not “quit app → previous device restored”. | **CONFIRMED** (recovery == uninstall); **INFERRED** (no auto-restore on quit). |
| **Crash** | Not documented. | **UNKNOWN** |
| **Reboot** | Driver persists in HAL; LaunchDaemon may reload agent. | **INFERRED** from plist presence. |
| **Uninstall** | Delete `MJRecorderDevice.driver`; delete `com.mingjie.mjrecorder.agent.plist`; restart Mac. Sidify/NoteBurner match. | **CONFIRMED** |
| **External device change** | Not documented. | **UNKNOWN** |
| **coreaudiod** | Vendors document **reboot**, not `killall`/`kickstart`. | **CONFIRMED** (reboot in FAQs); **UNKNOWN** (hot reload). |
| **DJ app output after onboarding** | Not documented. Music apps must play audio successfully (output device connected)—does not promise zero DJ settings changes. | **INFERRED** — routine DJ output changes **not ruled out** by public docs. |

**Contradiction:** Apple Community posts describe the LaunchDaemon as “housekeeping” vs essential; treat as **UNRESOLVED** until bundle inspection shows whether agent is required for routing or only startup optimization.

---

### 3.2 Record It Audio Device (Build to Connect “Record It”)

| Phase | Documented / observed behavior | Label |
|-------|----------------------------------|-------|
| **Install** | Mac App Store app separate from **`RecordItAudioDevice`** driver download; blog references **`RecordItAudioDevice.pkg`** with Gatekeeper “Open Anyway” flow. | **CONFIRMED** (driver prerequisite); **INFERRED** (pkg/HAL path). |
| **Device name** | **Record It Audio Device** (user-visible). | **CONFIRMED** (App Store + blog). |
| **Activation** | Third-party workflow: install driver → create **Aggregate Device** in Audio MIDI Setup → set **DAW output to Record It** → set **system output to aggregate** for monitoring. | **INFERRED** (blog); aligns with manual HAL loopback pattern. |
| **Default device** | Blog explicitly sets **system output to Aggregate** and **Ableton output to Record It**—dual manual routing. | **INFERRED** |
| **Deactivation / quit / restore** | Not documented in primary sources retrieved. | **UNKNOWN** |
| **Uninstall** | No official Record It uninstall page retrieved; Filmage sibling product uninstalls `FilmageAudioDevice.driver` from HAL + reboot. | **INFERRED** parallel only. |
| **coreaudiod** | Not documented for Record It. | **UNKNOWN** |
| **DJ app output after onboarding** | Documented third-party workflow requires **explicit app output choice** (DAW → Record It). | **INFERRED** — **incompatible** with “no routine DJ output changes” unless DJ app is already routed that way. |

**Smallest test:** Install `RecordItAudioDevice.pkg` on clean Mac; record `system_profiler SPAudioDataType`, HAL folder listing, and whether Record It app alone changes default output without Audio MIDI Setup steps.

---

### 3.3 NoteBurner-style converters (Mingjie `MJRecorderDevice` family)

Same HAL stack as §3.1. Additional vendor facts:

| Phase | Behavior | Label |
|-------|----------|-------|
| **Install** | “Recording Driver” installed with product; reinstall from in-app control. | **CONFIRMED** |
| **Capture mode** | Spotify macOS FAQ: **Record Mode** + web player for high-speed capture—implies playback through normal audio path while driver records. | **CONFIRMED** (mode names); **UNKNOWN** (exact tap point). |
| **Failure handling** | Failed **1106** / **1201**: check physical/logical **output device** and driver reinstall. | **CONFIRMED** |
| **Permissions** | No Screen Recording or System Audio Recording strings in retrieved NoteBurner FAQs—HAL + app permissions model **not fully documented**. | **UNKNOWN** |
| **DJ app output after onboarding** | No documentation that Serato/rekordbox/Traktor/VirtualDJ/djay require zero output changes. | **UNKNOWN** (per app); **INFERRED** category-wide: **do not assume** invisibility. |

**License:** Proprietary driver; **no code reuse**.

---

### 3.4 Comparable public implementations (architecture only)

#### BlackHole (Existential Audio) — **GPLv3, reference only**

- Install HAL bundle; manual multi-output; **`killall coreaudiod`** on uninstall.
- Does **not** auto-restore defaults or target one process.
- **Cannot be vendored** into DJMemory per project license rules.

#### libASPL + example drivers — **MIT**

- Documents Audio Server Plug-In model, HAL path, audio-server restart script.
- Does not implement app-level default-device management.

#### LitLink — **public product documentation**

- Documents automatic multi-output creation, **setting system default**, **Follow system output** when physical device changes, and uninstall path that **disables passthrough, removes multi-output, restores prior output, removes driver**.
- Closest **documented** analogue to “invisible after toggle” behavior—still requires user toggle and receiver app input selection unless the capturing app reads the bridge internally.

#### Omi Screen Recorder — **vendor blog**

- HAL driver + optional **aggregate device** managed separately in Audio MIDI Setup.
- Documents **`launchctl kickstart`** for reload (may fail on Sonoma 14.4+ per Apple forum).

#### Apple Core Audio process tap (macOS 14.2+ sample)

- No HAL `.driver` required for tap-based capture.
- Process list in `CATapDescription`; private aggregate devices supported in community samples (e.g. AudioCap README pattern).
- Permission: **`NSAudioCaptureUsageDescription`**; system prompts for system audio recording when using tap in aggregate device.

#### SoundPusher (public repo summary)

- HAL driver `SoundPusherAudio.driver`; menu-bar app sets **default output to selected source on run** and **restores default on exit** (README on Codeberg). Useful **lifecycle pattern** reference only.

---

## 4. Architecture patterns transferable without copying code

| Pattern | What public evidence establishes | Permissions / install | Auto default? | Process-specific? | License note |
|---------|-----------------------------------|----------------------|---------------|-------------------|--------------|
| **HAL Audio Server Plug-In** (`.driver` in `/Library/Audio/Plug-Ins/HAL/`) | Apple HAL hosts user-space plug-ins; BlackHole, libASPL, vendor uninstall guides agree on path. | Admin password for `/Library`; Developer ID signing expected on modern macOS (tympan-aspl docs). | **Not intrinsic**—BlackHole requires manual multi-output; LitLink docs show optional app layer that sets default. | **No**—device is global unless app routes per-process externally. | libASPL **MIT**; BlackHole **GPLv3** blocked. |
| **LaunchDaemon helper inside/beside driver** | Mingjie: `com.mingjie.mjrecorder.agent.plist` → `MJRecorder-agent`. | Root install to `/Library/LaunchDaemons/`. | **UNKNOWN** for Mingjie; pattern often used for startup/reconnect. | **UNKNOWN** | Proprietary. |
| **Aggregate / multi-output device** | Apple Audio MIDI Setup; BlackHole wiki; Omi/LitLink/Record It workflows. | User or companion app creates virtual aggregate/multi-output objects (may persist in CoreAudio prefs). | LitLink **CONFIRMED** auto-creates and sets default when passthrough on. | **No**—system-wide fan-out. | N/A (CoreAudio API). |
| **Companion app routing helper** | LitLink documents menu-bar toggles, restore on uninstall. SoundPusher documents restore default on exit. | Regular app + possibly SMAppService/Login Items (not documented for Mingjie). | **Yes** in documented LitLink/SoundPusher patterns. | LitLink Pro claims per-app routing (macOS 14.2+); needs bench validation. | Product-specific. |
| **Core Audio process tap + private aggregate** | Apple sample doc: `AudioHardwareCreateProcessTap`, `CATapDescription.processes`, tap list on aggregate device. | `NSAudioCaptureUsageDescription`; system audio recording consent (14.4+ behavior in community docs). | **No** DJ output change if tap attaches to DJ process output graph. | **Yes**—Apple-documented. | Apple sample code (follow Apple license on sample). |
| **ScreenCaptureKit audio** | Community/docs: system audio without HAL driver; Screen Recording permission. | Screen Recording permission. | **No** HAL routing. | Can exclude current process; not fine-grained DJ routing in public API summary. | Apple framework. |

**Permission / signing summary (CONFIRMED where cited):**

- HAL install: administrator authorization; Gatekeeper/notarization for distribution (LitLink docs; tympan-aspl AMFI notes).
- HAL reload: `killall coreaudiod` commonly documented; `launchctl kickstart` **unreliable** on Sonoma 14.4+ with SIP (Apple Developer Forums).
- Tap path: **`NSAudioCaptureUsageDescription`** required (Apple sample JSON).
- Microphone privacy: receiving apps need mic access to read virtual input devices (BlackHole FAQ).

---

## 5. Claims that cannot be verified publicly

1. **Mingjie/NoteBurner automatic enable/disable** of virtual device tied to app foreground/background without user action.
2. **Mingjie default-output save/restore** on quit, crash, or reboot.
3. **Mingjie per-process routing** vs system-wide loopback—no primary API documentation.
4. **Record It** exact HAL bundle identifier, helper plists, signing team, and in-app install/uninstall automation.
5. **Whether MJRecorder intercepts only parent-app audio** or all system default output.
6. **coreaudiod hot-plug** behavior for Mingjie/Record It installers on macOS 15+ (vendors mostly document reboot).
7. **Cross-vendor equivalence** (“all converter apps behave like NoteBurner”)—each product needs separate evidence.
8. **Any Serato/rekordbox/Traktor/VirtualDJ/djay-specific behavior** with these drivers—**no primary source** in this research set.

---

## 6. Smallest local inspection or clean-Mac tests

| Unknown | Smallest test |
|---------|----------------|
| MJRecorder enable/disable/default restoration | Clean Mac VM: install NoteBurner or Sidify; before/after `defaults read` + `system_profiler SPAudioDataType` + `Audio MIDI Setup` screenshot; record **system default output UID** on launch, during conversion, on quit, after kill -9, after reboot. |
| MJRecorder LaunchDaemon role | With driver installed, unload plist (`launchctl bootout`) vs rename agent binary; observe whether device appears and whether routing still works. |
| MJRecorder `coreaudiod` reload | Install driver; try `sudo killall coreaudiod` vs reboot; note whether device appears without reboot on macOS 14/15 target. |
| Record It bundle + helpers | Install `RecordItAudioDevice.pkg`; list `/Library/Audio/Plug-Ins/HAL/*RecordIt*`, `/Library/LaunchDaemons`, `/Library/LaunchAgents`; `codesign -dv` on `.driver`. |
| Record It automation vs manual aggregate | Open Record It only; attempt system-audio record **without** Audio MIDI Setup changes; observe default output and whether audio is captured. |
| NoteBurner routing | During Record Mode, play Spotify/Serato **each** with default output unchanged; verify capture and whether system output device changes in Control Center. **One DJ app per test**—do not generalize from Serato alone. |
| LitLink-style automation (reference) | Repeat default-output UID test with LitLink passthrough toggle to compare documented auto-restore behavior against Mingjie stack. |
| Process tap viability for DJ apps | On macOS 14.2+ bench: Apple tap sample targeting DJ process PID; verify permission prompt, audio presence, Bluetooth/AirPods latency (Apple Forums note BT clock issues). |

---

## Unresolved contradictions

| Topic | Conflict | Resolution test |
|-------|----------|-----------------|
| LaunchDaemon necessity | Removal thread calls plist “extra housekeeping”; other users report persistence/relaunch issues if plist remains. | Bootout/delete plist only, keep `.driver`; measure behavior. |
| HAL reload without reboot | NoteBurner/Sidify say reboot; BlackHole/libASPL use `killall coreaudiod`; Apple forum says `kickstart` blocked but `killall` works on 14.4.1. | Same VM, three reload methods, note device enumeration. |
| Record It vendor vs blog | App Store confirms driver name; blog gives manual routing recipe; developer site 404. | Install current pkg; compare to 2021 blog workflow. |
| “Invisible capture” product marketing | LitLink claims one-toggle automation; Mingjie converters market “record mode” but public FAQs emphasize driver reinstall—not invisibility. | Do not treat marketing copy as confirmed for Mingjie; bench each product. |

---

## Routine DJ-app output changes after onboarding?

| Stack | Public evidence | Label |
|-------|-----------------|-------|
| MJRecorder / NoteBurner / Sidify | FAQs require working **system output** for source apps; no doc promises DJ apps need zero output settings forever. | **INFERRED** — **likely still depends on default-output capture**; not proven invisible for DJ apps. |
| Record It | Third-party doc requires **explicit DAW output to Record It** + system aggregate. | **INFERRED** — **explicit routing required**. |
| BlackHole | Manual multi-output + output selection. | **CONFIRMED** — manual. |
| LitLink | Auto system default to multi-output when passthrough enabled; DJ app not mentioned. | **CONFIRMED** for **system** default change; **UNKNOWN** for DJ-internal device menus. |
| Core Audio process tap | Captures outgoing audio from chosen **processes** without making a global HAL loopback device user-visible. | **CONFIRMED** (Apple API intent); DJ bench still required. |

**Do not infer** universal behavior across all five DJ apps from any single vendor stack (including Serato Virtual Audio, not covered here).

---

## License implications (research only)

| Component | License / restriction | DJMemory note |
|-----------|----------------------|---------------|
| BlackHole | **GPLv3** | Reference architecture only; **must not vend** without GPL compliance. |
| libASPL | **MIT** (+ Apple sample notices) | Permitted to study/vend with **copyright notice preserved**. |
| Mingjie MJRecorder / Record It / NoteBurner drivers | **Proprietary** | **No reverse engineering or code reuse**; lifecycle evidence only. |
| Apple Core Audio sample (taps) | Apple sample license | Follow Apple terms on redistribution of sample-derived code. |
| LitLink / vendor products | Proprietary | Behavioral reference from public docs only. |

---

*End of Worker 1 reference-apps evidence file.*
