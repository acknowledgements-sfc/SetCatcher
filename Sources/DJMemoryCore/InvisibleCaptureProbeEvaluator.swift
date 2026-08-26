import Foundation

#if os(macOS)
public struct InvisibleCaptureProbePassInput: Equatable, Sendable {
    public var peakLevel: Float
    public var rmsLevel: Float
    public var framesWritten: Int64
    public var stagingBytes: Int?
    public var wavValid: Bool
    public var archivePath: String?
    public var libraryReconciled: Bool
    public var signalThreshold: Float

    public init(
        peakLevel: Float,
        rmsLevel: Float,
        framesWritten: Int64,
        stagingBytes: Int?,
        wavValid: Bool,
        archivePath: String?,
        libraryReconciled: Bool,
        signalThreshold: Float = LiveCaptureDetectionConfig.default.signalThreshold
    ) {
        self.peakLevel = peakLevel
        self.rmsLevel = rmsLevel
        self.framesWritten = framesWritten
        self.stagingBytes = stagingBytes
        self.wavValid = wavValid
        self.archivePath = archivePath
        self.libraryReconciled = libraryReconciled
        self.signalThreshold = signalThreshold
    }
}

public enum InvisibleCaptureProbeEvaluator {
    public static func passes(_ input: InvisibleCaptureProbePassInput) -> Bool {
        guard input.peakLevel >= input.signalThreshold else { return false }
        guard input.framesWritten > 0 else { return false }
        guard input.wavValid else { return false }
        guard let archivePath = input.archivePath, !archivePath.isEmpty else { return false }
        guard let bytes = input.stagingBytes, bytes > 0 else { return false }
        return input.libraryReconciled
    }

    public static func outcomeLabel(for input: InvisibleCaptureProbePassInput) -> String {
        passes(input) ? "pass_meter_archive" : "fail_gate"
    }
}
#endif
