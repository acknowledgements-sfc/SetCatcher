import Foundation

/// Zero-based stereo indexes into a multi-channel Core Audio / AVAudio input buffer.
public struct HardwareStereoChannelPair: Equatable, Sendable {
    public let leftIndex: Int
    public let rightIndex: Int

    public init(leftIndex: Int, rightIndex: Int) {
        self.leftIndex = leftIndex
        self.rightIndex = rightIndex
    }

    /// 1-based channel numbers for logs and operator-facing copy.
    public var oneBasedLabel: String {
        "\(leftIndex + 1)/\(rightIndex + 1)"
    }

    /// Highest channel index required (inclusive).
    public var requiredChannelCount: Int {
        max(leftIndex, rightIndex) + 1
    }
}

public enum PioneerRecOutChannelMatrixError: Error, Equatable, Sendable {
    case invalidIndexes
    case channelCountTooSmall(pairLabel: String, required: Int, actual: Int)

    public var message: String {
        switch self {
        case .invalidIndexes:
            return "REC OUT channel indexes must be non-negative and distinct."
        case let .channelCountTooSmall(pairLabel, required, actual):
            return "Hypothesized REC OUT pair \(pairLabel) needs \(required) input channels, "
                + "but this device exposes \(actual). "
                + "Open the hardware Setting Utility, confirm USB rec-out routing, or use MASTER REC / App audio Capture."
        }
    }
}

/// Pioneer / AlphaTheta USB **REC OUT** channel pairs.
///
/// XDJ-XZ 3/4 is measured (2026-08-29 live map on an 8-channel @ 44.1 kHz stream).
/// Other rows remain unverified hypotheses. See `docs/xdj-usb-routing-2026-08-29.md`.
public enum PioneerRecOutChannelMatrix {
    /// Looks up a REC OUT pair from a Core Audio device display name.
    /// Returns `nil` when the device is unrecognized — callers keep default convert behavior.
    public static func hypothesizedPair(forDeviceName name: String) -> HardwareStereoChannelPair? {
        let haystack = name.lowercased()
        if haystack.contains("xdj-xz") || haystack.contains("xdj xz") {
            // Measured 2026-08-29 on 8ch @ 44.1 kHz Core Audio: channels 5/6 hot (~1.0).
            // ffmpeg/AVFoundation channel order differed (first adjacent active was 3/4).
            return HardwareStereoChannelPair(leftIndex: 4, rightIndex: 5)
        }
        if haystack.contains("xdj-rx3") || haystack.contains("xdj rx3") {
            return HardwareStereoChannelPair(leftIndex: 4, rightIndex: 5)
        }
        if haystack.contains("xdj-rx2") || haystack.contains("xdj rx2") {
            return HardwareStereoChannelPair(leftIndex: 2, rightIndex: 3)
        }
        if haystack.contains("djm-v10") || haystack.contains("djm v10") {
            return HardwareStereoChannelPair(leftIndex: 10, rightIndex: 11)
        }
        if haystack.contains("djm-a9") || haystack.contains("djm a9") {
            return HardwareStereoChannelPair(leftIndex: 8, rightIndex: 9)
        }
        if haystack.contains("djm-900") || haystack.contains("djm 900") {
            return HardwareStereoChannelPair(leftIndex: 8, rightIndex: 9)
        }
        return nil
    }

    /// Validates that `pair` fits inside `channelCount`.
    public static func validate(
        _ pair: HardwareStereoChannelPair,
        channelCount: Int
    ) -> Result<HardwareStereoChannelPair, PioneerRecOutChannelMatrixError> {
        guard pair.leftIndex >= 0, pair.rightIndex >= 0, pair.leftIndex != pair.rightIndex else {
            return .failure(.invalidIndexes)
        }
        guard channelCount >= pair.requiredChannelCount else {
            return .failure(
                .channelCountTooSmall(
                    pairLabel: pair.oneBasedLabel,
                    required: pair.requiredChannelCount,
                    actual: channelCount
                )
            )
        }
        return .success(pair)
    }

    /// Resolves and validates a hypothesized pair for `deviceName`, or returns `nil` when none applies.
    public static func resolvedPair(
        forDeviceName deviceName: String,
        channelCount: Int
    ) -> Result<HardwareStereoChannelPair?, PioneerRecOutChannelMatrixError> {
        guard let hypothesized = hypothesizedPair(forDeviceName: deviceName) else {
            return .success(nil as HardwareStereoChannelPair?)
        }
        switch validate(hypothesized, channelCount: channelCount) {
        case .success(let pair):
            return .success(pair)
        case .failure(let error):
            return .failure(error)
        }
    }
}

/// Vendor-agnostic REC OUT lookup. Pioneer rows are measured/hypothesized;
/// Denon and Rane return `nil` until a live channel map exists (do not guess).
public enum HardwareRecOutChannelMatrix {
    public static func hypothesizedPair(forDeviceName name: String) -> HardwareStereoChannelPair? {
        if let pioneer = PioneerRecOutChannelMatrix.hypothesizedPair(forDeviceName: name) {
            return pioneer
        }
        // Denon / Rane: nil until live-mapped.
        return nil
    }

    public static func resolvedPair(
        forDeviceName deviceName: String,
        channelCount: Int
    ) -> Result<HardwareStereoChannelPair?, PioneerRecOutChannelMatrixError> {
        guard let hypothesized = hypothesizedPair(forDeviceName: deviceName) else {
            return .success(nil as HardwareStereoChannelPair?)
        }
        switch PioneerRecOutChannelMatrix.validate(hypothesized, channelCount: channelCount) {
        case .success(let pair):
            return .success(pair)
        case .failure(let error):
            return .failure(error)
        }
    }
}
