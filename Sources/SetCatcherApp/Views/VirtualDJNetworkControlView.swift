import SwiftUI
import SetCatcherCore

struct VirtualDJNetworkControlView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Control")
                        .font(.headline)
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.checkVirtualDJNetworkControl()
                } label: {
                    Label(buttonTitle, systemImage: model.isCheckingVirtualDJNetwork ? "hourglass" : "network")
                }
                .disabled(model.isCheckingVirtualDJNetwork)
                .help("Check whether VirtualDJ Network Control is reachable on this Mac.")
                .accessibilityIdentifier("virtualdj.networkControl.check")
            }

            HStack(spacing: 8) {
                Button("get_text") { model.runVirtualDJNetworkCommand(.getText) }
                    .disabled(model.isCheckingVirtualDJNetwork)
                    .accessibilityIdentifier("virtualdj.networkControl.getText")
                Button("deck") { model.runVirtualDJNetworkCommand(.getDeck) }
                    .disabled(model.isCheckingVirtualDJNetwork)
                    .accessibilityIdentifier("virtualdj.networkControl.deck")
            }

            if let commandResult = model.virtualDJNetworkCommandResult {
                Text(commandResult.reachable
                    ? "Last command \(commandResult.command.rawValue): HTTP \(commandResult.statusCode.map(String.init) ?? "?")"
                    : "Last command failed: \(commandResult.errorDescription ?? "unreachable")")
                    .font(.caption)
                    .foregroundStyle(DJToken.mutedForeground)
            }

            if let result = model.virtualDJNetworkProbeResult {
                HStack(spacing: 10) {
                    Label(result.reachable ? "Reachable" : "Not reachable", systemImage: result.reachable ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(result.reachable ? DJToken.ok : DJToken.warn)

                    Text(result.endpoint.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let statusCode = result.statusCode {
                        Text("HTTP \(statusCode)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(DJToken.card, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                .stroke(DJToken.border, lineWidth: 1)
        )
    }

    private var buttonTitle: String {
        model.isCheckingVirtualDJNetwork ? "Checking" : "Check"
    }

    private var statusText: String {
        if model.isCheckingVirtualDJNetwork {
            return "Checking the local VirtualDJ endpoint."
        }

        guard let result = model.virtualDJNetworkProbeResult else {
            return "Optional local probe for future deeper VirtualDJ support."
        }

        return result.reachable
            ? "VirtualDJ responded locally. File watching still remains the active MVP path."
            : "Not reachable. VirtualDJ may be closed or Network Control may be disabled."
    }
}
