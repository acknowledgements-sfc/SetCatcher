import Foundation

public enum DJAppRoutingDetection: Equatable, Sendable {
    case running
    case notRunning
}

/// Capability only. Status refresh may read this; it must never apply a route.
public enum DJAppRoutingAutomation: String, Equatable, Sendable {
    case notAutomatedYet
    case unavailable
}

public struct DJAppRoutingStatus: Equatable, Sendable {
    public var detection: DJAppRoutingDetection
    public var automation: DJAppRoutingAutomation

    public init(detection: DJAppRoutingDetection, automation: DJAppRoutingAutomation) {
        self.detection = detection
        self.automation = automation
    }
}

public enum DJAppRoutingOutcome: Equatable, Sendable {
    case routed
    case restored
    case notAutomatedYet
    case appNotRunning
    case driverUnavailable
    case routeChangeFailed
    case verificationFailed
}

/// App-specific output routing. Implementations must not patch binaries, inject code,
/// or edit undocumented preference files.
///
/// Status methods are pure. `applyRouteToSetCatcherDriver` / `restorePreviousRoute`
/// are explicit actions and must not run from listening / status refresh.
public protocol DJAppOutputRoutingAdapter: Sendable {
    var softwareID: String { get }
    func routingStatus(runningSoftwareIDs: Set<String>) -> DJAppRoutingStatus
    func applyRouteToSetCatcherDriver() -> DJAppRoutingOutcome
    func restorePreviousRoute() -> DJAppRoutingOutcome
}

/// Serato is the first adapter. Process matching is the existing safe pattern;
/// changing Serato's output is not automated in this slice.
public struct SeratoOutputRoutingAdapter: DJAppOutputRoutingAdapter {
    public let softwareID = "serato"

    public init() {}

    public func routingStatus(runningSoftwareIDs: Set<String>) -> DJAppRoutingStatus {
        DJAppRoutingStatus(
            detection: runningSoftwareIDs.contains(softwareID) ? .running : .notRunning,
            automation: .notAutomatedYet
        )
    }

    public func applyRouteToSetCatcherDriver() -> DJAppRoutingOutcome {
        .notAutomatedYet
    }

    public func restorePreviousRoute() -> DJAppRoutingOutcome {
        .notAutomatedYet
    }
}

public enum DJAppOutputRouting {
    public static let serato = SeratoOutputRoutingAdapter()

    public static func adapter(for softwareID: String) -> (any DJAppOutputRoutingAdapter)? {
        switch softwareID {
        case SeratoOutputRoutingAdapter().softwareID:
            return serato
        default:
            return nil
        }
    }
}
