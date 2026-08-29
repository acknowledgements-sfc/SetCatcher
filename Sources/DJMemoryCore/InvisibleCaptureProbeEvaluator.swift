import Foundation

#if os(macOS)
public struct InvisibleCaptureProbePassInput: Equatable, Sendable {
    /// Peak measured from archived WAV samples (not the live meter).
    public var peakLevel: Float
    public var rmsLevel: Float
    public var framesWritten: Int64
    public var stagingBytes: Int?
    public var wavValid: Bool
    public var archivePath: String?
    public var libraryReconciled: Bool
    public var signalThreshold: Float
    /// True when archived WAV samples were scanned for peak evidence.
    public var signalMeasuredDuringRecording: Bool
    /// Bench scenario label; `UNKNOWN` / empty must not PASS.
    public var outputModeLabel: String

    public init(
        peakLevel: Float,
        rmsLevel: Float,
        framesWritten: Int64,
        stagingBytes: Int?,
        wavValid: Bool,
        archivePath: String?,
        libraryReconciled: Bool,
        signalThreshold: Float = LiveCaptureDetectionConfig.default.signalThreshold,
        signalMeasuredDuringRecording: Bool = true,
        outputModeLabel: String = "system-default"
    ) {
        self.peakLevel = peakLevel
        self.rmsLevel = rmsLevel
        self.framesWritten = framesWritten
        self.stagingBytes = stagingBytes
        self.wavValid = wavValid
        self.archivePath = archivePath
        self.libraryReconciled = libraryReconciled
        self.signalThreshold = signalThreshold
        self.signalMeasuredDuringRecording = signalMeasuredDuringRecording
        self.outputModeLabel = outputModeLabel
    }
}

public enum InvisibleCaptureProbeEvaluator {
    public static func passes(_ input: InvisibleCaptureProbePassInput) -> Bool {
        guard isExplicitOutputModeLabel(input.outputModeLabel) else { return false }
        guard input.peakLevel >= input.signalThreshold else { return false }
        guard input.signalMeasuredDuringRecording else { return false }
        guard input.framesWritten > 0 else { return false }
        guard input.wavValid else { return false }
        guard let archivePath = input.archivePath, !archivePath.isEmpty else { return false }
        guard let bytes = input.stagingBytes, bytes > 0 else { return false }
        return input.libraryReconciled
    }

    public static func outcomeLabel(for input: InvisibleCaptureProbePassInput) -> String {
        if !isExplicitOutputModeLabel(input.outputModeLabel) {
            return "unknown_scenario"
        }
        return passes(input) ? "pass_archive_signal" : "fail_gate"
    }

    public static func isExplicitOutputModeLabel(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.uppercased() != "UNKNOWN"
    }
}
#endif
