import Foundation

/// What live capture can listen to. Hardware USB mix first; laptop driver second.
/// USB connection alone is never proof that a mix is reaching this Mac.
public enum LiveCaptureRouteKind: String, Codable, Equatable, Sendable {
    case verifiedHardwareFeed
    /// Hardware is attached and usable; the detection window has not finished yet.
    case detectingHardware
    /// Hardware is attached and usable but has produced no signal within the window.
    case connectedHardwareNoUsableSignal
    /// Future DJMemory Audio virtual driver.
    case djmemoryVirtualDriver
    /// Vendor-provided virtual input (e.g. Serato Virtual Audio).
    case vendorVirtualInput
    /// Current non-driver laptop app-audio fallback.
    case existingAppAudio
    case unavailable
}

/// What a verified hardware USB feed actually carries.
///
/// This is a quality grade, never a support gate. A DJM or all-in-one exposes the master mix
/// (post-crossfader, post-EQ, post-mic — the actual set). A bare CDJ exposes that deck's own
/// output. Both are real, capturable feeds; standalone players are supported whenever their
/// audio reaches this Mac. Only a rig whose audio never arrives is unavailable.
public enum LiveCaptureFeedGrade: String, Codable, Equatable, Sendable {
    case masterMix
    case deckFeed
    case unknown

    /// Higher wins when several verified feeds are connected at once.
    public var preferenceRank: Int {
        switch self {
        case .masterMix: return 2
        case .deckFeed: return 1
        case .unknown: return 0
        }
    }
}

/// Whether the existing app-audio path could actually capture right now.
/// A running DJ process is not capability — Screen Recording permission is.
public enum LiveCaptureAppAudioCapability: Equatable, Sendable {
    case available
    case permissionDenied
    case unavailable
}

/// Which way the rig is being driven. The same CDJ/DJM/XDJ hardware runs both ways with a
/// laptop connected, and neither device presence nor process presence can tell them apart —
/// only observed audio can.
public enum LiveCaptureRigMode: String, Codable, Equatable, Sendable {
    /// Players act as controllers; the Mac generates the audio.
    case laptopSoftware
    /// Players run off USB sticks and generate the audio themselves.
    case standaloneHardware
    case undetermined
}

/// App-level listening state. Plain language for the UI — not Core Audio jargon.
public enum LiveCaptureListeningState: String, Codable, Equatable, Sendable {
    case detecting
    case hardwareFeedActive
    case laptopDriverActive
    case fallbackActive
    case unavailable
    case recoveryNeeded
}

public enum LiveCaptureRecordingBackend: Equatable, Sendable {
    case hardwareInput(deviceID: String)
    case djmemoryDriver
    case vendorVirtualInput(deviceID: String)
    case existingAppAudio
    case none
}

public enum LiveCaptureRecoveryReason: String, Equatable, Sendable {
    case driverMissing
    case permissionOrInstallNeeded
    case appAudioUnavailable
}

public enum LiveCaptureRouteTransition: Equatable, Sendable {
    case none
    case apply
    case blockedUntilSessionBoundary
}

/// Load-bearing copy: say what DJMemory is listening to, and never claim standalone
/// CDJ/XDJ audio that never reaches this Mac.
public enum LiveCaptureCopy {
    public static let detecting = "Checking what DJMemory can listen to."
    public static let laptopDriverActive = "Listening to DJ app audio on this Mac."
    public static let fallbackActive = "Hardware is connected, but no USB mix was detected. Listening to DJ app audio on this Mac."
    public static let unavailable = "Live capture is not available. DJMemory can only record audio that reaches this Mac."
    public static let waitingForAudio = "Connected and ready. Waiting to hear audio."
    public static let driverMissing = "DJMemory Audio is not installed yet. Finish setup once, then DJMemory can listen automatically."
    public static let permissionOrInstallNeeded = "DJMemory needs its setup permissions before it can listen automatically."
    public static let appAudioUnavailable = "DJMemory cannot hear this DJ app yet. Finish setup once, then DJMemory can listen automatically."
    public static let notAutomatedYet = "DJMemory will use the best automatic capture path available after setup."

    public static func hardwareFeedActive(
        deviceName: String,
        grade: LiveCaptureFeedGrade = .unknown
    ) -> String {
        switch grade {
        case .deckFeed:
            return "Listening to the \(deviceName) USB feed on this Mac (deck output, not the mixer's master)."
        case .masterMix, .unknown:
            return "Listening to the \(deviceName) USB feed on this Mac."
        }
    }
}

public struct LiveCaptureDetectionConfig: Equatable, Sendable {
    public var windowSeconds: TimeInterval
    public var signalThreshold: Float

    public static let `default` = LiveCaptureDetectionConfig(windowSeconds: 2, signalThreshold: 0.02)

    public init(windowSeconds: TimeInterval = 2, signalThreshold: Float = 0.02) {
        self.windowSeconds = windowSeconds
        self.signalThreshold = signalThreshold
    }

    public func heardSignal(_ peakLevel: Float?) -> Bool {
        guard let peakLevel, peakLevel.isFinite else { return false }
        return peakLevel >= signalThreshold
    }
}

public struct HardwareInputObservation: Equatable, Sendable {
    public var device: AudioInputDevice
    public var inputChannelCount: Int
    public var formatIsSupported: Bool
    public var peakLevel: Float?
    public var detectionWindowComplete: Bool

    public init(
        device: AudioInputDevice,
        inputChannelCount: Int,
        formatIsSupported: Bool,
        peakLevel: Float? = nil,
        detectionWindowComplete: Bool = false
    ) {
        self.device = device
        self.inputChannelCount = inputChannelCount
        self.formatIsSupported = formatIsSupported
        self.peakLevel = peakLevel
        self.detectionWindowComplete = detectionWindowComplete
    }
}

public struct LiveCaptureSessionContext: Equatable, Sendable {
    public var phase: CapturePhase
    public var currentKind: LiveCaptureRouteKind?
    public var currentDeviceID: String?
    /// Signal observed on the *current route's own* device — not whatever input happens to
    /// be selected. Feeding a foreign device's level in here would fake a live feed.
    public var currentFeedIsProducingSignal: Bool
    public var recordingAlreadyActive: Bool

    public static let idle = LiveCaptureSessionContext(
        phase: .idle,
        currentKind: nil,
        currentDeviceID: nil,
        currentFeedIsProducingSignal: false,
        recordingAlreadyActive: false
    )

    public init(
        phase: CapturePhase = .idle,
        currentKind: LiveCaptureRouteKind? = nil,
        currentDeviceID: String? = nil,
        currentFeedIsProducingSignal: Bool = false,
        recordingAlreadyActive: Bool = false
    ) {
        self.phase = phase
        self.currentKind = currentKind
        self.currentDeviceID = currentDeviceID
        self.currentFeedIsProducingSignal = currentFeedIsProducingSignal
        self.recordingAlreadyActive = recordingAlreadyActive
    }

    public var blocksRouteChange: Bool {
        recordingAlreadyActive || phase.blocksLiveCaptureRouteChange
    }
}

public struct LiveCaptureRouteFacts: Equatable, Sendable {
    public var hardware: [HardwareInputObservation]
    public var driverAvailability: DJMemoryAudioDriverAvailability
    public var vendorVirtualInput: AudioInputDevice?
    public var vendorVirtualEnabled: Bool
    public var runningDJSoftwareIDs: Set<String>
    /// Whether app audio *could* capture (permission), not whether an app is open.
    public var appAudioCapability: LiveCaptureAppAudioCapability
    /// Whether app audio is actually producing samples right now. This is what
    /// distinguishes a laptop-software set from a standalone set with rekordbox merely open.
    public var appAudioIsProducing: Bool
    public var session: LiveCaptureSessionContext
    /// Pure status only. Never an apply-route outcome.
    public var routingAutomation: DJAppRoutingAutomation
    public var detection: LiveCaptureDetectionConfig

    public init(
        hardware: [HardwareInputObservation] = [],
        driverAvailability: DJMemoryAudioDriverAvailability = .missing,
        vendorVirtualInput: AudioInputDevice? = nil,
        vendorVirtualEnabled: Bool = false,
        runningDJSoftwareIDs: Set<String> = [],
        appAudioCapability: LiveCaptureAppAudioCapability = .unavailable,
        appAudioIsProducing: Bool = false,
        session: LiveCaptureSessionContext = .idle,
        routingAutomation: DJAppRoutingAutomation = .notAutomatedYet,
        detection: LiveCaptureDetectionConfig = .default
    ) {
        self.hardware = hardware
        self.driverAvailability = driverAvailability
        self.vendorVirtualInput = vendorVirtualInput
        self.vendorVirtualEnabled = vendorVirtualEnabled
        self.runningDJSoftwareIDs = runningDJSoftwareIDs
        self.appAudioCapability = appAudioCapability
        self.appAudioIsProducing = appAudioIsProducing
        self.session = session
        self.routingAutomation = routingAutomation
        self.detection = detection
    }

    /// Process presence only. Gates whether we bother looking at the laptop path; it never
    /// on its own justifies claiming we are listening to it.
    public var hasRunningDJApp: Bool {
        !runningDJSoftwareIDs.isEmpty
    }

    public var appAudioUsable: Bool {
        appAudioCapability == .available && hasRunningDJApp
    }
}

public struct LiveCaptureResolution: Equatable, Sendable {
    public var kind: LiveCaptureRouteKind
    public var listeningState: LiveCaptureListeningState
    public var listeningSummary: String
    public var backend: LiveCaptureRecordingBackend
    public var recovery: LiveCaptureRecoveryReason?
    public var hardwareDeviceID: String?
    public var feedGrade: LiveCaptureFeedGrade
    public var rigMode: LiveCaptureRigMode

    public init(
        kind: LiveCaptureRouteKind,
        listeningState: LiveCaptureListeningState,
        listeningSummary: String,
        backend: LiveCaptureRecordingBackend,
        recovery: LiveCaptureRecoveryReason? = nil,
        hardwareDeviceID: String? = nil,
        feedGrade: LiveCaptureFeedGrade = .unknown,
        rigMode: LiveCaptureRigMode = .undetermined
    ) {
        self.kind = kind
        self.listeningState = listeningState
        self.listeningSummary = listeningSummary
        self.backend = backend
        self.recovery = recovery
        self.hardwareDeviceID = hardwareDeviceID
        self.feedGrade = feedGrade
        self.rigMode = rigMode
    }

    /// True when `kind` and `backend` describe the same route. Blocked reconstruction
    /// must keep this true — never keep the current kind and copy a proposed backend.
    public var kindAgreesWithBackend: Bool {
        switch (kind, backend) {
        case (.verifiedHardwareFeed, .hardwareInput):
            return true
        case (.detectingHardware, .none):
            return true
        case (.connectedHardwareNoUsableSignal, .none):
            return true
        case (.djmemoryVirtualDriver, .djmemoryDriver):
            return true
        case (.vendorVirtualInput, .vendorVirtualInput):
            return true
        case (.existingAppAudio, .existingAppAudio):
            return true
        case (.unavailable, .none):
            return true
        default:
            return false
        }
    }

    public var sessionDeviceID: String? {
        switch backend {
        case .hardwareInput(let id), .vendorVirtualInput(let id):
            return id
        default:
            return hardwareDeviceID
        }
    }

    public var snapshot: LiveCaptureListeningSnapshot {
        LiveCaptureListeningSnapshot(
            state: listeningState,
            summary: listeningSummary,
            routeKind: kind,
            backend: backend,
            recovery: recovery,
            feedGrade: feedGrade,
            rigMode: rigMode
        )
    }
}

public struct LiveCaptureListeningSnapshot: Equatable, Sendable {
    public var state: LiveCaptureListeningState
    public var summary: String
    public var routeKind: LiveCaptureRouteKind
    public var backend: LiveCaptureRecordingBackend
    public var recovery: LiveCaptureRecoveryReason?
    public var feedGrade: LiveCaptureFeedGrade
    public var rigMode: LiveCaptureRigMode

    public static let detecting = LiveCaptureListeningSnapshot(
        state: .detecting,
        summary: LiveCaptureCopy.detecting,
        routeKind: .unavailable,
        backend: .none,
        recovery: nil,
        feedGrade: .unknown,
        rigMode: .undetermined
    )

    public init(
        state: LiveCaptureListeningState,
        summary: String,
        routeKind: LiveCaptureRouteKind,
        backend: LiveCaptureRecordingBackend,
        recovery: LiveCaptureRecoveryReason? = nil,
        feedGrade: LiveCaptureFeedGrade = .unknown,
        rigMode: LiveCaptureRigMode = .undetermined
    ) {
        self.state = state
        self.summary = summary
        self.routeKind = routeKind
        self.backend = backend
        self.recovery = recovery
        self.feedGrade = feedGrade
        self.rigMode = rigMode
    }
}

public struct LiveCaptureRouteDecision: Equatable, Sendable {
    public var resolution: LiveCaptureResolution
    public var transition: LiveCaptureRouteTransition

    public init(resolution: LiveCaptureResolution, transition: LiveCaptureRouteTransition) {
        self.resolution = resolution
        self.transition = transition
    }
}

extension CapturePhase {
    public var blocksLiveCaptureRouteChange: Bool {
        switch self {
        case .recording, .saving:
            return true
        default:
            return false
        }
    }
}
