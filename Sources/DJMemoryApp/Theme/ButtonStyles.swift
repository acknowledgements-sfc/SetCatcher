import SwiftUI

struct DJPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DJHoverableButton(
            configuration: configuration,
            pressedBackground: DJToken.primary.opacity(0.85),
            idleBackground: DJToken.primary,
            hoverBackground: DJToken.primary.opacity(0.92),
            foreground: .white,
            border: DJToken.primary
        )
    }
}

struct DJSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DJHoverableButton(
            configuration: configuration,
            pressedBackground: DJToken.secondary,
            idleBackground: DJToken.elevated,
            hoverBackground: DJToken.secondary.opacity(0.7),
            foreground: DJToken.foreground,
            border: DJToken.border
        )
    }
}

struct DJGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DJHoverableButton(
            configuration: configuration,
            pressedBackground: DJToken.secondary.opacity(0.7),
            idleBackground: .clear,
            hoverBackground: DJToken.secondary.opacity(0.45),
            foreground: DJToken.mutedForeground,
            pressedForeground: DJToken.foreground,
            border: nil
        )
    }
}

struct DJDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DJHoverableButton(
            configuration: configuration,
            pressedBackground: DJToken.danger.opacity(0.1),
            idleBackground: .clear,
            hoverBackground: DJToken.danger.opacity(0.08),
            foreground: DJToken.danger,
            border: DJToken.border
        )
    }
}

/// Filled light-on-dark primary for hero moments (e.g. Capture's "Stop & Save").
/// White fill, near-black ink text, larger touch target than the dense controls.
struct DJHeroFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DJHeroButton(configuration: configuration, filled: true)
    }
}

/// Hollow companion to the filled hero button (e.g. Capture's "Disarm"): a hairline
/// white border over the gradient ground.
struct DJHollowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DJHeroButton(configuration: configuration, filled: false)
    }
}

private struct DJHeroButton: View {
    let configuration: ButtonStyleConfiguration
    let filled: Bool

    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 26)
            .frame(minHeight: 44)
            .background(background, in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum))
            .overlay {
                if !filled {
                    RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                        .stroke(Color.white.opacity(isHovering ? 0.32 : 0.2), lineWidth: 1)
                }
            }
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var foreground: Color {
        if filled { return DJToken.Ground.base }
        return Color.white.opacity(configuration.isPressed ? 0.55 : 0.75)
    }

    private var background: Color {
        if filled {
            return Color.white.opacity(configuration.isPressed ? 0.82 : 1)
        }
        return Color.white.opacity(configuration.isPressed ? 0.1 : (isHovering ? 0.06 : 0))
    }
}

private struct DJHoverableButton: View {
    let configuration: ButtonStyleConfiguration
    let pressedBackground: Color
    let idleBackground: Color
    let hoverBackground: Color
    let foreground: Color
    var pressedForeground: Color?
    let border: Color?

    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(.system(size: DJToken.TypeSize.body, weight: .medium))
            .foregroundStyle(
                configuration.isPressed
                    ? (pressedForeground ?? foreground)
                    : foreground
            )
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(
                backgroundFill,
                in: RoundedRectangle(cornerRadius: DJToken.Radius.control)
            )
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: DJToken.Radius.control)
                        .stroke(border, lineWidth: 1)
                }
            }
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var backgroundFill: Color {
        if configuration.isPressed {
            return pressedBackground
        }
        if isHovering {
            return hoverBackground
        }
        return idleBackground
    }
}

#Preview("Button styles") {
    HStack(spacing: 8) {
        Button("Primary") {}
            .buttonStyle(DJPrimaryButtonStyle())
        Button("Secondary") {}
            .buttonStyle(DJSecondaryButtonStyle())
        Button("Ghost") {}
            .buttonStyle(DJGhostButtonStyle())
        Button("Danger") {}
            .buttonStyle(DJDangerButtonStyle())
    }
    .padding()
    .background(DJToken.content)
}
