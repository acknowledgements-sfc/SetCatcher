import AppKit
import SwiftUI

/// Renders the menu bar status item's icon + optional label, reflecting
/// the current capture state.
///
/// Two constraints shape this implementation:
///
/// 1. **Colour**: MenuBarExtra renders the label as a template NSImage,
///    stripping all SwiftUI foregroundStyle colours to monochrome. Colour
///    must be baked in at the AppKit level before the view reaches the
///    status-item renderer.
///
/// 2. **Stability**: a `MenuBarExtra` label is an `NSStatusBarButton`, not a
///    normal SwiftUI window. Do not use `TimelineView` here — it spins CPU.
///    Opacity and label slide are ticked at ~10Hz from `AppModel`.
struct MenuBarIconView: View, Equatable {
    let state: MenuBarState
    var iconOpacity: Double = 1
    var labelSlideProgress: Double = 1

    static func == (lhs: MenuBarIconView, rhs: MenuBarIconView) -> Bool {
        lhs.state == rhs.state
            && lhs.iconOpacity == rhs.iconOpacity
            && lhs.labelSlideProgress == rhs.labelSlideProgress
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 5) {
                Image(nsImage: MenuBarIconImageCache.image(for: state))
                    .opacity(iconOpacity)
                if let label = state.label {
                    Text(label)
                        .foregroundStyle(state.labelColor)
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.1)
                        .lineLimit(1)
                        .opacity(easedSlide)
                        .offset(x: (1 - easedSlide) * -6)
                }
            }
            if state == .attentionNeeded {
                Circle()
                    .fill(DJToken.LiveState.attention)
                    .frame(width: 6, height: 6)
                    .offset(x: 1, y: -1)
                    .accessibilityIdentifier("menuBar.attentionDot")
            }
        }
        .accessibilityLabel(state.accessibilityDescription)
    }

    /// Ease-out matching the prototype's 1.35s label slide (`1 - (1-t)^3`).
    private var easedSlide: Double {
        let t = min(1, max(0, labelSlideProgress))
        return 1 - pow(1 - t, 3)
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

    /// Draws the SetCatcher mark (circle outline + 3 vertical bars, matching
    /// `assets/logomark.svg`) into a 14×14 `NSImage`, baking in `state.tint`.
    private static func renderedSymbol(for state: MenuBarState) -> NSImage {
        let size = NSSize(width: 14, height: 14)
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
