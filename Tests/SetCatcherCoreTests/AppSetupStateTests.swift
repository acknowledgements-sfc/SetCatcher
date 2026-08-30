import XCTest
@testable import SetCatcherCore

final class AppSetupStateTests: XCTestCase {
    func testDeriveNeedsFolderAccessWhenNothingConfigured() {
        let state = AppSetupState.derive(
            scanResults: [],
            hasConfiguredRecordingsFolder: false,
            configuredFoldersReachable: false,
            appNotInstalledOrRunning: false,
            isScanning: false,
            hasRecentUnstableRecording: false
        )

        XCTAssertEqual(state, .needsFolderAccess)
    }

    func testDeriveAppNotFoundOnlyWhenInstallableAppMissing() {
        let state = AppSetupState.derive(
            scanResults: [],
            hasConfiguredRecordingsFolder: false,
            configuredFoldersReachable: false,
            appNotInstalledOrRunning: true,
            isScanning: false,
            hasRecentUnstableRecording: false
        )

        XCTAssertEqual(state, .appNotFound)
    }

    func testDeriveAttentionNeededWhenConfiguredUnreachable() {
        let state = AppSetupState.derive(
            scanResults: [],
            hasConfiguredRecordingsFolder: true,
            configuredFoldersReachable: false,
            appNotInstalledOrRunning: false,
            isScanning: false,
            hasRecentUnstableRecording: false
        )

        XCTAssertEqual(state, .attentionNeeded)
    }

    func testDeriveErrorForConfiguredFolderScanFailure() {
        let result = FolderScanResult(
            appID: "serato",
            folderURL: URL(fileURLWithPath: "/tmp/granted"),
            archivedSessions: [],
            errorDescription: "SetCatcher cannot read this folder. Choose it again to refresh permission."
        )

        let state = AppSetupState.derive(
            scanResults: [result],
            hasConfiguredRecordingsFolder: true,
            configuredFoldersReachable: true,
            appNotInstalledOrRunning: false,
            isScanning: false,
            hasRecentUnstableRecording: false
        )

        XCTAssertEqual(state, .error)
    }

    func testDeriveWatchingWhenConfiguredAndReachable() {
        let state = AppSetupState.derive(
            scanResults: [
                FolderScanResult(
                    appID: "serato",
                    folderURL: URL(fileURLWithPath: "/tmp/granted"),
                    archivedSessions: [],
                    errorDescription: nil
                )
            ],
            hasConfiguredRecordingsFolder: true,
            configuredFoldersReachable: true,
            appNotInstalledOrRunning: false,
            isScanning: false,
            hasRecentUnstableRecording: false
        )

        XCTAssertEqual(state, .watching)
    }
}
