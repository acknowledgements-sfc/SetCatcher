import SwiftUI

struct PathChip: View {
    let path: String
    var tone: StatusTone = .neutral

    private var fill: Color {
        switch tone {
        case .danger:
            return DJToken.danger.opacity(0.1)
        case .warn:
            return DJToken.warn.opacity(0.1)
        default:
            return DJToken.muted.opacity(0.7)
        }
    }

    private var stroke: Color {
        switch tone {
        case .danger:
            return DJToken.danger.opacity(0.35)
        case .warn:
            return DJToken.warn.opacity(0.35)
        default:
            return DJToken.hairline
        }
    }

    private var foreground: Color {
        switch tone {
        case .danger:
            return DJToken.danger
        case .warn:
            return DJToken.warn
        default:
            return DJToken.mutedForeground
        }
    }

    var body: some View {
        Text(path)
            .font(.system(size: DJToken.TypeSize.secondary, design: .monospaced))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .truncationMode(.head)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: DJToken.Radius.badge))
            .overlay(
                RoundedRectangle(cornerRadius: DJToken.Radius.badge)
                    .stroke(stroke, lineWidth: 1)
            )
            .help(path)
    }
}

#Preview("PathChip folder states / light") {
    VStack(alignment: .leading, spacing: 8) {
        Text("Set & reachable").microLabelStyle()
        PathChip(path: "/Users/dj/Music/Serato/_Recordings")
        Text("Not set").microLabelStyle()
        PathChip(path: "No folder selected", tone: .warn)
        Text("Set & unreachable").microLabelStyle()
        PathChip(path: "/Volumes/GIG-SSD/Recordings", tone: .danger)
        Text("Optional not set").microLabelStyle()
        PathChip(path: "History optional — not set", tone: .warn)
    }
    .padding()
    .frame(width: 360)
    .preferredColorScheme(.light)
}

#Preview("PathChip folder states / dark") {
    VStack(alignment: .leading, spacing: 8) {
        PathChip(path: "/Users/dj/Music/Serato/_Recordings")
        PathChip(path: "No folder selected", tone: .warn)
        PathChip(path: "/Volumes/GIG-SSD/Recordings", tone: .danger)
    }
    .padding()
    .frame(width: 360)
    .preferredColorScheme(.dark)
}
