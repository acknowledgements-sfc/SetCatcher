import SwiftUI
import DJMemoryCore

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

    /// DJs don't run multiple DJ apps/hardware sources at once, so DJMemory never silently
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
                Button("Switch") { model.switchToPendingAlternateSource() }
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
            .accessibilityIdentifier("capture.mode")

            if model.captureState.mode == .appAudio {
                appAudioPanels
            } else {
                inputDevicePanels
            }

            Panel(title: "Session", padding: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.captureState.listeningSummary)
                        .font(.system(size: DJToken.TypeSize.body))
                        .foregroundStyle(
                            model.captureState.listeningState == .recoveryNeeded
                                ? DJToken.warn
                                : DJToken.mutedForeground
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("capture.listeningSummary")
                    Text(model.captureState.statusMessage)
                        .font(.system(size: DJToken.TypeSize.body))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        sessionButtons
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
                        Text("Idle silence \(model.settings.appAudioIdleSeconds)s · min take \(model.settings.appAudioMinDurationSeconds)s. Audio stays on this Mac.")
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
            return "Record audio from a running DJ app even when Record/Save is off. DJMemory uses Process Audio Tap when available, then saves after idle silence."
        case .inputDevice:
            if model.captureState.selectedDevice?.isLikelyPioneerDJHardware == true,
               model.settings.dualRoutePosture == .both || model.settings.dualRoutePosture == .inputOnly {
                return "Folder Protection copies Serato or rekordbox recordings. Input Capture records this USB output if Record was forgotten. USB MASTER REC sticks stay untouched—add Pioneer Hardware to watch PIONEERREC."
            }
            return "Record the master mix from a DJM USB input into your DJMemory archive. USB MASTER REC sticks stay untouched—add Pioneer Hardware to watch PIONEERREC."
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
                levelMeter
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
                levelMeter
            }
        }
    }

    private var levelMeter: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DJToken.Radius.badge).fill(DJToken.muted)
                RoundedRectangle(cornerRadius: DJToken.Radius.badge).fill(DJToken.ok)
                    .frame(width: max(4, proxy.size.width * CGFloat(model.captureState.inputLevel)))
            }
        }
        .frame(height: 8)
        .accessibilityIdentifier("capture.levelMeter")
    }

    @ViewBuilder
    private var sessionButtons: some View {
        if model.captureState.mode == .appAudio {
            if model.captureState.isWatchingOrRecording {
                if model.captureState.isRecording || model.captureState.phase == .saving {
                    Button("Stop & Save") { model.stopCapture() }
                        .buttonStyle(DJPrimaryButtonStyle())
                        .disabled(model.captureState.phase == .saving)
                        .accessibilityIdentifier("capture.stop")
                }
                Button("Disarm") { model.disarmCapture() }
                    .disabled(model.captureState.phase == .saving)
                    .accessibilityIdentifier("capture.disarm")
            } else {
                Button("Arm") { model.armAppAudioCapture() }
                    .buttonStyle(DJPrimaryButtonStyle())
                    .disabled(model.captureState.targetApps.isEmpty || model.captureState.phase == .requestingPermission)
                    .accessibilityIdentifier("capture.arm")
            }
        } else if model.captureState.isWatchingOrRecording {
            if model.captureState.isRecording || model.captureState.phase == .saving {
                Button("Stop & Save") { model.stopCapture() }
                    .buttonStyle(DJPrimaryButtonStyle())
                    .disabled(model.captureState.phase == .saving)
                    .accessibilityIdentifier("capture.stop")
            }
            Button("Disarm") { model.disarmCapture() }
                .disabled(model.captureState.phase == .saving)
                .accessibilityIdentifier("capture.disarm")
        } else if usesUnattendedInput {
            Button("Arm") { model.armInputCaptureWatching() }
                .buttonStyle(DJPrimaryButtonStyle())
                .disabled(model.captureState.devices.isEmpty || model.captureState.phase == .requestingPermission)
                .accessibilityIdentifier("capture.arm")
        } else if model.captureState.isRecording || model.captureState.phase == .saving {
            Button("Stop") { model.stopCapture() }
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
        let pioneer = model.captureState.selectedDevice?.isLikelyPioneerDJHardware == true
        switch model.settings.dualRoutePosture {
        case .both, .inputOnly:
            return pioneer
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
