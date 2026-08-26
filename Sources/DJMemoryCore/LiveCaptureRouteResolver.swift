import Foundation

public enum LiveCaptureHardwareAssessment: Equatable, Sendable {
    case verified(deviceID: String, displayName: String, grade: LiveCaptureFeedGrade)
    case detecting(deviceID: String, displayName: String)
    case connectedSilent(deviceID: String, displayName: String)
    case connectedUnusable(deviceID: String, displayName: String)
    case none

    /// Dual-route may auto-prefer Input Capture only for a verified or still-detecting feed.
    public var prefersHardwareInput: Bool {
        switch self {
        case .verified, .detecting:
            return true
        case .connectedSilent, .connectedUnusable, .none:
            return false
        }
    }

    public var isVerified: Bool {
        if case .verified = self { return true }
        return false
    }
}

public enum LiveCaptureHardwareClassifier {
    /// What a unit's USB feed carries. This grades quality; it never decides support.
    /// A standalone CDJ playing off a USB stick is capturable — it just carries that deck's
    /// output rather than the mixer's master.
    public static func grade(for device: AudioInputDevice) -> LiveCaptureFeedGrade {
        if let profile = SupportedHardware.profile(matching: device) {
            return profile.canProvideUSBMasterFeed ? .masterMix : .deckFeed
        }
        let haystack = "\(device.name) \(device.manufacturer)".lowercased()
        if haystack.contains("cdj") { return .deckFeed }
        if haystack.contains("djm") { return .masterMix }
        // "xdj" alone is not proof of a master mix — XDJ-1000 is a player. Only the
        // profile table may promote an XDJ to masterMix.
        return .unknown
    }

    /// A device whose audio can actually be recorded: real input channels and a format we
    /// support. USB presence alone is never enough.
    public static func isUsable(_ observation: HardwareInputObservation) -> Bool {
        observation.inputChannelCount > 0 && observation.formatIsSupported
    }

    public static func assess(
        _ observations: [HardwareInputObservation],
        detection: LiveCaptureDetectionConfig = .default
    ) -> LiveCaptureHardwareAssessment {
        // Any connected unit is a candidate. Highest-grade verified feed wins, so a DJM
        // master beats a CDJ deck when both are present.
        let verified = observations
            .filter { isVerifiedFeed($0, detection: detection) }
            .max { grade(for: $0.device).preferenceRank < grade(for: $1.device).preferenceRank }
        if let verified {
            return .verified(
                deviceID: verified.device.id,
                displayName: verified.device.name,
                grade: grade(for: verified.device)
            )
        }
        if let detecting = observations.first(where: { isUsable($0) && !$0.detectionWindowComplete }) {
            return .detecting(deviceID: detecting.device.id, displayName: detecting.device.name)
        }
        if let silent = observations.first(where: { isUsable($0) }) {
            return .connectedSilent(deviceID: silent.device.id, displayName: silent.device.name)
        }
        if let unusable = observations.first {
            return .connectedUnusable(deviceID: unusable.device.id, displayName: unusable.device.name)
        }
        return .none
    }

    public static func isVerifiedFeed(
        _ observation: HardwareInputObservation,
        detection: LiveCaptureDetectionConfig = .default
    ) -> Bool {
        guard isUsable(observation) else { return false }
        guard observation.detectionWindowComplete else { return false }
        return detection.heardSignal(observation.peakLevel)
    }
}

/// Tracks the bounded hardware-signal window.
///
/// The window is re-armed once it completes, so a feed that goes quiet stops reading as
/// verified instead of latching on the loudest moment of the night.
public struct LiveCaptureDetectionTracker: Equatable, Sendable {
    public var windowStartedAt: Date?
    public var peakLevel: Float = 0
    public var deviceSignature: String = ""
    private var lastWindowComplete = false

    public init() {}

    public mutating func observe(
        _ drafts: [HardwareInputObservation],
        monitoredDeviceID: String?,
        level: Float,
        observing: Bool,
        now: Date,
        config: LiveCaptureDetectionConfig = .default
    ) -> [HardwareInputObservation] {
        let signature = drafts.map(\.device.id).sorted().joined(separator: ",")
        if signature != deviceSignature {
            deviceSignature = signature
            windowStartedAt = observing ? now : nil
            peakLevel = 0
            lastWindowComplete = false
        }
        if !observing {
            windowStartedAt = nil
            peakLevel = 0
            lastWindowComplete = false
            return drafts.map { draft in
                HardwareInputObservation(
                    device: draft.device,
                    inputChannelCount: draft.inputChannelCount,
                    formatIsSupported: draft.formatIsSupported,
                    peakLevel: nil,
                    detectionWindowComplete: false
                )
            }
        }

        var complete = false
        var reportedPeak: Float?
        if let monitoredDeviceID,
           drafts.contains(where: { $0.device.id == monitoredDeviceID }) {
            if windowStartedAt == nil { windowStartedAt = now }
            peakLevel = max(peakLevel, level)
            complete = windowStartedAt.map { now.timeIntervalSince($0) >= config.windowSeconds } == true
            reportedPeak = peakLevel
            if complete {
                // Re-arm: the next verdict must be earned by fresh audio, not by history.
                windowStartedAt = now
                peakLevel = level
            }
            lastWindowComplete = complete
        } else {
            windowStartedAt = nil
            peakLevel = 0
            lastWindowComplete = false
        }

        return drafts.map { draft in
            let isMonitored = draft.device.id == monitoredDeviceID
            return HardwareInputObservation(
                device: draft.device,
                inputChannelCount: draft.inputChannelCount,
                formatIsSupported: draft.formatIsSupported,
                peakLevel: isMonitored ? reportedPeak : nil,
                detectionWindowComplete: isMonitored ? complete : false
            )
        }
    }
}

/// Chooses what live capture listens to.
///
/// Governing rule: **observed audio decides the route; a running process never does.**
/// A verified hardware USB feed wins in both rig modes — in laptop-software mode it is the
/// same audio plus the mixer's contribution, and in standalone mode it is the only audio
/// that exists. The laptop path is only claimed when app audio is genuinely available, and
/// when hardware is connected it additionally has to be *heard*, because rekordbox being
/// open proves nothing about who is making the sound.
public enum LiveCaptureRouteResolver {
    public static func resolve(_ facts: LiveCaptureRouteFacts) -> LiveCaptureRouteDecision {
        let proposed = propose(facts)
        let session = facts.session
        let holdVerifiedHardware = session.currentKind == .verifiedHardwareFeed
            && session.currentFeedIsProducingSignal

        if holdVerifiedHardware, let current = currentResolution(for: facts, proposed: proposed) {
            let transition: LiveCaptureRouteTransition = current.kind == proposed.kind ? .none : .blockedUntilSessionBoundary
            return LiveCaptureRouteDecision(resolution: current, transition: transition)
        }

        if session.blocksRouteChange {
            if let current = currentResolution(for: facts, proposed: proposed) {
                let transition: LiveCaptureRouteTransition = current.kind == proposed.kind
                    ? .none
                    : .blockedUntilSessionBoundary
                return LiveCaptureRouteDecision(resolution: current, transition: transition)
            }
            // No current route on record while recording: we cannot verify what is being
            // written, so never silently adopt a different one mid-take.
            return LiveCaptureRouteDecision(resolution: proposed, transition: .blockedUntilSessionBoundary)
        }

        let transition: LiveCaptureRouteTransition
        if session.currentKind == nil || session.currentKind == proposed.kind {
            transition = .none
        } else {
            transition = .apply
        }
        return LiveCaptureRouteDecision(resolution: proposed, transition: transition)
    }

    /// Apply-route failures only. Status refresh must not feed an apply outcome into `resolve`.
    public static func resolution(forApplyOutcome outcome: DJAppRoutingOutcome) -> LiveCaptureResolution? {
        switch outcome {
        case .routeChangeFailed, .verificationFailed:
            return recovery(.appAudioUnavailable, summary: LiveCaptureCopy.appAudioUnavailable)
        case .routed, .restored, .notAutomatedYet, .appNotRunning, .driverUnavailable:
            return nil
        }
    }

    /// Which way the rig is being driven, inferred only from audio we can actually observe.
    public static func rigMode(_ facts: LiveCaptureRouteFacts) -> LiveCaptureRigMode {
        let hardware = LiveCaptureHardwareClassifier.assess(facts.hardware, detection: facts.detection)
        if hardware.isVerified {
            return facts.appAudioIsProducing ? .laptopSoftware : .standaloneHardware
        }
        if facts.appAudioIsProducing { return .laptopSoftware }
        return .undetermined
    }

    private static func propose(_ facts: LiveCaptureRouteFacts) -> LiveCaptureResolution {
        let hardware = LiveCaptureHardwareClassifier.assess(facts.hardware, detection: facts.detection)
        let mode = rigMode(facts)

        switch hardware {
        case .verified(let deviceID, let displayName, let grade):
            return LiveCaptureResolution(
                kind: .verifiedHardwareFeed,
                listeningState: .hardwareFeedActive,
                listeningSummary: LiveCaptureCopy.hardwareFeedActive(deviceName: displayName, grade: grade),
                backend: .hardwareInput(deviceID: deviceID),
                hardwareDeviceID: deviceID,
                feedGrade: grade,
                rigMode: mode
            )

        case .detecting:
            return LiveCaptureResolution(
                kind: .detectingHardware,
                listeningState: .detecting,
                listeningSummary: LiveCaptureCopy.detecting,
                backend: .none,
                rigMode: mode
            )

        case .connectedSilent, .connectedUnusable:
            // Hardware is present but quiet. Only hand over to the laptop path when app audio
            // is actually being heard — otherwise this is a standalone rig between tracks,
            // not a reason to switch.
            if facts.appAudioIsProducing {
                return laptopRoute(facts, listeningState: .fallbackActive, summary: LiveCaptureCopy.fallbackActive, mode: mode)
            }
            return LiveCaptureResolution(
                kind: .connectedHardwareNoUsableSignal,
                listeningState: .detecting,
                listeningSummary: LiveCaptureCopy.waitingForAudio,
                backend: .none,
                rigMode: mode
            )

        case .none:
            if facts.appAudioUsable {
                return laptopRoute(
                    facts,
                    listeningState: .laptopDriverActive,
                    summary: LiveCaptureCopy.laptopDriverActive,
                    mode: mode
                )
            }
            if facts.hasRunningDJApp, facts.appAudioCapability == .permissionDenied {
                return recovery(.permissionOrInstallNeeded, summary: LiveCaptureCopy.permissionOrInstallNeeded)
            }
            return LiveCaptureResolution(
                kind: .unavailable,
                listeningState: .unavailable,
                listeningSummary: LiveCaptureCopy.unavailable,
                backend: .none,
                rigMode: mode
            )
        }
    }

    /// Laptop-generated audio: Process Tap / ScreenCaptureKit first, then opt-in vendor input.
    /// DJMemory driver availability is diagnostic only and must not select a route in v1.
    private static func laptopRoute(
        _ facts: LiveCaptureRouteFacts,
        listeningState: LiveCaptureListeningState,
        summary: String,
        mode: LiveCaptureRigMode
    ) -> LiveCaptureResolution {
        let appleBackend = facts.appAudio.archiveBackend ?? .processAudioTap

        if facts.appAudio.isMonitoring {
            let active = facts.appAudioIsProducing
            if facts.appAudio.archiveBackend == .virtualInputDevice,
               let vendorUID = facts.appAudio.sourceDeviceUID ?? facts.vendorVirtualInput?.id,
               !vendorUID.isEmpty
            {
                return LiveCaptureResolution(
                    kind: .vendorVirtualInput,
                    listeningState: active ? listeningState : .detecting,
                    listeningSummary: active ? summary : LiveCaptureCopy.waitingForAudio,
                    backend: .vendorVirtualInput(deviceID: vendorUID),
                    rigMode: mode
                )
            }
            return LiveCaptureResolution(
                kind: .existingAppAudio,
                listeningState: active ? listeningState : .detecting,
                listeningSummary: active ? summary : LiveCaptureCopy.waitingForAudio,
                backend: .existingAppAudio(archiveBackend: appleBackend),
                rigMode: mode
            )
        }

        if facts.appAudio.applePathExhausted,
           facts.vendorVirtualEnabled,
           let vendor = facts.vendorVirtualInput
        {
            let active = facts.appAudioIsProducing
            return LiveCaptureResolution(
                kind: .vendorVirtualInput,
                listeningState: active ? listeningState : .detecting,
                listeningSummary: active ? summary : LiveCaptureCopy.waitingForAudio,
                backend: .vendorVirtualInput(deviceID: vendor.id),
                rigMode: mode
            )
        }

        if facts.appAudioUsable {
            return LiveCaptureResolution(
                kind: .existingAppAudio,
                listeningState: .detecting,
                listeningSummary: LiveCaptureCopy.waitingForAudio,
                backend: .existingAppAudio(archiveBackend: appleBackend),
                rigMode: mode
            )
        }

        if facts.appAudio.applePathExhausted,
           facts.vendorVirtualEnabled,
           facts.vendorVirtualInput != nil
        {
            return recovery(.appAudioUnavailable, summary: LiveCaptureCopy.appAudioUnavailable)
        }

        if facts.appAudioCapability == .permissionDenied {
            return recovery(.permissionOrInstallNeeded, summary: LiveCaptureCopy.permissionOrInstallNeeded)
        }
        return recovery(.appAudioUnavailable, summary: LiveCaptureCopy.appAudioUnavailable)
    }

    private static func driverResolution(
        listeningState: LiveCaptureListeningState,
        summary: String,
        mode: LiveCaptureRigMode
    ) -> LiveCaptureResolution {
        LiveCaptureResolution(
            kind: .djmemoryVirtualDriver,
            listeningState: listeningState,
            listeningSummary: summary,
            backend: .djmemoryDriver,
            rigMode: mode
        )
    }

    private static func recovery(
        _ reason: LiveCaptureRecoveryReason,
        summary: String
    ) -> LiveCaptureResolution {
        LiveCaptureResolution(
            kind: .unavailable,
            listeningState: .recoveryNeeded,
            listeningSummary: summary,
            backend: .none,
            recovery: reason
        )
    }

    private static func currentResolution(
        for facts: LiveCaptureRouteFacts,
        proposed: LiveCaptureResolution
    ) -> LiveCaptureResolution? {
        guard let kind = facts.session.currentKind else { return nil }
        if kind == proposed.kind { return proposed }
        return reconstruct(kind, from: facts)
    }

    /// Rebuild the live route from the current kind. Backend always matches that kind, and a
    /// route is never synthesised for hardware that is no longer there — claiming a feed we
    /// cannot see is the one failure this whole model exists to prevent.
    private static func reconstruct(
        _ kind: LiveCaptureRouteKind,
        from facts: LiveCaptureRouteFacts
    ) -> LiveCaptureResolution? {
        switch kind {
        case .verifiedHardwareFeed:
            return reconstructVerifiedHardware(facts)
        case .detectingHardware:
            return LiveCaptureResolution(
                kind: .detectingHardware,
                listeningState: .detecting,
                listeningSummary: LiveCaptureCopy.detecting,
                backend: .none,
                rigMode: rigMode(facts)
            )
        case .connectedHardwareNoUsableSignal:
            return LiveCaptureResolution(
                kind: .connectedHardwareNoUsableSignal,
                listeningState: .detecting,
                listeningSummary: LiveCaptureCopy.waitingForAudio,
                backend: .none,
                rigMode: rigMode(facts)
            )
        case .djmemoryVirtualDriver:
            guard facts.driverAvailability.isAvailable else { return nil }
            return reconstructDriver(facts)
        case .vendorVirtualInput:
            return reconstructVendor(facts)
        case .existingAppAudio:
            guard facts.appAudioCapability == .available else { return nil }
            let backend = facts.session.currentBackend ?? facts.appAudio.archiveBackend.map {
                LiveCaptureRecordingBackend.existingAppAudio(archiveBackend: $0)
            } ?? .existingAppAudio(archiveBackend: .processAudioTap)
            let active = facts.appAudioIsProducing
            return LiveCaptureResolution(
                kind: .existingAppAudio,
                listeningState: active ? .laptopDriverActive : .detecting,
                listeningSummary: active ? LiveCaptureCopy.laptopDriverActive : LiveCaptureCopy.waitingForAudio,
                backend: backend,
                rigMode: rigMode(facts)
            )
        case .unavailable:
            return LiveCaptureResolution(
                kind: .unavailable,
                listeningState: .unavailable,
                listeningSummary: LiveCaptureCopy.unavailable,
                backend: .none,
                rigMode: rigMode(facts)
            )
        }
    }

    private static func reconstructVerifiedHardware(_ facts: LiveCaptureRouteFacts) -> LiveCaptureResolution? {
        if case .hardwareInput(let frozenID) = facts.session.currentBackend,
           let observation = facts.hardware.first(where: { $0.device.id == frozenID }),
           LiveCaptureHardwareClassifier.isUsable(observation) {
            let grade = LiveCaptureHardwareClassifier.grade(for: observation.device)
            return LiveCaptureResolution(
                kind: .verifiedHardwareFeed,
                listeningState: .hardwareFeedActive,
                listeningSummary: LiveCaptureCopy.hardwareFeedActive(deviceName: observation.device.name, grade: grade),
                backend: .hardwareInput(deviceID: frozenID),
                hardwareDeviceID: frozenID,
                feedGrade: grade,
                rigMode: rigMode(facts)
            )
        }
        let assessment = LiveCaptureHardwareClassifier.assess(facts.hardware, detection: facts.detection)
        if case .verified(let deviceID, let displayName, let grade) = assessment {
            return LiveCaptureResolution(
                kind: .verifiedHardwareFeed,
                listeningState: .hardwareFeedActive,
                listeningSummary: LiveCaptureCopy.hardwareFeedActive(deviceName: displayName, grade: grade),
                backend: .hardwareInput(deviceID: deviceID),
                hardwareDeviceID: deviceID,
                feedGrade: grade,
                rigMode: rigMode(facts)
            )
        }
        // The device we were recording is still attached but momentarily quiet: hold the
        // route by its real identity rather than inventing one.
        if let deviceID = facts.session.currentDeviceID,
           let observation = facts.hardware.first(where: { $0.device.id == deviceID }),
           LiveCaptureHardwareClassifier.isUsable(observation) {
            let grade = LiveCaptureHardwareClassifier.grade(for: observation.device)
            return LiveCaptureResolution(
                kind: .verifiedHardwareFeed,
                listeningState: .hardwareFeedActive,
                listeningSummary: LiveCaptureCopy.hardwareFeedActive(deviceName: observation.device.name, grade: grade),
                backend: .hardwareInput(deviceID: deviceID),
                hardwareDeviceID: deviceID,
                feedGrade: grade,
                rigMode: rigMode(facts)
            )
        }
        // Gone. Say so; never fabricate a device ID or a display name.
        return nil
    }

    private static func reconstructDriver(_ facts: LiveCaptureRouteFacts) -> LiveCaptureResolution {
        let hardware = LiveCaptureHardwareClassifier.assess(facts.hardware, detection: facts.detection)
        let isFallback: Bool
        switch hardware {
        case .connectedSilent, .connectedUnusable:
            isFallback = true
        case .verified, .detecting, .none:
            isFallback = false
        }
        return driverResolution(
            listeningState: isFallback ? .fallbackActive : .laptopDriverActive,
            summary: isFallback ? LiveCaptureCopy.fallbackActive : LiveCaptureCopy.laptopDriverActive,
            mode: rigMode(facts)
        )
    }

    private static func reconstructVendor(_ facts: LiveCaptureRouteFacts) -> LiveCaptureResolution? {
        let deviceID: String?
        if case .vendorVirtualInput(let id) = facts.session.currentBackend {
            deviceID = id
        } else {
            deviceID = facts.appAudio.sourceDeviceUID ?? facts.vendorVirtualInput?.id ?? facts.session.currentDeviceID
        }
        guard let deviceID, !deviceID.isEmpty,
              facts.vendorVirtualInput != nil || facts.appAudio.archiveBackend == .virtualInputDevice
        else { return nil }
        return LiveCaptureResolution(
            kind: .vendorVirtualInput,
            listeningState: .laptopDriverActive,
            listeningSummary: LiveCaptureCopy.laptopDriverActive,
            backend: .vendorVirtualInput(deviceID: deviceID),
            rigMode: rigMode(facts)
        )
    }
}
