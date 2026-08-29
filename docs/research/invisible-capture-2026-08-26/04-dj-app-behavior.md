# DJ app audio output behavior and invisible-capture implications

**Access date:** 2026-08-26
**Scope:** Serato DJ Pro, rekordbox (macOS desktop), Traktor Pro, VirtualDJ, djay Pro/2 (macOS)
**Question:** How is audio output selected in laptop-only and controller/mixer modes, and what does that imply for automatic capture?

Evidence labels: **CONFIRMED** (primary vendor/Apple documentation), **INFERRED** (reasonable deduction not explicitly documented), **UNKNOWN** (no reliable public primary source).

---

## 1. Five-row application summary

| Application | Laptop-only output selection | Controller / mixer output selection | Bypasses macOS default routing? | Vendor virtual / broadcast output | Routine output changes after onboarding? |
|---|---|---|---|---|---|
| **Serato DJ Pro** | Practice / offline player uses the **current macOS default output device** (**CONFIRMED**). Optional **Use Laptop Speakers** routes master to the OS default while keeping cue on connected controller hardware (**CONFIRMED**). | With supported hardware connected, master normally exits the **controller/mixer USB audio interface**; cue/headphones use controller outputs (**CONFIRMED** for controller routing pattern; **INFERRED** that this is the default when *Use Laptop Speakers* is off). | **Partially.** Controller-as-interface mode does not require macOS default to be the playback path for the main mix (**INFERRED**). *Use Laptop Speakers* explicitly couples master output to the **OS default device** (**CONFIRMED**). | **Serato Virtual Audio** (macOS driver, opt-in via Setup → Audio → *Make Audio Output Available to Other Applications*) exposes mix to other apps as an input device (**CONFIRMED**, Serato-only). | **Sometimes.** *Use Laptop Speakers* docs require setting macOS default first and **disabling/re-enabling** the option after changing OS output (**CONFIRMED**). |
| **rekordbox** | Preferences → Audio: select **built-in / computer speaker** device; **Mixer Mode: Internal** for software mixing (**CONFIRMED**). | Preferences → Audio: select **Pioneer/AlphaTheta driver device** (e.g. `DDJ-800`, `XDJ-RX3`) with **Internal** or **External** mixer mode and per-channel output mapping (**CONFIRMED**). CDJ/XDJ-as-output uses **Pioneer CDJ/XDJ** aggregate device on Mac (**CONFIRMED**). | **Yes, when controller/interface is selected.** rekordbox targets the chosen **Audio device** in preferences, not the macOS menu-bar default (**CONFIRMED**). **PC MASTER OUT** additionally mirrors master to Mac speakers while hardware is connected (**CONFIRMED**). | No rekordbox-owned macOS virtual **master tap** documented (**UNKNOWN**). PERFORMANCE-mode recording is internal or via Pioneer **Input Record** channel selection (**CONFIRMED**). | **Uncommon if hardware stable.** PC MASTER OUT, mixer mode, and Audio device are preference-level; troubleshooting docs assume **quit → reconnect → reselect Audio** after driver/aggregate changes (**CONFIRMED**). |
| **Traktor Pro** | Preferences → Audio Setup: select **built-in sound card**; Output Routing → **Internal**, assign **Output Master** (**CONFIRMED**). Single stereo out; no cue on built-in only (**CONFIRMED**). | Preferences → Audio Setup: select **controller/interface** as **Audio Device**; routing auto-configured for Kontrol/certified devices (**CONFIRMED**). **External** mixing mode sends deck pairs directly to interface outputs (**CONFIRMED**). | **Yes, when an explicit Audio Device is selected.** Traktor opens the chosen Core Audio device via preferences, not implicitly via system default (**CONFIRMED**). | No Traktor virtual master output driver documented (**UNKNOWN**). Mix Recorder / Broadcasting are in-app features (**CONFIRMED** broadcasting exists; not a system virtual device). | **Rare.** Device choice persists in preferences. **Win Built-In fallback** is documented for Windows only (**CONFIRMED**); macOS live fallback on disconnect is **UNKNOWN**. |
| **VirtualDJ** | Basic setup **SPEAKER ONLY** / **COMPUTER AUDIO** uses the **computer default soundcard** (**CONFIRMED**). Advanced OUTPUTS rows can pin each source (Master, Headphones, Deck…) to a specific driver/channel (**CONFIRMED**). | Connect supported controller → click hardware button for **pre-defined Audio Setup**; master/phones/deck channels assigned per device (**CONFIRMED**). **SEPARATE DECKS** + multi-channel interface for external mixer (**CONFIRMED**). | **Depends on profile.** Per-output soundcard fields can bypass “default-only” routing (**CONFIRMED**). **COMPUTER AUDIO** explicitly tracks macOS default (**CONFIRMED**). | No VirtualDJ macOS virtual audio driver documented (**UNKNOWN**). Internal **Record** captures Master; **Broadcast** streams from app (**CONFIRMED**). External mixer requires **Record Loopback** line input (**CONFIRMED**). | **Profile-dependent.** Users with multiple saved Audio Profiles may switch intentionally; stable controller setups should not need routine changes (**INFERRED**). |
| **djay Pro/2** | Settings → Devices → **Internal** mixer mode; pick **Main Output** (Mac speakers/headphones); optional **Split Output** for pre-cue (**CONFIRMED**). | Supported controllers: **automatic audio configuration** on connect; master on controller master out, cue on headphone out (**CONFIRMED**). **External** mode assigns per-deck interface outputs (**CONFIRMED**). | **Yes, when controller/interface outputs are selected or auto-configured.** Laptop path uses explicit **Main Output** device, not macOS default alone (**CONFIRMED**). | No djay virtual master tap driver documented (**UNKNOWN**). Internal recording from software master in Internal mode; External mode needs **Recording Input** loopback (**CONFIRMED**). | **Low for supported hardware** (auto-config). Manual External/multi-interface setups may need preference edits (**CONFIRMED**). **Reset to Defaults** documented for routing recovery (**CONFIRMED**). |

---

## 2. Detailed sections

### 2.1 Serato DJ Pro

#### Output selection modes

**Laptop-only (Practice / offline player)**
Serato documents that the offline player—Practice mode when no hardware is connected—**outputs through the current default audio device** (**CONFIRMED**, [Offline Player](https://support.serato.com/hc/en-us/articles/235211327-Offline-Player)). This is **explicit OS-default coupling**, not a separate Serato-only output picker for that mode.

**Controller / mixer**
Primary workflow: connect Serato-compatible hardware; software **automatically detects hardware** when drivers are present (**CONFIRMED**, [Serato DJ Pro User Manual PDF](https://d1aeri3ty3izns.cloudfront.net/media/36/366330/download_366330.pdf), launch section). Master audio is normally taken from the **controller’s or mixer’s audio outputs** (physical master/booth RCA/XLR), with USB carrying the digital audio interface (**CONFIRMED**, [Numark controller audio guide](https://support.numark.com/en/support/solutions/articles/69000829471-how-do-i-get-sound-from-my-controller-) — Serato OEM pattern article).

**Use Laptop Speakers (controller connected)**
From Serato DJ Pro 2.4+, when compatible hardware is connected, Setup → Audio → **Use Laptop Speakers** routes **master** to the computer’s output while **cue/headphones remain on the controller** (**CONFIRMED**, [Use Laptop Speakers](https://support.serato.com/hc/en-us/articles/360001860415-Use-Laptop-Speakers-or-External-Soundcard-as-Master-Output-with-Serato-DJ-Pro)). Prerequisites documented by Serato:

- macOS **default output** must be set to Internal Speakers (or the intended external soundcard) **before** enabling the option (**CONFIRMED**, same article).
- If macOS default is another device while the option is enabled, Serato **also outputs via that selected OS device** (**CONFIRMED**, same article).
- After changing macOS output, Serato instructs users to **disable and re-enable Use Laptop Speakers** (**CONFIRMED**, same article).
- Option appears **only with compatible hardware connected** (**CONFIRMED**, same article).

#### System-default vs explicit selection

| Mode | Mechanism | Label |
|---|---|---|
| Practice / no hardware | macOS **default output device** | **CONFIRMED** |
| Controller, default | USB audio interface owned by Serato hardware path | **CONFIRMED** (routing); **INFERRED** as default when Use Laptop Speakers off |
| Controller + Use Laptop Speakers | macOS **default output** for master + controller for cue | **CONFIRMED** |

Serato does **not** publicly document a general-purpose “Audio Device” dropdown equivalent to Traktor/rekordbox for all modes (**UNKNOWN** for non–Use Laptop Speakers master path beyond hardware interface).

#### Vendor virtual output (Serato-specific)

**Serato Virtual Audio** is optional. Setup → Audio → **Make Audio Output Available to Other Applications** installs/uses the bundled macOS virtual driver (Serato DJ Pro ≥2.5.5) so **other applications can select Serato Virtual Audio as an input** (**CONFIRMED**, [Live Stream setup](https://support.serato.com/hc/en-us/articles/360001784415-Getting-Serato-DJ-Pro-Lite-ready-to-Live-Stream)). This is **not** enabled by default and **must not be extrapolated** to other DJ apps.

#### macOS default change while session running

- Practice mode: **INFERRED** to follow Core Audio default-output behavior (see §2.6); **bench test required**.
- Use Laptop Speakers: Serato documents **toggle refresh** after OS output changes, implying stale routing without re-enable (**CONFIRMED** intent; live session behavior **UNKNOWN**).

#### Exclusive access / restrictions

No Serato public doc states hog/exclusive mode (**UNKNOWN**). macOS troubleshooting notes **other audio devices and drivers** can conflict with Serato hardware connection (**CONFIRMED**, [Troubleshooting Connection on macOS](https://support.serato.com/hc/en-us/articles/203189300-Troubleshooting-Connection-on-macOS)).

#### Lifecycle: launch, quit, connect/disconnect, device loss

| Event | Documented behavior | Label |
|---|---|---|
| Launch | Auto-detect Serato hardware if drivers installed | **CONFIRMED** (manual) |
| Quit | Not specified for audio routing | **UNKNOWN** |
| Controller connect | Standard connect workflow; macOS built-in I/O sometimes required for MIDI/audio access per troubleshooting | **CONFIRMED** (troubleshooting) |
| Controller disconnect | Windows 11 MIDI disconnect freeze/crash known issue with workarounds; macOS disconnect audio routing **UNKNOWN** | **CONFIRMED** (Windows issue article); macOS **UNKNOWN** |
| Device loss | Troubleshooting: remove conflicting devices, reset Audio MIDI Setup, restart | **CONFIRMED** |

#### Capture-path evaluation (do not overclaim)

| Path | Applicability | Label |
|---|---|---|
| **Process Audio Tap** | Theoretically taps Serato process output on macOS 14.2+ regardless of physical device, if mix is rendered in-process | **INFERRED**; bench test required |
| **ScreenCaptureKit app audio** | Filter to Serato DJ Pro bundle; captures app’s emitted audio if routed through normal app graph | **INFERRED** from Apple SC filters; bench test required |
| **Vendor virtual input** | **Serato Virtual Audio** when user enables opt-in setting | **CONFIRMED** (optional, user-dependent) |
| **DJMemory HAL / default-device routing** | Helps Practice mode + Use Laptop Speakers paths tied to macOS default; **does not** capture controller-only master on hardware outputs | **INFERRED** |
| **Verified USB master / deck input** | When master is **not** on Mac (normal controller gig), archive must use **hardware master/rec return** or loopback, not Mac default | **CONFIRMED** (routing docs) |

#### Routine output changes after onboarding?

**Sometimes** for Use Laptop Speakers / OS default changes (**CONFIRMED**). Stable controller→PA setups with master on hardware likely need **no** Serato setting changes (**INFERRED**).

---

### 2.2 rekordbox (macOS desktop)

#### Output selection modes

**Laptop-only**
Preferences → Audio:

- **Audio**: computer built-in speaker/device (**CONFIRMED**, [Cannot record in PERFORMANCE mode](https://support.pioneerdj.com/hc/en-us/articles/8213839784473-I-cannot-record-audio-in-PERFORMANCE-mode)).
- **Mixer Mode**: **Internal** (**CONFIRMED**, same article).

**Controller / all-in-one / DJM**
Preferences → Audio:

- **Audio**: hardware driver name (example Mac mapping: `XDJ-RX3` with `:MASTER`, `:PHONES`, deck channels) (**CONFIRMED**, [Sound incorrect article snippet](https://support.pioneerdj.com/hc/en-us/articles/4409257604761-Sound-comes-out-of-my-headphones-or-speakers-incorrectly-rekordbox)).
- **Mixer Mode**: **Internal** (software mixer on hardware) or **External** (per-deck outputs to external mixer) (**CONFIRMED**, [Internal/External FAQ](https://rekordbox.com/en/support/faq/operation-hint/#faq-q500212)).

**PC MASTER OUT**
When enabled, rekordbox can output master to **PC/Mac speakers** while DJ hardware is connected (**CONFIRMED**, [AlphaTheta DE output FAQ](https://support.pioneerdj.com/hc/de/articles/12185292173337-Warum-kommt-der-Ton-aus-meinem-PC-Mac-oder-dem-eingebauten-Lautsprecher-meines-mobilen-Ger%C3%A4ts-nicht-richtig-heraus)). PC MASTER OUT volume follows **computer speaker volume**, not controller MASTER knob (**CONFIRMED**, [rekordbox troubleshooting FAQ](https://rekordbox.com/en/support/faq/trouble-shooting-5/#faq-q500342)).

**CDJ/XDJ multi-player (Mac)**
Requires **CDJ/XDJ Aggregator** aggregate device; rekordbox Audio = **Pioneer CDJ/XDJ**; External mixer mode; per-deck output channels (**CONFIRMED**, [Aggregator manual](https://support.pioneerdj.com/hc/en-us/articles/4413832776345-CDJ-XDJ-Aggregator-Instruction-Manual), [Connection guide PDF](https://cdn.rekordbox.com/files/20200312171207/rekordbox5.3.0_connection_guide_for_performance_mode_EN.pdf)).

#### System-default vs explicit selection

rekordbox **always** uses the device selected in Preferences → Audio, not the macOS menu-bar default alone (**CONFIRMED**, preference articles above). PC MASTER OUT is an **explicit secondary path** to built-in speakers (**CONFIRMED**).

#### Hardware modes bypassing ordinary system routing

When Audio = Pioneer USB driver, rekordbox talks to the **vendor driver/device** directly. macOS default output can remain built-in while main PA sound is on hardware (**INFERRED**, consistent with Windows PC MASTER OUT troubleshooting requiring Windows default ≠ DDJ for speaker path — [Windows PC MASTER OUT](https://support.pioneerdj.com/hc/en-us/articles/4408162031769-No-sound-comes-out-from-the-PC-speaker-even-though-PC-MASTER-OUT-is-turned-on-Windows)).

#### Vendor virtual / recording outputs

- PERFORMANCE recording: **Master Out** internally, or **Input Record** from connected Pioneer product (**CONFIRMED**, [Recording troubleshooting](https://support.pioneerdj.com/hc/en-us/articles/8213839784473-I-cannot-record-audio-in-PERFORMANCE-mode)).
- No Pioneer **system-wide virtual master device** for third-party capture documented (**UNKNOWN**).

#### macOS default change while session running

**UNKNOWN.** Public docs focus on preference and driver reinstall workflows, not live default switching.

#### Exclusive access

**UNKNOWN** in rekordbox public docs. Aggregate/CDJ bandwidth issues documented at USB level (**CONFIRMED**, aggregator manual).

#### Lifecycle

| Event | Documented behavior | Label |
|---|---|---|
| Launch | Audio device must appear in Preferences → Audio | **CONFIRMED** |
| Quit / reconnect after driver issues | Close rekordbox, disconnect hardware, reinstall/recreate aggregate, relaunch | **CONFIRMED** |
| USB port change (CDJ aggregate) | Recreate aggregate device | **CONFIRMED** |
| Device loss | Troubleshooting: direct USB, PC mode on players, rerun Aggregator | **CONFIRMED** |

#### Capture-path evaluation

| Path | Applicability | Label |
|---|---|---|
| Process Audio Tap | May tap rekordbox process if master rendered in-app (Internal mode) | **INFERRED** |
| ScreenCaptureKit | App-filtered capture possible | **INFERRED** |
| Vendor virtual input | None documented | **UNKNOWN** |
| HAL / default-device routing | Affects PC MASTER OUT / built-in selection only | **INFERRED** |
| USB master/deck input | External mode + physical mixer, or hardware master out, bypasses Mac master mix | **CONFIRMED** for External/hardware-PA workflows |

#### Routine output changes after onboarding?

**Uncommon** for fixed DDJ/XDJ setups (**INFERRED**). Required when adding PC MASTER OUT, switching mixer mode, or changing aggregate/CDJ topology (**CONFIRMED**).

---

### 2.3 Traktor Pro

#### Output selection modes

**Laptop-only**
Preferences → Audio Setup → **Audio Device: built-in sound card**; Output Routing → **Internal** → assign **Output Master** (only one stereo pair; **no cue** on built-in-only setup) (**CONFIRMED**, [Setting Up Traktor](https://docs.native-instruments.com/ni-tech-manuals/traktor-pro-manual/en/setting-up-traktor), [Preferences](https://docs.native-instruments.com/ni-tech-manuals/traktor-pro-manual/en/preferences)).

**External audio interface / controller**
Select interface as **Audio Device**. Kontrol/certified controllers: routing **usually auto-configured** (**CONFIRMED**, Preferences). Manual setups:

- **Internal mixing**: Output Master + Output Monitor (cue) pairs (**CONFIRMED**).
- **External mixing**: deck pairs to interface outputs; internal mixer bypassed (**CONFIRMED**, Preferences → External Mixing Mode section).

Connecting external interface: Traktor **automatically sets External Mixing** in some setup flows (**CONFIRMED**, Setting Up Traktor).

#### System-default vs explicit selection

Traktor selects **Audio Device in preferences** (built-in or USB interface). This is **explicit**, not macOS-default-only (**CONFIRMED**).

#### Fallback / device loss

- Header **AUDIO** indicator: blue = connected; red = not connected; orange = internal soundcard selected (**CONFIRMED**, [Traktor Pro 2 manual PDF](https://docs.native-instruments.com/pdf-guides/traktor/traktor_pro_2_manual_english.pdf) — UI semantics; verify on current Traktor Pro 4 build).
- **Win Built-In fallback**: when primary Audio Device unavailable at startup, Traktor uses selected internal fallback (**CONFIRMED**, Preferences — **Windows only**).
- Appendix “On-board Sound Card and Fallback” describes choosing built-in fallback when external missing at **startup** (**CONFIRMED**, manual §18.1). **macOS hot-unplug during session** behavior is **UNKNOWN**.

#### Vendor virtual / broadcast

Traktor **Broadcasting** uses in-app server/client configuration (**CONFIRMED**, manual §13.17). No NI virtual macOS master driver for third-party apps documented (**UNKNOWN**).

#### macOS default change while running

**UNKNOWN** for Traktor explicitly. Traktor uses AUHAL on chosen device (**INFERRED** from Core Audio model).

#### Exclusive access

**UNKNOWN** in Traktor docs.

#### Lifecycle

| Event | Documented behavior | Label |
|---|---|---|
| Launch | Welcome/setup selects audio interface | **CONFIRMED** |
| External connect | Auto External Mixing in documented workflow | **CONFIRMED** |
| Disconnect | Windows fallback documented; macOS live **UNKNOWN** | **CONFIRMED** / **UNKNOWN** |

#### Capture-path evaluation

| Path | Applicability | Label |
|---|---|---|
| Process Audio Tap | Internal mixing renders master in-process | **INFERRED** |
| ScreenCaptureKit | App-level filter | **INFERRED** |
| Vendor virtual input | None documented | **UNKNOWN** |
| HAL / default-device routing | Limited value while explicit Audio Device selected | **INFERRED** |
| USB master/deck input | External mixing → physical mixer master | **CONFIRMED** |

#### Routine output changes after onboarding?

**Rare** if hardware unchanged (**INFERRED**). Travel without interface benefits from Windows fallback preference (**CONFIRMED**, Windows only).

---

### 2.4 VirtualDJ

#### Output selection modes

**Laptop-only**
Basic: **SPEAKER ONLY** + **COMPUTER AUDIO** → uses **default soundcard of the computer** (**CONFIRMED**, [Audio Setup](https://virtualdj.com/manuals/virtualdj/settings/audiosetup.html)). Advanced OUTPUTS table can assign Master/Headphones to specific drivers/channels (**CONFIRMED**).

**Controller / multi-channel**
Supported controllers show a **hardware button** that auto-creates predefined routing (**CONFIRMED**, [Controller audio setup](https://virtualdj.com/manuals/virtualdj/settings/audiosetup/controller.html)). **SEPARATE DECKS** sends each deck to interface channels for external mixer (**CONFIRMED**, Audio Setup).

**macOS 4-channel interfaces**
May require **Audio MIDI Setup** channel format change (Quadraphonic) before all outputs work (**CONFIRMED**, [Mac 4 Channel Audio wiki](https://virtualdj.com/wiki/Mac%204%20Channel%20Audio.html)).

#### System-default vs explicit selection

**Hybrid.** COMPUTER AUDIO tracks macOS default (**CONFIRMED**). Advanced per-source soundcard fields override defaults (**CONFIRMED**). Profiles saved via **APPLY** (**CONFIRMED**).

#### Internal vs external mixer capture

- **Internal / master on software mixer**: recording is **internal** from Master (**CONFIRMED**, [Record](https://virtualdj.com/manuals/virtualdj/settings/record/)).
- **External hardware mixer**: software cannot see crossfader; requires **Record Loopback** from mixer REC/BOOTH → line input (**CONFIRMED**, [Record Loopback](https://virtualdj.com/manuals/virtualdj/settings/audiosetup/recordloopback.html), [Record Loopback wiki](https://virtualdj.com/wiki/Record%20Loopback.html)).

#### Broadcast / recording outputs

Broadcast tab streams from VirtualDJ (direct/server/podcast) (**CONFIRMED**, [Broadcast](https://virtualdj.com/manuals/virtualdj/settings/broadcast.html)). Not documented as a Core Audio virtual output device for other apps (**UNKNOWN**).

#### macOS default change while running

**UNKNOWN.** COMPUTER AUDIO mode **INFERRED** to track default on next APPLY or buffer restart.

#### Exclusive access

**UNKNOWN** in VirtualDJ docs.

#### Lifecycle

| Event | Documented behavior | Label |
|---|---|---|
| Launch | Last applied Audio Profile | **INFERRED** |
| Controller connect | Hardware button appears; click to create setup + APPLY | **CONFIRMED** |
| Device loss | Not documented | **UNKNOWN** |

#### Capture-path evaluation

| Path | Applicability | Label |
|---|---|---|
| Process Audio Tap | Strong for Internal master routing | **INFERRED** |
| ScreenCaptureKit | App filter | **INFERRED** |
| Vendor virtual input | None documented | **UNKNOWN** |
| HAL / default-device routing | Useful only for COMPUTER AUDIO profiles | **INFERRED** |
| USB master/deck input | External mixer + SEPARATE DECKS → hardware master is truth | **CONFIRMED** |

#### Routine output changes after onboarding?

**Profile-dependent.** Stable controller preset should persist (**INFERRED**). External mixer users must maintain loopback wiring + Record input (**CONFIRMED**).

---

### 2.5 djay Pro / djay 2 (macOS)

#### Output selection modes

**Laptop-only**
Settings → Devices → **Internal** mixer mode; choose **Main Output** (Mac speakers/headphones); optional **Split Output** + DJ split cable for pre-cue (**CONFIRMED**, [Audio settings getting started](https://help.algoriddim.com/user-manual/djay-pro-mac/getting-started/audio-settings), [Audio devices](https://help.algoriddim.com/user-manual/djay-pro-mac/settings/audio-devices)).

**Controller**
Supported controllers: **automatic detection and audio configuration**; master on controller master, cue on headphone output (**CONFIRMED**, getting started + [topic audio setup](https://help.algoriddim.com/topic/first-steps/audio-setup)).

**External mixer / multi-channel interface**
**External** mode: assign Decks 1–4, Pre-cueing, Sampler, Looper outputs separately (**CONFIRMED**, Audio devices; [External mixers](https://help.algoriddim.com/user-manual/djay-pro-mac/hardware/external-mixers)).

#### Internal vs External implications

- **Internal**: single combined Main Output; internal recording available (**CONFIRMED**, [Recording](https://help.algoriddim.com/user-manual/djay-pro-mac/mixing-basics/recording)).
- **External**: internal recording and Automix **disabled**; crossfader position unknown to software (**CONFIRMED**, [Mixer mode](https://help.algoriddim.com/user-manual/djay-pro-mac/hardware/mixer-mode)). External recording via **Recording Input** loopback (**CONFIRMED**, [External mixer recording](https://help.algoriddim.com/user-manual/djay-pro-mac/mixing-basics/external-mixer-recording)).

#### System-default vs explicit selection

djay picks explicit **Main Output** / per-channel devices in Settings (**CONFIRMED**). Not documented as “follow macOS default only” (**CONFIRMED** negative for default-only design).

#### Vendor virtual output

**UNKNOWN** — no Algoriddim virtual master driver in public manuals.

#### macOS default change while running

**UNKNOWN.**

#### Lifecycle

| Event | Documented behavior | Label |
|---|---|---|
| Controller connect | Auto-config + on-screen instructions | **CONFIRMED** |
| Routing failure | Settings → Reset to Defaults | **CONFIRMED** |
| Quit without stop record | Corrupted recording file risk | **CONFIRMED** (recording page) |

#### Capture-path evaluation

| Path | Applicability | Label |
|---|---|---|
| Process Audio Tap | Internal mode | **INFERRED** |
| ScreenCaptureKit | App filter | **INFERRED** |
| Vendor virtual input | None documented | **UNKNOWN** |
| HAL / default-device routing | Only if Main Output = built-in device | **INFERRED** |
| USB master/deck input | External mode / controller PA master | **CONFIRMED** |

#### Routine output changes after onboarding?

**Low** for plug-and-play controllers (**CONFIRMED** auto-config). External mixer setups need stable External mode mapping (**CONFIRMED**).

---

### 2.6 Shared macOS platform notes (Apple documentation)

#### Default output vs per-app device

Apple documents that users choose the system output device in **System Settings → Sound → Output** (**CONFIRMED**, [Change sound output on Mac](https://support.apple.com/en-au/guide/mac-help/mchlp2256/mac)). Core Audio **default output unit** routes to the user-selected default device (**CONFIRMED**, [Core Audio Overview](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/ARoadmaptoCommonTasks/ARoadmaptoCommonTasks.html)).

Whether a **running** DJ app follows a mid-session macOS default change depends on whether the app uses the default output unit vs a **specific AUHAL device ID**. Apple/archive guidance: behavior is **application-dependent** (**INFERRED**, [TN2097 Default Output Audio Unit](https://developer.apple.com/library/archive/technotes/tn2097/_index.html); community reports vary by app — treat as **bench test**).

#### Process Audio Tap (platform)

Apple sample **Capturing system audio with Core Audio taps** documents:

- macOS **14.2+**
- `AudioHardwareCreateProcessTap` + aggregate device
- First capture prompts for **system audio recording** permission
- Taps can target process output; optional mute of tapped output

(**CONFIRMED**, [Apple sample doc mirror](https://apple-docs.everest.mt/docs/sample-code/coreaudio/capturing-system-audio-with-core-audio-taps/))

**Entitlements / shipping:** sample requires macOS 14.2+, TCC permission, user-facing consent; kernel extension not required (**CONFIRMED**). DJ-specific behavior **UNKNOWN** without per-app bench tests.

#### ScreenCaptureKit application audio

Apple **Meet ScreenCaptureKit** (WWDC22) documents:

- `capturesAudio = true` on `SCStreamConfiguration`
- Audio filtering at **application level** via `SCContentFilter`
- Requires **Screen Recording** consent

(**CONFIRMED**, [WWDC22 session](https://developer.apple.com/videos/play/wwdc2022/10156/))

Audio-only capture typically still instantiates a minimal video stream (**INFERRED**, widely reported; not a DJ-vendor concern).

#### Hog / exclusive mode

Core Audio supports `kAudioDevicePropertyHogMode` exclusive access (**CONFIRMED**, [Apple property documentation](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertyhogmode)). Consumer DJ apps do **not** document hog mode use (**UNKNOWN** per app). Third-party notes list audiophile apps (Audirvana, Roon, Tidal), not DJ apps (**INFERRED** low likelihood).

---

## 3. Claim table

| # | Claim | Label | Primary URL | Evidence location | Scope |
|---|---|---|---|---|---|
| C1 | Serato offline/Practice outputs through **current macOS default audio device** | **CONFIRMED** | https://support.serato.com/hc/en-us/articles/235211327-Offline-Player | Offline player paragraph | Serato DJ Pro, no hardware |
| C2 | **Use Laptop Speakers** sends master to OS default output; cue stays on controller; requires compatible hardware | **CONFIRMED** | https://support.serato.com/hc/en-us/articles/360001860415-Use-Laptop-Speakers-or-External-Soundcard-as-Master-Output-with-Serato-DJ-Pro | Setup → Audio section; OS default prerequisite | Serato + supported controller |
| C3 | After OS output change, Serato instructs disable/re-enable **Use Laptop Speakers** | **CONFIRMED** | same as C2 | Note on refreshing selection | Serato |
| C4 | **Serato Virtual Audio** exposes mix to other apps when opt-in enabled; driver install required | **CONFIRMED** | https://support.serato.com/hc/en-us/articles/360001784415-Getting-Serato-DJ-Pro-Lite-ready-to-Live-Stream | Virtual Audio install + checkbox steps | Serato only |
| C5 | Serato launch auto-detects hardware when drivers installed | **CONFIRMED** | https://d1aeri3ty3izns.cloudfront.net/media/36/366330/download_366330.pdf | Installation / launch NOTE | Serato DJ Pro |
| C6 | rekordbox **Internal** mixer mode uses software mixer; **External** uses hardware/external mixer routing | **CONFIRMED** | https://rekordbox.com/en/support/faq/operation-hint/#faq-q500212 | Internal/External definitions | rekordbox desktop |
| C7 | rekordbox selects audio via Preferences → **Audio** device list, not macOS default alone | **CONFIRMED** | https://support.pioneerdj.com/hc/en-us/articles/4409257604761-Sound-comes-out-of-my-headphones-or-speakers-incorrectly-rekordbox | Step 1 Audio preference examples | rekordbox PERFORMANCE |
| C8 | **PC MASTER OUT** routes master to PC/Mac built-in speakers while hardware connected | **CONFIRMED** | https://support.pioneerdj.com/hc/de/articles/12185292173337-Warum-kommt-der-Ton-aus-meinem-PC-Mac-oder-dem-eingebauten-Lautsprecher-meines-mobilen-Ger%C3%A4ts-nicht-richtig-heraus | rekordbox Mac/Windows PC Master Out section | rekordbox desktop |
| C9 | Mac CDJ/XDJ multi-player output uses **Pioneer CDJ/XDJ** aggregate via Aggregator tool | **CONFIRMED** | https://support.pioneerdj.com/hc/en-us/articles/4413832776345-CDJ-XDJ-Aggregator-Instruction-Manual | rekordbox PERFORMANCE configuration section | Mac + CDJ/XDJ |
| C10 | rekordbox laptop recording: built-in speaker + Internal mixer mode | **CONFIRMED** | https://support.pioneerdj.com/hc/en-us/articles/8213839784473-I-cannot-record-audio-in-PERFORMANCE-mode | “no equipment / non-Pioneer” bullet | rekordbox PERFORMANCE |
| C11 | Traktor **Audio Device** dropdown selects built-in or external interface explicitly | **CONFIRMED** | https://docs.native-instruments.com/ni-tech-manuals/traktor-pro-manual/en/preferences | Audio Setup → Audio Device | Traktor Pro |
| C12 | Traktor **External Mixing Mode** bypasses internal mixer; decks to interface outputs | **CONFIRMED** | same as C11 | Output Routing → External Mixing Mode | Traktor Pro |
| C13 | Traktor auto-configures routing for Kontrol/certified devices | **CONFIRMED** | same as C11 | Output Routing intro paragraph | Traktor Pro + certified gear |
| C14 | Traktor **Win Built-In** fallback when primary device unavailable | **CONFIRMED** | same as C11 | Built-in Soundcard → Win Built-In | **Windows only** |
| C15 | VirtualDJ **COMPUTER AUDIO** uses computer **default soundcard** | **CONFIRMED** | https://virtualdj.com/manuals/virtualdj/settings/audiosetup.html | HARDWARE → COMPUTER AUDIO | VirtualDJ |
| C16 | VirtualDJ advanced OUTPUTS assign per-source soundcards/channels | **CONFIRMED** | same as C15 | ADVANCED AUDIO SETTINGS → OUTPUTS | VirtualDJ |
| C17 | VirtualDJ internal master recording vs external mixer **Record Loopback** | **CONFIRMED** | https://virtualdj.com/manuals/virtualdj/settings/record/ ; https://virtualdj.com/manuals/virtualdj/settings/audiosetup/recordloopback.html | Record intro; Record Loopback section | VirtualDJ |
| C18 | djay **Internal** mode: Main Output picker; **External** mode: per-deck outputs | **CONFIRMED** | https://help.algoriddim.com/user-manual/djay-pro-mac/settings/audio-devices | Internal/External mixing options | djay Pro Mac |
| C19 | djay auto-configures audio for supported controllers on connect | **CONFIRMED** | https://help.algoriddim.com/user-manual/djay-pro-mac/getting-started/audio-settings | “Setting up audio with a supported DJ controller” | djay Pro Mac |
| C20 | djay **External** mode disables internal recording / Automix | **CONFIRMED** | https://help.algoriddim.com/user-manual/djay-pro-mac/hardware/mixer-mode | External mixer mode section | djay Pro Mac |
| C21 | Core Audio process taps available macOS 14.2+ with user consent | **CONFIRMED** | https://apple-docs.everest.mt/docs/sample-code/coreaudio/capturing-system-audio-with-core-audio-taps/ | Intro + permission note | Platform |
| C22 | ScreenCaptureKit captures audio; filters at application level | **CONFIRMED** | https://developer.apple.com/videos/play/wwdc2022/10156/ | Audio side configuration segment | Platform |
| U1 | Any listed DJ app uses Core Audio hog mode during normal DJ play | **UNKNOWN** | — | — | All five apps |
| U2 | Mid-session macOS default output change retargets each DJ app’s master stream | **UNKNOWN** | — | — | Per-app bench |
| U3 | rekordbox / Traktor / VirtualDJ / djay ship macOS virtual master drivers like Serato Virtual Audio | **UNKNOWN** | — | — | Non-Serato apps |
| U4 | Process Audio Tap captures master when mix is routed only to controller physical outputs | **UNKNOWN** | — | — | Controller-PA mode |

---

## 4. Capture-path applicability matrix

Legend: **✓** documented or strongly supported · **~** plausible, bench test required · **✗** poor fit / documented bypass · **?** unknown

### 4.1 By application and output mode

| App | Output mode | Process Audio Tap | ScreenCaptureKit app audio | Vendor virtual input | HAL / default-device routing | USB master / loopback input |
|---|---|---|---|---|---|---|
| **Serato** | Practice / offline (OS default) | ~ | ~ | ✗ (unless user enables Serato VA) | ✓ | ✗ |
| **Serato** | Controller → hardware master | ~ | ~ | ✗ (unless Serato VA enabled) | ✗ | ✓ |
| **Serato** | Controller + Use Laptop Speakers | ~ | ~ | ✗ (unless Serato VA) | ✓ (master on OS default) | ~ (cue on controller) |
| **Serato** | + Serato Virtual Audio enabled | ~ | ~ | ✓ (Serato VA) | ~ | ~ |
| **rekordbox** | Laptop Internal → built-in | ~ | ~ | ? | ✓ | ✗ |
| **rekordbox** | Controller Internal → hardware driver | ~ | ~ | ? | ✗ | ✓ |
| **rekordbox** | + PC MASTER OUT | ~ | ~ | ? | ✓ (parallel Mac speaker path) | ✓ (hardware) |
| **rekordbox** | External → mixer/interface | ~ | ~ | ? | ✗ | ✓ |
| **Traktor** | Built-in Internal | ~ | ~ | ? | ✓ | ✗ |
| **Traktor** | Interface Internal (master+cue) | ~ | ~ | ? | ✗ | ✓ (if PA on hardware) |
| **Traktor** | External mixing | ~ | ~ | ? | ✗ | ✓ |
| **VirtualDJ** | COMPUTER AUDIO / Internal master | ~ | ~ | ? | ✓ | ✗ |
| **VirtualDJ** | Controller predefined profile | ~ | ~ | ? | ✗ | ✓ |
| **VirtualDJ** | External mixer + SEPARATE DECKS | ~ | ✗ (crossfader blind) | ? | ✗ | ✓ + Record Loopback |
| **djay** | Internal → Main Output built-in | ~ | ~ | ? | ✓ | ✗ |
| **djay** | Controller auto Internal | ~ | ~ | ? | ✗ | ✓ |
| **djay** | External mixer | ~ | ✗ (no internal rec) | ? | ✗ | ✓ + Recording Input |

### 4.2 Permission / installation notes (capture paths)

| Path | Permission / install | Label |
|---|---|---|
| Process Audio Tap | macOS 14.2+; system audio recording TCC; no vendor driver | **CONFIRMED** (Apple sample) |
| ScreenCaptureKit | Screen Recording TCC; dummy video stream common; app signed/notarized as usual Mac app | **CONFIRMED** / **INFERRED** |
| Serato Virtual Audio | User opt-in; Serato driver install via in-app prompt; **Serato license to Serato ecosystem only** | **CONFIRMED** |
| HAL default switch | No extra driver; affects only apps/devices bound to default output | **INFERRED** |
| USB / loopback | Physical cable or mixer REC→interface input; may need user wiring | **CONFIRMED** (VDJ/djay external docs) |

**License note:** Serato Virtual Audio driver and streaming guides are **Serato proprietary**; redistribution or bundling by DJMemory would require separate legal review (**INFERRED** from Serato support articles — not a license grant).

---

## 5. Smallest bench matrix

Minimum experiments to resolve **UNKNOWN** routing/capture claims. Each cell: one 10-minute session, record whether capture received full master post-fader.

| App | A: System-default / laptop path | B: Representative USB controller path |
|---|---|---|
| **Serato DJ Pro** | Practice mode; macOS default = Built-in; no hardware. Capture via PAT + SCK + default HAL. | DDJ/Numark-class controller; master on RCA to interface/monitor; *Use Laptop Speakers* **off**. Repeat with Serato Virtual Audio **on** (isolated Serato test). |
| **rekordbox** | PERFORMANCE; Audio = Built-in; Internal mixer; PC MASTER OUT **off**. | DDJ/XDJ class; Audio = device driver; Internal mixer; master on hardware PHONES/MASTER ports; PC MASTER OUT **on** vs **off**. |
| **Traktor Pro** | Audio Device = Built-in; Internal routing; master on Built-in. | Traktor Kontrol or class-compliant interface; Internal routing; master on hardware MAIN. Second run: External mixing + external mixer or interface deck outs. |
| **VirtualDJ** | SPEAKER ONLY + COMPUTER AUDIO; record internally vs PAT. | Supported controller profile; master on controller RCA. Second run: SEPARATE DECKS + external mixer + Record Loopback. |
| **djay Pro** | Internal; Main Output = Built-in; record internally vs PAT. | Supported controller; auto-config; master on controller main. Second run: External mixer mode + REC loopback input. |

**Cross-cutting row (all apps):** With app running and audibly playing, switch macOS default output once; note whether master moves without touching app preferences (**resolves U2**).

**Pass criteria:** Identify which capture paths receive (1) full post-fader master, (2) cue bleed, (3) silence despite audible PA.

---

## 6. Cross-app conclusions

### Safe cross-app claims

1. **All five apps support an explicit in-app audio routing layer** beyond macOS System Settings for at least some modes (Preferences/Settings/Audio Setup/Devices) (**CONFIRMED** across vendor manuals).
2. **Controller/mixer gig mode commonly routes master audio through the USB audio interface or physical master outputs**, not through the Mac’s default output device (**CONFIRMED** pattern across Serato controller guides, rekordbox Audio preference examples, Traktor Audio Device selection, VirtualDJ controller profiles, djay auto-config docs).
3. **External mixer modes** (rekordbox External, Traktor External, VirtualDJ SEPARATE DECKS, djay External) move the **authoritative mix bus to hardware**; software-side master capture is documented as incomplete unless loopback/recording input is configured (**CONFIRMED** for VirtualDJ and djay; **CONFIRMED** External mixing semantics for Traktor/rekordbox).
4. **Only Serato documents a first-party macOS virtual master device (Serato Virtual Audio)** for third-party consumption; absence of public docs for other vendors is **UNKNOWN**, not evidence of absence (**CONFIRMED** Serato; **UNKNOWN** others).
5. **Apple platform capture APIs (Process Audio Tap, ScreenCaptureKit)** are process/app-oriented and **may** capture software-rendered master regardless of selected device, but **cannot be assumed** when the audible master never passes through the Mac (**CONFIRMED** API scope; **UNKNOWN** per-app graphs — bench required).
6. **Routine post-onboarding output changes should not be required** for stable single-controller setups (**INFERRED**); documented exceptions include Serato *Use Laptop Speakers* refresh (C3), rekordbox aggregate/driver recovery, and VirtualDJ profile switching.

### App-specific claims (do not generalize)

| Claim | Applies to |
|---|---|
| Serato Virtual Audio streaming/recording path | **Serato only** |
| rekordbox PC MASTER OUT + Pioneer aggregate CDJ workflow | **rekordbox / Pioneer ecosystem only** |
| VirtualDJ Record Loopback for external mixer truth | **VirtualDJ only** (similar pattern in djay but separate docs) |
| Traktor Win Built-In fallback | **Traktor on Windows only** |
| djay Automix/recording disabled in External mode | **djay only** |

### Unresolved contradictions

| Contradiction | Smallest test |
|---|---|
| Traktor appendix §18.1 describes onboard **Fallback** generically, but Preferences labels **Win Built-In** as Windows-only | On macOS: set external Audio Device, unplug interface mid-session; observe AUDIO indicator color + audible output |
| Serato *Use Laptop Speakers* couples to OS default, but normal controller mode path is less explicitly documented in fetchable primary pages | Controller connected, Use Laptop Speakers off: change macOS default mid-set; measure whether PA master moves |
| ScreenCaptureKit / PAT may capture in-app master while user listens on hardware outputs | Controller mode, PAT+SCK vs physical master meter on hardware simultaneously |

### Behavior still requiring bench test (not documented)

- Mid-session macOS default output switch for each app (**U2**)
- Hot USB disconnect/reconnect audio rebind (macOS) for each app
- Hog/exclusive mode use (**U1**)
- PAT/SCK signal presence vs audible master on controller RCA (**U4**)

---

*Document produced for DJMemory invisible-capture evidence gathering. Does not recommend final DJMemory architecture.*
