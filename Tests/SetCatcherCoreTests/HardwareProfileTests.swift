import XCTest
@testable import SetCatcherCore

final class HardwareProfileTests: XCTestCase {
    func testCatalogIncludesRequestedPioneerModels() {
        let ids = Set(SupportedHardware.all.map(\.id))
        for id in ["xdj-rx2","xdj-rx3","xdj-xz","xdj-az","cdj-2000","cdj-2000nxs","cdj-3000","djm-900","djm-v10","djm-v10lf"] {
            XCTAssertTrue(ids.contains(id))
        }
    }

    func testSoftwareCatalogIncludesCaptureAndPioneerHardware() {
        let ids = Set(SupportedDJSoftware.all.map(\.id))
        XCTAssertTrue(ids.contains(SupportedDJSoftware.captureAppID))
        XCTAssertTrue(ids.contains(SupportedDJSoftware.pioneerHardwareAppID))
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
    }
}
