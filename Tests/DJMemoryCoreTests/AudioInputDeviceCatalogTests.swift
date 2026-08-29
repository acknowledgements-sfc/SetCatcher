import XCTest
@testable import DJMemoryCore

final class AudioInputDeviceCatalogTests: XCTestCase {
    func testPioneerHeuristicMatchesKnownHardware() {
        let fixtures: [(String, String, Bool)] = [
            ("XDJ-XZ", "Pioneer DJ", true),
            ("DJM-V10", "Pioneer", true),
            ("CDJ-3000", "Pioneer DJ", true),
            ("XDJ-RX3", "", true),
            ("MacBook Pro Microphone", "Apple Inc.", false),
            ("USB Audio Device", "Generic", false),
            ("Scarlett 2i2", "Focusrite", false)
        ]
        for (name, manufacturer, expected) in fixtures {
            let device = AudioInputDevice(id: name, name: name, manufacturer: manufacturer)
            XCTAssertEqual(device.isLikelyPioneerDJHardware, expected, "\(name) \(manufacturer)")
        }
    }

    func testListInputsReturnsUniqueIDs() {
        let devices = AudioInputDeviceCatalog.listInputs()
        XCTAssertEqual(Set(devices.map(\.id)).count, devices.count)
    }

    func testPreferredDefaultPicksPioneerFirst() {
        let mic = AudioInputDevice(id: "mic", name: "MacBook Pro Microphone", manufacturer: "Apple Inc.", transportType: .builtIn)
        let xz = AudioInputDevice(id: "xz", name: "XDJ-XZ", manufacturer: "Pioneer DJ", transportType: .usb)
        XCTAssertEqual(AudioInputDeviceCatalog.preferredDefault(from: [mic, xz])?.id, "xz")
    }

    // MARK: Safety invariant — never auto-select or record from an ambient/system mic

    func testPreferredDefaultNeverReturnsBuiltInMicAlone() {
        let mic = AudioInputDevice(id: "mic", name: "MacBook Pro Microphone", manufacturer: "Apple Inc.", transportType: .builtIn)
        XCTAssertNil(AudioInputDeviceCatalog.preferredDefault(from: [mic]))
    }

    func testPreferredDefaultNeverReturnsUnknownUSBMicAlone() {
        let mic = AudioInputDevice(id: "mic", name: "MacBook Pro Microphone", manufacturer: "Apple Inc.", transportType: .builtIn)
        let unknownUSB = AudioInputDevice(id: "usb", name: "USB Audio Device", manufacturer: "Generic", transportType: .usb)
        XCTAssertNil(AudioInputDeviceCatalog.preferredDefault(from: [mic, unknownUSB]))
    }

    func testBuiltInMicIsBlocked() {
        let mic = AudioInputDevice(id: "mic", name: "MacBook Pro Microphone", manufacturer: "Apple Inc.", transportType: .builtIn)
        XCTAssertTrue(mic.isBlockedInput)
        if case .blocked = mic.safety {} else { XCTFail("built-in mic should be blocked") }
    }

    func testBluetoothMicIsBlocked() {
        let airpods = AudioInputDevice(id: "bt", name: "AirPods Pro", manufacturer: "Apple Inc.", transportType: .bluetooth)
        XCTAssertTrue(airpods.isBlockedInput)
    }

    func testContinuityMicIsBlocked() {
        let iphone = AudioInputDevice(id: "cc", name: "iPhone Microphone", manufacturer: "Apple Inc.", transportType: .continuityCapture)
        XCTAssertTrue(iphone.isBlockedInput)
    }

    func testPioneerHardwareIsTrustedRegardlessOfTransport() {
        let xz = AudioInputDevice(id: "xz", name: "XDJ-XZ", manufacturer: "Pioneer DJ", transportType: .usb)
        XCTAssertTrue(xz.isTrustedAutoSelectable)
    }

    func testUnknownUSBInterfaceIsManualOnly() {
        let scarlett = AudioInputDevice(id: "s", name: "Scarlett 2i2", manufacturer: "Focusrite", transportType: .usb)
        XCTAssertFalse(scarlett.isTrustedAutoSelectable)
        XCTAssertFalse(scarlett.isBlockedInput)
        if case .manualOnly = scarlett.safety {} else { XCTFail("unknown USB interface should be manualOnly") }
    }

    func testUnreadableTransportIsManualOnlyNotTrusted() {
        // transportType query failure maps to .unknown → never auto-selectable, never blocked.
        let mystery = AudioInputDevice(id: "m", name: "Some Interface", manufacturer: "Vendor", transportType: .unknown)
        XCTAssertFalse(mystery.isTrustedAutoSelectable)
        XCTAssertFalse(mystery.isBlockedInput)
    }

    func testSelectableInputsExcludesBlockedMics() {
        let mic = AudioInputDevice(id: "mic", name: "MacBook Pro Microphone", manufacturer: "Apple Inc.", transportType: .builtIn)
        let xz = AudioInputDevice(id: "xz", name: "XDJ-XZ", manufacturer: "Pioneer DJ", transportType: .usb)
        let scarlett = AudioInputDevice(id: "s", name: "Scarlett 2i2", manufacturer: "Focusrite", transportType: .usb)
        let selectable = AudioInputDeviceCatalog.selectableInputs(from: [mic, xz, scarlett])
        XCTAssertEqual(Set(selectable.map(\.id)), ["xz", "s"])
    }

    func testUnknownUIDDoesNotResolveToAudioDeviceID() {
        XCTAssertNil(AudioInputDeviceCatalog.audioDeviceID(forUID: ""))
        XCTAssertNil(AudioInputDeviceCatalog.audioDeviceID(forUID: "djmemory-missing-uid-\(UUID().uuidString)"))
        XCTAssertEqual(AudioInputDeviceCatalog.inputChannelCount(forUID: ""), 0)
        XCTAssertFalse(AudioInputDeviceCatalog.isSupportedCaptureFormat(forUID: "djmemory-missing-uid-\(UUID().uuidString)"))
    }

    func testListedInputUIDsResolveToAudioDeviceIDs() {
        for device in AudioInputDeviceCatalog.listInputs() {
            XCTAssertNotNil(AudioInputDeviceCatalog.audioDeviceID(forUID: device.id), device.id)
        }
    }

    func testListedInputDevicesExposeInputStreamFormats() throws {
        let devices = AudioInputDeviceCatalog.listInputs()
        guard !devices.isEmpty else {
            throw XCTSkip("No Core Audio input devices are available on this host.")
        }
        for device in devices {
            let deviceID = try XCTUnwrap(
                AudioInputDeviceCatalog.audioDeviceID(forUID: device.id),
                device.id
            )
            let format = try AudioInputDeviceCatalog.inputStreamFormat(for: deviceID)
            XCTAssertGreaterThan(format.mSampleRate, 0, device.name)
            XCTAssertGreaterThan(format.mChannelsPerFrame, 0, device.name)
        }
    }

    // MARK: PR2 — Serato Virtual Audio matching and trust

    func testSeratoVirtualDeviceIsTrustedWhenSeratoIsRunning() {
        let sva = Self.seratoVirtualAudio
        XCTAssertTrue(AudioInputDeviceCatalog.matchesDJSoftwareVirtualAudioDevice(sva, for: Self.serato))
        let safety = AudioInputDeviceCatalog.safety(for: sva, currentSoftwareIDs: ["serato"])
        if case .trustedAutoSelectable = safety {} else {
            XCTFail("Serato Virtual Audio should be trusted when Serato is running, got \(safety)")
        }
        XCTAssertEqual(
            AudioInputDeviceCatalog.preferredDefault(from: [sva], currentSoftwareIDs: ["serato"])?.id,
            sva.id
        )
    }

    func testSeratoVirtualDeviceIsNotAutoSelectedWhenNoAppDetected() {
        let sva = Self.seratoVirtualAudio
        XCTAssertFalse(sva.isTrustedAutoSelectable)
        XCTAssertNil(AudioInputDeviceCatalog.preferredDefault(from: [sva], currentSoftwareIDs: []))
        if case .manualOnly = AudioInputDeviceCatalog.safety(for: sva, currentSoftwareIDs: []) {} else {
            XCTFail("installed virtual device with no running DJ app must not auto-select")
        }
    }

    func testSeratoBrandedNonVirtualDeviceIsNotAVirtualBackend() {
        let sl3 = AudioInputDevice(
            id: "sl3",
            name: "Serato SL3",
            manufacturer: "Serato",
            transportType: .usb
        )
        XCTAssertFalse(AudioInputDeviceCatalog.matchesDJSoftwareVirtualAudioDevice(sl3, for: Self.serato))

        let namedButUSB = AudioInputDevice(
            id: "sva-usb",
            name: "Serato Virtual Audio",
            manufacturer: "Serato",
            transportType: .usb
        )
        XCTAssertFalse(AudioInputDeviceCatalog.matchesDJSoftwareVirtualAudioDevice(namedButUSB, for: Self.serato))

        let manufacturerOnly = AudioInputDevice(
            id: "sva-mfr",
            name: "Loopback",
            manufacturer: "Serato",
            transportType: .virtual
        )
        XCTAssertFalse(
            AudioInputDeviceCatalog.matchesDJSoftwareVirtualAudioDevice(manufacturerOnly, for: Self.serato),
            "\"Serato\" alone must not match the virtual backend hint"
        )
    }

    func testPioneerWinsPreferredDefaultOverSeratoVirtual() {
        let sva = Self.seratoVirtualAudio
        let xz = AudioInputDevice(id: "xz", name: "XDJ-XZ", manufacturer: "Pioneer DJ", transportType: .usb)
        XCTAssertEqual(
            AudioInputDeviceCatalog.preferredDefault(from: [sva, xz], currentSoftwareIDs: ["serato"])?.id,
            "xz"
        )
    }

    private static let seratoVirtualAudio = AudioInputDevice(
        id: "sva",
        name: "Serato Virtual Audio",
        manufacturer: "Serato",
        transportType: .virtual
    )

    private static var serato: DJSoftware {
        SupportedDJSoftware.all.first { $0.id == "serato" }!
    }
}

final class DualRoutePolicyTests: XCTestCase {
    func testBothPostureAutoSwitchesAndWatchesWhenPioneerPresent() {
        XCTAssertTrue(DualRoutePolicy.shouldAutoSwitchToInput(posture: .both, pioneerPresent: true, userSuppressedAutoSwitch: false))
        XCTAssertTrue(DualRoutePolicy.shouldUnattendedWatch(posture: .both, pioneerPresent: true, userDisarmedInput: false))
        XCTAssertFalse(DualRoutePolicy.shouldUnattendedWatch(posture: .both, pioneerPresent: true, userDisarmedInput: true))
        XCTAssertFalse(DualRoutePolicy.shouldAutoSwitchToInput(posture: .both, pioneerPresent: true, userSuppressedAutoSwitch: true))
    }

    func testFolderOnlyNeverAutoSwitches() {
        XCTAssertFalse(DualRoutePolicy.shouldAutoSwitchToInput(posture: .folderOnly, pioneerPresent: true, userSuppressedAutoSwitch: false))
        XCTAssertFalse(DualRoutePolicy.shouldUnattendedWatch(posture: .folderOnly, pioneerPresent: true, userDisarmedInput: false))
        XCTAssertFalse(DualRoutePolicy.shouldAutoSelectPioneer(posture: .folderOnly))
    }

    func testOnDemandSelectsButDoesNotUnattendedWatch() {
        XCTAssertFalse(DualRoutePolicy.shouldAutoSwitchToInput(posture: .folderPrimaryInputOnDemand, pioneerPresent: true, userSuppressedAutoSwitch: false))
        XCTAssertFalse(DualRoutePolicy.shouldUnattendedWatch(posture: .folderPrimaryInputOnDemand, pioneerPresent: true, userDisarmedInput: false))
        XCTAssertTrue(DualRoutePolicy.shouldAutoSelectPioneer(posture: .folderPrimaryInputOnDemand))
    }

    func testFallbackToAppAudioWhenPioneerLeaves() {
        XCTAssertTrue(DualRoutePolicy.shouldFallBackToAppAudio(posture: .both, pioneerPresent: false, userSuppressedAutoSwitch: false))
        XCTAssertFalse(DualRoutePolicy.shouldFallBackToAppAudio(posture: .both, pioneerPresent: true, userSuppressedAutoSwitch: false))
        XCTAssertFalse(DualRoutePolicy.shouldFallBackToAppAudio(posture: .both, pioneerPresent: false, userSuppressedAutoSwitch: true))
        XCTAssertFalse(DualRoutePolicy.shouldFallBackToAppAudio(posture: .folderOnly, pioneerPresent: false, userSuppressedAutoSwitch: false))
    }
}
