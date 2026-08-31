import Foundation

/// Engine actions the host (AppModel) must perform — coordinator never touches ScreenCaptureKit.
public enum CaptureSessionEngineAction: Equatable, Sendable {
    case beginRecordingFile
    case endRecordingFile(discard: Bool)
}

/// One tick of Capture session policy: phase + meter + optional engine action.
public struct CaptureSessionTick: Equatable, Sendable {
    public var phase: CapturePhase
    public var inputLevel: Float
    public var statusMessage: String
    public var engineAction: CaptureSessionEngineAction?

    public init(
        phase: CapturePhase,
        inputLevel: Float = 0,
        statusMessage: String,
        engineAction: CaptureSessionEngineAction? = nil
    ) {
        self.phase = phase
        self.inputLevel = inputLevel
        self.statusMessage = statusMessage
        self.engineAction = engineAction
    }
}

/// Deep module for App audio Capture session control: silence FSM → phase → engine actions.
/// AppModel stays the adapter for permissions, ingest, notifications, and Task polling.
public struct CaptureSessionCoordinator: Equatable, Sendable {
    private var silence: SilenceSessionController
    private var phase: CapturePhase
    private var targetDisplayName: String
    private var route: CaptureMode

    public init(config: SilenceSessionConfig = .default) {
        self.silence = SilenceSessionController(config: config)
        self.phase = .idle
        self.targetDisplayName = ""
        self.route = .appAudio
    }

    public var currentPhase: CapturePhase { phase }

    public mutating func prepareWatching(
        config: SilenceSessionConfig,
        targetDisplayName: String,
        route: CaptureMode = .appAudio
    ) -> CaptureSessionTick {
        silence = SilenceSessionController(config: config)
        self.targetDisplayName = targetDisplayName
        self.route = route
        phase = .watching
        return CaptureSessionTick(
            phase: .watching,
            statusMessage: watchingMessage
        )
    }

    public mutating func disarm(hasTargets: Bool) -> CaptureSessionTick {
        silence.resetToArmed()
        phase = hasTargets ? .armed : .idle
        return CaptureSessionTick(
            phase: phase,
            statusMessage: disarmMessage
        )
    }

    /// Feed RMS from the capture engine while watching or recording.
    public mutating func tick(level: Float, now: Date = Date()) -> CaptureSessionTick {
        guard phase == .watching || phase == .recording else {
            return CaptureSessionTick(phase: phase, inputLevel: level, statusMessage: "")
        }

        let event = silence.process(level: level, now: now)
        switch event {
        case .none:
            return CaptureSessionTick(
                phase: phase,
                inputLevel: level,
                statusMessage: phase == .recording ? recordingMessage : watchingMessage
            )

        case .startedRecording:
            phase = .recording
            return CaptureSessionTick(
                phase: .recording,
                inputLevel: level,
                statusMessage: recordingMessage,
                engineAction: .beginRecordingFile
            )

        case .finalizeSession(_, let discard):
            phase = .saving
            return CaptureSessionTick(
                phase: .saving,
                inputLevel: level,
                statusMessage: discard ? "Discarding short take…" : savingMessage,
                engineAction: .endRecordingFile(discard: discard)
            )
        }
    }

    /// Manual start while watching — no confirmation in UI.
    public mutating func requestManualStart(level: Float) -> CaptureSessionTick? {
        guard phase == .watching else { return nil }
        silence.forceStartRecording()
        phase = .recording
        return CaptureSessionTick(
            phase: .recording,
            inputLevel: level,
            statusMessage: recordingMessage,
            engineAction: .beginRecordingFile
        )
    }

    /// Manual Stop while recording: finalize without discard (host still performs endRecordingFile).
    public mutating func requestManualSave() -> CaptureSessionTick {
        silence.resetToArmed()
        phase = .saving
        return CaptureSessionTick(
            phase: .saving,
            statusMessage: savingMessage,
            engineAction: .endRecordingFile(discard: false)
        )
    }

    public mutating func resumeWatchingAfterSave(discarded: Bool, minDurationSeconds: TimeInterval, level: Float) -> CaptureSessionTick {
        phase = .watching
        let message = discarded
            ? "Short take discarded (under \(Int(minDurationSeconds))s). Still watching."
            : savedWatchingMessage
        return CaptureSessionTick(phase: .watching, inputLevel: level, statusMessage: message)
    }

    public mutating func resumeWatchingAfterManualSave(level: Float) -> CaptureSessionTick {
        phase = .watching
        return CaptureSessionTick(
            phase: .watching,
            inputLevel: level,
            statusMessage: "Manual stop saved. Still watching for the next set."
        )
    }

    private var watchingMessage: String {
        switch route {
        case .appAudio:
            return "Watching \(targetDisplayName). Recording starts when audio is detected; idle silence saves the take automatically."
        case .inputDevice:
            return "Watching \(targetDisplayName). Recording starts when audio is detected; idle silence saves the take automatically. Folder Protection still watches recording folders."
        }
    }

    private var recordingMessage: String {
        switch route {
        case .appAudio:
            return "Recording \(targetDisplayName) app audio…"
        case .inputDevice:
            return "Recording \(targetDisplayName)…"
        }
    }

    private var savingMessage: String {
        switch route {
        case .appAudio:
            return "Saving app audio into your archive…"
        case .inputDevice:
            return "Saving capture into your archive…"
        }
    }

    private var savedWatchingMessage: String {
        switch route {
        case .appAudio:
            return "App audio saved. Watching for the next set. Source DJ app files were not moved."
        case .inputDevice:
            return "Capture saved. Watching for the next set. Folder Protection still watches recording folders."
        }
    }

    private var disarmMessage: String {
        switch route {
        case .appAudio:
            return "App audio Capture is disarmed. Folder Protection still watches recording folders."
        case .inputDevice:
            return "Input device Capture is disarmed. Folder Protection still watches recording folders."
        }
    }
}
