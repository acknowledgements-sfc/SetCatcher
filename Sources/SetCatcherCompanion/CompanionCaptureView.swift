import SetCatcherCore
import SwiftUI

struct CompanionCaptureView: View {
    @Bindable var model: CompanionModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(MobileDJSoftware.capture.guidance)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Capture does not silently watch other DJ apps in the background.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Input") {
                    if model.selectableAudioInputs.isEmpty {
                        Text("No inputs yet. Enable Microphone access, then pull to refresh.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Device", selection: Binding(
                            get: { model.selectedInputID ?? model.selectableAudioInputs.first?.id ?? "" },
                            set: { model.selectedInputID = $0 }
                        )) {
                            ForEach(model.selectableAudioInputs) { device in
                                Text(device.name).tag(device.id)
                            }
                        }
                        .disabled(model.isCapturing)
                        .accessibilityIdentifier("ipad.capture.inputPicker")
                    }
                }

                Section("Session") {
                    if model.isCapturing {
                        Text(timeString(model.captureElapsedSeconds))
                            .font(.largeTitle.monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("ipad.capture.elapsed")
                        Button("Stop & Archive", role: .destructive) {
                            model.stopCaptureAndArchive()
                        }
                        .accessibilityIdentifier("ipad.capture.stop")
                    } else {
                        Button("Start Capture") {
                            Task { await model.startCapture() }
                        }
                        .accessibilityIdentifier("ipad.capture.start")
                    }
                }
            }
            .navigationTitle("Capture")
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    CompanionCaptureView(model: CompanionModel())
}
