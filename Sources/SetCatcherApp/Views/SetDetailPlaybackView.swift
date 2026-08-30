import SwiftUI

struct SetDetailPlaybackView: View {
    let sessionID: UUID
    let seed: String
    let tint: Color
    let state: PlaybackViewState
    let togglePlayback: () -> Void
    let seek: (Double) -> Void
    let retry: () -> Void
    let openArchiveFolder: () -> Void

    private var isActiveSession: Bool { state.sessionID == sessionID }
    private var activeState: PlaybackViewState { isActiveSession ? state : PlaybackViewState() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Playback")
                    .microLabelStyle()
                Spacer()
                Text("Verification only")
                    .font(.system(size: DJToken.TypeSize.secondary))
                    .foregroundStyle(DJToken.mutedForeground)
            }

            if let errorMessage = activeState.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.system(size: DJToken.TypeSize.body))
                        .foregroundStyle(DJToken.warn)
                    HStack {
                        Button("Retry", action: retry)
                            .accessibilityIdentifier("setDetail.\(sessionID).playback.retry")
                        Button("Open Archive Folder", action: openArchiveFolder)
                            .accessibilityIdentifier("setDetail.\(sessionID).playback.openArchiveFolder")
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Button(action: togglePlayback) {
                        Label(
                            activeState.isPlaying ? "Pause" : "Play",
                            systemImage: activeState.isPlaying ? "pause.fill" : "play.fill"
                        )
                    }
                    .accessibilityIdentifier("setDetail.\(sessionID).playback.toggle")

                    WaveformScrubber(
                        seed: seed,
                        tint: tint,
                        progress: activeState.progress,
                        duration: activeState.duration,
                        onSeek: seek
                    )
                    .accessibilityIdentifier("setDetail.\(sessionID).playback.scrubber")

                    Text("\(format(activeState.currentTime)) / \(format(activeState.duration))")
                        .font(.system(size: DJToken.TypeSize.secondary, design: .monospaced))
                        .foregroundStyle(DJToken.mutedForeground)
                        .monospacedDigit()
                        .frame(minWidth: 84, alignment: .trailing)
                }
            }
        }
        .padding(10)
        .background(DJToken.muted, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                .stroke(DJToken.border, lineWidth: 1)
        )
    }

    private func format(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "0:00" }
        let total = Int(time.rounded(.down))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview("Set detail playback") {
    SetDetailPlaybackView(
        sessionID: UUID(),
        seed: "Set.wav",
        tint: DJToken.primary,
        state: PlaybackViewState(isPlaying: true, currentTime: 72, duration: 3_600),
        togglePlayback: {},
        seek: { _ in },
        retry: {},
        openArchiveFolder: {}
    )
    .padding()
    .frame(width: 520)
    .background(DJToken.background)
}
