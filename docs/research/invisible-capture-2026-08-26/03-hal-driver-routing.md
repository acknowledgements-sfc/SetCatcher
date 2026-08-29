# HAL Driver Routing — Invisible Capture Evidence (Worker 3)

**Access date:** 2026-08-26  
**Scope:** Original `DJMemoryAudio.driver` AudioServerPlugIn + privileged helper install model. Intended identity from `Sources/DJMemoryCore/DJMemoryAudioDriver.swift`: bundle `DJMemoryAudio.driver`, device name **DJMemory Audio**, UID `app.djmemory.DJMemoryAudio:device`, bundle ID `app.djmemory.DJMemoryAudio`.  
**Out of scope:** Final architecture recommendation; DJ-app behavior inferred from Serato Virtual Audio; copying BlackHole or proprietary recorder drivers.

---

## Executive answer

An original **AudioServerPlugIn** virtual device (`DJMemoryAudio.driver`) **can** make capture invisible for apps that **follow the system default output**, if onboarding installs the driver and (once) sets system default or a multi-output device that includes the virtual device **and** the DJ’s real interface—without asking the DJ to open Audio MIDI Setup on every session.

That approach **fails the universal no-manual-routing bar** when DJ software **pins an explicit output device** (USB interface, built-in, controller audio): a HAL virtual driver **does not receive that app’s PCM** unless the app’s output route includes the virtual device. Apple documents explicit per-device output via `kAudioOutputUnitProperty_CurrentDevice`; loopback HAL plugins only see audio **written to them**.

**Core Audio process taps** (macOS 14.2+, separate from AudioServerPlugIn) can capture outgoing audio in parallel without changing the user’s output device, but they require **Screen & System Audio Recording** permission, `NSAudioCaptureUsageDescription`, and per-process targeting—they are not a drop-in substitute for `DJMemoryAudio.driver`.

---

## 1. Architecture diagram (prose)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  User session: DJMemoryApp (SwiftUI, DJMemoryCore client)               │
│  • Discovers UID app.djmemory.DJMemoryAudio:device via HAL APIs         │
│  • Registers SMAppService daemon; XPC to helper for install lifecycle   │
│  • (Optional) sets/restores kAudioHardwarePropertyDefaultOutputDevice    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ NSXPCConnection + code-signing requirements
                                │ Mach service names declared in both sides
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Root: Privileged helper daemon (SMAppService, embedded in app bundle)   │
│  Contents/Library/LaunchDaemons/*.plist → register() prompts admin once │
│  • Validates driver bundle signature (Team ID / requirement string)     │
│  • Copies DJMemoryAudio.driver → /Library/Audio/Plug-Ins/HAL/           │
│  • chown root:wheel; triggers coreaudiod reload (killall, not kickstart) │
│  • Uninstall: rm driver bundle + reload                                  │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ file install + coreaudiod restart
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Root: coreaudiod (com.apple.audio.coreaudiod)                         │
│  Scans /Library/Audio/Plug-Ins/HAL/*.driver                             │
│  Loads CFPlugIn factories: kAudioServerPlugInTypeUUID                   │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ AudioServerPlugInDriverInterface
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Sandboxed plug-in host process (per driver bundle)                     │
│  DJMemoryAudio.driver — virtual I/O device "DJMemory Audio"           │
│  • Must NOT call client HAL APIs (CoreAudio.framework) from plug-in      │
│  • IPC via AudioServerPlugIn_MachServices → helper/app XPC (if used)    │
│  • Persistent key-value storage via host-provided Storage API only      │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ PCM only when apps render TO this device
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  DJ app audio path                                                       │
│  System-default followers → default / multi-output → may hit driver     │
│  Explicit hardware pinners → named interface only → bypasses driver     │
└─────────────────────────────────────────────────────────────────────────┘
```

**Data plane vs control plane:** Installation and `coreaudiod` reload are **control plane** (helper, admin auth, Background Items approval). Capture is **data plane**: PCM flows only through HAL routes the DJ app actually selects.

---

## 2. Eight-point evidence matrix

| # | Question | Verdict | Evidence strength |
|---|----------|---------|-------------------|
| 1 | Is `/Library/Audio/Plug-Ins/HAL` the required install location for `.driver` bundles? | **CONFIRMED** | Apple `AudioServerPlugIn.h` Overview |
| 2 | Can HAL plug-ins install user-level without root (`~/Library/...`)? | **UNKNOWN** (likely **no** for production) | Apple header names only system path; forum reports of missing `~/Library/.../HAL` |
| 3 | Can a virtual AudioServerPlugIn hear app audio **without** that app routing output through it? | **CONFIRMED no** (classic loopback model) | libASPL example semantics; HAL I/O model |
| 4 | Can capture be invisible for **system-default** apps after one-time route setup? | **INFERRED yes** (bench test required) | Default output property APIs; multi-output Apple Support |
| 5 | Does approach fail when DJ app selects explicit hardware output? | **CONFIRMED yes** | Core Audio Overview AUHAL `CurrentDevice` |
| 6 | Can `SMAppService.daemon` replace SMJobBless for HAL file install? | **INFERRED yes** (pattern exists; not Apple HAL-specific doc) | Apple Service Management docs + LemurCam reference implementation |
| 7 | Does `SMAppService.register()` itself grant passwordless root file copy? | **CONFIRMED no** — daemon registration prompts authentication; helper still performs privileged ops | Apple updating-helper docs; theevilbit SMAppService notes |
| 8 | After driver install on macOS 14.4+, is `launchctl kickstart -k system/com.apple.audio.coreaudiod` supported? | **CONFIRMED no** — use `kill`/`killall coreaudiod` instead | macOS 14.4 Release Notes Known Issues |

---

## 3. Claim table

| Claim | Label | Primary URL | Evidence location | Scope / notes |
|-------|-------|-------------|-------------------|---------------|
| AudioServerPlugIn bundles install in `/Library/Audio/Plug-Ins/HAL`, suffix `.driver`, factory UUID `kAudioServerPlugInTypeUUID`, interface `kAudioServerPlugInDriverInterfaceUUID` | **CONFIRMED** | [AudioServerPlugIn.h (Apple SDK header mirror)](https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.11.sdk/System/Library/Frameworks/CoreAudio.framework/Versions/A/Headers/AudioServerPlugIn.h) | `@header AudioServerPlugIn` Overview, lines 27–31 | All macOS versions using legacy HAL plug-in model |
| Plug-in host is sandboxed: no client HAL API calls; bundle-only reads; Mach services must be listed in `AudioServerPlugIn_MachServices` | **CONFIRMED** | [QA1811: AudioServerPlugIn_MachServices](https://developer.apple.com/library/archive/qa/qa1811/_index.html) | Answer paragraphs 1–3 | Any AudioServerPlugIn needing IPC to DJMemory helper |
| HAL plug-ins are loaded by `coreaudiod` (root); installing into HAL path requires root ownership | **CONFIRMED** | [Beyond the good ol' LaunchAgents — Audio Plugins](https://theevilbit.github.io/beyond/beyond_0013/) | Section “HAL plugins are loaded by coreaudiod…” | Secondary source; consistent with Apple header path + forum install reports |
| For **virtual** devices, Apple recommends **Audio Server Plug-In**, not AudioDriverKit; AudioServerPlugIn interface is **not deprecated** | **CONFIRMED** | [WWDC21 — Create audio drivers with DriverKit](https://developer.apple.com/videos/play/wwdc2021/10190/) | Transcript: virtual driver entitlements not granted; “plug-in driver model should continue to be used”; “not deprecated” | Virtual loopback / cable devices |
| AudioDriverKit sample note: virtual device → use Audio Server Driver Plug-in | **CONFIRMED** | [Creating an audio device driver](https://developer.apple.com/documentation/audiodriverkit/creating-an-audio-device-driver) | Note under driver setup | Reinforces WWDC21; dext path not evaluated for DJMemory here |
| libASPL is **MIT** licensed; vendoring requires copyright + permission notice in copies | **CONFIRMED** | [libASPL LICENSE (raw)](https://raw.githubusercontent.com/gavv/libASPL/main/LICENSE) | Full MIT text | Framework only; DJMemory driver must be original code |
| libASPL CI builds on macOS 13–15; M1 fixes in release notes → **arm64 + Intel** viable when built universal | **INFERRED** | [libASPL README](https://github.com/gavv/libASPL/blob/main/README.md), [Releases](https://github.com/gavv/libASPL/releases) | CI matrix; “Fix tests on M1” | No single Apple doc; build architecture is vendor responsibility |
| libASPL **NetcatDevice** output driver: “Sound from apps that **write to device** is mixed…” | **CONFIRMED** | [libASPL README — Example drivers table](https://github.com/gavv/libASPL/blob/main/README.md) | Example drivers table, NetcatDevice row | Parallels loopback HAL semantics; not DJ-specific |
| BlackHole is **GPL-3.0**; non-GPL integration requires separate license | **CONFIRMED** | [BlackHole LICENSE](https://github.com/ExistentialAudio/BlackHole/blob/df74f6bb880eba393b772330039834a420937911/LICENSE), [BlackHole README FAQ](https://github.com/ExistentialAudio/BlackHole?tab=readme-ov-file) | GPL text; “Can I integrate BlackHole into my app?” | **Cannot vend BlackHole in DJMemory tree** |
| System default output changed via `kAudioHardwarePropertyDefaultOutputDevice` + `AudioObjectSetPropertyData` on system object | **CONFIRMED** | [ConfigDefaultOutput.c (Apple sample)](https://developer.apple.com/library/archive/samplecode/HALExamples/Listings/ConfigDefaultOutput_c.html) | Set/get default output device | Apps using default output unit follow this route |
| Apps can target a **specific** device with AUHAL `kAudioOutputUnitProperty_CurrentDevice` | **CONFIRMED** | [Core Audio Overview — Common Tasks](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/ARoadmaptoCommonTasks/ARoadmaptoCommonTasks.html) | “The AUHAL Unit” section | **Explicit hardware pinners** |
| User-created aggregate devices are **global**; programmatic aggregates can be process-local | **CONFIRMED** | [Core Audio Overview — Using Aggregate Devices](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/ARoadmaptoCommonTasks/ARoadmaptoCommonTasks.html) | Aggregate Devices section | Persistence differs by creation path |
| Aggregate device **cannot be system default** unless **all** sub-devices can be default; else apps must **explicitly select** it | **CONFIRMED** | Same as above | Limitations list | Blocks “silent default to aggregate” when subdevices include non-default-capable members |
| Multi-output device plays through **several outputs at once**; configured in Audio MIDI Setup | **CONFIRMED** | [Apple Support — Play audio through multiple devices](https://support.apple.com/guide/audio-midi-setup/play-audio-through-multiple-devices-at-once-ams7c093f372/mac) | Steps 1–3 | Candidate for “hear interface + capture virtual” **if** DJ app uses multi-output as output |
| Core Audio **process taps** (macOS 14.2+): capture outgoing audio from process/group; add tap to aggregate device; **does not require** changing speaker output for tap path | **CONFIRMED** | [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps) | Overview + Important note on `NSAudioCaptureUsageDescription` | **Separate mechanism** from AudioServerPlugIn; needs Screen & System Audio Recording |
| First tap recording prompts **system audio recording** permission | **CONFIRMED** | Same as above | Permission paragraph | Onboarding consent, not DJ output menu |
| `SMAppService.daemon(plistName:)` registers LaunchDaemon **inside app bundle**; first registration prompts user approval + **authentication** for daemon | **CONFIRMED** | [Updating helper executables (macOS 13+)](https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos) | Install paths; register flow; daemon auth | Helper still must implement copy/reload XPC handlers |
| Re-registering an **already approved** daemon may not re-prompt authentication | **INFERRED** | [SMAppService quick notes (theevilbit)](https://theevilbit.github.io/posts/smappservice/) | “unregistering and registering again doesn’t require further authentication” | Upgrade/reinstall UX |
| `SMAppService` daemon does **not** automatically inherit app TCC permissions (e.g. HID seize) | **CONFIRMED** | [Apple Developer Forums — SMAppService vs SMJobBless HID](https://developer.apple.com/forums/thread/795686) | DTS + OP reports `kIOReturnNotPermitted` | Analogous caution for audio capture entitlements in helper |
| macOS 14.4+: `launchctl kickstart -k` **not permitted** for `coreaudiod`; Apple recommends **`kill`** | **CONFIRMED** | [macOS 14.4 Release Notes](https://developer.apple.com/documentation/macos-release-notes/macos-14_4-release-notes) | Core Audio Known Issues (123028502) | Install/uninstall scripts must use `killall coreaudiod` |
| Apple feedback to developer: **reboot** only supported plug-in load/unload method (community uses kill anyway) | **INFERRED** | [Stack Overflow — Catalina AudioServerPlugIn installation](https://stackoverflow.com/questions/57839594/macos-catalina-audioserverplugin-installation) | Accepted answer UPDATE (Apple FB7244673) | Contradiction: kill works in practice on 14.4+ per forum |
| HAL driver distribution: Developer ID sign + **notarize**; plug-ins may need host entitlements | **CONFIRMED** | [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) | Hardened runtime + plug-in inheritance sections | `.pkg` or notarized `.driver` in signed installer |
| `~/Library/Audio/Plug-Ins/HAL` is a supported plug-in scan path | **UNKNOWN** | Apple header cites **only** `/Library/Audio/Plug-Ins/HAL` | — | Smallest test: install to `~/Library/...` and enumerate devices |
| Privileged helper can install HAL driver without separate **AuthorizationExecuteWithPrivileges** / `.pkg` if helper runs as root via SMAppService | **INFERRED** | [LemurCam LemurAudioHelper.swift](https://github.com/steelbrain/LemurCam/blob/816bfb86/Shared/LemurAudioHelper.swift) | Comments + `halPluginsDirectory` constant | Reference pattern, not Apple normative doc |
| DJMemory can rely on SMAppService alone with **no** admin password after first approval for HAL **file** writes | **UNKNOWN** | — | — | Needs bench: helper `copyItem` to `/Library/Audio/Plug-Ins/HAL` after daemon enabled |

---

## 4. Install / update / uninstall lifecycle

### 4.1 Prerequisites

| Requirement | Label | Notes |
|-------------|-------|-------|
| Developer ID Application certificate | **CONFIRMED** | Sign app, helper, and `.driver` bundle |
| Hardened Runtime on signed executables | **CONFIRMED** | Required for notarization |
| Notarization + staple (for distribution outside Mac App Store) | **CONFIRMED** | Prefer signed flat `.pkg` or notarized zip per [Customizing notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) |
| `AudioServerPlugIn_MachServices` in driver `Info.plist` if driver talks to helper | **CONFIRMED** | [QA1811](https://developer.apple.com/library/archive/qa/qa1811/_index.html) |
| `AssociatedBundleIdentifiers` in daemon plist | **CONFIRMED** | [Updating helper executables](https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos) |
| User approves Background Item / Login Item for daemon | **CONFIRMED** | System Settings → Login Items |
| Admin password on **first** daemon registration (typical) | **INFERRED** | SMAppService daemon auth flow |

### 4.2 Install sequence (documented pattern)

1. App embeds `DJMemoryAudio.driver` in Resources and helper daemon under `Contents/Library/LaunchDaemons/*.plist` with `.plist` extension in `SMAppService.daemon(plistName:)`.
2. `register()` → user approves background item → admin authentication.
3. Helper (root) validates driver signature against pinned requirement (Team ID + bundle ID `app.djmemory.DJMemoryAudio`).
4. Helper copies to `/Library/Audio/Plug-Ins/HAL/DJMemoryAudio.driver`, `chown root:wheel`.
5. Helper reloads audio stack: **`sudo killall coreaudiod`** on macOS 14.4+ (**CONFIRMED**); avoid `launchctl kickstart -k system/com.apple.audio.coreaudiod`.
6. App verifies UID `app.djmemory.DJMemoryAudio:device` appears via HAL enumeration.

### 4.3 Update

| Step | Label |
|------|-------|
| Ship new `.driver` inside updated app bundle | **CONFIRMED** pattern |
| Helper stops IO (best effort), replaces bundle, reloads `coreaudiod` | **INFERRED** — Apple silent on hot-swap |
| Re-registration without re-auth if daemon already approved | **INFERRED** |
| Active DJ session may glitch or lose device during reload | **INFERRED** — bench test |

### 4.4 Uninstall / rollback

1. Helper removes `/Library/Audio/Plug-Ins/HAL/DJMemoryAudio.driver`.
2. Reload `coreaudiod` (or reboot if reload fails — **INFERRED** from Apple “reboot only” guidance vs community kill practice).
3. App restores previous default output if it changed defaults during onboarding (**application responsibility** — **INFERRED**; Apple provides property APIs only).
4. `SMAppService.unregister()` disables daemon; user can disallow in Login Items (**CONFIRMED**).

### 4.5 Approval & upgrade implications

- **Gatekeeper / quarantine:** Notarized `.pkg` or stapled ticket reduces friction (**CONFIRMED**).
- **Login Items “enabled but disallowed”** state after user toggle: daemon plist may show enabled+disallowed (**INFERRED**, theevilbit).
- **MDM silent install:** Enterprise pkg as user may succeed where headless `register()` fails with “Operation not permitted” (**INFERRED**, [Forums Service Management tag](https://developer.apple.com/forums/tags/servicemanagement)).

---

## 5. Routing and restoration limits

### 5.1 System-default followers vs explicit hardware

| Behavior | Label | Mechanism |
|----------|-------|-----------|
| App uses **default output** (Default Output audio unit, or OS default) | **CONFIRMED** | Follows `kAudioHardwarePropertyDefaultOutputDevice` |
| App sets **named interface** (Rane, Pioneer, built-in, “DJM-…”) | **CONFIRMED** | AUHAL `kAudioOutputUnitProperty_CurrentDevice` |
| Virtual HAL driver receives PCM | **CONFIRMED** | Only when app renders to that device ID / name |
| Changing system default programmatically affects default followers | **INFERRED** | Requires admin-capable helper or user consent; persistence across reboot **UNKNOWN** without bench |

**Routine DJ-app output changes after onboarding:**

| Scenario | DJ must change output in app? | Label |
|----------|------------------------------|-------|
| HAL loopback; DJ app already pinned to USB interface | **Yes** — otherwise silence on virtual input | **CONFIRMED** |
| Onboarding sets **multi-output** (interface + DJMemory) as system default; DJ app follows system default | **No** per session if default persists | **INFERRED** |
| Onboarding sets DJ app output to DJMemory / aggregate once; app remembers last device | **No** until app resets preference or OS update clears it | **INFERRED** |
| Core Audio **process tap** on DJ process PID; output stays on hardware | **No output change**; permission prompt instead | **CONFIRMED** (tap doc) — **not** HAL plug-in path |

### 5.2 Aggregate vs multi-output (HAL plug-in path)

| Approach | Capture + monitor DJ booth | Default-route hijack? | Label |
|----------|------------------------------|----------------------|-------|
| Set virtual device as **system default** | DJ hears virtual unless driver forwards to hardware (proxy driver) | Yes | **INFERRED** |
| **Multi-output** (interface + DJMemory) as default | Both receive PCM if driver forwards or multi-out duplicates | Yes (system default) | **CONFIRMED** concept; **UNKNOWN** per-DJ-app |
| **Aggregate** with virtual subdevice | Input side may expose virtual capture; output routing varies | Often requires explicit selection | **CONFIRMED** limitations on default eligibility |
| Programmatic **private** aggregate with tap (14.2+) | Parallel capture | No output change | **CONFIRMED** for tap API |

**Sample-rate rule:** All aggregate sub-devices must run the **same sample rate** (**CONFIRMED**, Core Audio Overview). DJ interfaces at 48 kHz vs driver at 44.1 kHz → **presentButUnusable** class failure until aligned (**INFERRED**).

### 5.3 Hard constraint — can virtual driver hear without routing?

**No**, for the AudioServerPlugIn loopback model DJMemory identity describes.

| Mechanism | Hears un-routed app output? | Label |
|-----------|----------------------------|-------|
| Classic virtual HAL output (BlackHole-style, DJMemory-style) | **No** | **CONFIRMED** |
| Proxy HAL driver (forwards what is written **to proxy** to real device) | **No** — app must still write to proxy | **INFERRED** from proxy-audio-device install docs |
| Core Audio process tap + aggregate | **Yes**, for targeted process(es), output unchanged | **CONFIRMED** |
| Kernel tap / undocumented HAL hooks | — | **UNKNOWN** — out of scope |

**Fails universal no-manual-routing bar:** Any DJ app that **retains explicit hardware output** and never includes `app.djmemory.DJMemoryAudio:device` in its route.

### 5.4 Invisible recovery matrix

| Failure | Detection | Recovery action | Label |
|---------|-----------|-----------------|-------|
| Driver crash / plug-in host exit | UID missing from device list | Helper reinstall + `killall coreaudiod`; offer re-run onboarding | **INFERRED** |
| DJMemoryApp force quit | Helper + driver may survive | Re-enumerate UID on relaunch | **INFERRED** |
| Reboot | Driver persists if installed; default route may revert | Re-apply saved default / multi-output from persisted snapshot | **INFERRED** |
| Helper disabled in Login Items | XPC install fails | `openSystemSettingsLoginItems()` + re-register (**CONFIRMED** API) |
| USB interface unplugged | Sub-device vanishes from aggregate/multi-out | Fall back to previous output UID; surface “interface disconnected” | **INFERRED** |
| Stale aggregate referencing removed device | HAL property errors / silent drop | Destroy and recreate aggregate composition | **INFERRED** |
| Sample-rate mismatch | IO start failure, glitch | Negotiate rate with subdevices; reconfigure driver | **CONFIRMED** rule + **INFERRED** UX |
| Previous output unavailable after restore | SetProperty returns error | Walk fallback list (built-in, last known good) | **INFERRED** |
| `coreaudiod` reload during live set | Audio glitch / device dropout | Defer reload until session end; or warn DJ | **INFERRED** |
| Tap permission revoked (14.2+ path) | IOProc `nope` / permission errors | Deep-link Privacy → Screen & System Audio Recording | **INFERRED** ([Forums 784955](https://developer.apple.com/forums/thread/784955)) |

Persist **previous route snapshot** (default output device ID/UID, DJ app bundle ID + last known output UID if readable): **INFERRED** best practice; Apple documents get/set default, not DJ-app-specific persistence.

---

## 6. Licensing constraints

| Component | License | DJMemory obligation | Label |
|-----------|---------|---------------------|-------|
| **libASPL** (optional framework) | MIT | Include copyright + permission notice in source/binary distributions | **CONFIRMED** |
| **Apple SimpleAudio / NullAudio** samples (if referenced) | Apple MIT / Apple MIT 2012 per libASPL README | Preserve Apple sample licenses if code borrowed | **CONFIRMED** |
| **BlackHole** | GPL-3.0 | **Do not copy or vend**; GPL would infect proprietary app | **CONFIRMED** |
| **Pancake** (Swift HAL framework) | Apache-2.0 | Alternative to libASPL; separate compliance | **CONFIRMED** (project README) |
| **Proprietary recorder drivers** (Loopback, etc.) | Commercial | No reuse | **CONFIRMED** policy |
| **DJMemoryAudio.driver** | Original | Must be clean-room; libASPL may be linked, not BlackHole | **CONFIRMED** intent in `DJMemoryAudioDriver.swift` |

---

## 7. Smallest bench tests

### 7.1 Clean Mac (HAL plug-in path)

| # | Test | Resolves | Pass criteria |
|---|------|----------|---------------|
| C1 | Install `DJMemoryAudio.driver` to `/Library/Audio/Plug-Ins/HAL` via SMAppService helper; reload with `killall coreaudiod` on macOS 14.4+ | Kickstart vs kill contradiction | UID `app.djmemory.DJMemoryAudio:device` visible in `system_profiler SPAudioDataType` without reboot |
| C2 | Play tone to **Built-in Output** default; record from DJMemory input | Universal capture without routing | **Expect silence** on DJMemory input |
| C3 | Set **DJMemory Audio** as system default; play tone | Default-follower capture | Non-zero PCM on virtual input |
| C4 | Create **multi-output** (Built-in + DJMemory); set as default; play tone | Multi-out invisible monitoring | PCM on DJMemory **and** audible built-in (**UNKNOWN** until run) |
| C5 | Uninstall driver; `killall coreaudiod`; reboot | Uninstall completeness | UID absent; no orphaned aggregate |
| C6 | Attempt install to `~/Library/Audio/Plug-Ins/HAL` only (no system copy) | User-level HAL path | **UNKNOWN** — device absent vs present |

### 7.2 Real DJ apps (one app per test; no cross-app inference)

| # | Test | Resolves | Pass criteria |
|---|------|----------|---------------|
| D1 | App X: note **Output device** in preferences (explicit hardware name) | Pinner vs follower | Record whether setting is interface name vs “System” |
| D2 | App X: start playback with **unchanged** DJ output preference | No-manual-routing bar | DJMemory input silent → **routing required** |
| D3 | App X: set system default to multi-out (interface + DJMemory) **without** changing in-app preference | Default follower hypothesis | If in-app still pins hardware → still silent |
| D4 | App X: change in-app output to DJMemory / aggregate **once**; relaunch app | Persistence | Does app remember route across relaunch? |
| D5 | App X: unplug USB interface mid-set | Recovery | Document HAL error + whether app auto-switches |
| D6 | macOS 14.2+ only: **process tap** on App X PID (official sample code) | Tap vs HAL plug-in | Capture with unchanged in-app hardware output + permission prompt |

**Contradictions to resolve:**

1. **Reboot vs killall for plug-in load** — Apple “reboot only” vs 14.4+ forum success with `killall coreaudiod` → **C1** on Sonoma 14.4+ and Sequoia 15.
2. **SMAppService root write without pkg** — **C1** with filesystem audit of HAL directory ownership after helper-only install.
3. **Multi-output default + explicit in-app pin** — **D3** per DJ app (Traktor, rekordbox, Serato, VirtualDJ, djay Pro each separate).

---

## Unresolved contradictions summary

| Contradiction | Smallest test |
|---------------|---------------|
| Apple FB7244673 “reboot only” vs `killall coreaudiod` working post-14.4 | **C1** without reboot after install |
| Aggregate/multi-output as system default vs DJ app explicit pin | **D3** per app |
| User-level `~/Library/.../HAL` support | **C6** |
| Whether proxy-style driver can snoop non-routed hardware without OS tap APIs | **C2** + code review of forward-only proxy semantics — expect **fail** |

---

## Routine onboarding vs per-session DJ output changes (summary)

| Path | Post-onboarding DJ output changes required? |
|------|---------------------------------------------|
| Original **DJMemoryAudio.driver** + explicit-hardware DJ apps | **Yes**, unless user/dev already routes app through DJMemory, multi-output, or aggregate |
| **DJMemoryAudio.driver** + system-default-only apps + persistent default/multi-out | **No** ( **INFERRED**, verify with **D3/D4** ) |
| **Core Audio process tap** (not HAL plug-in) | **No output change**; **Screen & System Audio Recording** consent instead (**CONFIRMED**) |

---

*Worker 3 — HAL driver routing evidence. No architecture recommendation. Access date 2026-08-26.*
