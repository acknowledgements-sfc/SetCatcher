import XCTest
@testable import SetCatcherCore

final class HardwareProfileTests: XCTestCase {
    func testCatalogIncludesRequestedPioneerModels() {
        let ids = Set(SupportedHardware.all.map(\.id))
        for id in ["xdj-rx2","xdj-rx3","xdj-xz","xdj-az","cdj-2000","cdj-2000nxs","cdj-3000","djm-900","djm-v10","djm-v10lf"] {
            XCTAssertTrue(ids.contains(id))
        }
    }

    func testCatalogIncludesDenonRaneAndAnalogProfiles() {
        let ids = Set(SupportedHardware.all.map(\.id))
        for id in ["prime-4", "prime-4-plus", "sc-live-4", "sc6000", "seventy", "seventy-two", "analog-rec-out"] {
            XCTAssertTrue(ids.contains(id), id)
        }
        XCTAssertEqual(SupportedHardware.profile(id: "prime-4")?.vendor, .denon)
        XCTAssertEqual(SupportedHardware.profile(id: "seventy")?.vendor, .rane)
        XCTAssertEqual(SupportedHardware.profile(id: "analog-rec-out")?.vendor, .genericMixer)
        XCTAssertEqual(SupportedHardware.profile(id: "prime-4")?.usbRecFolderHint, "Sessions")
    }

    func testSoftwareCatalogIncludesCaptureAndPioneerHardware() {
        let ids = Set(SupportedDJSoftware.all.map(\.id))
        XCTAssertTrue(ids.contains(SupportedDJSoftware.captureAppID))
        XCTAssertTrue(ids.contains(SupportedDJSoftware.pioneerHardwareAppID))
        XCTAssertTrue(ids.contains(SupportedDJSoftware.analogMixerAppID))
        XCTAssertTrue(ids.contains(SupportedDJSoftware.denonHardwareAppID))
        XCTAssertTrue(ids.contains(SupportedDJSoftware.raneHardwareAppID))
    }

    func testPioneerRECFilenameIsAudio() {
        XCTAssertTrue(FileStabilityChecker().isAudioFile(URL(fileURLWithPath: "/tmp/PIONEERREC/REC001.WAV")))
    }

    func testXDJXZHintDescribesLaptopUSBDualRoute() {
        let hint = SupportedHardware.profile(id: "xdj-xz")?.captureHint ?? ""
        XCTAssertTrue(hint.contains("Folder Protection"))
        XCTAssertTrue(hint.contains("Input Capture"))
        XCTAssertTrue(hint.contains("PIONEERREC"))
    }

    func testXDJXZAdapterListCaptionIsLaptopUSBNotMasterRec() {
        XCTAssertEqual(
            SupportedHardware.profile(id: "xdj-xz")?.adapterListCaption,
            "laptop + USB / Input Capture"
        )
        XCTAssertFalse((SupportedHardware.profile(id: "xdj-xz")?.adapterListCaption ?? "").contains("USB MASTER REC"))
        XCTAssertEqual(SupportedHardware.profile(id: "xdj-rx2")?.adapterListCaption, "USB MASTER REC")
        XCTAssertEqual(SupportedHardware.profile(id: "xdj-rx3")?.adapterListCaption, "USB MASTER REC")
        XCTAssertEqual(SupportedHardware.profile(id: "xdj-az")?.adapterListCaption, "USB MASTER REC")
        XCTAssertEqual(SupportedHardware.profile(id: "cdj-3000")?.adapterListCaption, "needs mixer for master")
        XCTAssertEqual(SupportedHardware.profile(id: "djm-v10")?.adapterListCaption, "USB Capture")
    }

    func testPlayersCannotProvideUSBMasterFeed() {
        XCTAssertEqual(SupportedHardware.profile(id: "cdj-3000")?.canProvideUSBMasterFeed, false)
        XCTAssertEqual(SupportedHardware.profile(id: "djm-v10")?.canProvideUSBMasterFeed, true)
        XCTAssertEqual(SupportedHardware.profile(id: "xdj-xz")?.canProvideUSBMasterFeed, true)
    }

    func testProfileMatchingUsesDeviceName() {
        let xz = AudioInputDevice(id: "xz", name: "XDJ-XZ", manufacturer: "AlphaTheta Corporation", transportType: .usb)
        XCTAssertEqual(SupportedHardware.profile(matching: xz)?.id, "xdj-xz")
        let unknown = AudioInputDevice(id: "mic", name: "MacBook Pro Microphone", manufacturer: "Apple Inc.", transportType: .builtIn)
        XCTAssertNil(SupportedHardware.profile(matching: unknown))
        let prime = AudioInputDevice(id: "p4", name: "PRIME 4", manufacturer: "Denon DJ", transportType: .usb)
        XCTAssertEqual(SupportedHardware.profile(matching: prime)?.id, "prime-4")
        let focusrite = AudioInputDevice(id: "scarlett", name: "Scarlett 2i2", manufacturer: "Focusrite", transportType: .usb)
        XCTAssertFalse(SupportedHardware.isTrustedHardwareFeed(focusrite))
        XCTAssertTrue(SupportedHardware.isTrustedHardwareFeed(xz))
        XCTAssertFalse(SupportedHardware.isTrustedHardwareFeed(
            AudioInputDevice(id: "a", name: "Analog Mixer Rec Out", manufacturer: "Generic", transportType: .usb)
        ))
    }

    func testHardwareRecOutMatrixLeavesDenonRaneUnmapped() {
        XCTAssertNil(HardwareRecOutChannelMatrix.hypothesizedPair(forDeviceName: "PRIME 4"))
        XCTAssertNil(HardwareRecOutChannelMatrix.hypothesizedPair(forDeviceName: "Rane Seventy"))
        XCTAssertEqual(
            HardwareRecOutChannelMatrix.hypothesizedPair(forDeviceName: "XDJ-XZ"),
            HardwareStereoChannelPair(leftIndex: 4, rightIndex: 5)
        )
    }
}
