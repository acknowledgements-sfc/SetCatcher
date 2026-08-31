import AppKit
import SwiftUI

/// Shared design tokens for SetCatcherApp (HANDOFF.md §2).
/// Views use these names only — do not hardcode hex in view files.
enum DJToken {
    static let background = Color.djDynamic(
        light: (0xF2, 0xF2, 0xF4, 1),
        dark: (0x17, 0x17, 0x1A, 1)
    )
    static let content = Color.djDynamic(
        light: (0xFB, 0xFB, 0xFD, 1),
        dark: (0x0C, 0x0C, 0x0E, 1)
    )
    static let chrome = Color.djDynamic(
        light: (0xF6, 0xF6, 0xF8, 0.72),
        dark: (0x18, 0x18, 0x1B, 0.66)
    )
    static let foreground = Color.djDynamic(
        light: (0x1D, 0x1D, 0x1F, 1),
        dark: (0xF2, 0xF2, 0xF4, 1)
    )
    static let card = Color.djDynamic(
        light: (0xFF, 0xFF, 0xFF, 1),
        dark: (0x17, 0x18, 0x1B, 1)
    )
    static let elevated = Color.djDynamic(
        light: (0xFF, 0xFF, 0xFF, 1),
        dark: (0x20, 0x20, 0x24, 1)
    )
    static let secondary = Color.djDynamic(
        light: (0xE8, 0xE8, 0xED, 1),
        dark: (0x2A, 0x2A, 0x2E, 1)
    )
    static let muted = Color.djDynamic(
        light: (0xF2, 0xF2, 0xF7, 1),
        dark: (0x1E, 0x1E, 0x21, 1)
    )
    static let mutedForeground = Color.djDynamic(
        light: (0x6E, 0x6E, 0x73, 1),
        dark: (0x9A, 0x9A, 0xA1, 1)
    )
    static let primary = Color.djDynamic(
        light: (0x00, 0x71, 0xE3, 1),
        dark: (0x0A, 0x84, 0xFF, 1)
    )
    static let border = Color.djDynamic(
        light: (0xD8, 0xD8, 0xDD, 1),
        dark: (0x2E, 0x2E, 0x33, 1)
    )
    static let hairline = Color.djDynamic(
        light: (0x00, 0x00, 0x00, 0.08),
        dark: (0xFF, 0xFF, 0xFF, 0.07)
    )
    static let ok = Color.djDynamic(
        light: (0x1D, 0x8A, 0x4B, 1),
        dark: (0x32, 0xD7, 0x4B, 1)
    )
    static let warn = Color.djDynamic(
        light: (0xA8, 0x68, 0x00, 1),
        dark: (0xFF, 0xD6, 0x0A, 1)
    )
    static let danger = Color.djDynamic(
        light: (0xC8, 0x36, 0x2C, 1),
        dark: (0xFF, 0x45, 0x3A, 1)
    )

    enum Radius {
        static let swatch: CGFloat = 2
        static let badge: CGFloat = 3
        static let control: CGFloat = 5
        static let maximum: CGFloat = 8
    }

    enum TypeSize {
        static let micro: CGFloat = 10
        static let secondary: CGFloat = 11
        static let body: CGFloat = 12
        static let title: CGFloat = 17
        static let metric: CGFloat = 22
    }

    enum RowHeight {
        static let library: CGFloat = 36
    }

    private static let appAccents: [String: Color] = [
        "serato": Color(srgbHex: 0x4BD07A),
        "rekordbox": Color(srgbHex: 0x5B8CFF),
        "traktor": Color(srgbHex: 0xFFB02E),
        "virtualdj": Color(srgbHex: 0xC88CFF),
        "djay": Color(srgbHex: 0xFF6F5E),
        "setcatcher-capture": Color(srgbHex: 0x5B8CFF),
        "pioneer-hardware": Color(srgbHex: 0x5B8CFF),
        "analog-mixer": Color(srgbHex: 0xA86800),
        "denon-hardware": Color(srgbHex: 0xE8B800),
        "rane-hardware": Color(srgbHex: 0xFF6F5E)
    ]

    static func accent(forAppID id: String) -> Color {
        appAccents[id] ?? primary
    }

    /// Menu bar status-item semantic colors (design handoff: SetCatcher Menu Bar).
    /// Constant across appearance — matches the dark-only menu bar chrome.
    enum MenuBarStatus {
        static let watching = Color(srgbHex: 0x8A8A92)
        static let armed = Color(srgbHex: 0xE8B800)
        static let capturing = danger
        static let saved = Color(srgbHex: 0x0A84FF)
    }
}

extension DJToken {
    /// Bright, fixed signal roles for capture/status micro-labels.
    static let signalGreen = Color(srgbHex: 0x4BD07A)
    static let signalGreenBright = Color(srgbHex: 0x8EE6A8)
    static let signalGreenDeep = Color(srgbHex: 0x39B46A)
    static let recordRed = Color(srgbHex: 0xFF4D3D)
    static let recordRedBright = Color(srgbHex: 0xFF8A7A)
}

extension DJToken.TypeSize {
    static let eyebrow: CGFloat = 11
}

enum StatusTone {
    case ok
    case warn
    case danger
    case info
    case neutral

    var color: Color {
        switch self {
        case .ok:
            return DJToken.ok
        case .warn:
            return DJToken.warn
        case .danger:
            return DJToken.danger
        case .info:
            return DJToken.primary
        case .neutral:
            return DJToken.mutedForeground
        }
    }
}

struct MicroLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: DJToken.TypeSize.micro, weight: .semibold))
            .tracking(0.09 * DJToken.TypeSize.micro)
            .textCase(.uppercase)
            .foregroundStyle(DJToken.mutedForeground)
    }
}

extension View {
    func microLabelStyle() -> some View {
        modifier(MicroLabelModifier())
    }
}

private extension Color {
    typealias RGBA = (Int, Int, Int, Double)

    static func djDynamic(light: RGBA, dark: RGBA) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let rgba = isDark ? dark : light
                return NSColor(
                    srgbRed: CGFloat(rgba.0) / 255,
                    green: CGFloat(rgba.1) / 255,
                    blue: CGFloat(rgba.2) / 255,
                    alpha: rgba.3
                )
            }
        )
    }

    init(srgbHex: Int, alpha: Double = 1) {
        self.init(
            nsColor: NSColor(
                srgbRed: CGFloat((srgbHex >> 16) & 0xFF) / 255,
                green: CGFloat((srgbHex >> 8) & 0xFF) / 255,
                blue: CGFloat(srgbHex & 0xFF) / 255,
                alpha: alpha
            )
        )
    }
}

#Preview("Tokens — light") {
    TokenSwatchGrid()
        .padding()
        .frame(width: 420)
        .preferredColorScheme(.light)
}

#Preview("Tokens — dark") {
    TokenSwatchGrid()
        .padding()
        .frame(width: 420)
        .preferredColorScheme(.dark)
}

private struct TokenSwatchGrid: View {
    private let rows: [(String, Color)] = [
        ("background", DJToken.background),
        ("content", DJToken.content),
        ("chrome", DJToken.chrome),
        ("foreground", DJToken.foreground),
        ("card", DJToken.card),
        ("elevated", DJToken.elevated),
        ("secondary", DJToken.secondary),
        ("muted", DJToken.muted),
        ("mutedForeground", DJToken.mutedForeground),
        ("primary", DJToken.primary),
        ("border", DJToken.border),
        ("hairline", DJToken.hairline),
        ("ok", DJToken.ok),
        ("warn", DJToken.warn),
        ("danger", DJToken.danger),
        ("serato", DJToken.accent(forAppID: "serato")),
        ("rekordbox", DJToken.accent(forAppID: "rekordbox")),
        ("traktor", DJToken.accent(forAppID: "traktor")),
        ("virtualdj", DJToken.accent(forAppID: "virtualdj")),
        ("djay", DJToken.accent(forAppID: "djay"))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                ForEach(rows, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: DJToken.Radius.control)
                            .fill(color)
                            .frame(height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: DJToken.Radius.control)
                                    .stroke(DJToken.border, lineWidth: 1)
                            )
                        Text(name)
                            .font(.system(size: DJToken.TypeSize.secondary))
                            .foregroundStyle(DJToken.mutedForeground)
                    }
                }
            }
        }
        .background(DJToken.background)
    }
}
