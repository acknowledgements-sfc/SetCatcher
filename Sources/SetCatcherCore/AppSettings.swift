import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public static let defaultArchiveNamingTemplate = "{date} {time} - {app} - Set"

    public let automaticScanningEnabled: Bool
    public let scanIntervalSeconds: Int
    public let archiveNamingTemplate: String
    public let archiveRootPath: String?
    public let archiveRootBookmarkData: Data?
    public let hasCompletedOnboarding: Bool
    public let verifyCopies: Bool
    public let notifyAfterArchiving: Bool
    public let launchAtLogin: Bool
    public let lastCaptureDeviceID: String?
    public let captureMode: CaptureMode
    public let lastCaptureTargetAppID: String?
    public let appAudioIdleSeconds: Int
    public let appAudioMinDurationSeconds: Int
    public let appAudioStartHoldSeconds: Int
    public let appAudioEnergyThreshold: Float
    public let cloudSyncEnabled: Bool
    public let cloudArchiveBackupEnabled: Bool
    public let autoArmOnDJAppFound: Bool
    public let appPresentationMode: AppPresentationMode
    public let showFolderScanDetailsInMenuBar: Bool
    public let dualRoutePosture: DualRoutePosture
    /// Pinned Core Audio UID for Analog Mixer rec-out. Nil until the DJ Choose-rec-out once.
    public let pinnedAnalogInputDeviceID: String?

    /// Legacy alias — true only for `.menuBarOnly`. Prefer `appPresentationMode`.
    public var menuBarOnly: Bool { appPresentationMode == .menuBarOnly }

    public init(
        automaticScanningEnabled: Bool = true,
        scanIntervalSeconds: Int = 60,
        archiveNamingTemplate: String = Self.defaultArchiveNamingTemplate,
        archiveRootPath: String? = nil,
        archiveRootBookmarkData: Data? = nil,
        hasCompletedOnboarding: Bool = false,
        verifyCopies: Bool = true,
        notifyAfterArchiving: Bool = true,
        launchAtLogin: Bool = false,
        lastCaptureDeviceID: String? = nil,
        captureMode: CaptureMode = .appAudio,
        lastCaptureTargetAppID: String? = nil,
        appAudioIdleSeconds: Int = 60,
        appAudioMinDurationSeconds: Int = 30,
        appAudioStartHoldSeconds: Int = 3,
        appAudioEnergyThreshold: Float = CaptureLevelScale.dispatchStartEnergyThreshold,
        cloudSyncEnabled: Bool = false,
        cloudArchiveBackupEnabled: Bool = false,
        autoArmOnDJAppFound: Bool = true,
        appPresentationMode: AppPresentationMode = .menuBarAndMainWindow,
        menuBarOnly: Bool? = nil,
        showFolderScanDetailsInMenuBar: Bool = false,
        dualRoutePosture: DualRoutePosture = .both,
        pinnedAnalogInputDeviceID: String? = nil
    ) {
        self.automaticScanningEnabled = automaticScanningEnabled
        self.scanIntervalSeconds = scanIntervalSeconds
        self.archiveNamingTemplate = archiveNamingTemplate
        self.archiveRootPath = archiveRootPath
        self.archiveRootBookmarkData = archiveRootBookmarkData
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.verifyCopies = verifyCopies
        self.notifyAfterArchiving = notifyAfterArchiving
        self.launchAtLogin = launchAtLogin
        self.lastCaptureDeviceID = lastCaptureDeviceID
        self.captureMode = captureMode
        self.lastCaptureTargetAppID = lastCaptureTargetAppID
        // Protection timing is a product safety contract, not a user preference. Keep the
        // legacy fields for backwards-compatible JSON while normalizing every construction.
        self.appAudioIdleSeconds = Int(CaptureLevelScale.dispatchIdleSeconds)
        self.appAudioMinDurationSeconds = Int(CaptureLevelScale.dispatchMinimumDurationSeconds)
        self.appAudioStartHoldSeconds = Int(CaptureLevelScale.dispatchStartHoldSeconds)
        self.appAudioEnergyThreshold = CaptureLevelScale.dispatchStartEnergyThreshold
        self.cloudSyncEnabled = cloudSyncEnabled
        self.cloudArchiveBackupEnabled = cloudArchiveBackupEnabled
        self.autoArmOnDJAppFound = autoArmOnDJAppFound
        if let menuBarOnly {
            self.appPresentationMode = menuBarOnly ? .menuBarOnly : appPresentationMode
        } else {
            self.appPresentationMode = appPresentationMode
        }
        self.showFolderScanDetailsInMenuBar = showFolderScanDetailsInMenuBar
        self.dualRoutePosture = dualRoutePosture
        self.pinnedAnalogInputDeviceID = pinnedAnalogInputDeviceID
    }

    public static let `default` = AppSettings()

    public var silenceSessionConfig: SilenceSessionConfig {
        SilenceSessionConfig(
            startEnergyThreshold: CaptureLevelScale.dispatchStartEnergyThreshold,
            idleEnergyThreshold: CaptureLevelScale.dispatchIdleEnergyThreshold,
            startHoldSeconds: CaptureLevelScale.dispatchStartHoldSeconds,
            idleSeconds: CaptureLevelScale.dispatchIdleSeconds,
            minDurationSeconds: CaptureLevelScale.dispatchMinimumDurationSeconds,
            prerollSeconds: CaptureLevelScale.dispatchPrerollSeconds,
            postRollSeconds: CaptureLevelScale.dispatchPostRollSeconds
        )
    }

    private enum CodingKeys: String, CodingKey {
        case automaticScanningEnabled, scanIntervalSeconds, archiveNamingTemplate
        case archiveRootPath, archiveRootBookmarkData, hasCompletedOnboarding
        case verifyCopies, notifyAfterArchiving, launchAtLogin
        case lastCaptureDeviceID, captureMode, lastCaptureTargetAppID
        case appAudioIdleSeconds, appAudioMinDurationSeconds, appAudioStartHoldSeconds, appAudioEnergyThreshold
        case cloudSyncEnabled, cloudArchiveBackupEnabled, autoArmOnDJAppFound
        case appPresentationMode, menuBarOnly, showFolderScanDetailsInMenuBar, dualRoutePosture
        case pinnedAnalogInputDeviceID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        automaticScanningEnabled = try c.decodeIfPresent(Bool.self, forKey: .automaticScanningEnabled) ?? true
        scanIntervalSeconds = try c.decodeIfPresent(Int.self, forKey: .scanIntervalSeconds) ?? 60
        archiveNamingTemplate = try c.decodeIfPresent(String.self, forKey: .archiveNamingTemplate) ?? Self.defaultArchiveNamingTemplate
        archiveRootPath = try c.decodeIfPresent(String.self, forKey: .archiveRootPath)
        archiveRootBookmarkData = try c.decodeIfPresent(Data.self, forKey: .archiveRootBookmarkData)
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        verifyCopies = try c.decodeIfPresent(Bool.self, forKey: .verifyCopies) ?? true
        notifyAfterArchiving = try c.decodeIfPresent(Bool.self, forKey: .notifyAfterArchiving) ?? true
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        lastCaptureDeviceID = try c.decodeIfPresent(String.self, forKey: .lastCaptureDeviceID)
        captureMode = try c.decodeIfPresent(CaptureMode.self, forKey: .captureMode) ?? .appAudio
        lastCaptureTargetAppID = try c.decodeIfPresent(String.self, forKey: .lastCaptureTargetAppID)
        // Read legacy keys for schema compatibility, but migrate their behavior to the locked
        // protection policy. Encoding writes these canonical values back on the next save.
        _ = try c.decodeIfPresent(Int.self, forKey: .appAudioIdleSeconds)
        _ = try c.decodeIfPresent(Int.self, forKey: .appAudioMinDurationSeconds)
        _ = try c.decodeIfPresent(Int.self, forKey: .appAudioStartHoldSeconds)
        _ = try c.decodeIfPresent(Float.self, forKey: .appAudioEnergyThreshold)
        appAudioIdleSeconds = Int(CaptureLevelScale.dispatchIdleSeconds)
        appAudioMinDurationSeconds = Int(CaptureLevelScale.dispatchMinimumDurationSeconds)
        appAudioStartHoldSeconds = Int(CaptureLevelScale.dispatchStartHoldSeconds)
        appAudioEnergyThreshold = CaptureLevelScale.dispatchStartEnergyThreshold
        cloudSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .cloudSyncEnabled) ?? false
        cloudArchiveBackupEnabled = try c.decodeIfPresent(Bool.self, forKey: .cloudArchiveBackupEnabled) ?? false
        autoArmOnDJAppFound = try c.decodeIfPresent(Bool.self, forKey: .autoArmOnDJAppFound) ?? true
        if let mode = try c.decodeIfPresent(AppPresentationMode.self, forKey: .appPresentationMode) {
            appPresentationMode = mode
        } else if let legacyMenuBarOnly = try c.decodeIfPresent(Bool.self, forKey: .menuBarOnly), legacyMenuBarOnly {
            appPresentationMode = .menuBarOnly
        } else {
            appPresentationMode = .menuBarAndMainWindow
        }
        showFolderScanDetailsInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showFolderScanDetailsInMenuBar) ?? false
        dualRoutePosture = try c.decodeIfPresent(DualRoutePosture.self, forKey: .dualRoutePosture) ?? .both
        pinnedAnalogInputDeviceID = try c.decodeIfPresent(String.self, forKey: .pinnedAnalogInputDeviceID)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(automaticScanningEnabled, forKey: .automaticScanningEnabled)
        try c.encode(scanIntervalSeconds, forKey: .scanIntervalSeconds)
        try c.encode(archiveNamingTemplate, forKey: .archiveNamingTemplate)
        try c.encodeIfPresent(archiveRootPath, forKey: .archiveRootPath)
        try c.encodeIfPresent(archiveRootBookmarkData, forKey: .archiveRootBookmarkData)
        try c.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try c.encode(verifyCopies, forKey: .verifyCopies)
        try c.encode(notifyAfterArchiving, forKey: .notifyAfterArchiving)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encodeIfPresent(lastCaptureDeviceID, forKey: .lastCaptureDeviceID)
        try c.encode(captureMode, forKey: .captureMode)
        try c.encodeIfPresent(lastCaptureTargetAppID, forKey: .lastCaptureTargetAppID)
        try c.encode(appAudioIdleSeconds, forKey: .appAudioIdleSeconds)
        try c.encode(appAudioMinDurationSeconds, forKey: .appAudioMinDurationSeconds)
        try c.encode(appAudioStartHoldSeconds, forKey: .appAudioStartHoldSeconds)
        try c.encode(appAudioEnergyThreshold, forKey: .appAudioEnergyThreshold)
        try c.encode(cloudSyncEnabled, forKey: .cloudSyncEnabled)
        try c.encode(cloudArchiveBackupEnabled, forKey: .cloudArchiveBackupEnabled)
        try c.encode(autoArmOnDJAppFound, forKey: .autoArmOnDJAppFound)
        try c.encode(appPresentationMode, forKey: .appPresentationMode)
        // Keep legacy key in sync for older builds / tooling.
        try c.encode(menuBarOnly, forKey: .menuBarOnly)
        try c.encode(showFolderScanDetailsInMenuBar, forKey: .showFolderScanDetailsInMenuBar)
        try c.encode(dualRoutePosture, forKey: .dualRoutePosture)
        try c.encodeIfPresent(pinnedAnalogInputDeviceID, forKey: .pinnedAnalogInputDeviceID)
    }

    public func updating(
        automaticScanningEnabled: Bool? = nil,
        scanIntervalSeconds: Int? = nil,
        archiveNamingTemplate: String? = nil,
        archiveRootPath: String?? = nil,
        archiveRootBookmarkData: Data?? = nil,
        hasCompletedOnboarding: Bool? = nil,
        verifyCopies: Bool? = nil,
        notifyAfterArchiving: Bool? = nil,
        launchAtLogin: Bool? = nil,
        lastCaptureDeviceID: String?? = nil,
        captureMode: CaptureMode? = nil,
        lastCaptureTargetAppID: String?? = nil,
        appAudioIdleSeconds: Int? = nil,
        appAudioMinDurationSeconds: Int? = nil,
        appAudioStartHoldSeconds: Int? = nil,
        appAudioEnergyThreshold: Float? = nil,
        cloudSyncEnabled: Bool? = nil,
        cloudArchiveBackupEnabled: Bool? = nil,
        autoArmOnDJAppFound: Bool? = nil,
        appPresentationMode: AppPresentationMode? = nil,
        menuBarOnly: Bool? = nil,
        showFolderScanDetailsInMenuBar: Bool? = nil,
        dualRoutePosture: DualRoutePosture? = nil,
        pinnedAnalogInputDeviceID: String?? = nil
    ) -> AppSettings {
        let resolvedMode: AppPresentationMode
        if let appPresentationMode {
            resolvedMode = appPresentationMode
        } else if let menuBarOnly {
            resolvedMode = menuBarOnly ? .menuBarOnly : .menuBarAndMainWindow
        } else {
            resolvedMode = self.appPresentationMode
        }
        return AppSettings(
            automaticScanningEnabled: automaticScanningEnabled ?? self.automaticScanningEnabled,
            scanIntervalSeconds: scanIntervalSeconds ?? self.scanIntervalSeconds,
            archiveNamingTemplate: archiveNamingTemplate ?? self.archiveNamingTemplate,
            archiveRootPath: archiveRootPath ?? self.archiveRootPath,
            archiveRootBookmarkData: archiveRootBookmarkData ?? self.archiveRootBookmarkData,
            hasCompletedOnboarding: hasCompletedOnboarding ?? self.hasCompletedOnboarding,
            verifyCopies: verifyCopies ?? self.verifyCopies,
            notifyAfterArchiving: notifyAfterArchiving ?? self.notifyAfterArchiving,
            launchAtLogin: launchAtLogin ?? self.launchAtLogin,
            lastCaptureDeviceID: lastCaptureDeviceID ?? self.lastCaptureDeviceID,
            captureMode: captureMode ?? self.captureMode,
            lastCaptureTargetAppID: lastCaptureTargetAppID ?? self.lastCaptureTargetAppID,
            appAudioIdleSeconds: appAudioIdleSeconds ?? self.appAudioIdleSeconds,
            appAudioMinDurationSeconds: appAudioMinDurationSeconds ?? self.appAudioMinDurationSeconds,
            appAudioStartHoldSeconds: appAudioStartHoldSeconds ?? self.appAudioStartHoldSeconds,
            appAudioEnergyThreshold: appAudioEnergyThreshold ?? self.appAudioEnergyThreshold,
            cloudSyncEnabled: cloudSyncEnabled ?? self.cloudSyncEnabled,
            cloudArchiveBackupEnabled: cloudArchiveBackupEnabled ?? self.cloudArchiveBackupEnabled,
            autoArmOnDJAppFound: autoArmOnDJAppFound ?? self.autoArmOnDJAppFound,
            appPresentationMode: resolvedMode,
            showFolderScanDetailsInMenuBar: showFolderScanDetailsInMenuBar ?? self.showFolderScanDetailsInMenuBar,
            dualRoutePosture: dualRoutePosture ?? self.dualRoutePosture,
            pinnedAnalogInputDeviceID: pinnedAnalogInputDeviceID ?? self.pinnedAnalogInputDeviceID
        )
    }
}

public struct AppSettingsStore {
    public let storageURL: URL
    private let fileManager: FileManager

    public init(storageURL: URL = Self.defaultStorageURL(), fileManager: FileManager = .default) {
        self.storageURL = storageURL
        self.fileManager = fileManager
    }

    public static func defaultStorageURL() -> URL {
        DefaultPathProvider().applicationSupportDirectory()
            .appendingPathComponent("settings.json")
    }

    public func load() throws -> AppSettings {
        guard fileManager.fileExists(atPath: storageURL.path) else { return .default }
        return try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: storageURL))
    }

    public func save(_ settings: AppSettings) throws {
        try fileManager.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: storageURL, options: [.atomic])
    }
}
