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
    public let appAudioEnergyThreshold: Float
    public let cloudSyncEnabled: Bool
    public let cloudArchiveBackupEnabled: Bool
    public let autoArmOnDJAppFound: Bool
    public let menuBarOnly: Bool
    public let showFolderScanDetailsInMenuBar: Bool
    public let dualRoutePosture: DualRoutePosture
    /// Pinned Core Audio UID for Analog Mixer rec-out. Nil until the DJ Choose-rec-out once.
    public let pinnedAnalogInputDeviceID: String?

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
        appAudioIdleSeconds: Int = 90,
        appAudioMinDurationSeconds: Int = 30,
        appAudioEnergyThreshold: Float = 0.02,
        cloudSyncEnabled: Bool = false,
        cloudArchiveBackupEnabled: Bool = false,
        autoArmOnDJAppFound: Bool = true,
        menuBarOnly: Bool = false,
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
        self.appAudioIdleSeconds = appAudioIdleSeconds
        self.appAudioMinDurationSeconds = appAudioMinDurationSeconds
        self.appAudioEnergyThreshold = appAudioEnergyThreshold
        self.cloudSyncEnabled = cloudSyncEnabled
        self.cloudArchiveBackupEnabled = cloudArchiveBackupEnabled
        self.autoArmOnDJAppFound = autoArmOnDJAppFound
        self.menuBarOnly = menuBarOnly
        self.showFolderScanDetailsInMenuBar = showFolderScanDetailsInMenuBar
        self.dualRoutePosture = dualRoutePosture
        self.pinnedAnalogInputDeviceID = pinnedAnalogInputDeviceID
    }

    public static let `default` = AppSettings()

    public var silenceSessionConfig: SilenceSessionConfig {
        SilenceSessionConfig(
            energyThreshold: appAudioEnergyThreshold,
            startHoldSeconds: 0.5,
            idleSeconds: TimeInterval(appAudioIdleSeconds),
            minDurationSeconds: TimeInterval(appAudioMinDurationSeconds)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case automaticScanningEnabled, scanIntervalSeconds, archiveNamingTemplate
        case archiveRootPath, archiveRootBookmarkData, hasCompletedOnboarding
        case verifyCopies, notifyAfterArchiving, launchAtLogin
        case lastCaptureDeviceID, captureMode, lastCaptureTargetAppID
        case appAudioIdleSeconds, appAudioMinDurationSeconds, appAudioEnergyThreshold
        case cloudSyncEnabled, cloudArchiveBackupEnabled, autoArmOnDJAppFound
        case menuBarOnly, showFolderScanDetailsInMenuBar, dualRoutePosture
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
        appAudioIdleSeconds = try c.decodeIfPresent(Int.self, forKey: .appAudioIdleSeconds) ?? 90
        appAudioMinDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .appAudioMinDurationSeconds) ?? 30
        appAudioEnergyThreshold = try c.decodeIfPresent(Float.self, forKey: .appAudioEnergyThreshold) ?? 0.02
        cloudSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .cloudSyncEnabled) ?? false
        cloudArchiveBackupEnabled = try c.decodeIfPresent(Bool.self, forKey: .cloudArchiveBackupEnabled) ?? false
        autoArmOnDJAppFound = try c.decodeIfPresent(Bool.self, forKey: .autoArmOnDJAppFound) ?? true
        menuBarOnly = try c.decodeIfPresent(Bool.self, forKey: .menuBarOnly) ?? false
        showFolderScanDetailsInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showFolderScanDetailsInMenuBar) ?? false
        dualRoutePosture = try c.decodeIfPresent(DualRoutePosture.self, forKey: .dualRoutePosture) ?? .both
        pinnedAnalogInputDeviceID = try c.decodeIfPresent(String.self, forKey: .pinnedAnalogInputDeviceID)
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
        appAudioEnergyThreshold: Float? = nil,
        cloudSyncEnabled: Bool? = nil,
        cloudArchiveBackupEnabled: Bool? = nil,
        autoArmOnDJAppFound: Bool? = nil,
        menuBarOnly: Bool? = nil,
        showFolderScanDetailsInMenuBar: Bool? = nil,
        dualRoutePosture: DualRoutePosture? = nil,
        pinnedAnalogInputDeviceID: String?? = nil
    ) -> AppSettings {
        AppSettings(
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
            appAudioEnergyThreshold: appAudioEnergyThreshold ?? self.appAudioEnergyThreshold,
            cloudSyncEnabled: cloudSyncEnabled ?? self.cloudSyncEnabled,
            cloudArchiveBackupEnabled: cloudArchiveBackupEnabled ?? self.cloudArchiveBackupEnabled,
            autoArmOnDJAppFound: autoArmOnDJAppFound ?? self.autoArmOnDJAppFound,
            menuBarOnly: menuBarOnly ?? self.menuBarOnly,
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
