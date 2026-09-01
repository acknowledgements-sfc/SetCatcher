import SwiftUI
import SetCatcherCore

enum OnboardingAnalogPath: String {
    case booth
    case dump
}

/// Booth pin or dump-folder grant, finished inside the onboarding sheet.
struct OnboardingAnalogSetupView: View {
    @EnvironmentObject var model: AppModel
    @Binding var analogPath: OnboardingAnalogPath?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button("Booth — pin rec-out") {
                    analogPath = .booth
                    model.prepareAnalogRecOutPicker()
                }
                .buttonStyle(DJPrimaryButtonStyle())
                .opacity(analogPath == .booth || analogPath == nil ? 1 : 0.55)
                .accessibilityIdentifier("onboarding.analogBooth")

                Button("Dump folder") {
                    analogPath = .dump
                }
                .buttonStyle(DJHollowButtonStyle())
                .opacity(analogPath == .dump || analogPath == nil ? 1 : 0.55)
                .accessibilityIdentifier("onboarding.analogDump")
            }

            Text("Do not use booth, headphones, or a built-in mic. Those are not the set.")
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.warn)

            if analogPath == .booth {
                boothPicker
            }

            if analogPath == .dump {
                Button("Choose dump folder") {
                    model.chooseFolder(appID: SupportedDJSoftware.analogMixerAppID, kind: .recordings)
                }
                .buttonStyle(DJPrimaryButtonStyle())
                .accessibilityIdentifier("onboarding.analogChooseDump")
            }
        }
        .onAppear {
            if analogPath == .booth {
                model.prepareAnalogRecOutPicker()
            }
        }
    }

    @ViewBuilder
    private var boothPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let pinned = model.pinnedAnalogInputDevice {
                PathChip(path: pinned.name)
            }

            if model.captureState.devices.isEmpty {
                Text("No audio inputs found.")
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)
            } else {
                Picker("Device", selection: Binding(
                    get: { model.captureState.selectedDeviceID },
                    set: { if let value = $0 { model.selectOnboardingCaptureDevice(value) } }
                )) {
                    ForEach(model.captureState.devices) { device in
                        Text(device.manufacturer.isEmpty ? device.name : "\(device.name) (\(device.manufacturer))")
                            .tag(Optional(device.id))
                    }
                }
                .accessibilityIdentifier("onboarding.analogDevicePicker")
            }

            HStack(spacing: 8) {
                Button("Refresh Devices") {
                    model.prepareAnalogRecOutPicker()
                }
                .buttonStyle(DJHollowButtonStyle())
                .accessibilityIdentifier("onboarding.analogRefreshDevices")

                if let deviceID = model.captureState.selectedDeviceID {
                    Button("Pin this rec-out") {
                        model.pinAnalogRecOut(deviceID: deviceID)
                    }
                    .buttonStyle(DJPrimaryButtonStyle())
                    .accessibilityIdentifier("onboarding.analogChooseRecOut")
                }
            }
        }
    }
}

#Preview("Onboarding Analog booth") {
    analogBoothPreview()
}

#Preview("Onboarding Analog booth Light") {
    analogBoothPreview(colorScheme: .light)
}

#Preview("Onboarding Analog dump") {
    analogDumpPreview()
}

#Preview("Onboarding Analog dump Light") {
    analogDumpPreview(colorScheme: .light)
}

@MainActor
private func analogBoothPreview(colorScheme: ColorScheme = .dark) -> some View {
    let model = AppModel()
    model.previewApplyCaptureState(CaptureUIState(
        mode: .inputDevice,
        phase: .armed,
        devices: [AudioInputDevice(id: "focusrite", name: "Scarlett 2i2", manufacturer: "Focusrite")],
        selectedDeviceID: "focusrite",
        statusMessage: "Choose the mixer REC OUT / SESSION OUT input, then pin it."
    ))
    return OnboardingAnalogSetupView(analogPath: .constant(.booth))
        .environmentObject(model)
        .padding()
        .frame(width: 656, height: 240)
        .background(DJToken.background)
        .preferredColorScheme(colorScheme)
}

@MainActor
private func analogDumpPreview(colorScheme: ColorScheme = .dark) -> some View {
    OnboardingAnalogSetupView(analogPath: .constant(.dump))
        .environmentObject(AppModel())
        .padding()
        .frame(width: 656, height: 200)
        .background(DJToken.background)
        .preferredColorScheme(colorScheme)
}
