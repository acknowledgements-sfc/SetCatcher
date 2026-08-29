# Invisible DJ-app capture: evidence synthesis and recommendation

**Date and access date:** 2026-08-26
**Scope:** Serato DJ Pro, rekordbox, Traktor Pro, VirtualDJ, and djay Pro/2 on macOS.
**Evidence labels:** **CONFIRMED** = stated by Apple or the relevant vendor, or directly present in this repository; **INFERRED** = a defensible design conclusion not promised by the source; **UNKNOWN** = requires a real-machine or real-DJ-software bench test.

## Decision

**Recommendation — verified hardware first; Apple process/app capture first for laptop audio.** Preserve the governing route priority: if a USB hardware input is producing a verified master/deck feed, capture it. Otherwise make a Core Audio **Process Tap** the primary laptop path on **macOS 14.2 or later**, targeting the active DJ process and reading it through a private aggregate device. Keep **ScreenCaptureKit** as the in-process fallback when the tap cannot arm. Both Apple paths preserve the DJ app's existing output choice and therefore meet the no-routine-manual-routing rule in their documented operating model. Apple confirms that a process tap captures outgoing audio from specified processes, can be private, and is attached to a HAL aggregate device; it also confirms the 14.2 minimum and `NSAudioCaptureUsageDescription` requirement in [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps). Apple confirms that ScreenCaptureKit can capture an application's audio and that audio filtering is application-level in [Meet ScreenCaptureKit](https://developer.apple.com/videos/play/wwdc2022/10156/).

**Laptop fallback — already-enabled vendor input, then honest unavailability.** After Process Tap and ScreenCaptureKit, a vendor virtual input may be consumed when it already exists and produces verified audio, but DJMemory must not ask the DJ to enable or route to it during a set. A physical REC/BOOTH return remains a verified hardware route, not a laptop fallback. If no verified hardware feed exists and all laptop paths fail or remain silent, say **DJMemory cannot hear the set yet**; do not silently switch system defaults or rewrite DJ-app preferences.

**Rejected as routine capture:** a classic DJMemory-owned HAL loopback driver, system-default hijacking, aggregate/multi-output default switching, or app-specific output automation. A virtual device hears only audio routed to that device; all five DJ apps can select explicit interfaces in at least some modes. Such a route cannot satisfy universal invisible capture without changing DJ settings. MJRecorder/NoteBurner and Record It demonstrate installable virtual-device patterns, not documented per-process interception or reliable restoration. BlackHole's documented multi-output workflow is manual and its GPLv3 code must not be vendored; libASPL is MIT-compatible with preserved notices, but licensing does not remove the routing limitation.

**Minimum OS:** **macOS 14.2** for the recommended design. ScreenCaptureKit audio exists earlier, but lowering the product minimum would make the less-specific fallback the primary architecture. That is not justified merely to preserve legacy support.

## What is confirmed, inferred, and still unknown

- **CONFIRMED:** Process Tap can target one process or a group; it does not require a HAL driver install; first use prompts for System Audio Recording permission; a usage string is required. [Apple Process Tap sample](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- **CONFIRMED:** ScreenCaptureKit captures audio associated with selected applications, with consent stored under Screen Recording / Screen & System Audio Recording. Audio filtering is application-level, not window-level. [Apple WWDC22](https://developer.apple.com/videos/play/wwdc2022/10156/)
- **CONFIRMED:** External-mixer configurations can move the authoritative crossfader/master outside software. VirtualDJ requires a physical record/booth return in that mode ([Record Loopback](https://virtualdj.com/manuals/virtualdj/settings/audiosetup/recordloopback.html)); djay explicitly says it cannot capture the external main output internally and requires a recording input ([external-mixer recording](https://help.algoriddim.com/user-manual/djay-pro-mac/mixing-basics/external-mixer-recording)). Traktor says External Mixing bypasses its internal mixer ([Traktor Preferences](https://docs.native-instruments.com/ni-tech-manuals/traktor-pro-manual/en/preferences)).
- **INFERRED:** Process Tap is the best v1 route because it is the most specific Apple-documented process mechanism, avoids output mutation, and already matches DJMemory's existing app-audio seam.
- **UNKNOWN:** Whether an unscoped `stereoMixdownOfProcesses` tap or an application-filtered ScreenCaptureKit stream contains the full post-fader master when each DJ app writes to an explicitly selected USB/controller device. Apple's docs do not promise this device-routing behavior.
- **UNKNOWN:** Whether a software tap contains controller microphone/AUX inputs or hardware crossfader/EQ contributions. Serato documents hardware-specific limits even for its own recording/streaming features ([hardware limitations](https://support.serato.com/hc/en-us/articles/360001976175-Recording-Live-Streaming-Laptop-Speaker-Hardware-Limitations)).
- **UNKNOWN:** Exact master/deck/REC USB input exposure varies by controller, mixer, firmware, driver, mixer utility configuration, and operating mode. A connected USB device is not proof of a capturable master mix.

## Eight-point architecture comparison

| Evidence bar | Process Tap — recommended | ScreenCaptureKit — fallback | Vendor virtual input | HAL / DJMemory virtual driver | Verified USB / physical return |
|---|---|---|---|---|---|
| 1. Exact mechanism | `CATapDescription` → `AudioHardwareCreateProcessTap` → private aggregate tap list → IOProc PCM. **CONFIRMED** | `SCShareableContent` → `SCRunningApplication` → `SCContentFilter` → `SCStreamConfiguration.capturesAudio` → `.audio` sample buffers. **CONFIRMED** | Normal Core Audio input device supplied by vendor. Serato Virtual Audio is documented; peers are **UNKNOWN**. | `AudioServerPlugIn`/HAL `.driver`; app must render to it, directly or via aggregate/multi-output. **CONFIRMED** model | Enumerated Core Audio input; record the selected input channels. **CONFIRMED** mechanism |
| 2. Install/helper | No driver or privileged helper. In-process temporary objects. **CONFIRMED** | No driver/helper; in-process framework stream. **CONFIRMED** | Vendor installer/driver and opt-in may be required. **CONFIRMED** for Serato | System HAL install normally under `/Library/Audio/Plug-Ins/HAL/`; privileged installer/helper and audio-server reload/reboot may be needed. **CONFIRMED** path, lifecycle details partly **INFERRED** | Vendor driver may be needed; no DJMemory component if class-compliant. **CONFIRMED/UNKNOWN per device** |
| 3. Permission/signing | `NSAudioCaptureUsageDescription`; System Audio Recording consent; stable signed identity; Developer ID distribution should be hardened, signed, and notarized. **CONFIRMED** | Screen Recording / Screen & System Audio Recording consent; include `NSScreenCaptureUsageDescription`; same signing/notarization baseline. **CONFIRMED** | Vendor approval/install plus ordinary input permission as applicable. **UNKNOWN per vendor** | Admin/user approval for installation; sign every executable/bundle; notarize app/pkg/plug-in. Apple documents Developer ID and notarization requirements in [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). | Audio-input permission/sandbox entitlement where applicable; vendor driver approval may apply. **CONFIRMED/UNKNOWN per device** |
| 4. Specific process | Yes, process object(s). **CONFIRMED** | Application-level only. **CONFIRMED** | Usually device-wide; Serato-specific source only. **CONFIRMED/UNKNOWN** | No; device-wide and only receives routed audio. **CONFIRMED** | No; device/channel-wide. **CONFIRMED** |
| 5. DJ changes after onboarding | None documented; explicit-USB result still **UNKNOWN** | None documented; explicit-USB result still **UNKNOWN** | Only acceptable if already enabled; otherwise enabling it is manual routing and rejected | Often required for explicit-device DJ apps; therefore rejected as universal route | None if hardware already exposes a usable input; physical wiring/configuration may have been required beforehand |
| 6. Prove real audio | Require sustained peak/RMS above threshold, valid PCM frames, growing staging file, then archive reconciliation. **INFERRED product rule** | Same | Same; presence/name is not proof | Same; installed UID is not proof | Same; USB attachment is not proof |
| 7. Smallest bench | 30-second known mix per app on laptop output and controller output; meter + WAV + archive | Repeat forced-SCK cases | One isolated Serato-VA run; inventory other vendors without enabling them | Clean-Mac install plus explicit-route negative control; not a v1 gate | One representative hardware route per app plus master/deck/mic/AUX classification |
| 8. Failure/recovery | Destroy tap/aggregate; re-resolve PID; retry once; fall back to SCK; never claim listening before samples | Stop stream; re-fetch shareable content; retry once; then verified vendor/hardware or unavailable | Re-enumerate; if absent/silent, skip without changing vendor setting | Defer install/reload during a set; restore saved defaults; reboot fallback; never strand output | Hold active verified route through brief silence; on disconnect stop safely, test app capture, otherwise unavailable |

## Conflict with the current route model

The repository's documented direction says **verified hardware → Process Tap → ScreenCaptureKit → already-available vendor input**, but `LiveCaptureRouteResolver.laptopRoute` currently chooses **DJMemory driver → vendor virtual input → existing app audio**. That ordering conflicts with the evidence: the driver is not process-targeted and cannot hear an app pinned to another device, while Process Tap and ScreenCaptureKit are the documented no-output-change paths. **Recommendation:** preserve the hardware-first rule, but reorder the laptop backends to **Process Tap, ScreenCaptureKit, already-enabled verified vendor input**. Keep the driver only as experimental future work, never as the default laptop route.

There is a second conflict. The product rule requires app audio to be **heard**, but the no-hardware branch accepts `appAudioUsable`, which is only `capability == available && a DJ process is running`; `appAudioIsProducing` is not required there. Thus a permission grant plus process presence can select and label a laptop route before samples exist. **Recommendation:** distinguish `armed/capable` from `verified/producing`. The resolver may arm a candidate from capability + process, but it must remain `detecting` and must not claim active listening or begin the archival take until the meter observes real audio. Apply the same observed-audio gate to driver and vendor-input candidates.

## Per-app real-software bench matrix

No row below is accepted from documentation or simulator tests alone. Use real licensed DJ software, real playback, and representative hardware. Preserve the DJ app's current output settings; any test that requires changing them fails the invisible-runtime bar.

| App | Laptop control | Representative controller / explicit USB test | External-mix truth test | Required pass evidence |
|---|---|---|---|---|
| Serato DJ Pro | Practice/offline through current Mac output: Process Tap, then forced SCK | Controller master with **Use Laptop Speakers off**; repeat Serato Virtual Audio only as an isolated already-enabled vendor case | Hardware named in Serato limitations page; include mic/AUX classification | Full post-fader program, no cue bleed; meter, non-silent WAV, archive; state whether mic/AUX is absent |
| rekordbox | PERFORMANCE, Internal, built-in/Mac output | DDJ/XDJ selected explicitly; PC MASTER OUT off then on without changing it for DJMemory | External mixer/DJM USB input inventory; identify master vs deck feeds | Same; separately label PC MASTER OUT dependency and USB channel identity. Pioneer documents Internal/External modes in the [rekordbox operation hints](https://rekordbox.com/en/support/faq/operation-hint/#faq-q500212). |
| Traktor Pro | Internal mixing, built-in output | Kontrol or interface selected in Audio Device; master on hardware MAIN | External Mixing with deck outputs to mixer and physical record return | Same; confirm whether software tap is master, pre-mixer decks, or silent |
| VirtualDJ | SPEAKER ONLY + COMPUTER AUDIO | Supported controller profile, master on controller RCA | SEPARATE DECKS + external mixer + documented Record Loopback | Same; external truth must match physical REC/BOOTH return, not the internal crossfader |
| djay Pro/2 | Internal mode, Main Output on Mac | Supported controller auto-configuration, master on controller | External mode + documented Recording Input / REC OUT return | Same; external truth must include hardware crossfader and state mic/AUX coverage |

For every row: run Process Tap and forced ScreenCaptureKit separately; record output device UID, sample rate/channels, app version, macOS build, hardware/firmware/driver, mode, 30 seconds of known A/B deck transitions, and hot unplug/reconnect. Pass only when non-zero samples become a valid file, ArchiveService ingests it, the Library entry reconciles, and a human listen confirms master/cue correctness. Arming, permission success, device enumeration, or an exit code alone is not acceptance.

## Permissions, install, signing, and notarization

1. Onboarding requests **System Audio Recording** for Process Tap with a clear `NSAudioCaptureUsageDescription`. Permission denial is recoverable through a direct System Settings action; local protection remains usable.
2. ScreenCaptureKit fallback requests Screen Recording / Screen & System Audio Recording and must ship the appropriate usage description. Re-check the packaged Info.plist, not only source configuration.
3. Use a stable Developer ID identity and Hardened Runtime for distribution; sign nested components and notarize/staple the final app/package. Ad-hoc builds are development proof only and should not be used to judge durable TCC behavior.
4. Do not install a HAL driver for v1. If later pursued, use original code or libASPL under its MIT notice, a signed/notarized installer/helper, explicit onboarding approval, exact UID verification, reversible uninstall, and a saved previous-output snapshot. Never reload `coreaudiod` during an active set.
5. Do not copy proprietary MJRecorder, Record It, NoteBurner, or similar drivers. Do not vendor BlackHole without an explicit GPLv3 product decision.

## Invisible failure recovery

- **Target not running / PID changed:** return to detecting, resolve the new process, recreate the tap/filter, and keep any completed file intact.
- **Permission denied or revoked:** stop cleanly, retain local archive functionality, show one plain-language permission action, and do not loop prompts.
- **Tap creation/aggregate start fails:** fully destroy partial objects, retry once, then force ScreenCaptureKit.
- **SCK stream stops:** stop and rebuild after re-fetching applications; retry once.
- **Backend arms but remains silent:** never label it active. Continue the short detection window; test an already-enabled vendor input and verified physical inputs; otherwise state that DJMemory cannot hear the set.
- **USB input disconnects or becomes silent:** preserve the current recording through the bounded transition policy, close it safely if the route is lost, then test the process path. Never fabricate a device identity.
- **Sample-rate/channel change:** close or reconfigure at a file boundary; do not silently reinterpret frames.
- **App or DJMemory crash/relaunch:** reconcile staging files, never overwrite a source recording, re-resolve the live process/device, and require fresh observed audio.

## Future work mapped to existing seams

- `AppAudioCaptureService`: keep its Process Tap-first / ScreenCaptureKit-fallback behavior authoritative; expose backend identity and observed-sample state to routing facts.
- `LiveCaptureRouteKind`: keep `.verifiedHardwareFeed` as the highest-priority signal-verified route and `.existingAppAudio` as the Apple process/app route; do not promote `.djmemoryVirtualDriver` merely because its device UID is present.
- `LiveCaptureRouteFacts`: split **candidate capability** from **observed production** and carry the chosen app-audio backend rather than collapsing both Apple APIs into a generic route.
- `LiveCaptureRouteResolver`: hardware remains first only when verified by signal; reorder laptop candidates; use `detecting` until samples arrive; remove driver availability as a priority signal.
- `DJMemoryAudioDriverAvailability`: retain `.available`, `.missing`, `.permissionOrInstallNeeded`, and `.presentButUnusable` as experimental driver discovery/diagnostic state only; none should outrank a viable Apple process/app capture candidate.
- `DJMemoryAudioDriverClient`: retain discovery as an experimental seam; do not build an installer or route automation until the five-app bench disproves both Apple paths for an important supported mode.
- `DJAppOutputRoutingAdapter`: keep status pure. Do not implement preference editing, binary injection, undocumented automation, or routine `applyRouteToDJMemoryDriver` behavior.
- `AudioInputDeviceCatalog` / hardware classifier: add explicit master/deck/unknown feed evidence and persist the exact device/channel observation used by the bench.
- Automation: add a result artifact containing backend, process/bundle ID, device UID, peak/RMS window, frames written, file format, archive path, and Library reconciliation. No track titles or audio in diagnostics.

## Acceptance caveat

This report recommends the next architecture; it does **not** confirm invisible capture for real DJ performances. Process Tap and ScreenCaptureKit priority is documented, but the decisive explicit USB/controller behavior is **UNKNOWN** until the five-app bench matrix passes on real DJ software and representative hardware. A physical-hardware failure to produce Mac-visible master audio is a route limitation, not automatically a code failure. Until that evidence exists, support labels must remain partial/research where applicable.

## Primary sources checked for this synthesis

- Apple: [Core Audio Process Tap sample](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps), [Meet ScreenCaptureKit](https://developer.apple.com/videos/play/wwdc2022/10156/), [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
- Serato: [Recording, Live Streaming & Laptop Speaker Hardware Limitations](https://support.serato.com/hc/en-us/articles/360001976175-Recording-Live-Streaming-Laptop-Speaker-Hardware-Limitations).
- Native Instruments: [Traktor Pro Preferences / Output Routing](https://docs.native-instruments.com/ni-tech-manuals/traktor-pro-manual/en/preferences).
- VirtualDJ: [Audio Setup](https://virtualdj.com/manuals/virtualdj/settings/audiosetup.html), [Record Loopback](https://virtualdj.com/manuals/virtualdj/settings/audiosetup/recordloopback.html).
- Algoriddim: [djay audio devices](https://help.algoriddim.com/user-manual/djay-pro-mac/settings/audio-devices), [external mixers](https://help.algoriddim.com/user-manual/djay-pro-mac/hardware/external-mixers), [external-mixer recording](https://help.algoriddim.com/user-manual/djay-pro-mac/mixing-basics/external-mixer-recording).
