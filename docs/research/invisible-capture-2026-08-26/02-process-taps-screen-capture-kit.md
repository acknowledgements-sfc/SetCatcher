# Process Audio Taps and ScreenCaptureKit — Invisible Capture Evidence

**Access date:** 2026-08-26
**Scope:** macOS invisible app-audio capture for DJMemory after onboarding
**Question:** Can Core Audio Process Taps or ScreenCaptureKit capture one DJ application's audio automatically after onboarding, including when the application selects explicit USB/controller hardware rather than the system default output?

**DJMemory implementation reference (read-only):** `Sources/DJMemoryCore/AppAudioCaptureService.swift` already implements both backends: `ProcessAudioTapCaptureService` (preferred on macOS 14.2+) and `ScreenCaptureKitAppAudioCaptureService` (fallback). Selection order: optional verified virtual input (opt-in env) → Process Audio Tap → ScreenCaptureKit.

---

## 1. Executive findings

Neither Apple API documents capture behavior relative to a DJ app's **selected output device**. Both APIs are designed to intercept **process-level outgoing audio** inside Core Audio / ScreenCaptureKit without requiring the DJ app to expose a vendor tap. That supports the product goal of **no routine DJ-app output/input changes after onboarding** *when the mix is actually rendered through macOS audio for that process*.

**Process Audio Tap (Core Audio, macOS 14.2+)** is the stronger per-process mechanism. Apple documents `CATapDescription` as a mix of specified processes' output audio, `AudioHardwareCreateProcessTap`, aggregate-device attachment, and a **System Audio Recording** TCC prompt keyed by `NSAudioCaptureUsageDescription`. DJMemory already uses `CATapDescription(stereoMixdownOfProcesses:)`, private tap, aggregate device with `kAudioAggregateDeviceTapAutoStartKey`, IOProc metering/writing, and destroys tap + aggregate on stop.

**ScreenCaptureKit (macOS 13.0+ for `capturesAudio`)** can filter audio at **application level only** (WWDC22). DJMemory uses a display filter including one `SCRunningApplication`, minimal 2×2 video, `capturesAudio = true`, `excludesCurrentProcessAudio = true`, and **Screen & System Audio Recording** TCC via `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`. A video stream is still required even for audio-only capture (INFERRED from Apple's screen-capture sample architecture; bench-confirmed pattern in DJMemory code).

**Explicit USB / controller / vendor-driver / exclusive / aggregate-output routing:** **UNKNOWN** from Apple primary documentation. Apple's optional `CATapDescription` `deviceUID` + `stream` parameters imply taps *can* target a specific device output stream, but Apple does not state that `stereoMixdownOfProcesses` (no `deviceUID`) follows the DJ app's currently selected non-default device. ScreenCaptureKit likewise documents app-level audio filtering, not HAL output-device routing.

**Distribution:** No Apple-documented entitlement grants system-audio or screen capture. Process Tap needs `NSAudioCaptureUsageDescription`; ScreenCaptureKit needs `NSScreenCaptureUsageDescription` (currently **missing** from `scripts/build-app.sh` — packaging gap). Sandbox apps using Core Audio input paths need `com.apple.security.device.audio-input` (DJMemory has it). Developer ID builds require notarization; Mac App Store builds use App Store review instead. TCC grants bind to code signature — ad-hoc signing resets permissions (Apple Developer Forums, DTS).

**Bench status (repo, system-default / Mac-heard output only):** All five DJ apps passed meter+write probes through Mac system output (`docs/integration-status.md`, 2026-08-12–14). That does **not** establish USB-explicit-output behavior and must not be extrapolated per app.

**Direct answer to the question:** **Partially supported, hardware path unproven.** After onboarding permissions, both APIs can auto-target a running DJ process by bundle ID/PID without further DJ-app setting changes **if** audio is present in the process tap / SCK app-audio stream. Whether that holds when Serato/rekordbox/Traktor/VirtualDJ/djay route master output to an explicit USB/controller device (Pioneer DJM, XDJ, Traktor Kontrol, etc.) is **UNKNOWN** and requires per-app bench tests (Section 6).

No architecture recommendation in this document — evidence only.

---

## 2. Process Tap eight-point evidence matrix

| # | Evidence area | Finding | Label |
|---|---------------|---------|-------|
| **1** | **Exact API / mechanism** | `CATapDescription` → `AudioHardwareCreateProcessTap(_:_:)` → read `kAudioTapPropertyUID` + `kAudioTapPropertyFormat` → attach tap UID via `kAudioAggregateDeviceTapListKey` on `AudioHardwareCreateAggregateDevice` → read PCM via device IOProc. Modern Swift wrapper: `AudioHardwareSystem.makeProcessTap(description:)`. PID→process object: `kAudioHardwarePropertyTranslatePIDToProcessObject`. Destroy: `AudioHardwareDestroyProcessTap`, `AudioHardwareDestroyAggregateDevice`. **Minimum macOS: 14.2** (Apple sample code requirement). DJMemory uses `stereoMixdownOfProcesses`, `isPrivate = true`, drift-compensated sub-tap. | **CONFIRMED** — [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps), [CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription), [init(stereoMixdownOfProcesses:)](https://developer.apple.com/documentation/coreaudio/catapdescription/init(stereomixdownofprocesses:)), [AudioHardwareTap](https://developer.apple.com/documentation/coreaudio/audiohardwaretap) |
| **2** | **Install location / helper model** | In-process HAL APIs only. No Apple-documented kernel extension, Audio Server plug-in, launch daemon, or privileged helper for Process Taps. Tap and aggregate device are created in the capturing app's process. | **CONFIRMED** — [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps) (sample creates/destroys tap and aggregate in app) |
| **3** | **Entitlements, permissions, signing, notarization** | **Info.plist:** `NSAudioCaptureUsageDescription` required; first recording from aggregate-with-tap triggers **System Audio Recording** prompt. **No** Apple-documented `com.apple.security.system-audio-capture` or similar entitlement (repo already verified absent from [Entitlement Key Reference](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html)). **Sandbox:** `com.apple.security.device.audio-input` enables Core Audio input access ([Audio Input Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input)). **Developer ID:** notarization required ([Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)). **Mac App Store:** sandbox + review; notarization not required for store builds. **TCC persistence:** stable Developer ID signing identity required; ad-hoc signing resets TCC ([Forums #695689](https://developer.apple.com/forums/thread/695689)). DJMemory maps `kAudioHardwareIllegalOperationError` to permission denied (implementation detail). | **CONFIRMED** (permissions/entitlements/notarization rules); **INFERRED** (illegal-op ↔ TCC denial mapping) |
| **4** | **Per-process targeting** | `init(stereoMixdownOfProcesses:)` takes `[AudioObjectID]` process objects; overview: "mix of all of the specified processes output audio." Alternative: `init(processes:deviceUID:stream:)` for device-scoped tap. Exclusion: `init(stereoGlobalTapButExcludeProcesses:)` and related. DJMemory resolves bundle ID → running app PID → process object → single-process stereo mixdown. | **CONFIRMED** — [CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription), [Core Audio Constants](https://developer.apple.com/documentation/coreaudio/core-audio-constants) (`kAudioHardwarePropertyTranslatePIDToProcessObject`) |
| **5** | **DJ setting changes after onboarding** | Apple documents capture of **outgoing audio from a process** without requiring the source app to expose its own tap. No Apple doc requires changing the DJ app's output device for tap creation. **Caveat:** if the process sends no audible stream to a tap-visible path (exclusive hardware, off-Mac routing), capture may be silent — Apple does not document this for DJ apps. | **CONFIRMED** (no Apple-mandated DJ setting change); **UNKNOWN** (silent capture on explicit USB) |
| **6** | **Verify real audio heard** | Apple sample reads tap format (`kAudioTapPropertyFormat`) and drives IOProc on aggregate device. DJMemory: `CoreAudioIOProcCapture` meters RMS → `currentInputLevel()`; writes staging WAV on take. Permission probe: start aggregate with tap (prompt if needed). | **CONFIRMED** (Apple properties exist); **INFERRED** (DJMemory metering/write path) — repo implementation |
| **7** | **Smallest bench test** | Per DJ app: grant System Audio Recording once → launch app → route master to **explicit USB/controller output** (not system default) → arm Process Tap by bundle ID → play 30 s test tone → assert meter peak > threshold and non-empty WAV. Compare against same test with system default output. Repeat after output-device hot-swap. | **INFERRED** (test design; not Apple-specified) |
| **8** | **Failure modes & recovery** | Documented/implied: permission denied/revoked (TCC); tap create failure; aggregate create failure; process not running / PID invalid (`TranslatePIDToProcessObject` fails); tap invalidation on destroy. **Not Apple-documented:** format change mid-stream, sleep/wake, app relaunch with new PID, silent stream on device change. DJMemory recovery today: destroy tap+aggregate on stop/error; fall back to ScreenCaptureKit on arm failure; surface `permissionDenied`, `appNotShareable`, `streamStopped`. Re-arm required after target quit (new PID). | **CONFIRMED** (cleanup APIs, TCC); **INFERRED** (PID relaunch, fallback); **UNKNOWN** (sleep/wake, format change, USB swap without re-arm) |

---

## 3. ScreenCaptureKit eight-point evidence matrix

| # | Evidence area | Finding | Label |
|---|---------------|---------|-------|
| **1** | **Exact API / mechanism** | `SCShareableContent.excludingDesktopWindows(_:onScreenWindowsOnly:)` → pick `SCRunningApplication` → `SCContentFilter(display:including:exceptingWindows:)` (app-including display filter) → `SCStreamConfiguration` (`capturesAudio`, `sampleRate`, `channelCount`, `excludesCurrentProcessAudio`) → `SCStream` + `addStreamOutput(..., type: .audio)` → `startCapture()`. Update running stream: `updateConfiguration`, `updateContentFilter`. Delegate: `SCStreamDelegate.stream(_:didStopWithError:)`. **ScreenCaptureKit framework:** macOS 12.3+ ([SDK diff](http://codeworkshop.net/objc-diff/sdkdiffs/macos/13.0/ScreenCaptureKit.html)). **Audio capture properties:** added macOS 13.0 (`capturesAudio`, `sampleRate`, `channelCount`, `excludesCurrentProcessAudio`, `SCStreamOutputType.audio`). DJMemory minimum product target macOS 14.0 (`Package.swift`). | **CONFIRMED** — [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit), [capturesAudio](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/capturesaudio), [SCContentFilter init(display:including:exceptingWindows:)](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init(display:including:exceptingwindows:)), [Capturing screen content in macOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos), [updateConfiguration](https://developer.apple.com/documentation/screencapturekit/scstream/updateconfiguration(_:completionhandler:)) |
| **2** | **Install location / helper model** | In-process framework. No helper/daemon. Still requires minimal video pipeline (DJMemory: 2×2 px, 1 fps) because `SCStream` delivers screen + audio outputs. | **CONFIRMED** (in-process); **INFERRED** (minimal video workaround — Apple sample is screen-centric; WWDC22 describes video+audio streams together) — [Meet ScreenCaptureKit (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10156/) |
| **3** | **Entitlements, permissions, signing, notarization** | **Info.plist:** `NSScreenCaptureUsageDescription` required ([ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)). **TCC:** Screen & System Audio Recording; preflight/request via `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess` (macOS 10.15+). **No** screen-capture entitlement in Apple security-entitlements reference. Microphone via SCK (`captureMicrophone`, macOS 15+) is separate from system audio and needs `NSMicrophoneUsageDescription` + mic TCC — **not used by DJMemory app-audio path**. Sandbox `com.apple.security.device.audio-input` optional for some audio paths ([Enabling App Sandbox](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html)). **Gap:** DJMemory `scripts/build-app.sh` includes `NSAudioCaptureUsageDescription` but **not** `NSScreenCaptureUsageDescription` as of 2026-08-26 — SCK fallback may be terminated or denied without it ([Requesting Authorization for Media Capture on macOS](https://developer.apple.com/documentation/bundleresources/requesting-authorization-for-media-capture-on-macos) pattern for missing usage strings). Notarization: same Developer ID rules as Process Tap. | **CONFIRMED** (NSScreenCaptureUsageDescription, TCC, no capture entitlement); **CONFIRMED** (packaging gap in repo) |
| **4** | **Per-process targeting** | WWDC22: "audio capture can only be filtered at an application level." `SCContentFilter` display + `including: [SCRunningApplication]` captures that app's audio (with display-attached filter). Window-level filters do not apply to audio granularity. `excludesCurrentProcessAudio` excludes capturer's own audio. | **CONFIRMED** — [Meet ScreenCaptureKit (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10156/), [init(display:including:exceptingWindows:)](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init(display:including:exceptingwindows:)), [excludesCurrentProcessAudio](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/excludescurrentprocessaudio) |
| **5** | **DJ setting changes after onboarding** | No Apple requirement to change DJ app output for SCK. Filter selects running application from `SCShareableContent.applications`. User must grant Screen Recording once. **Caveat:** same as Process Tap — if app audio never enters SCK-visible app audio graph for selected hardware route, stream may be silent. | **CONFIRMED** (no Apple-mandated DJ setting change); **UNKNOWN** (explicit USB hardware) |
| **6** | **Verify real audio heard** | Receive float audio `CMSampleBuffer` on `.audio` output; DJMemory computes RMS meter, converts to 48 kHz / 16-bit WAV, preroll ring while armed. | **INFERRED** — repo implementation; **CONFIRMED** — [capturesAudio](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/capturesaudio) enables audio samples |
| **7** | **Smallest bench test** | Grant Screen & System Audio Recording → force SCK backend (`DJMEMORY_FORCE_SCK_APP_AUDIO=1`) → explicit USB output in DJ app → arm → 30 s tone → meter + WAV. Compare default vs USB output. One forced SCK run per platform baseline (already done for Serato on system output only). | **INFERRED** |
| **8** | **Failure modes & recovery** | Documented: `stream(_:didStopWithError:)` (`userStopped` recoverable); error constants include `systemStoppedStream`. Permission errors on `SCShareableContent` fetch. DJMemory: maps permission strings/codes to `permissionDenied`; `onStreamStopped` callback; non-float or format mismatch → fail take with user-facing message. **Not documented:** permission revoked mid-stream, target app quit, display sleep, sample-rate change (DJMemory rebuilds converter on rate/channel change — implementation). Re-fetch `SCShareableContent` + restart stream after target relaunch. | **CONFIRMED** — [stream(_:didStopWithError:)](https://developer.apple.com/documentation/screencapturekit/scstreamdelegate/stream(_:didstopwitherror:)), [Error constants](https://developer.apple.com/documentation/screencapturekit/error-constants); **INFERRED** (DJMemory handling) |

---

## 4. Claim table

| Claim | Label | Primary URL | Evidence location | Scope |
|-------|-------|-------------|-------------------|-------|
| Process Audio Tap APIs (`CATapDescription`, `AudioHardwareCreateProcessTap`, aggregate tap list) require macOS 14.2+ | CONFIRMED | https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps | Sample intro: "macOS 14.2 or later"; tap creation section | Core Audio Process Tap |
| `stereoMixdownOfProcesses` creates a stereo mix of listed processes' output audio | CONFIRMED | https://developer.apple.com/documentation/coreaudio/catapdescription/init(stereomixdownofprocesses:) | Initializer + class overview ("mix of all of the specified processes output audio") | Process Tap targeting |
| Optional `deviceUID` + `stream` on `CATapDescription` select which output stream to tap | CONFIRMED | https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps | Sample sets `description.deviceUID`, `description.stream` | Device-scoped tap (not used by DJMemory today) |
| `NSAudioCaptureUsageDescription` required; first aggregate+tap record prompts System Audio Recording | CONFIRMED | https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps | Important callout + permission paragraph | Process Tap TCC |
| No Apple-documented entitlement bypasses System Audio Recording TCC | CONFIRMED | https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html | Sandbox entitlement list (no system-audio capture key) | All distribution channels |
| `com.apple.security.device.audio-input` allows Core Audio input in sandbox | CONFIRMED | https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input | Entitlement discussion | Sandboxed apps |
| ScreenCaptureKit `capturesAudio` defaults false; must opt in | CONFIRMED | https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/capturesaudio | Property discussion | SCK audio |
| SCK audio filtering is application-level only | CONFIRMED | https://developer.apple.com/videos/play/wwdc2022/10156/ | ~8:00 filter discussion | SCK targeting |
| `NSScreenCaptureUsageDescription` required for screen capture permission | CONFIRMED | https://developer.apple.com/documentation/screencapturekit | Overview / permission note | SCK TCC |
| SCK audio capture APIs added in macOS 13.0 SDK | CONFIRMED | http://codeworkshop.net/objc-diff/sdkdiffs/macos/13.0/ScreenCaptureKit.html | SCStreamConfiguration audio properties added | Minimum OS for audio |
| Running SCK stream can update filter/config without restart | CONFIRMED | https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos | Post-start update section | Stream lifecycle |
| Developer ID distributed apps must be notarized (macOS 10.15+) | CONFIRMED | https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution | Introduction | Developer ID |
| TCC remembers grants when code signature is stable | CONFIRMED | https://developer.apple.com/forums/thread/695689 | DTS reply on signing identity | Dev workflow |
| Process Tap captures DJ app on explicit USB/controller output without deviceUID | UNKNOWN | — | — | Explicit hardware routing |
| ScreenCaptureKit app filter captures DJ app on explicit USB/controller output | UNKNOWN | — | — | Explicit hardware routing |
| Exclusive-mode or vendor-driver outputs remain tap-visible | UNKNOWN | — | — | Vendor drivers |
| Aggregate/multi-output device as DJ master route remains capturable | UNKNOWN | — | — | Aggregate routing |
| `stereoMixdownOfProcesses` (no deviceUID) follows whichever device the DJ app selected | INFERRED | https://developer.apple.com/documentation/coreaudio/catapdescription | Process mixdown vs `init(processes:deviceUID:stream:)` suggests device-specific variant exists because routing varies | Requires bench proof |
| DJMemory SCK fallback safe without `NSScreenCaptureUsageDescription` in shipped plist | INFERRED (likely false) | https://developer.apple.com/documentation/screencapturekit | Missing usage string → termination on TCC prompt (pattern from media-capture docs) | DJMemory packaging |
| All five DJ apps capture on system-default output (Process Tap + SCK) | CONFIRMED (bench) | `docs/integration-status.md` (repo) | 2026-08-12–14 live probes | System output only; not USB-exclusive |
| Serato Virtual Audio behavior implies other DJ apps behave identically | **Rejected** | — | — | Do not extrapolate |

---

## 5. Explicit-output and hardware-output unknowns

Apple primary sources establish **what** to configure, not **how DJ apps route to USB/class-compliant/controller interfaces**.

| Unknown | Why it matters | Apple primary evidence (partial) | Status |
|---------|----------------|----------------------------------|--------|
| **Explicit USB/controller output selected in DJ app** (e.g., Pioneer DJM-900NXS2, XDJ-XZ, Traktor Kontrol S4) | Core product question for invisible capture | `CATapDescription.init(processes:deviceUID:stream:)` exists for device-scoped taps; `stereoMixdownOfProcesses` does not mention following selected device | **UNKNOWN** |
| **Vendor ASIO-like / class-compliant driver exclusive paths** | Some DJ stacks bypass default HAL mix points | No DJ-vendor docs in Apple corpus | **UNKNOWN** |
| **Exclusive output mode** | May bypass tap-visible buffers | `description.isExclusive` in Apple sample (mute/routing semantics), not DJ exclusive mode | **UNKNOWN** |
| **Aggregate / multi-output master** | DJ may split booth/main | Aggregate device docs cover DJMemory-owned aggregates, not DJ-app-owned routes | **UNKNOWN** |
| **Hardware that does not present as Mac-playable output** (controller-only, no Mac monitoring path) | No Mac-heard audio → nothing to tap | Product rule: "cannot hear the set yet" | **CONFIRMED** product constraint; **UNKNOWN** per API |
| **Hot-swapping output device while armed** | Invisible capture must survive set prep | No Apple doc for Process Tap or SCK | **UNKNOWN** |
| **macOS 14.2+ multi-channel default output level bug** (global tap / channel normalization) | Meter/archive gain wrong on >2ch interfaces | Not Apple-doc; public gist reports device-channel halving on 14.2+ | **UNKNOWN** (community report only — [gist sudara/34f00ef](https://gist.github.com/sudara/34f00efad69a7e8ceafa078ea0f76f6f); license: unrestricted use, not Apple) |

**Documented capability vs bench test:** Apple confirms APIs exist for process-scoped and app-scoped capture. **Behavior when DJ software selects non-default HAL output is not documented** and remains a bench-test surface for each supported app independently.

---

## 6. Smallest bench tests (five DJ apps)

Run on macOS 14.2+ clean-ish Mac (stable Developer ID build, both usage strings present). Each app tested **in isolation**. Do not infer across apps.

### Shared setup (once per machine)

1. Install build with `NSAudioCaptureUsageDescription` **and** add `NSScreenCaptureUsageDescription` before SCK tests.
2. Grant **System Audio Recording** (Process Tap) and **Screen & System Audio Recording** (SCK) in System Settings.
3. Use `swift run djmemory app-audio-probe` or `.build/DJMemory.app/.../DJMemory --app-audio-probe`.

### Matrix per app

| App | Bundle / probe ID | Test A — system default output | Test B — explicit USB/controller output | Test C — failure recovery |
|-----|-------------------|--------------------------------|----------------------------------------|---------------------------|
| **Serato DJ Pro** | `serato` | Arm Process Tap; play 30 s; expect `PASS meter+write`; peak > 0.05 | In Serato: select connected DJM/controller as master output (not Mac speakers); repeat; log meter peak + WAV SHA | Revoke System Audio Recording mid-arm → expect `permissionDenied`; re-grant → re-arm succeeds |
| **rekordbox 6/7** | `rekordbox` | Same as A | Same as B with rekordbox Performance output → controller | Quit rekordbox mid-arm → `streamStopped` or `appNotShareable`; relaunch → re-arm by bundle ID |
| **Traktor DJ 2** | `com.native-instruments.tmnt` | Same as A | Traktor: explicit DJ controller output | Force SCK (`DJMEMORY_FORCE_SCK_APP_AUDIO=1`); repeat B |
| **VirtualDJ** | `virtualdj` | Same as A | VirtualDJ: explicit sound card mapping | Switch output device while armed; note silent vs continuous meter |
| **djay Pro 2** | `djay` | Same as A | djay: external interface output | Sleep/wake Mac while armed; note tap/stream validity |

### Pass/fail criteria

- **Pass:** meter peak ≥ 0.05 during playback **and** non-empty staging/archive WAV with expected duration.
- **Fail (actionable):** meter 0 with audible booth/master on hardware → record "Mac-audible path absent" vs "API gap"; do not claim app support.
- **Compare A vs B:** If A passes and B fails → evidence that explicit hardware routing breaks invisible capture for that app/backend; smallest follow-up is retry Process Tap with `init(processes:deviceUID:stream:)` using the DJ-selected device UID (engineering experiment, not Apple-guaranteed).

### Unresolved contradictions → smallest test

| Contradiction | Smallest test to resolve |
|---------------|-------------------------|
| Process mixdown without `deviceUID` should follow process vs must target `deviceUID` for non-default output | Serato Test B vs Test B2: arm with `stereoMixdownOfProcesses` then repeat with tap description bound to USB device UID from Audio MIDI Setup |
| SCK app filter independent of HAL default vs tied to display-audio mix | Traktor Test B with SCK forced; compare to Process Tap on same route |
| Sandbox + Process Tap viability under MAS entitlements | Developer ID sandbox build vs current `packaging/DJMemory.entitlements` on clean Mac |
| Missing `NSScreenCaptureUsageDescription` | Launch SCK-only arm on machine without prior TCC grant; observe termination vs prompt |

---

## Failure mode map (both backends)

| Failure | Process Tap | ScreenCaptureKit | DJMemory today | Label |
|---------|-------------|------------------|----------------|-------|
| Permission denied / revoked | Tap create `kAudioHardwareIllegalOperationError`; aggregate start blocked | `SCShareableContent` error; CG preflight false | `permissionDenied` | INFERRED mapping |
| Target not running | `TranslatePIDToProcessObject` / no running app | App absent from `SCShareableContent.applications` | `appNotShareable` | CONFIRMED path |
| PID replacement on relaunch | Old process object invalid | App reappears with new process ID | Requires stop + re-arm | INFERRED |
| Device / route change | Not documented | `updateContentFilter` exists; audio route change undocumented | No hot rebind | UNKNOWN |
| Silent stream (audible on hardware) | Not documented | Not documented | Meter 0; user message needed | UNKNOWN |
| Format / sample-rate change | `kAudioTapPropertyFormat` readable; change notifications not cited | Buffers may change; DJMemory rebuilds converter | Partial handling (SCK) | INFERRED |
| Tap / stream invalidation | `AudioHardwareDestroyProcessTap` | `didStopWithError` | Cleanup on stop | CONFIRMED |
| System sleep / wake | Not documented | `systemStoppedStream` constant exists | Not handled explicitly | UNKNOWN |
| Disk full | IOProc write failure | AVAudioFile write | `diskFull` / engine error | INFERRED |

---

## Licensing / proprietary code

- **Apple sample code** (Core Audio taps, ScreenCaptureKit): Apple sample license applies if copied; DJMemory implements patterns independently.
- **Community gist (sudara Core Audio Tap example):** "do whatever you want"; useful for deviceUID experimentation only — not primary evidence.
- **Recall.ai / third-party blogs:** secondary; not cited as confirmed behavior when Apple docs exist.
- **Do not reuse** MJAudioRecorder, NoteBurner, BlackHole, or other proprietary/virtual-driver code without explicit license review (per handoff).

---

## DJMemory implementation snapshot (2026-08-26)

Read-only summary of `AppAudioCaptureService.swift`:

| Backend | Key APIs used | Permission gate |
|---------|---------------|-----------------|
| Process Audio Tap | `CATapDescription(stereoMixdownOfProcesses:)`, `AudioHardwareCreateProcessTap`, aggregate + IOProc | System Audio Recording (via aggregate start); `NSAudioCaptureUsageDescription` in build script |
| ScreenCaptureKit | `SCShareableContent`, `SCContentFilter(display:including:)`, `SCStreamConfiguration.capturesAudio`, `.audio` output | `CGPreflightScreenCaptureAccess`; **`NSScreenCaptureUsageDescription` not in build script** |

---

*End of evidence document. No architecture recommendation.*
