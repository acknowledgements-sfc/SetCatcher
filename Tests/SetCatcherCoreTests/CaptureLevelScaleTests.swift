import XCTest
@testable import SetCatcherCore

final class CaptureLevelScaleTests: XCTestCase {
    func testDispatchThresholdsMatchSpecDbFS() {
        XCTAssertEqual(
            CaptureLevelScale.dbFS(forInputLevel: CaptureLevelScale.dispatchStartEnergyThreshold),
            CaptureLevelScale.dispatchStartDbFS,
            accuracy: 0.05
        )
        XCTAssertEqual(
            CaptureLevelScale.dbFS(forInputLevel: CaptureLevelScale.dispatchIdleEnergyThreshold),
            CaptureLevelScale.dispatchIdleDbFS,
            accuracy: 0.05
        )
    }

    func testRoundTripInputLevelAndDbFS() {
        let level = CaptureLevelScale.inputLevel(forDbFS: -20)
        XCTAssertEqual(CaptureLevelScale.dbFS(forInputLevel: level), -20, accuracy: 0.01)
    }

    func testMeterFractionMapsFloorAndMidScale() {
        XCTAssertEqual(CaptureLevelScale.meterFraction(forInputLevel: 0), 0, accuracy: 0.01)
        // UI level 1.0 is RMS 0.25 ≈ −12 dBFS (inputLevelScale clips at 1).
        let fullUI = CaptureLevelScale.meterFraction(forInputLevel: 1)
        XCTAssertEqual(fullUI, (-12 - CaptureLevelScale.meterFloorDbFS) / -CaptureLevelScale.meterFloorDbFS, accuracy: 0.02)
        let mid = CaptureLevelScale.inputLevel(forDbFS: -30)
        XCTAssertEqual(CaptureLevelScale.meterFraction(forInputLevel: mid), 0.5, accuracy: 0.02)
    }
}
