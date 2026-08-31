import XCTest
@testable import SetCatcherCore

final class AnalogMixerPolicyTests: XCTestCase {
    func testConfiguredRequiresPinOrDumpFolder() {
        XCTAssertFalse(AnalogMixerPolicy.isConfigured(pinnedDeviceID: nil, hasDumpFolder: false))
        XCTAssertFalse(AnalogMixerPolicy.isConfigured(pinnedDeviceID: "", hasDumpFolder: false))
        XCTAssertTrue(AnalogMixerPolicy.isConfigured(pinnedDeviceID: "uid-1", hasDumpFolder: false))
        XCTAssertTrue(AnalogMixerPolicy.isConfigured(pinnedDeviceID: nil, hasDumpFolder: true))
    }

    func testUnattendedWatchOnlyOnMatchingPin() {
        XCTAssertFalse(AnalogMixerPolicy.shouldUnattendedWatch(
            pinnedDeviceID: nil,
            selectedDeviceID: "a",
            userDisarmedInput: false
        ))
        XCTAssertFalse(AnalogMixerPolicy.shouldUnattendedWatch(
            pinnedDeviceID: "a",
            selectedDeviceID: "b",
            userDisarmedInput: false
        ))
        XCTAssertFalse(AnalogMixerPolicy.shouldUnattendedWatch(
            pinnedDeviceID: "a",
            selectedDeviceID: "a",
            userDisarmedInput: true
        ))
        XCTAssertTrue(AnalogMixerPolicy.shouldUnattendedWatch(
            pinnedDeviceID: "a",
            selectedDeviceID: "a",
            userDisarmedInput: false
        ))
    }

    func testMissingDeviceCopyNamesSafety() {
        let message = AnalogMixerPolicy.missingPinnedDeviceMessage(deviceName: "Focusrite")
        XCTAssertTrue(message.contains("Focusrite"))
        XCTAssertTrue(message.contains("Everything already in your archive is safe."))
    }
}
