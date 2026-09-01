import SwiftUI
import SetCatcherCore

struct CaptureView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let pending = model.captureState.pendingAlternateSource {
                alternateSourceBanner(pending)
            }
            captureConfig
        }
        .onAppear {
            if model.captureState.mode == .appAudio {
                Task { await model.refreshAppAudioTargets(attemptAutoArm: true) }
            } else {
                model.refreshAudioInputs()
            }
        }
    }

    /// DJs don't run multiple DJ apps/hardware sources at once, so SetCatcher never silently
    /// switches an already-armed/watching/recording session — it surfaces the alternate here
    /// (and via a local notification) and waits for an explicit choice.
    private func alternateSourceBanner(_ pending: PendingAlternateSource) -> some View {
        Panel(tone: .warn, padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(DJToken.warn)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pending.displayName) is also \(pending.kind.isInputDevice ? "connected" : "running")")
                        .font(.system(size: DJToken.TypeSize.body, weight: .semibold))
                    Text("Still watching the current source. Switch if you meant to use \(pending.displayName) instead.")
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)
                }
                Spacer()
                Button("Keep Current") { model.dismissPendingAlternateSource() }
                    .buttonStyle(DJGhostButtonStyle())
                    .accessibilityIdentifier("capture.alternateSource.dismiss")
                Button(model.captureState.phase == .recording ? "Stop Capture to Switch" : "Switch") {
                    model.switchToPendingAlternateSource()
                }
                    .disabled(model.captureState.phase == .recording || model.captureState.phase == .saving)
                    .buttonStyle(DJPrimaryButtonStyle())
                    .accessibilityIdentifier("capture.alternateSource.switch")
            }
        }
        .accessibilityIdentifier("capture.alternateSourceBanner")
    }

    private var captureConfig: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Capture")
                    .font(.system(size: DJToken.TypeSize.title, weight: .semibold))
                Spacer()
                SupportBadge(status: .manualSetup)
            }

            Text(introCopy)
                .font(.system(size: DJToken.TypeSize.body))
                .foregroundStyle(DJToken.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Mode", selection: Binding(
                get: { model.captureState.mode },
                set: { model.setCaptureMode($0) }
            )) {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Mode")
            .accessibilityIdentifier("capture.mode")

            if model.captureState.mode == .appAudio {
                appAudioPanels
            } else {
                inputDevicePanels
            }

            Panel(title: "Session", padding: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    sessionPrimaryControl

                    if showsSessionMeter {
                        levelMeter
                    }

                    Text(model.captureState.listeningSummary)
                        .font(.system(size: DJToken.TypeSize.body))
                        .foregroundStyle(
                            model.captureState.listeningState == .recoveryNeeded
                                ? DJToken.warn
                                : DJToken.mutedForeground
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(model.captureState.listeningSummary)
                        .accessibilityIdentifier("capture.listeningSummary")
                    Text(model.captureState.statusMessage)
                        .font(.system(size: DJToken.TypeSize.body))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        sessionSecondaryButtons
                        if case .needsScreenRecordingPermission = model.captureState.phase {
                            Button("Retry") { model.armAppAudioCapture() }
                                .accessibilityIdentifier("capture.retryAppAudio")
                            Button("Open Screen Recording Settings") { model.openScreenRecordingPrivacySettings() }
                                .accessibilityIdentifier("capture.openScreenRecordingSettings")
                        }
                        if model.captureState.listeningState == .recoveryNeeded,
                           model.captureState.mode == .appAudio {
                            Button("Retry") { model.armAppAudioCapture() }
                                .accessibilityIdentifier("capture.retryListening")
                            Button("Open Screen Recording Settings") { model.openScreenRecordingPrivacySettings() }
                                .accessibilityIdentifier("capture.openScreenRecordingSettings")
                        }
                        if case .failed = model.captureState.phase,
                           model.captureState.mode == .inputDevice
                            || model.captureState.statusMessage.contains("Microphone access") {
                            Button("Open Microphone Settings") { model.openMicrophonePrivacySettings() }
                                .accessibilityIdentifier("capture.openPrivacySettings")
                        }
                        if model.captureState.lastArchivedSessionID != nil {
                            Button("Open Library") { model.selectedRoute = .library }
                                .accessibilityIdentifier("capture.openLibrary")
                        }
                    }
                }
            }

            if model.captureState.mode == .inputDevice {
                Panel(title: "Hardware tips", padding: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(SupportedHardware.all.prefix(4)) { profile in
                            Text("\(profile.displayName): \(profile.captureHint)")
                                .font(.system(size: DJToken.TypeSize.secondary))
                                .foregroundStyle(DJToken.mutedForeground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("CDJs need the Mac in the USB audio path, a DJM Capture path, or a PIONEERREC folder. A mixer that never reaches the Mac is Manual Setup.")
                            .font(.system(size: DJToken.TypeSize.secondary))
                            .foregroundStyle(DJToken.warn)
                    }
                }
            } else {
                Panel(title: "Limits", padding: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("If the DJ app routes audio only to a hardware interface, App audio Capture hears silence. Use Input device Capture or folder Protection.")
                            .font(.system(size: DJToken.TypeSize.secondary))
                            .foregroundStyle(DJToken.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Folder Protection still copies recordings the DJ app writes. Source files are never moved, renamed, or deleted.")
                            .font(.system(size: DJToken.TypeSize.secondary))
                            .foregroundStyle(DJToken.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Idle silence \(model.settings.appAudioIdleSeconds)s · start hold \(model.settings.appAudioStartHoldSeconds)s · min take \(model.settings.appAudioMinDurationSeconds)s. Audio stays on this Mac.")
                            .font(.system(size: DJToken.TypeSize.secondary))
                            .foregroundStyle(DJToken.mutedForeground)
                    }
                }
            }
        }
    }

    private var introCopy: String {
        switch model.captureState.mode {
        case .appAudio:
            return "Record audio from a running DJ app even when Record/Save is off. SetCatcher uses Process Audio Tap when available, then saves after idle silence."
        case .inputDevice:
            if model.captureState.selectedDevice?.isTrustedDJHardwareFeed == true,
               model.settings.dualRoutePosture == .both || model.settings.dualRoutePosture == .inputOnly {
                return "Folder Protection copies Serato or rekordbox recordings. Input Capture records this USB output if Record was forgotten. USB MASTER REC sticks stay untouched—add Pioneer Hardware to watch PIONEERREC."
            }
            if model.selectedAppID == SupportedDJSoftware.analogMixerAppID
                || model.hasPinnedAnalogRecOut {
                return "This records the mixer rec-out, not a microphone. No tracklist is attached unless you import one. Pin the device once; after that, recording starts when audio is detected."
            }
            return "Record the master mix from a DJM USB input into your SetCatcher archive. USB MASTER REC sticks stay untouched—add Pioneer Hardware to watch PIONEERREC."
        }
    }

    @ViewBuilder
    private var appAudioPanels: some View {
        Panel(title: "Target app", padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                if model.captureState.targetApps.isEmpty {
                    Text("No supported DJ apps are running and shareable.")
                        .font(.system(size: DJToken.TypeSize.body))
                        .foregroundStyle(DJToken.mutedForeground)
                } else {
                    Picker("App", selection: Binding(
                        get: { model.captureState.selectedTargetAppID },
                        set: { if let v = $0 { model.selectCaptureTargetApp(v) } }
                    )) {
                        ForEach(model.captureState.targetApps) { app in
                            Text(app.software.displayName).tag(Optional(app.software.id))
                        }
                    }
                    .disabled(model.captureState.isWatchingOrRecording)
                    .accessibilityIdentifier("capture.targetApp")
                }
                Button("Refresh Targets") {
                    Task { await model.refreshAppAudioTargets() }
                }
                .disabled(model.captureState.isWatchingOrRecording)
                .accessibilityIdentifier("capture.refreshTargets")
            }
        }
    }

    @ViewBuilder
    private var inputDevicePanels: some View {
        Panel(title: "Input", padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                if model.captureState.devices.isEmpty {
                    Text("No audio inputs found.")
                        .font(.system(size: DJToken.TypeSize.body))
                        .foregroundStyle(DJToken.mutedForeground)
                } else {
                    Picker("Device", selection: Binding(
                        get: { model.captureState.selectedDeviceID },
                        set: { if let v = $0 { model.selectCaptureDevice(v) } }
                    )) {
                        ForEach(model.captureState.devices) { device in
                            Text(device.manufacturer.isEmpty ? device.name : "\(device.name) (\(device.manufacturer))")
                                .tag(Optional(device.id))
                        }
                    }
                    .accessibilityIdentifier("capture.devicePicker")
                }
                Button("Refresh Devices") { model.refreshAudioInputs() }
                    .accessibilityIdentifier("capture.refreshDevices")
                if (model.pendingAnalogRecOutPinning
                    || model.selectedAppID == SupportedDJSoftware.analogMixerAppID),
                   let deviceID = model.captureState.selectedDeviceID {
                    Button("Pin this rec-out") {
                        model.pinAnalogRecOut(deviceID: deviceID)
                    }
                    .buttonStyle(DJPrimaryButtonStyle())
                    .accessibilityIdentifier("capture.pinAnalogRecOut")
                }
            }
        }
    }

    private var levelMeter: some View {
        CaptureLevelMeterView(level: model.captureState.inputLevel)
    }

    private var showsSessionMeter: Bool {
        switch model.captureState.phase {
        case .watching, .recording, .armed:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var sessionPrimaryControl: some View {
        if model.captureState.phase == .recording || model.captureState.phase == .saving {
            CaptureSessionStripView(
                elapsedText: captureElapsedHHMMSS,
                sourceName: model.liveSourceDisplayName ?? "Capture",
                sizeText: model.captureStagingSizeText,
                isSaving: model.captureState.phase == .saving,
                onStop: { model.requestStopCapture() }
            )
        } else if canShowArmToggle {
            CaptureArmToggleView(
                isArmed: model.cockpitSnapshot.state.primaryDisplay == .armed,
                isCapturing: false,
                isDisabled: armToggleIsDisabled,
                disabledHint: armToggleDisabledHint,
                detail: armToggleDetail,
                onToggle: { toggleArmFromCapture() }
            )
        }
    }

    private var canShowArmToggle: Bool {
        if model.captureState.mode == .appAudio { return true }
        return usesUnattendedInput
            || model.captureState.phase == .watching
            || model.captureState.phase == .armed
    }

    private var armToggleDetail: String {
        if model.captureState.phase == .watching {
            let name = model.liveSourceDisplayName ?? "source"
            return "Watching \(name) · Will capture automatically"
        }
        return "Tap to arm protection"
    }

    private var armToggleIsDisabled: Bool {
        if model.captureState.phase == .saving || model.captureState.phase == .requestingPermission {
            return true
        }
        if model.captureState.phase == .watching {
            return false
        }
        switch model.captureState.mode {
        case .appAudio:
            return model.captureState.selectedTargetApp == nil
        case .inputDevice:
            return model.captureState.selectedDevice == nil
        }
    }

    private var armToggleDisabledHint: String? {
        if model.captureState.phase == .saving {
            return "Unavailable while the current set is saving"
        }
        if model.captureState.phase == .requestingPermission {
            return "Unavailable while SetCatcher requests access"
        }
        if model.captureState.selectedTargetApp == nil && model.captureState.mode == .appAudio {
            return "Choose a running DJ app before arming protection"
        }
        if model.captureState.selectedDevice == nil && model.captureState.mode == .inputDevice {
            return "Choose an input device before arming protection"
        }
        return nil
    }

    private var captureElapsedHHMMSS: String {
        guard let started = model.recordingStartedAt else { return "00:00:00" }
        let elapsed = max(0, Int(Date().timeIntervalSince(started)))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func toggleArmFromCapture() {
        switch model.captureState.phase {
        case .watching, .recording:
            model.requestDisarmCapture()
        default:
            if model.captureState.mode == .appAudio {
                model.armAppAudioCapture()
            } else {
                model.armInputCaptureWatching()
            }
        }
    }

    @ViewBuilder
    private var sessionSecondaryButtons: some View {
        if model.captureState.phase == .watching {
            Button("Start Capture Now") { model.startCaptureNow() }
                .accessibilityIdentifier("capture.startNow")
        }
        if !canShowArmToggle {
            sessionButtonsLegacy
        } else if model.captureState.mode == .inputDevice,
                  !usesUnattendedInput,
                  model.captureState.phase != .watching,
                  model.captureState.phase != .recording,
                  model.captureState.phase != .saving {
            Button("Start") { model.startCapture() }
                .buttonStyle(DJPrimaryButtonStyle())
                .disabled(model.captureState.devices.isEmpty || model.captureState.phase == .requestingPermission)
                .accessibilityIdentifier("capture.start")
        }
    }

    /// Legacy Arm/Disarm/Stop controls when the pill toggle is not used (manual Start path).
    @ViewBuilder
    private var sessionButtonsLegacy: some View {
        if model.captureState.isRecording || model.captureState.phase == .saving {
            Button("Stop") { model.requestStopCapture() }
                .buttonStyle(DJPrimaryButtonStyle())
                .disabled(model.captureState.phase == .saving)
                .accessibilityIdentifier("capture.stop")
        } else {
            Button("Start") { model.startCapture() }
                .buttonStyle(DJPrimaryButtonStyle())
                .disabled(model.captureState.devices.isEmpty || model.captureState.phase == .requestingPermission)
                .accessibilityIdentifier("capture.start")
        }
    }

    private var usesUnattendedInput: Bool {
        if AnalogMixerPolicy.shouldUnattendedWatch(
            pinnedDeviceID: model.settings.pinnedAnalogInputDeviceID,
            selectedDeviceID: model.captureState.selectedDeviceID,
            userDisarmedInput: false
        ) {
            return true
        }
        let hardware = model.captureState.selectedDevice?.isTrustedDJHardwareFeed == true
        switch model.settings.dualRoutePosture {
        case .both, .inputOnly:
            return hardware
        case .folderPrimaryInputOnDemand, .folderOnly:
            return false
        }
    }
}

/// A slowly pulsing status dot with a soft glow (the recording indicator). Static under
/// Reduce Motion, where the dot stays fully lit.
private struct PulsingDot: View {
    var color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .shadow(color: color.opacity(0.6), radius: 8)
            .opacity(reduceMotion ? 1 : (on ? 1 : 0.4))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

#if DEBUG
#Preview("Capture recording hero") {
    let model = AppModel()
    model.previewApplyCaptureState(CaptureUIState(
        mode: .inputDevice,
        phase: .recording,
        devices: [AudioInputDevice(id: "xz", name: "XDJ-XZ", manufacturer: "Pioneer DJ")],
        selectedDeviceID: "xz",
        inputLevel: 0.7,
        statusMessage: "Recording the XDJ-XZ input."
    ))
    model.previewSetRecordingStartedAt(Date(timeIntervalSinceNow: -2472))
    return CaptureView()
        .environmentObject(model)
        .padding()
        .frame(width: 900, height: 620)
        .preferredColorScheme(.dark)
}

#Preview("Capture idle") {
    let model = AppModel()
    model.previewApplyCaptureState(CaptureUIState(
        mode: .appAudio,
        phase: .armed,
        statusMessage: "Choose a running DJ app, then arm App audio Capture."
    ))
    return CaptureView()
        .environmentObject(model)
        .padding()
        .frame(width: 520)
}

#Preview("Capture input watching / dark") {
    let model = AppModel()
    model.previewApplyCaptureState(CaptureUIState(
        mode: .inputDevice,
        phase: .watching,
        devices: [AudioInputDevice(id: "xz", name: "XDJ-XZ", manufacturer: "Pioneer DJ")],
        selectedDeviceID: "xz",
        statusMessage: "Watching the XDJ-XZ input. Recording starts when audio is detected; idle silence saves the take automatically. Folder Protection still watches recording folders."
    ))
    return CaptureView()
        .environmentObject(model)
        .padding()
        .frame(width: 520)
        .preferredColorScheme(.dark)
}
#endif
