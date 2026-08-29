import AppKit
import SwiftUI

/// Renders the menu bar status item's icon + optional label, reflecting
/// the current capture state.
///
/// Two constraints shape this implementation:
///
/// 1. **Colour**: MenuBarExtra renders the label as a template NSImage,
///    stripping all SwiftUI foregroundStyle colours to monochrome. Colour
///    must be baked in at the AppKit level via NSImage.SymbolConfiguration
///    before the view reaches the status-item renderer.
///
/// 2. **Stability**: a `MenuBarExtra` label is an `NSStatusBarButton`, not a
///    normal SwiftUI window. It must not be animated or given a newly allocated
///    image during ordinary body invalidations. The artwork below is cached by
///    discrete state so AppKit receives the same image instance until the state
///    actually changes.
struct MenuBarIconView: View, Equatable {
    let state: MenuBarState

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIconImageCache.image(for: state))
            if let label = state.label {
                Text(label)
                    .foregroundStyle(state.labelColor)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
        }
        .accessibilityLabel(state.accessibilityDescription)
    }

}

@MainActor
private enum MenuBarIconImageCache {
    private static var images: [String: NSImage] = [:]

    static func image(for state: MenuBarState) -> NSImage {
        if let image = images[state.iconCacheKey] {
            return image
        }
        let image = renderedSymbol(for: state)
        images[state.iconCacheKey] = image
        return image
    }

    /// Draws the DJMemory mark (circle outline + 3 vertical bars, matching
    /// `assets/logomark.svg`) directly into an `NSImage`, baking in `state.tint`.
    /// A hand-drawn `NSImage` (rather than an SF Symbol) so the glyph matches the
    /// design handoff pixel-for-pixel; see the type doc for why color must be
    /// baked in here rather than applied via SwiftUI `foregroundStyle`.
    private static func renderedSymbol(for state: MenuBarState) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let scale = size.width / 28
        let color = NSColor(state.tint ?? .primary)

        let image = NSImage(size: size)
        image.lockFocus()
        color.setStroke()
        color.setFill()

        let circleRect = NSRect(x: 0.7 * scale, y: 0.7 * scale, width: 26.6 * scale, height: 26.6 * scale)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        circlePath.lineWidth = 1.6 * scale
        circlePath.stroke()

        // (x, yFromTop, height) in the 28×28 SVG viewBox; flipped to NSImage's
        // bottom-up coordinate space below.
        let bars: [(CGFloat, CGFloat, CGFloat)] = [
            (9, 9.5, 9),
            (13, 6.5, 15),
            (17, 11, 6)
        ]
        for (x, yFromTop, height) in bars {
            let rect = NSRect(
                x: x * scale,
                y: (28 - yFromTop - height) * scale,
                width: 2 * scale,
                height: height * scale
            )
            NSBezierPath(roundedRect: rect, xRadius: scale, yRadius: scale).fill()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
