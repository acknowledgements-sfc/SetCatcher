import Foundation

public enum CapturePhase: Equatable, Sendable {
    case idle
    case requestingPermission
    case needsScreenRecordingPermission
    case armed
    case watching
    case recording
    case saving
    case failed(String)

    /// Whether Capture is on duty and idle system sleep must be prevented.
    ///
    /// True for `.watching` (Armed, waiting for audio), `.recording`, and `.saving`.
    /// False for `.armed` alone (targets known but not monitoring) and idle/permission/failed.
    public var shouldPreventIdleSleep: Bool {
        switch self {
        case .watching, .recording, .saving:
            return true
        case .idle, .requestingPermission, .needsScreenRecordingPermission, .armed, .failed:
            return false
        }
    }
}

/// A different DJ app or input device detected while one is already armed/watching/recording.
/// DJs don't run multiple DJ apps at once, so SetCatcher never silently retargets an active
/// session — it surfaces this instead and waits for the user to accept or dismiss.
public struct PendingAlternateSource: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case appAudio(softwareID: String)
        case inputDevice(deviceID: String)

        public var isInputDevice: Bool {
            if case .inputDevice = self { return true }
            return false
        }
    }
    public let kind: Kind
    public let displayName: String

    public init(kind: Kind, displayName: String) {
        self.kind = kind
        self.displayName = displayName
    }

    /// Identity used to dedupe/dismiss, independent of `Kind`'s associated value shape.
    public var id: String {
        switch kind {
        case .appAudio(let softwareID): return "appAudio:\(softwareID)"
        case .inputDevice(let deviceID): return "inputDevice:\(deviceID)"
        }
    }
}

public struct CaptureUIState: Equatable, Sendable {
    public var mode: CaptureMode
    public var phase: CapturePhase
    public var devices: [AudioInputDevice]
    public var selectedDeviceID: String?
    public var targetApps: [MatchedDJApp]
    public var selectedTargetAppID: String?
    public var inputLevel: Float
    public var lastArchivedSessionID: UUID?
    public var statusMessage: String
    public var pendingAlternateSource: PendingAlternateSource?
    /// Device name when App Audio is capturing a virtual input (e.g. Serato Virtual Audio).
    public var appAudioSourceName: String?
    /// Public laptop-driver / hardware-feed listening state. Defaults keep older previews compiling.
    public var listeningState: LiveCaptureListeningState
    public var listeningSummary: String

    public init(
        mode: CaptureMode = .appAudio,
        phase: CapturePhase = .idle,
        devices: [AudioInputDevice] = [],
        selectedDeviceID: String? = nil,
        targetApps: [MatchedDJApp] = [],
        selectedTargetAppID: String? = nil,
        inputLevel: Float = 0,
        lastArchivedSessionID: UUID? = nil,
        statusMessage: String = "Choose a running DJ app, then arm App audio Capture.",
        pendingAlternateSource: PendingAlternateSource? = nil,
        appAudioSourceName: String? = nil,
        listeningState: LiveCaptureListeningState = .detecting,
        listeningSummary: String = LiveCaptureCopy.detecting
    ) {
        self.mode = mode
        self.phase = phase
        self.devices = devices
        self.selectedDeviceID = selectedDeviceID
        self.targetApps = targetApps
        self.selectedTargetAppID = selectedTargetAppID
        self.inputLevel = inputLevel
        self.lastArchivedSessionID = lastArchivedSessionID
        self.statusMessage = statusMessage
        self.pendingAlternateSource = pendingAlternateSource
        self.appAudioSourceName = appAudioSourceName
        self.listeningState = listeningState
        self.listeningSummary = listeningSummary
    }

    public var selectedDevice: AudioInputDevice? {
        guard let selectedDeviceID else { return nil }
        return devices.first { $0.id == selectedDeviceID }
    }

    public var selectedTargetApp: MatchedDJApp? {
        guard let selectedTargetAppID else { return nil }
        return targetApps.first { $0.software.id == selectedTargetAppID }
    }

    public var isRecording: Bool {
        if case .recording = phase { return true }
        return false
    }

    public var isWatchingOrRecording: Bool {
        phase.shouldPreventIdleSleep
    }
}
