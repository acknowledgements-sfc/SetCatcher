import XCTest
@testable import DJMemoryCore

final class LiveCaptureRouteResolverTests: XCTestCase {

    // MARK: - Hardware feed wins whenever it is actually heard

    func testVerifiedHardwareFeedBeatsDriver() {
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.verifiedXZ],
            driverAvailability: .available(deviceID: "djmemory-audio"),
            runningDJSoftwareIDs: ["serato"],
            appAudioCapability: .available,
            appAudio: Self.producingAppAudio
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .verifiedHardwareFeed)
        XCTAssertEqual(decision.resolution.backend, .hardwareInput(deviceID: "xz"))
        XCTAssertEqual(decision.resolution.feedGrade, .masterMix)
        // Mac is generating and the mixer is returning it: laptop-software mode.
        XCTAssertEqual(decision.resolution.rigMode, .laptopSoftware)
        XCTAssertFalse(decision.resolution.listeningSummary.lowercased().contains("core audio"))
    }

    func testMasterMixBeatsDeckFeedWhenBothVerified() {
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.verifiedCDJ, Self.verifiedDJM],
            driverAvailability: .missing
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.backend, .hardwareInput(deviceID: "djm"))
        XCTAssertEqual(decision.resolution.feedGrade, .masterMix)
    }

    // MARK: - Finding 14: standalone CDJs are supported

    func testStandaloneCDJIsCapturableAsDeckFeed() {
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.verifiedCDJ],
            driverAvailability: .missing
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .verifiedHardwareFeed)
        XCTAssertEqual(decision.resolution.listeningState, .hardwareFeedActive)
        XCTAssertEqual(decision.resolution.backend, .hardwareInput(deviceID: "cdj"))
        XCTAssertEqual(decision.resolution.feedGrade, .deckFeed)
        XCTAssertEqual(decision.resolution.rigMode, .standaloneHardware)
        // Says it is a deck output, not the mixer's master — but never says it cannot record.
        XCTAssertTrue(decision.resolution.listeningSummary.contains("deck output"))
        XCTAssertTrue(LiveCaptureHardwareClassifier.assess(facts.hardware).isVerified)
    }

    // MARK: - Finding 13: process presence never decides the route

    func testStandaloneRigWithRekordboxOpenStillPrefersHardware() {
        // Players run off USB sticks; rekordbox is merely open for library/Link.
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.verifiedDJM],
            driverAvailability: .available(deviceID: "djmemory-audio"),
            runningDJSoftwareIDs: ["rekordbox"],
            appAudioCapability: .available,
            appAudio: Self.silentAppAudio
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .verifiedHardwareFeed)
        XCTAssertEqual(decision.resolution.rigMode, .standaloneHardware)
    }

    func testSilentHardwareWithNoAppAudioWaitsInsteadOfFallingBack() {
        // Standalone rig between tracks. Silence is not a reason to switch to the laptop.
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.silentDJM],
            driverAvailability: .available(deviceID: "djmemory-audio"),
            runningDJSoftwareIDs: ["rekordbox"],
            appAudioCapability: .available,
            appAudio: Self.silentAppAudio
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .connectedHardwareNoUsableSignal)
        XCTAssertEqual(decision.resolution.listeningState, .detecting)
        XCTAssertEqual(decision.resolution.backend, .none)
        XCTAssertEqual(decision.resolution.listeningSummary, LiveCaptureCopy.waitingForAudio)
    }

    func testSilentHardwareWithAppAudioProducingFallsBackToExistingAppAudio() {
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.silentDJM],
            driverAvailability: .available(deviceID: "djmemory-audio"),
            runningDJSoftwareIDs: ["serato"],
            appAudioCapability: .available,
            appAudio: Self.producingAppAudio
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .existingAppAudio)
        XCTAssertEqual(decision.resolution.listeningState, .fallbackActive)
        XCTAssertEqual(decision.resolution.backend, .existingAppAudio(archiveBackend: .processAudioTap))
        XCTAssertEqual(decision.resolution.rigMode, .laptopSoftware)
    }

    // MARK: - Finding 3: permission, not process presence, gates app audio

    func testDJAppRunningWithoutScreenRecordingNeverClaimsListening() {
        let facts = LiveCaptureRouteFacts(
            hardware: [],
            driverAvailability: .missing,
            runningDJSoftwareIDs: ["serato"],
            appAudioCapability: .permissionDenied
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertNotEqual(decision.resolution.listeningState, .laptopDriverActive)
        XCTAssertEqual(decision.resolution.listeningState, .recoveryNeeded)
        XCTAssertEqual(decision.resolution.backend, .none)
    }

    func testLaptopOnlyDJAppPathIgnoresDriverAvailability() {
        let facts = LiveCaptureRouteFacts(
            hardware: [],
            driverAvailability: .available(deviceID: "djmemory-audio"),
            runningDJSoftwareIDs: ["serato"],
            appAudioCapability: .available
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .existingAppAudio)
        XCTAssertEqual(decision.resolution.listeningState, .detecting)
        XCTAssertEqual(decision.resolution.backend, .existingAppAudio(archiveBackend: .processAudioTap))
    }

    func testLaptopOnlyUsesExistingAppAudioWhenDriverMissing() {
        let facts = LiveCaptureRouteFacts(
            hardware: [],
            driverAvailability: .missing,
            runningDJSoftwareIDs: ["serato"],
            appAudioCapability: .available
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .existingAppAudio)
        XCTAssertEqual(decision.resolution.listeningState, .detecting)
        XCTAssertEqual(decision.resolution.backend, .existingAppAudio(archiveBackend: .processAudioTap))
    }

    func testLaptopOnlyUsesVendorVirtualInputOnlyAfterApplePathExhausted() {
        let facts = LiveCaptureRouteFacts(
            hardware: [],
            driverAvailability: .missing,
            vendorVirtualInput: Self.seratoVirtual,
            vendorVirtualEnabled: true,
            runningDJSoftwareIDs: ["serato"],
            appAudioCapability: .available,
            appAudio: AppAudioObservation(
                capability: .available,
                applePathExhausted: true
            )
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .vendorVirtualInput)
        XCTAssertEqual(decision.resolution.listeningState, .detecting)
        XCTAssertEqual(decision.resolution.backend, .vendorVirtualInput(deviceID: "sva"))
    }

    func testLaptopOnlyDoesNotPreferVendorVirtualInputBeforeApplePathExhausted() {
        let facts = LiveCaptureRouteFacts(
            hardware: [],
            driverAvailability: .missing,
            vendorVirtualInput: Self.seratoVirtual,
            vendorVirtualEnabled: true,
            runningDJSoftwareIDs: ["serato"],
            appAudioCapability: .available
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .existingAppAudio)
        XCTAssertEqual(decision.resolution.backend, .existingAppAudio(archiveBackend: .processAudioTap))
    }

    func testNothingReachingTheMacIsUnavailable() {
        let decision = LiveCaptureRouteResolver.resolve(LiveCaptureRouteFacts())
        XCTAssertEqual(decision.resolution.kind, .unavailable)
        XCTAssertEqual(decision.resolution.listeningSummary, LiveCaptureCopy.unavailable)
    }

    // MARK: - Verification is earned, never assumed

    func testUSBConnectionAloneIsNotVerified() {
        let justPluggedIn = HardwareInputObservation(
            device: Self.xzDevice,
            inputChannelCount: 8,
            formatIsSupported: true,
            peakLevel: nil,
            detectionWindowComplete: false
        )
        XCTAssertFalse(LiveCaptureHardwareClassifier.isVerifiedFeed(justPluggedIn))
        let decision = LiveCaptureRouteResolver.resolve(
            LiveCaptureRouteFacts(hardware: [justPluggedIn], driverAvailability: .missing)
        )
        XCTAssertEqual(decision.resolution.kind, .detectingHardware)
        XCTAssertEqual(decision.resolution.listeningState, .detecting)
        XCTAssertTrue(decision.resolution.kindAgreesWithBackend)
    }

    func testHardwareWithoutInputChannelsIsNotCapturable() {
        let muteXZ = HardwareInputObservation(
            device: Self.xzDevice,
            inputChannelCount: 0,
            formatIsSupported: false,
            peakLevel: nil,
            detectionWindowComplete: true
        )
        let decision = LiveCaptureRouteResolver.resolve(
            LiveCaptureRouteFacts(hardware: [muteXZ], driverAvailability: .missing)
        )
        XCTAssertNotEqual(decision.resolution.kind, .verifiedHardwareFeed)
    }

    // MARK: - Finding 2: a feed that goes quiet stops reading as verified

    func testDetectionTrackerRearmsSoAVerifiedFeedCanGoSilent() {
        var tracker = LiveCaptureDetectionTracker()
        let start = Date(timeIntervalSince1970: 1_000)
        let drafts = [Self.silentDJM]

        _ = tracker.observe(drafts, level: 0.5, observing: true, now: start)
        let loud = tracker.observe(drafts, level: 0.0, observing: true, now: start.addingTimeInterval(2))
        XCTAssertTrue(loud[0].detectionWindowComplete)
        XCTAssertTrue(LiveCaptureHardwareClassifier.isVerifiedFeed(loud[0]), "loud window should verify")

        // The room goes quiet. The old running-max would have latched 0.5 forever.
        let quiet = tracker.observe(drafts, level: 0.0, observing: true, now: start.addingTimeInterval(4))
        XCTAssertTrue(quiet[0].detectionWindowComplete)
        XCTAssertFalse(LiveCaptureHardwareClassifier.isVerifiedFeed(quiet[0]), "silence must not stay verified")
    }

    func testDetectionTrackerCompletesOnlyWhileObserving() {
        var tracker = LiveCaptureDetectionTracker()
        let start = Date(timeIntervalSince1970: 2_000)
        let drafts = [Self.silentDJM]
        let idle = tracker.observe(drafts, level: 0.2, observing: false, now: start.addingTimeInterval(10))
        XCTAssertFalse(idle[0].detectionWindowComplete)
        XCTAssertNil(idle[0].peakLevel)
    }

    // MARK: - Finding 1: never fabricate a feed we cannot see

    func testUnpluggedHardwareMidRecordingNeverFabricatesAFeed() {
        let facts = LiveCaptureRouteFacts(
            hardware: [],
            driverAvailability: .missing,
            session: LiveCaptureSessionContext(
                phase: .recording,
                currentKind: .verifiedHardwareFeed,
                currentDeviceID: "xz",
                currentFeedIsProducingSignal: false,
                recordingAlreadyActive: true
            )
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertNotEqual(decision.resolution.backend, .hardwareInput(deviceID: ""))
        XCTAssertNil(decision.resolution.sessionDeviceID.flatMap { $0.isEmpty ? "" : nil })
        XCTAssertFalse(decision.resolution.listeningSummary.contains("mixer)"))
        XCTAssertTrue(decision.resolution.kindAgreesWithBackend)
    }

    func testStillAttachedButQuietHardwareKeepsItsRealIdentity() {
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.silentDJM],
            driverAvailability: .missing,
            session: LiveCaptureSessionContext(
                phase: .recording,
                currentKind: .verifiedHardwareFeed,
                currentDeviceID: "djm",
                currentFeedIsProducingSignal: false,
                recordingAlreadyActive: true
            )
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.backend, .hardwareInput(deviceID: "djm"))
        XCTAssertTrue(decision.resolution.listeningSummary.contains("DJM-V10"))
    }

    // MARK: - Mid-take route stability

    func testActiveRecordingDoesNotSwitchAwayFromVerifiedHardware() {
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.verifiedXZ],
            driverAvailability: .available(deviceID: "djmemory-audio"),
            runningDJSoftwareIDs: ["serato"],
            appAudioCapability: .available,
            appAudio: Self.producingAppAudio,
            session: LiveCaptureSessionContext(
                phase: .recording,
                currentKind: .verifiedHardwareFeed,
                currentDeviceID: "xz",
                currentFeedIsProducingSignal: true,
                recordingAlreadyActive: true
            )
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .verifiedHardwareFeed)
        XCTAssertEqual(decision.transition, .none)
    }

    func testBlockedExistingAppAudioKeepsBackendWhenHardwareAppears() {
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.verifiedXZ],
            driverAvailability: .missing,
            runningDJSoftwareIDs: ["serato"],
            appAudioCapability: .available,
            session: LiveCaptureSessionContext(
                phase: .recording,
                currentKind: .existingAppAudio,
                currentFeedIsProducingSignal: false,
                recordingAlreadyActive: true
            )
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.transition, .blockedUntilSessionBoundary)
        XCTAssertEqual(decision.resolution.kind, .existingAppAudio)
        XCTAssertEqual(decision.resolution.backend, .existingAppAudio(archiveBackend: .processAudioTap))
        XCTAssertTrue(decision.resolution.kindAgreesWithBackend)
    }

    func testBlockedVendorVirtualInputKeepsBackendWhenHardwareAppears() {
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.verifiedXZ],
            driverAvailability: .missing,
            vendorVirtualInput: Self.seratoVirtual,
            vendorVirtualEnabled: true,
            runningDJSoftwareIDs: ["serato"],
            appAudioCapability: .available,
            session: LiveCaptureSessionContext(
                phase: .recording,
                currentKind: .vendorVirtualInput,
                currentDeviceID: "sva",
                currentFeedIsProducingSignal: false,
                recordingAlreadyActive: true
            )
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.transition, .blockedUntilSessionBoundary)
        XCTAssertEqual(decision.resolution.backend, .vendorVirtualInput(deviceID: "sva"))
        XCTAssertTrue(decision.resolution.kindAgreesWithBackend)
    }

    /// Finding 11: recording with no route on record must not silently adopt a new one.
    func testRecordingWithNoCurrentKindIsBlockedNotSilentlyAdopted() {
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.verifiedXZ],
            driverAvailability: .missing,
            session: LiveCaptureSessionContext(
                phase: .recording,
                currentKind: nil,
                recordingAlreadyActive: true
            )
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.transition, .blockedUntilSessionBoundary)
    }

    func testIdleSessionAppliesARouteChange() {
        let facts = LiveCaptureRouteFacts(
            hardware: [Self.verifiedXZ],
            driverAvailability: .missing,
            session: LiveCaptureSessionContext(phase: .watching, currentKind: .existingAppAudio)
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        XCTAssertEqual(decision.resolution.kind, .verifiedHardwareFeed)
        XCTAssertEqual(decision.transition, .apply)
    }

    // MARK: - Apply outcomes stay out of status refresh

    func testRouteChangeFailedNeedsAutomaticSetupRecoveryOnlyFromApplyOutcome() {
        XCTAssertEqual(
            LiveCaptureRouteResolver.resolution(forApplyOutcome: .routeChangeFailed)?.recovery,
            .appAudioUnavailable
        )
        XCTAssertNil(LiveCaptureRouteResolver.resolution(forApplyOutcome: .notAutomatedYet))
        XCTAssertNil(LiveCaptureRouteResolver.resolution(forApplyOutcome: .routed))
    }

    // MARK: - Grading

    func testHardwareIdentityMatchingPrefersLongerNames() {
        let nxs = AudioInputDevice(id: "nxs", name: "CDJ-2000NXS", manufacturer: "Pioneer DJ", transportType: .usb)
        XCTAssertEqual(SupportedHardware.profile(matching: nxs)?.id, "cdj-2000nxs")
        XCTAssertEqual(LiveCaptureHardwareClassifier.grade(for: nxs), .deckFeed)

        let v10lf = AudioInputDevice(id: "v10lf", name: "DJM-V10LF", manufacturer: "Pioneer DJ", transportType: .usb)
        XCTAssertEqual(SupportedHardware.profile(matching: v10lf)?.id, "djm-v10lf")
        XCTAssertEqual(LiveCaptureHardwareClassifier.grade(for: v10lf), .masterMix)
    }

    /// Finding 8: a bare "xdj" substring is not proof of a master mix.
    func testXDJPlayerIsDeckFeedNotMasterMix() {
        let xdj1000 = AudioInputDevice(id: "x1k", name: "XDJ-1000", manufacturer: "Pioneer DJ", transportType: .usb)
        XCTAssertEqual(SupportedHardware.profile(matching: xdj1000)?.id, "xdj-1000")
        XCTAssertEqual(LiveCaptureHardwareClassifier.grade(for: xdj1000), .deckFeed)

        let xz = AudioInputDevice(id: "xz", name: "XDJ-XZ", manufacturer: "AlphaTheta Corporation", transportType: .usb)
        XCTAssertEqual(LiveCaptureHardwareClassifier.grade(for: xz), .masterMix)

        // An unrecognised XDJ is never optimistically promoted to a master mix.
        let unknownXDJ = AudioInputDevice(id: "u", name: "XDJ-9999", manufacturer: "Pioneer DJ", transportType: .usb)
        XCTAssertNotEqual(LiveCaptureHardwareClassifier.grade(for: unknownXDJ), .masterMix)
    }

    /// An XDJ-1000 playing off a USB stick is still capturable — just as a deck feed.
    func testXDJPlayerIsStillCapturableWhenHeard() {
        let observation = HardwareInputObservation(
            device: AudioInputDevice(id: "x1k", name: "XDJ-1000", manufacturer: "Pioneer DJ", transportType: .usb),
            inputChannelCount: 2,
            formatIsSupported: true,
            peakLevel: 0.5,
            detectionWindowComplete: true
        )
        let decision = LiveCaptureRouteResolver.resolve(
            LiveCaptureRouteFacts(hardware: [observation], driverAvailability: .missing)
        )
        XCTAssertEqual(decision.resolution.kind, .verifiedHardwareFeed)
        XCTAssertEqual(decision.resolution.feedGrade, .deckFeed)
    }

    // MARK: - Fixtures

    private static let producingAppAudio = AppAudioObservation(
        capability: .available,
        isMonitoring: true,
        archiveBackend: .processAudioTap,
        observedSignal: true
    )

    private static let silentAppAudio = AppAudioObservation(
        capability: .available,
        isMonitoring: true,
        archiveBackend: .processAudioTap,
        observedSignal: false
    )

    private static let xzDevice = AudioInputDevice(
        id: "xz",
        name: "XDJ-XZ",
        manufacturer: "AlphaTheta Corporation",
        transportType: .usb
    )

    private static let verifiedXZ = HardwareInputObservation(
        device: xzDevice,
        inputChannelCount: 8,
        formatIsSupported: true,
        peakLevel: 0.4,
        detectionWindowComplete: true
    )

    private static let djmDevice = AudioInputDevice(
        id: "djm", name: "DJM-V10", manufacturer: "Pioneer DJ", transportType: .usb
    )

    private static let silentDJM = HardwareInputObservation(
        device: djmDevice,
        inputChannelCount: 2,
        formatIsSupported: true,
        peakLevel: 0,
        detectionWindowComplete: true
    )

    private static let verifiedDJM = HardwareInputObservation(
        device: djmDevice,
        inputChannelCount: 2,
        formatIsSupported: true,
        peakLevel: 0.6,
        detectionWindowComplete: true
    )

    private static let verifiedCDJ = HardwareInputObservation(
        device: AudioInputDevice(id: "cdj", name: "CDJ-3000", manufacturer: "Pioneer DJ", transportType: .usb),
        inputChannelCount: 2,
        formatIsSupported: true,
        peakLevel: 0.8,
        detectionWindowComplete: true
    )

    private static let seratoVirtual = AudioInputDevice(
        id: "sva",
        name: "Serato Virtual Audio",
        manufacturer: "Serato",
        transportType: .virtual
    )
}

final class DJMemoryAudioDriverIdentityTests: XCTestCase {
    func testMatchesByDeviceUID() {
        // AudioInputDevice.id is the Core Audio device UID.
        let driver = AudioInputDevice(
            id: DJMemoryAudioDriverIdentity.deviceUID,
            name: "Renamed By User",
            manufacturer: "DJMemory",
            transportType: .virtual
        )
        XCTAssertTrue(DJMemoryAudioDriverIdentity.matchesByUID(driver))
        XCTAssertTrue(DJMemoryAudioDriverIdentity.matches(driver))
        XCTAssertEqual(
            DJMemoryAudioDriverIdentity.availability(in: [driver]),
            .available(deviceID: DJMemoryAudioDriverIdentity.deviceUID)
        )
        XCTAssertEqual(
            DJMemoryAudioDriverClient.recordingBackend(availability: .available(deviceID: "x")),
            .djmemoryDriver
        )
    }

    func testNameMatchIsSecondaryAndUIDMatchIsExact() {
        let namedOnly = AudioInputDevice(id: "some-other-uid", name: "DJMemory Audio", manufacturer: "DJMemory", transportType: .virtual)
        XCTAssertTrue(DJMemoryAudioDriverIdentity.matches(namedOnly), "name is accepted as a secondary signal")
        XCTAssertFalse(DJMemoryAudioDriverIdentity.matchesByUID(namedOnly), "but it is not identity")

        let impostor = AudioInputDevice(id: "agg", name: "DJMemory Audio Aggregate", manufacturer: "Someone Else", transportType: .virtual)
        XCTAssertFalse(DJMemoryAudioDriverIdentity.matches(impostor), "substring names must not match")
    }

    func testDoesNotMatchUSBOrWrongName() {
        let usb = AudioInputDevice(id: "u", name: "DJMemory Audio", manufacturer: "DJMemory", transportType: .usb)
        let other = AudioInputDevice(id: "sva", name: "Serato Virtual Audio", manufacturer: "Serato", transportType: .virtual)
        XCTAssertFalse(DJMemoryAudioDriverIdentity.matches(usb))
        XCTAssertFalse(DJMemoryAudioDriverIdentity.matches(other))
        XCTAssertEqual(DJMemoryAudioDriverIdentity.availability(in: [usb, other]), .missing)
    }
}

final class DJAppOutputRoutingTests: XCTestCase {
    func testSeratoAdapterDetectsRunningAppAndIsNotAutomated() {
        let adapter = SeratoOutputRoutingAdapter()
        XCTAssertEqual(adapter.routingStatus(runningSoftwareIDs: ["serato"]).detection, .running)
        XCTAssertEqual(adapter.routingStatus(runningSoftwareIDs: ["serato"]).automation, .notAutomatedYet)
        XCTAssertEqual(adapter.routingStatus(runningSoftwareIDs: ["rekordbox"]).detection, .notRunning)
        XCTAssertEqual(adapter.applyRouteToDJMemoryDriver(), .notAutomatedYet)
        XCTAssertEqual(adapter.restorePreviousRoute(), .notAutomatedYet)
        XCTAssertNil(DJAppOutputRouting.adapter(for: "rekordbox"))
        XCTAssertEqual(DJAppOutputRouting.adapter(for: "serato")?.softwareID, "serato")
    }
}

final class LiveCaptureSampleRingTests: XCTestCase {
    func testWriteThenReadPreservesInterleavedFrames() {
        let ring = LiveCaptureSampleRing(frameCapacity: 8, channelCount: 2)
        let source: [Float] = [0.1, -0.1, 0.2, -0.2, 0.3, -0.3]
        let written = source.withUnsafeBufferPointer { ring.writeRealtime(interleavedFrames: $0.baseAddress!, frameCount: 3) }
        XCTAssertEqual(written, 3)
        XCTAssertEqual(ring.availableFrames, 3)

        var dest = [Float](repeating: 0, count: 8)
        let read = dest.withUnsafeMutableBufferPointer { ring.read(into: $0.baseAddress!, maxFrames: 3) }
        XCTAssertEqual(read, 3)
        XCTAssertEqual(Array(dest.prefix(6)), source)
        XCTAssertEqual(ring.availableFrames, 0)
        XCTAssertEqual(ring.diagnostics, LiveCaptureRingDiagnostics())
    }

    func testWrapAroundPreservesFrameOrder() {
        let ring = LiveCaptureSampleRing(frameCapacity: 4, channelCount: 2)
        let first: [Float] = [1, 1, 2, 2, 3, 3]
        _ = first.withUnsafeBufferPointer { ring.writeRealtime(interleavedFrames: $0.baseAddress!, frameCount: 3) }
        var drain = [Float](repeating: 0, count: 6)
        _ = drain.withUnsafeMutableBufferPointer { ring.read(into: $0.baseAddress!, maxFrames: 3) }

        // Next write wraps past the end of the buffer.
        let second: [Float] = [4, 4, 5, 5, 6, 6]
        XCTAssertEqual(second.withUnsafeBufferPointer { ring.writeRealtime(interleavedFrames: $0.baseAddress!, frameCount: 3) }, 3)
        var out = [Float](repeating: 0, count: 6)
        XCTAssertEqual(out.withUnsafeMutableBufferPointer { ring.read(into: $0.baseAddress!, maxFrames: 3) }, 3)
        XCTAssertEqual(out, second)
    }

    /// Overflow must discard the OLDEST audio, not refuse the newest.
    func testOverflowDropsOldestAndKeepsNewest() {
        let ring = LiveCaptureSampleRing(frameCapacity: 4, channelCount: 1)
        let stale: [Float] = [1, 2, 3, 4]
        XCTAssertEqual(stale.withUnsafeBufferPointer { ring.writeRealtime(interleavedFrames: $0.baseAddress!, frameCount: 4) }, 4)

        let fresh: [Float] = [5, 6]
        XCTAssertEqual(fresh.withUnsafeBufferPointer { ring.writeRealtime(interleavedFrames: $0.baseAddress!, frameCount: 2) }, 2)
        XCTAssertEqual(ring.diagnostics.droppedFrames, 2)
        XCTAssertEqual(ring.availableFrames, 4)

        var out = [Float](repeating: 0, count: 4)
        XCTAssertEqual(out.withUnsafeMutableBufferPointer { ring.read(into: $0.baseAddress!, maxFrames: 4) }, 4)
        // 1 and 2 are gone; the newest audio survived.
        XCTAssertEqual(out, [3, 4, 5, 6])
        XCTAssertEqual(ring.diagnostics.discontinuities, 1)
    }

    func testWriteLargerThanCapacityKeepsNewestFrames() {
        let ring = LiveCaptureSampleRing(frameCapacity: 3, channelCount: 1)
        let burst: [Float] = [1, 2, 3, 4, 5]
        XCTAssertEqual(burst.withUnsafeBufferPointer { ring.writeRealtime(interleavedFrames: $0.baseAddress!, frameCount: 5) }, 3)
        var out = [Float](repeating: 0, count: 3)
        XCTAssertEqual(out.withUnsafeMutableBufferPointer { ring.read(into: $0.baseAddress!, maxFrames: 3) }, 3)
        XCTAssertEqual(out, [3, 4, 5])
        XCTAssertEqual(ring.diagnostics.droppedFrames, 2)
    }

    func testUnderflowFillsSilenceAndCounts() {
        let ring = LiveCaptureSampleRing(frameCapacity: 8, channelCount: 1)
        let source: [Float] = [7, 7]
        _ = source.withUnsafeBufferPointer { ring.writeRealtime(interleavedFrames: $0.baseAddress!, frameCount: 2) }

        var out = [Float](repeating: 99, count: 5)
        let delivered = out.withUnsafeMutableBufferPointer { ring.readFillingSilence(into: $0.baseAddress!, maxFrames: 5) }
        XCTAssertEqual(delivered, 2)
        XCTAssertEqual(out, [7, 7, 0, 0, 0], "underflow must be silence, not stale memory")
        XCTAssertEqual(ring.diagnostics.underflowFrames, 3)
    }

    /// Concurrent producer/consumer soak. The previous implementation took `&property`
    /// as `inout` from two threads, which is both an exclusivity violation and not
    /// reliably atomic; this exercises that path hard.
    func testConcurrentProducerConsumerDoesNotCorruptCursors() {
        let ring = LiveCaptureSampleRing(frameCapacity: 512, channelCount: 2)
        let iterations = 20_000
        let block = 16
        let finished = NSLock()
        var producerDone = false

        DispatchQueue.global(qos: .userInitiated).async {
            let frames = [Float](repeating: 0.25, count: block * 2)
            for _ in 0..<iterations {
                _ = frames.withUnsafeBufferPointer {
                    ring.writeRealtime(interleavedFrames: $0.baseAddress!, frameCount: block)
                }
            }
            finished.lock()
            producerDone = true
            finished.unlock()
        }

        var sink = [Float](repeating: 0, count: block * 2)
        var totalRead = 0
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            let got = sink.withUnsafeMutableBufferPointer { ring.read(into: $0.baseAddress!, maxFrames: block) }
            totalRead += got
            // Cursor corruption would show up here as a nonsensical fill level.
            XCTAssertLessThanOrEqual(ring.availableFrames, ring.frameCapacity)
            finished.lock()
            let done = producerDone
            finished.unlock()
            if done, got == 0 { break }
        }

        finished.lock()
        let done = producerDone
        finished.unlock()
        XCTAssertTrue(done, "producer did not finish within the deadline")
        XCTAssertEqual(ring.availableFrames, 0)
        XCTAssertGreaterThan(totalRead, 0)
    }
}
