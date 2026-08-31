import Foundation

/// Hardware monitor reading bound to a single device UID. Levels from other devices are ignored.
public struct LiveCaptureHardwareMonitorReading: Equatable, Sendable {
    public var monitoredDeviceID: String?
    public var level: Float
    public var observing: Bool

    public static let unbound = LiveCaptureHardwareMonitorReading(
        monitoredDeviceID: nil,
        level: 0,
        observing: false
    )

    public init(monitoredDeviceID: String?, level: Float, observing: Bool) {
        self.monitoredDeviceID = monitoredDeviceID
        self.level = level
        self.observing = observing
    }
}

/// Pure route-fact assembly. Stateful detection tracking stays in `LiveCaptureDetectionTracker`.
public enum LiveCaptureRouteFactsBuilder {
    public struct Input: Sendable {
        public var devices: [AudioInputDevice]
        public var hardwareObservationCache: [String: (channels: Int, formatOK: Bool)]
        public var hardwareMonitor: LiveCaptureHardwareMonitorReading
        public var hardware: [HardwareInputObservation]
        public var driverAvailability: SetCatcherAudioDriverAvailability
        public var vendorVirtualInput: AudioInputDevice?
        public var vendorVirtualEnabled: Bool
        public var runningDJSoftwareIDs: Set<String>
        public var appAudioCapability: LiveCaptureAppAudioCapability
        public var appAudio: AppAudioObservation
        public var phase: CapturePhase
        public var currentKind: LiveCaptureRouteKind?
        public var currentDeviceID: String?
        public var currentBackend: LiveCaptureRecordingBackend?
        public var currentFeedIsProducingSignal: Bool
        public var recordingAlreadyActive: Bool
        public var routingAutomation: DJAppRoutingAutomation
        public var detection: LiveCaptureDetectionConfig

        public init(
            devices: [AudioInputDevice] = [],
            hardwareObservationCache: [String: (channels: Int, formatOK: Bool)] = [:],
            hardwareMonitor: LiveCaptureHardwareMonitorReading = .unbound,
            hardware: [HardwareInputObservation] = [],
            driverAvailability: SetCatcherAudioDriverAvailability = .missing,
            vendorVirtualInput: AudioInputDevice? = nil,
            vendorVirtualEnabled: Bool = false,
            runningDJSoftwareIDs: Set<String> = [],
            appAudioCapability: LiveCaptureAppAudioCapability = .unavailable,
            appAudio: AppAudioObservation = .idle,
            phase: CapturePhase = .idle,
            currentKind: LiveCaptureRouteKind? = nil,
            currentDeviceID: String? = nil,
            currentBackend: LiveCaptureRecordingBackend? = nil,
            currentFeedIsProducingSignal: Bool = false,
            recordingAlreadyActive: Bool = false,
            routingAutomation: DJAppRoutingAutomation = .notAutomatedYet,
            detection: LiveCaptureDetectionConfig = .default
        ) {
            self.devices = devices
            self.hardwareObservationCache = hardwareObservationCache
            self.hardwareMonitor = hardwareMonitor
            self.hardware = hardware
            self.driverAvailability = driverAvailability
            self.vendorVirtualInput = vendorVirtualInput
            self.vendorVirtualEnabled = vendorVirtualEnabled
            self.runningDJSoftwareIDs = runningDJSoftwareIDs
            self.appAudioCapability = appAudioCapability
            self.appAudio = appAudio
            self.phase = phase
            self.currentKind = currentKind
            self.currentDeviceID = currentDeviceID
            self.currentBackend = currentBackend
            self.currentFeedIsProducingSignal = currentFeedIsProducingSignal
            self.recordingAlreadyActive = recordingAlreadyActive
            self.routingAutomation = routingAutomation
            self.detection = detection
        }
    }

    public static func pioneerDrafts(
        from devices: [AudioInputDevice],
        cache: [String: (channels: Int, formatOK: Bool)]
    ) -> [HardwareInputObservation] {
        hardwareDrafts(from: devices, cache: cache)
    }

    public static func hardwareDrafts(
        from devices: [AudioInputDevice],
        cache: [String: (channels: Int, formatOK: Bool)]
    ) -> [HardwareInputObservation] {
        devices.filter(\.isTrustedDJHardwareFeed).map { device in
            let cached = cache[device.id]
            return HardwareInputObservation(
                device: device,
                inputChannelCount: cached?.channels ?? 0,
                formatIsSupported: cached?.formatOK ?? false
            )
        }
    }

    public static func build(_ input: Input) -> LiveCaptureRouteFacts {
        LiveCaptureRouteFacts(
            hardware: input.hardware,
            driverAvailability: input.driverAvailability,
            vendorVirtualInput: input.vendorVirtualInput,
            vendorVirtualEnabled: input.vendorVirtualEnabled,
            runningDJSoftwareIDs: input.runningDJSoftwareIDs,
            appAudioCapability: input.appAudioCapability,
            appAudio: input.appAudio,
            session: LiveCaptureSessionContext(
                phase: input.phase,
                currentKind: input.currentKind,
                currentDeviceID: input.currentDeviceID,
                currentBackend: input.currentBackend,
                currentFeedIsProducingSignal: input.currentFeedIsProducingSignal,
                recordingAlreadyActive: input.recordingAlreadyActive
            ),
            routingAutomation: input.routingAutomation,
            detection: input.detection
        )
    }

    public static func vendorVirtualInput(
        runningDJSoftwareIDs: Set<String>,
        devices: [AudioInputDevice]
    ) -> AudioInputDevice? {
        runningDJSoftwareIDs.compactMap { id in SupportedDJSoftware.all.first { $0.id == id } }
            .compactMap { AudioInputDeviceCatalog.virtualAudioDevice(for: $0, in: devices) }
            .first
    }

    public static func appAudioCapability(
        runningDJSoftwareIDs: Set<String>,
        screenCapturePermissionGranted: Bool
    ) -> LiveCaptureAppAudioCapability {
        if runningDJSoftwareIDs.isEmpty {
            return .unavailable
        }
        if screenCapturePermissionGranted {
            return .available
        }
        return .permissionDenied
    }

    public static func appAudioObservation(
        runningDJSoftwareIDs: Set<String>,
        isMonitoring: Bool,
        activeBackend: AppAudioCaptureBackendKind,
        sourceDeviceUID: String?,
        peakLevel: Float,
        applePathExhausted: Bool,
        screenCapturePermissionGranted: Bool,
        detection: LiveCaptureDetectionConfig = .default
    ) -> AppAudioObservation {
        AppAudioObservation(
            capability: appAudioCapability(
                runningDJSoftwareIDs: runningDJSoftwareIDs,
                screenCapturePermissionGranted: screenCapturePermissionGranted
            ),
            isMonitoring: isMonitoring,
            archiveBackend: isMonitoring ? activeBackend.archiveBackend : nil,
            sourceDeviceUID: sourceDeviceUID,
            observedSignal: detection.heardSignal(peakLevel),
            applePathExhausted: applePathExhausted
        )
    }

    /// Signal on the current route's own hardware device — never a foreign or app-audio level.
    public static func hardwareFeedIsProducingSignal(
        currentKind: LiveCaptureRouteKind?,
        currentDeviceID: String?,
        monitoredDeviceID: String?,
        level: Float,
        detection: LiveCaptureDetectionConfig = .default
    ) -> Bool {
        guard currentKind == .verifiedHardwareFeed,
              let currentID = currentDeviceID,
              currentID == monitoredDeviceID
        else { return false }
        return detection.heardSignal(level)
    }
}
